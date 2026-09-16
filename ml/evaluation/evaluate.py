"""Evaluate a saved classifier on the fixed test split."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import torch
from torch.utils.data import DataLoader

from ml.evaluation.metrics import classification_metrics, save_metrics
from ml.models.transfer_learning import build_model
from ml.training.data import CLASS_NAMES, PharmaceuticalImageDataset, evaluation_transform, load_splits


def load_test_manifest(split_dir: Path, test_manifest: str | None) -> list[dict[str, str]]:
    if test_manifest is None:
        return load_splits(split_dir)["test"]
    manifest_path = Path(test_manifest)
    with manifest_path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def evaluate(args: argparse.Namespace) -> dict:
    device = torch.device("cuda" if torch.cuda.is_available() and not args.cpu else "cpu")
    checkpoint = torch.load(args.checkpoint, map_location=device, weights_only=False)
    metadata = checkpoint["metadata"]
    model = build_model(metadata["model_name"], Path(args.pretrained_checkpoint)).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    split = load_test_manifest(Path(args.split_dir), args.test_manifest)
    loader = DataLoader(PharmaceuticalImageDataset(split, Path(args.raw_dir), evaluation_transform()), batch_size=args.batch_size, shuffle=False)
    targets, predictions = [], []
    with torch.no_grad():
        for images, labels in loader:
            predictions.extend(model(images.to(device)).argmax(dim=1).cpu().tolist())
            targets.extend(labels.tolist())
    result = classification_metrics(targets, predictions, CLASS_NAMES)
    if args.output:
        save_metrics(result, Path(args.output))
    print(json.dumps(result, indent=2))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--pretrained-checkpoint", required=True)
    parser.add_argument("--raw-dir", default="data/raw")
    parser.add_argument("--split-dir", default="data/splits")
    parser.add_argument("--test-manifest", help="Explicit test CSV manifest; defaults to test.csv")
    parser.add_argument("--output")
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--cpu", action="store_true")
    evaluate(parser.parse_args())


if __name__ == "__main__":
    main()