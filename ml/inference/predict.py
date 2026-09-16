"""Run one image through a saved two-class classifier."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from torchvision.io import ImageReadMode, read_image

from ml.models.transfer_learning import build_model
from ml.training.data import CLASS_NAMES, evaluation_transform


def predict(image_path: Path, checkpoint_path: Path, pretrained_checkpoint: Path, threshold: float = 0.70, cpu: bool = False) -> dict:
    device = torch.device("cuda" if torch.cuda.is_available() and not cpu else "cpu")
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)
    metadata = checkpoint["metadata"]
    model = build_model(metadata["model_name"], pretrained_checkpoint).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    image = read_image(str(image_path), mode=ImageReadMode.RGB)
    tensor = evaluation_transform()(image).unsqueeze(0).to(device)
    with torch.no_grad():
        probabilities = torch.softmax(model(tensor), dim=1)[0]
    confidence, index = probabilities.max(dim=0)
    confidence_value = float(confidence.item())
    predicted_class = CLASS_NAMES[index.item()]
    return {
        "predicted_class": predicted_class,
        "confidence": confidence_value,
        "status": predicted_class if confidence_value >= threshold else "NEEDS MANUAL REVIEW",
        "probabilities": {name: float(probabilities[i].item()) for i, name in enumerate(CLASS_NAMES)},
        "model_name": metadata["model_name"],
        "threshold": threshold,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--pretrained-checkpoint", required=True)
    parser.add_argument("--threshold", type=float, default=0.70)
    parser.add_argument("--cpu", action="store_true")
    args = parser.parse_args()
    print(json.dumps(
        predict(
            Path(args.image),
            Path(args.checkpoint),
            Path(args.pretrained_checkpoint),
            threshold=args.threshold,
            cpu=args.cpu,
        ),
        indent=2,
    ))


if __name__ == "__main__":
    main()