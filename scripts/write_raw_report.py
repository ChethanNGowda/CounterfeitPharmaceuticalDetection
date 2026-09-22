"""Write the raw-data experiment comparison report from saved artifacts."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> None:
    root = Path(".")
    raw_root = root / "data" / "raw_training"
    metrics = sorted((root / "outputs" / "raw_training" / "checkpoints").glob("*/metrics.json"))
    split = json.loads((raw_root / "audit" / "raw_split_report.json").read_text(encoding="utf-8"))
    audit = json.loads((raw_root / "audit" / "raw_audit.json").read_text(encoding="utf-8"))
    lines = ["# Raw-Data Training Experiment", "", "## Dataset construction", "", f"- Raw images discovered: **{sum(audit['discovered'].values()) - audit['discovered']['c3pi_records']} image files** (counterfeit={audit['discovered']['counterfeit_files']}, C3PI={audit['discovered']['c3pi_files']}, PharmAssist={audit['discovered']['pharmassist_files']})", f"- Valid labeled candidates: **{audit['candidate_counts']['valid_hashed_candidates']}**", f"- Final unique images: **{split['final_count']}**", f"- Authentic/counterfeit: **{sum(split['label_counts'][s]['authentic'] for s in split['label_counts'])}/{sum(split['label_counts'][s]['counterfeit'] for s in split['label_counts'])}**", f"- Split counts: train={split['split_counts']['train']}, validation={split['split_counts']['validation']}, test={split['split_counts']['test']}", f"- Exact duplicate groups detected: **{len(audit['exact_duplicate_groups'])}**", f"- Near/exact perceptual-hash groups detected: **{len(audit['perceptual_hash_groups'])}**", f"- Duplicate candidates removed during construction: **{split['excluded_count']}**", "", "Mixed-label counterfeit frames were excluded because a whole-image binary label would be ambiguous. C3PI contributes one RXNAV ORIGINAL per NDC11; RXBASE/NLM and alternate resolutions were excluded. PharmAssist was excluded because Class_Label is medicine identity, not authenticity.", "", "## Model results", "", "| Model | Val accuracy | Val F1 | Test accuracy | Precision | Recall | Specificity | Test F1 | ROC-AUC | PR-AUC |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for path in metrics:
        item = json.loads(path.read_text(encoding="utf-8"))
        if "test" not in item:
            continue
        val = item.get("best_validation", {})
        validation_path = path.parent / "validation_metrics.json"
        if not val and validation_path.exists():
            val = json.loads(validation_path.read_text(encoding="utf-8")).get("test", {})
        test = item["test"]
        lines.append(f"| {item['model']} | {val.get('accuracy', 0):.4f} | {val.get('f1', 0):.4f} | {test['accuracy']:.4f} | {test['precision']:.4f} | {test['recall_sensitivity']:.4f} | {test['specificity']:.4f} | {test['f1']:.4f} | {test['roc_auc']:.4f} | {test['pr_auc']:.4f} |")
    lines.extend(["", "## Existing cleaned-data comparison", "", "| Model | Clean test accuracy | Clean test F1 | Raw test accuracy | Raw test F1 |", "|---|---:|---:|---:|---:|", "| Baseline CNN | 0.9247 | 0.8867 | see above | see above |", "| EfficientNet-B0 | 0.9974 | 0.9959 | see above | see above |", "| MobileNetV3-Large | 0.9987 | 0.9979 | see above | see above |", "", "The raw experiment changes the domain substantially: authentic C3PI RXNAV reference images dominate the authentic class, while counterfeit images come from the Roboflow/CreateML source. The high scores should therefore be interpreted as within-source/domain evaluation, not proof of real-world counterfeit detection. Cross-dataset generalization, product identity confounding, and visual-source artifacts remain important concerns.", "", "## Leakage and artifacts", "", "- Group overlap and SHA256 overlap were both zero for every split pair.", "- The original 5,172-image experiment and its checkpoints were not modified.", "- Raw checkpoints and metrics are under `outputs/raw_training/checkpoints/`.", "- Raw manifests, audit, duplicate records, and split reports are under `data/raw_training/`."])
    report = root / "outputs" / "raw_training" / "reports" / "raw_experiment_report.md"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()