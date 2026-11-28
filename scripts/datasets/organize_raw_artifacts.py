"""Materialize requested per-model raw metrics, predictions, and confusion CSVs."""

from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path


def main() -> None:
    root = Path("outputs/raw_training")
    for directory in ("metrics", "predictions", "confusion_matrices"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    for path in (root / "checkpoints").glob("*/metrics.json"):
        item = json.loads(path.read_text(encoding="utf-8"))
        if "test" not in item:
            continue
        model = item["model"]
        shutil.copy2(path, root / "metrics" / f"{model}.json")
        predictions = path.parent / "predictions.csv"
        if predictions.exists():
            shutil.copy2(predictions, root / "predictions" / f"{model}.csv")
        matrix = item["test"]["confusion_matrix"]
        with (root / "confusion_matrices" / f"{model}.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(["true_label", "predicted_authentic", "predicted_counterfeit"])
            writer.writerow(["authentic", matrix[0][0], matrix[0][1]])
            writer.writerow(["counterfeit", matrix[1][0], matrix[1][1]])
    print("Raw artifacts organized.")


if __name__ == "__main__":
    main()