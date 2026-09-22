"""Evaluate an existing raw-experiment checkpoint without retraining it."""

from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import average_precision_score, classification_report, confusion_matrix, roc_auc_score
from torch.utils.data import DataLoader

from train_pipeline import CLASS_NAMES, ManifestDataset, build_model, metrics, read_manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=Path("data/raw_training/test.csv"))
    parser.add_argument("--data-root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=32)
    args = parser.parse_args()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = build_model(args.model).to(device)
    checkpoint = torch.load(args.checkpoint, map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    loader = DataLoader(ManifestDataset(read_manifest(args.manifest), args.data_root, False), batch_size=args.batch_size, shuffle=False, num_workers=0)
    targets, probabilities, paths = [], [], []
    started = time.perf_counter()
    model.eval()
    with torch.no_grad():
        for images, labels, batch_paths in loader:
            output = model(images.to(device))
            targets.extend(labels.numpy())
            probabilities.extend(torch.softmax(output, dim=1)[:, 1].cpu().numpy())
            paths.extend(batch_paths)
    evaluation = metrics(np.asarray(targets), np.asarray(probabilities))
    result = {"model": args.model, "test": evaluation, "evaluation_seconds": time.perf_counter() - started, "checkpoint": str(args.checkpoint)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    with args.output.with_name("predictions.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "true_label", "counterfeit_probability", "prediction"])
        writer.writeheader()
        writer.writerows({"image_path": path, "true_label": CLASS_NAMES[target], "counterfeit_probability": float(probability), "prediction": CLASS_NAMES[int(probability >= 0.5)]} for path, target, probability in zip(paths, targets, probabilities))
    print(json.dumps({"model": args.model, "accuracy": evaluation["accuracy"], "f1": evaluation["f1"], "roc_auc": evaluation["roc_auc"], "seconds": result["evaluation_seconds"]}, indent=2))


if __name__ == "__main__":
    main()