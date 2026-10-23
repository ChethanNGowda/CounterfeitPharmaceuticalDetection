
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
    """Create the preprocessing transform used by the classifier."""
    return transforms.Compose(
        [
            transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )


def predict(
    image_input: Union[str, Path, Image.Image, bytes, bytearray],
    model: Union[str, nn.Module] = DEFAULT_MODEL,
    checkpoint_path: Optional[Union[str, Path]] = None,
    pretrained_checkpoint: Optional[Union[str, Path]] = None,
    threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
    quality_check: bool = True,
    device: Optional[torch.device] = None,
) -> dict:
    """Validate image quality and run the trained classifier."""
    dev = device or get_device()

    model_name = (
        model
        if isinstance(model, str)
        else getattr(model, "model_name", DEFAULT_MODEL)
    )
    norm_name = normalize_model_name(str(model_name))

    # 1. Quality screening.
    # Never classify an image that fails the quality gate.
    if quality_check:
        quality_res = check_image_quality(image_input)

        if not quality_res.is_valid:
            quality_reason = (
                quality_res.reason
                or "Image failed the image-quality check."
            )

            return {
                "image_path": (
                    str(image_input)
                    if isinstance(image_input, (str, Path))
                    else "in_memory"
                ),
                "prediction": "UNKNOWN",
                "predicted_class": "UNKNOWN",
                "authentic_probability": 0.0,
                "counterfeit_probability": 0.0,
                "confidence": 0.0,
                "status": "NEEDS MANUAL REVIEW",
                "reason": quality_reason,
                "probabilities": {
                    "authentic": 0.0,
                    "counterfeit": 0.0,
                },
                "model_name": norm_name,
                "threshold": threshold,
                "quality": quality_res.to_dict(),
                "needs_human_verification": True,
                "final_result": "SUSPICIOUS / NEEDS VERIFICATION",
                "final_status": "NEEDS MANUAL REVIEW",
                "warning": (
                    "The image did not pass quality screening. "
                    "No authenticity classification was performed. "
                    "Upload a clearer image and seek manual verification."
                ),
            }
    else:
        quality_res = None

    # 2. Load the model.
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

    # 3. Load and preprocess the image.
    if isinstance(image_input, (str, Path)):
        with Image.open(image_input) as source_image:
            img = source_image.convert("RGB")
    elif isinstance(image_input, Image.Image):
        img = image_input.convert("RGB")
    elif isinstance(image_input, (bytes, bytearray)):
        with Image.open(io.BytesIO(image_input)) as source_image:
            img = source_image.convert("RGB")
    else:
        raise ValueError(
            f"Unsupported image type: {type(image_input).__name__}"
        )

    transform = get_inference_transform()
    tensor = transform(img).unsqueeze(0).to(dev)

    # 4. Neural inference.
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

    # 5. Confidence threshold routing.
    if confidence >= threshold:
        status = predicted_class.upper()
        reason = None
    else:
        status = "NEEDS MANUAL REVIEW"
        reason = (
            f"Confidence {confidence * 100:.1f}% is below "
            f"screening threshold {threshold * 100:.1f}%."
        )

    return {
        "image_path": (
            str(image_input)
            if isinstance(image_input, (str, Path))
            else "in_memory"
        ),
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
    """Run image screening, classification and decision-engine verification.

    Pipeline:
    1. Image-quality validation.
    2. Primary neural classification.
    3. Conditional Qwen vision verification.
    4. Decision-engine synthesis.
    5. Visual feature analysis.
    """
    norm_vision_mode = str(vision_mode).lower().strip()

    if norm_vision_mode not in ("auto", "always", "never"):
        raise ValueError(
            f"Invalid vision_mode '{vision_mode}'. "
            "Must be 'auto', 'always', or 'never'."
        )

    # 1. Primary classifier and image-quality gate.
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

    # 2. Decide whether secondary vision verification should run.
    if not quality_is_valid:
        should_run_vision = False
        quality_reason = (
            quality.get("reason")
            or primary_res.get("reason")
            or "Poor image quality."
        )
        secondary_reason = (
            f"Skipped: image quality check failed ({quality_reason})"
        )
    elif norm_vision_mode == "never":
        should_run_vision = False
        secondary_reason = (
            "Skipped: secondary verification disabled by vision mode "
            "'never'."
        )
    elif norm_vision_mode == "always":
        should_run_vision = True
        secondary_reason = (
            "Executed: forced secondary verification by vision mode "
            "'always'."
        )
    else:
        if primary_conf < threshold:
            should_run_vision = False
            secondary_reason = (
                f"Skipped: low primary confidence "
                f"({primary_conf * 100:.1f}% < "
                f"{threshold * 100:.1f}% threshold)."
            )
        elif primary_conf < high_threshold:
            should_run_vision = True
            secondary_reason = (
                f"Executed: primary confidence "
                f"({primary_conf * 100:.1f}%) within secondary "
                f"review range [{threshold * 100:.1f}%, "
                f"{high_threshold * 100:.1f}%)."
            )
        else:
            should_run_vision = False
            secondary_reason = (
                f"Skipped: high-confidence primary prediction "
                f"({primary_conf * 100:.1f}% >= "
                f"{high_threshold * 100:.1f}%)."
            )

    # 3. Run secondary vision review if required.
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
                "reasoning": [
                    f"Secondary vision verification error: {exc}"
                ],
                "needs_human_verification": True,
                "warning": (
                    "Secondary AI verification unavailable. "
                    "Manual review is required."
                ),
                "model_name": getattr(
                    vision_verifier, "model_name", "qwen3.5:4b"
                ),
                "raw_text": "",
            }

    # 4. Authoritative synthesis through the DecisionEngine.
    from ml.verification.decision_engine import DecisionEngine

    engine = DecisionEngine(
        confidence_threshold=threshold,
        high_confidence_threshold=high_threshold,
    )

    decision = engine.evaluate(
        primary_result=primary_res,
        qwen_review=qwen_review,
    )

    # 5. Visual feature analysis.
    try:
        from ml.inference.visual_inspector import analyze_visual_features

        visual_analysis = analyze_visual_features(image_input)
    except Exception as vis_exc:
        visual_analysis = {
            "error": f"Visual analysis unavailable: {vis_exc}"
        }

    # 6. Assemble unified pipeline output.
    if decision["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION":
        effective_status = "NEEDS MANUAL REVIEW"
    else:
        effective_status = primary_res.get(
            "status",
            primary_res.get("prediction", "AUTHENTIC"),
        )

    result = dict(primary_res)

    result.update(
        {
            "status": effective_status,
            "final_result": decision["final_result"],
            "needs_human_verification": decision[
                "needs_human_verification"
            ],
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
            "visual_analysis": visual_analysis,
        }
    )

    # Final safety normalization: if quality screening failed, no model label
    # may be exposed as the screening prediction, regardless of what the
    # decision engine or downstream API serializer returned earlier.
    if not quality_is_valid:
        quality_reason = (
            quality.get("reason")
            or primary_res.get("reason")
            or "Image failed the quality check."
        )
        result.update(
            {
                "prediction": "UNKNOWN",
                "predicted_class": "UNKNOWN",
                "confidence": 0.0,
                "authentic_probability": 0.0,
                "counterfeit_probability": 0.0,
                "probabilities": {"authentic": 0.0, "counterfeit": 0.0},
                "status": "NEEDS MANUAL REVIEW",
                "final_result": "SUSPICIOUS / NEEDS VERIFICATION",
                "final_status": "NEEDS MANUAL REVIEW",
                "needs_human_verification": True,
                "primary_prediction": "UNKNOWN",
                "primary_confidence": 0.0,
                "qwen": {
                    "available": False,
                    "status": "SKIPPED",
                    "assessment": "SKIPPED",
                    "confidence": 0.0,
                    "reasoning": ["Skipped because the image failed quality screening."],
                    "needs_human_verification": False,
                    "warning": "Secondary AI verification was not executed because image quality failed.",
                    "error": None,
                    "image_quality": "POOR",
                    "recommendation": "RETAKE IMAGE",
                    "model_name": None,
                    "raw_text": None,
                },
                "secondary_executed": False,
                "secondary_available": False,
                "secondary_assessment": "SKIPPED",
                "secondary_reason": f"Skipped: image quality check failed ({quality_reason})",
                "disagreement": False,
                "warning": f"Image quality check failed: {quality_reason}. Upload a clearer image; no authenticity verdict was issued.",
                "reason": f"Image quality check failed: {quality_reason}",
                "reasons": [f"Image quality check failed: {quality_reason}"],
            }
        )

    return result


def main() -> None:
    """Run prediction from the command line."""
    parser = argparse.ArgumentParser(
        description="Predict pharmaceutical authenticity from an image."
    )
    parser.add_argument("image", help="Path to medicine image")
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help="Model architecture",
    )
    parser.add_argument(
        "--checkpoint",
        default=None,
        help="Custom checkpoint path",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_CONFIDENCE_THRESHOLD,
        help="Confidence threshold",
    )
    parser.add_argument(
        "--cpu",
        action="store_true",
        help="Force CPU inference",
    )
    parser.add_argument(
        "--no-quality-check",
        action="store_true",
        help="Disable image-quality pre-check",
    )

    args = parser.parse_args()

    dev = torch.device("cpu") if args.cpu else get_device()

    result = predict(
        image_input=Path(args.image),
        model=args.model,
        checkpoint_path=args.checkpoint,
        threshold=args.threshold,
        quality_check=not args.no_quality_check,
        device=dev,
    )

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
