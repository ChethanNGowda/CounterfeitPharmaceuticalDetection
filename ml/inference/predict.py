"""Unified inference engine for counterfeit pharmaceutical detection."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
from typing import Any, Optional, Union

from PIL import Image
import torch
from torch import nn
from torchvision import transforms

from ml.config import (
    CLASS_NAMES,
    DEFAULT_CONFIDENCE_THRESHOLD,
    DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
    DEFAULT_MODEL,
    IMAGE_SIZE,
    IMAGENET_MEAN,
    IMAGENET_STD,
    get_device,
)
from ml.models.transfer_learning import load_classifier, normalize_model_name
from ml.preprocessing.quality_checker import check_image_quality


def get_inference_transform() -> transforms.Compose:
    return transforms.Compose([
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
    ])


def predict(
    image_input: Union[str, Path, Image.Image, bytes, bytearray],
    model: Union[str, nn.Module] = DEFAULT_MODEL,
    checkpoint_path: Optional[Union[str, Path]] = None,
    pretrained_checkpoint: Optional[Union[str, Path]] = None,
    threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
    quality_check: bool = True,
    device: Optional[torch.device] = None,
) -> dict:
    """Run an image through image quality validation and the trained classifier."""
    dev = device or get_device()
    model_name = model if isinstance(model, str) else getattr(model, "model_name", DEFAULT_MODEL)
    norm_name = normalize_model_name(str(model_name))

    # 1. Quality screening
    if quality_check:
        quality_res = check_image_quality(image_input)
        if not quality_res.is_valid:
            return {
                "image_path": str(image_input) if isinstance(image_input, (str, Path)) else "in_memory",
                "prediction": "UNKNOWN",
                "predicted_class": "UNKNOWN",
                "authentic_probability": 0.0,
                "counterfeit_probability": 0.0,
                "confidence": 0.0,
                "status": "NEEDS MANUAL REVIEW",
                "reason": quality_res.reason,
                "probabilities": {"authentic": 0.0, "counterfeit": 0.0},
                "model_name": norm_name,
                "threshold": threshold,
                "quality": quality_res.to_dict(),
            }
    else:
        quality_res = None

    # 2. Load model if model argument is string
    if isinstance(model, str):
        classifier = load_classifier(
            model_name=norm_name,
            checkpoint_path=checkpoint_path,
            pretrained_path=pretrained_checkpoint,
            device=dev,
        )
    else:
        classifier = model.to(dev)
        classifier.eval()

    # 3. Load & preprocess image
    if isinstance(image_input, (str, Path)):
        img = Image.open(image_input).convert("RGB")
    elif isinstance(image_input, Image.Image):
        img = image_input.convert("RGB")
    elif isinstance(image_input, (bytes, bytearray)):
        img = Image.open(io.BytesIO(image_input)).convert("RGB")
    else:
        raise ValueError(f"Unsupported image type: {type(image_input).__name__}")

    transform = get_inference_transform()
    tensor = transform(img).unsqueeze(0).to(dev)

    # 4. Neural inference
    with torch.no_grad():
        output = classifier(tensor)
        if isinstance(output, tuple):
            output = output[0]
        probabilities = torch.softmax(output, dim=1)[0]

    p_auth = float(probabilities[0].item())
    p_fake = float(probabilities[1].item())
    pred_idx = int(probabilities.argmax().item())
    predicted_class = CLASS_NAMES[pred_idx]
    confidence = float(probabilities.max().item())

    # 5. Threshold routing
    if confidence >= threshold:
        status = predicted_class.upper()
        reason = None
    else:
        status = "NEEDS MANUAL REVIEW"
        reason = f"Confidence {confidence*100:.1f}% is below screening threshold {threshold*100:.1f}%"

    return {
        "image_path": str(image_input) if isinstance(image_input, (str, Path)) else "in_memory",
        "prediction": predicted_class.upper(),
        "predicted_class": predicted_class,
        "authentic_probability": round(p_auth, 4),
        "counterfeit_probability": round(p_fake, 4),
        "confidence": round(confidence, 4),
        "status": status,
        "reason": reason,
        "probabilities": {
            "authentic": round(p_auth, 4),
            "counterfeit": round(p_fake, 4),
        },
        "model_name": norm_name,
        "threshold": threshold,
        "quality": quality_res.to_dict() if quality_res else None,
    }


def predict_pipeline(
    image_input: Union[str, Path, Image.Image, bytes, bytearray],
    model: Union[str, nn.Module] = DEFAULT_MODEL,
    checkpoint_path: Optional[Union[str, Path]] = None,
    pretrained_checkpoint: Optional[Union[str, Path]] = None,
    threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
    high_threshold: float = DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
    vision_mode: str = "auto",
    vision_verifier: Optional[Any] = None,
    device: Optional[torch.device] = None,
    quality_check: bool = True,
) -> dict[str, Any]:
    """Full end-to-end pharmaceutical detection pipeline with conditional vision verification.

    Orchestrates:
    1. OpenCV Image Quality Gate (resolution, blur, brightness)
    2. EfficientNet-B0 primary neural classification
    3. Confidence-based gating policy:
       - < threshold (0.70): Suspicious / Needs Review (no automatic Qwen call)
       - threshold <= confidence < high_threshold (0.70 - 0.8999): Qwen3-VL secondary visual verification
       - >= high_threshold (0.90): High-confidence fast path (Qwen skipped in auto mode)
       - vision_mode 'always': Force secondary vision verification
       - vision_mode 'never': Skip secondary vision verification
    4. Authoritative DecisionEngine synthesis
    """
    norm_vision_mode = str(vision_mode).lower().strip()
    if norm_vision_mode not in ("auto", "always", "never"):
        raise ValueError(
            f"Invalid vision_mode '{vision_mode}'. Must be one of: 'auto', 'always', 'never'."
        )

    # 1. Primary ML Classifier + Quality Gate
    primary_res = predict(
        image_input=image_input,
        model=model,
        checkpoint_path=checkpoint_path,
        pretrained_checkpoint=pretrained_checkpoint,
        threshold=threshold,
        quality_check=quality_check,
        device=device,
    )

    quality = primary_res.get("quality") or {}
    quality_is_valid = quality.get("is_valid", True)
    primary_conf = float(primary_res.get("confidence", 0.0))

    # 2. Determine whether to run Qwen3-VL Vision Verifier
    if not quality_is_valid:
        should_run_vision = False
        secondary_reason = f"Skipped: image quality check failed ({primary_res.get('reason', 'poor quality')})"
    elif norm_vision_mode == "never":
        should_run_vision = False
        secondary_reason = "Skipped: secondary verification disabled by vision mode 'never'"
    elif norm_vision_mode == "always":
        should_run_vision = True
        secondary_reason = "Executed: forced secondary verification by vision mode 'always'"
    else:  # "auto"
        if primary_conf < threshold:
            should_run_vision = False
            secondary_reason = (
                f"Skipped: low primary confidence ({primary_conf*100:.1f}% < {threshold*100:.1f}% threshold)"
            )
        elif primary_conf < high_threshold:
            should_run_vision = True
            secondary_reason = (
                f"Executed: primary confidence ({primary_conf*100:.1f}%) within secondary review "
                f"range [{threshold*100:.1f}%, {high_threshold*100:.1f}%)"
            )
        else:
            should_run_vision = False
            secondary_reason = (
                f"Skipped: high-confidence primary prediction ({primary_conf*100:.1f}% >= {high_threshold*100:.1f}%)"
            )

    # 3. Execute secondary visual review if required
    qwen_review = None
    if should_run_vision:
        if vision_verifier is None:
            from ml.verification.qwen_verifier import QwenVisionVerifier
            vision_verifier = QwenVisionVerifier()
        try:
            qwen_review = vision_verifier.verify_image(image_input)
        except Exception as exc:
            qwen_review = {
                "available": False,
                "status": "UNAVAILABLE",
                "assessment": "UNCERTAIN",
                "confidence": "LOW",
                "image_quality": "POOR",
                "recommendation": "MANUAL REVIEW",
                "reason": f"Secondary vision verification error: {exc}",
                "reasoning": [f"Secondary vision verification error: {exc}"],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                "model_name": getattr(vision_verifier, "model_name", "qwen3-vl:4b"),
                "raw_text": "",
            }

    # 4. Authoritative synthesis via Phase 1 DecisionEngine
    from ml.verification.decision_engine import DecisionEngine

    engine = DecisionEngine(
        confidence_threshold=threshold,
        high_confidence_threshold=high_threshold,
    )
    decision = engine.evaluate(primary_result=primary_res, qwen_review=qwen_review)

    # 5. Assemble unified pipeline output
    result = dict(primary_res)
    result.update({
        "final_result": decision["final_result"],
        "needs_human_verification": decision["needs_human_verification"],
        "final_status": decision["final_status"],
        "primary_prediction": decision["primary_prediction"],
        "primary_confidence": decision["primary_confidence"],
        "primary_model": decision["primary_model"],
        "qwen": decision["qwen"],
        "secondary_executed": decision["secondary_executed"],
        "secondary_available": decision["secondary_available"],
        "secondary_assessment": decision["secondary_assessment"],
        "secondary_reason": secondary_reason,
        "vision_mode": norm_vision_mode,
        "disagreement": decision["disagreement"],
        "warning": decision.get("warning"),
        "reason": decision.get("reason"),
        "reasons": decision.get("reasons", []),
        "disclaimer": decision.get("disclaimer"),
    })
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict pharmaceutical authenticity from image.")
    parser.add_argument("image", help="Path to tablet image file")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model architecture")
    parser.add_argument("--checkpoint", default=None, help="Custom checkpoint path")
    parser.add_argument("--threshold", type=float, default=DEFAULT_CONFIDENCE_THRESHOLD, help="Confidence threshold")
    parser.add_argument("--cpu", action="store_true", help="Force CPU inference")
    parser.add_argument("--no-quality-check", action="store_true", help="Disable image quality pre-check")
    args = parser.parse_args()

    dev = torch.device("cpu") if args.cpu else get_device()
    res = predict(
        image_input=Path(args.image),
        model=args.model,
        checkpoint_path=args.checkpoint,
        threshold=args.threshold,
        quality_check=not args.no_quality_check,
        device=dev,
    )
    print(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()