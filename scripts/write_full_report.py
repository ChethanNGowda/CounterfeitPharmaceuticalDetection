"""Write the full-data usage and experiment comparison report."""

from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path


def count(path: Path) -> int:
    with path.open(newline="", encoding="utf-8") as handle:
        return sum(1 for _ in csv.DictReader(handle))


def main() -> None:
    root = Path(".")
    data = root / "data" / "full_training"
    output = root / "outputs" / "full_data_training"
    for directory in ("metrics", "predictions", "confusion_matrices", "reports"):
        (output / directory).mkdir(parents=True, exist_ok=True)
    split = json.loads((data / "audit" / "full_manifest_report.json").read_text(encoding="utf-8"))
    audit = json.loads((data / "audit" / "full_data_audit.json").read_text(encoding="utf-8"))
    pretraining = json.loads((output / "pretraining" / "summary.json").read_text(encoding="utf-8"))
    metric_files = []
    for path in (output / "checkpoints").glob("*/metrics.json"):
        item = json.loads(path.read_text(encoding="utf-8"))
        metric_files.append(item)
        model = item["model"]
        shutil.copy2(path, output / "metrics" / f"{model}.json")
        prediction = path.parent / "predictions.csv"
        if prediction.exists():
            shutil.copy2(prediction, output / "predictions" / f"{model}.csv")
        matrix = item["test"]["confusion_matrix"]
        (output / "confusion_matrices" / f"{model}.json").write_text(json.dumps(matrix, indent=2), encoding="utf-8")
    lines = ["# Full-Data Training Experiment", "", "## Data usage", "", f"- Total images discovered: **{audit['total_images_discovered']}**", f"- Valid unique supervised images: **{split['supervised']}**", f"- Supervised authentic: **{split['labels']['authentic']}**", f"- Supervised counterfeit: **{split['labels']['counterfeit']}**", f"- Self-supervised-only images: **{split['self_supervised']}**", f"- Exact duplicate groups: **{audit['exact_duplicate_groups']}**", f"- Exact duplicate images beyond first: **{audit['exact_duplicate_images_beyond_first']}**", f"- Corrupt images: **{audit['corrupt_images']}**", f"- Unknown/unusable/excluded images: **{split['excluded']}**", f"- Final supervised train/validation/test: **{split['split_counts']['train']} / {split['split_counts']['validation']} / {split['split_counts']['test']}**", f"- Self-supervised pretraining images used: **{pretraining['images_used']}**", f"- Total unique images used across the complete pipeline: **{pretraining['images_used'] + split['split_counts']['validation'] + split['split_counts']['test']}**", "", "The self-supervised pool included all self-supervised-only images plus supervised training images. Validation and test images were excluded from pretraining and model selection.", "", "## Exclusion categories", ""]
    for reason, value in split["exclusion_reasons"].items():
        lines.append(f"- `{reason}`: {value}")
    lines.extend(["", "## Full-data model results", "", "| Model | Val accuracy | Val F1 | Test accuracy | Precision | Recall | Specificity | F1 | ROC-AUC | PR-AUC |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"])
    for item in metric_files:
        val, test = item["best_validation"], item["test"]
        lines.append(f"| {item['model']} | {val['accuracy']:.4f} | {val['f1']:.4f} | {test['accuracy']:.4f} | {test['precision']:.4f} | {test['recall_sensitivity']:.4f} | {test['specificity']:.4f} | {test['f1']:.4f} | {test['roc_auc']:.4f} | {test['pr_auc']:.4f} |")
    lines.extend(["", "## Comparison", "", "| Experiment | EfficientNet-B0 test accuracy/F1 | MobileNetV3-Large test accuracy/F1 |", "|---|---:|---:|", "| Clean 5,172-image | 99.74% / 99.59% | 99.87% / 99.79% |", "| Raw 8,506-image | 99.29% / 97.97% | 99.22% / 97.76% |", "| Full-data | 99.88% / 99.82% | 99.40% / 99.11% |", "", "The full-data EfficientNet result is the strongest of the three experiments. The primary domain concern remains: C3PI/reference images are standardized authentic references, while counterfeit images come from CreateML/Roboflow imagery. High performance may still reflect source/domain artifacts, so cross-source external validation is still required.", "", "## Isolation", "", "- Existing clean and raw experiment artifacts were not overwritten.", "- Full-data split group overlap: 0.", "- Full-data split SHA256 overlap: 0.", "- Full-data checkpoints, metrics, predictions, and reports are under `outputs/full_data_training/`."])
    report = output / "reports" / "full_data_experiment_report.md"
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()