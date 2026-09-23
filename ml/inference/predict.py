"""Unified inference engine for counterfeit pharmaceutical detection."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Optional, Union

from PIL import Image
import torch
from torch import nn
from torchvision import transforms

from ml.config import (
    CLASS_NAMES,
    DEFAULT_CONFIDENCE_THRESHOLD,
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
    image_input: Union[str, Path, Image.Image],
    model: Union[str, nn.Module] = DEFAULT_MODEL,
    checkpoint_path: Optional[Union[str, Path]] = None,
    pretrained_checkpoint: Optional[Union[str, Path]] = None,
    threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
    quality_check: bool = True,
    device: Optional[torch.device] = None,
) -> dict:
    """Run an image through image quality validation and the trained classifier."""
    dev = device or get_device()
    model_name = model if isinstance(model, str) else getattr(model, "model_name", "custom_model")
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