"""Create a test manifest excluding only audited exact train/validation duplicates."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def create_clean_test_split(
    audit_path: Path,
    data_root: Path,
    train_manifest: Path,
    validation_manifest: Path,
    test_manifest: Path,
    output_manifest: Path,
    output_report: Path,
) -> None:
    if output_manifest.exists() or output_report.exists():
        raise FileExistsError("Refusing to overwrite an existing clean test manifest or report.")

    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    audited_test_files: dict[str, dict[str, object]] = {}
    for group in audit["exact_cross_split_duplicate_groups"]:
        group_id = group["duplicate_group"]
        for file_info in group["files"]:
            if file_info["split"] == "test":
                audited_test_files[file_info["filename"]] = {
                    "duplicate_group": group_id,
                    "other_split": file_info["other_split"],
                }

    train_rows = load_rows(train_manifest)
    validation_rows = load_rows(validation_manifest)
    test_rows = load_rows(test_manifest)
    train_hashes = {sha256(data_root / row["image_path"]) for row in train_rows}
    validation_hashes = {sha256(data_root / row["image_path"]) for row in validation_rows}

    removed: list[dict[str, object]] = []
    kept: list[dict[str, str]] = []
    for row in test_rows:
        path = data_root / row["image_path"]
        image_hash = sha256(path)
        matches = []
        if image_hash in train_hashes:
            matches.append("train")
        if image_hash in validation_hashes:
            matches.append("validation")
        audited = audited_test_files.get(path.name)
        if not audited:
            if matches:
                raise ValueError(f"Unreported exact duplicate found for {row['image_path']}: {matches}")
            kept.append(row)
            continue
        if not matches or set(matches) != {audited["other_split"]}:
            raise ValueError(f"Audit/hash mismatch for {row['image_path']}: audit={audited}, hashes={matches}")
        removed.append({
            "image_path": row["image_path"],
            "class": row["label"],
            "sha256": image_hash,
            "duplicate_group": audited["duplicate_group"],
            "leakage_category": f"test duplicate of {audited['other_split']}",
        })

    output_manifest.parent.mkdir(parents=True, exist_ok=True)
    with output_manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "label", "group_id"])
        writer.writeheader()
        writer.writerows(kept)

    clean_hashes = {sha256(data_root / row["image_path"]) for row in kept}
    remaining_train_overlap = clean_hashes & train_hashes
    remaining_validation_overlap = clean_hashes & validation_hashes
    if remaining_train_overlap or remaining_validation_overlap:
        raise ValueError("Clean test manifest still overlaps train or validation by SHA-256.")

    class_counts = Counter(row["label"] for row in kept)
    report = {
        "source_audit": str(audit_path),
        "original_test_image_count": len(test_rows),
        "removed_exact_duplicate_test_image_count": len(removed),
        "clean_test_image_count": len(kept),
        "clean_test_class_counts": {
            "authentic": class_counts["authentic"],
            "counterfeit": class_counts["counterfeit"],
        },
        "removed_by_leakage_category": dict(Counter(item["leakage_category"] for item in removed)),
        "removed_images": removed,
        "verification": {
            "all_clean_manifest_files_exist": all((data_root / row["image_path"]).is_file() for row in kept),
            "clean_test_sha256_overlaps_train": len(remaining_train_overlap),
            "clean_test_sha256_overlaps_validation": len(remaining_validation_overlap),
            "near_duplicate_candidates_removed": 0,
            "near_duplicate_policy": "Perceptual-hash candidates were intentionally retained.",
        },
    }
    markdown = [
        "# Clean Test Evaluation Split",
        "",
        "This manifest excludes only test images whose exact SHA-256 content also occurs in the original training or validation manifest.",
        "The original dataset, original split CSVs, and trained checkpoint were not modified.",
        "",
        "## Counts",
        "",
        f"- Original test image count: **{len(test_rows)}**",
        f"- Exact duplicate test images removed: **{len(removed)}**",
        f"- Clean test image count: **{len(kept)}**",
        f"- Authentic: **{class_counts['authentic']}**",
        f"- Counterfeit: **{class_counts['counterfeit']}**",
        "",
        "## Removal Categories",
        "",
    ]
    for item in removed:
        markdown.append(
            f"- `{item['image_path']}` ({item['class']}) -> **{item['leakage_category']}**, "
            f"group `{item['duplicate_group']}`"
        )
    markdown.extend([
        "",
        "## Verification",
        "",
        "- Every file referenced by `data/splits/test_clean.csv` exists.",
        "- No clean-test SHA-256 hash occurs in `data/splits/train.csv`.",
        "- No clean-test SHA-256 hash occurs in `data/splits/validation.csv`.",
        "- Near-duplicate perceptual-hash candidates were intentionally retained.",
        "- No model was retrained and no evaluation metrics were generated by this step.",
        "",
    ])
    output_report.parent.mkdir(parents=True, exist_ok=True)
    output_report.write_text("\n".join(markdown), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", default="reports/duplicate_leakage_audit.json")
    parser.add_argument("--data-root", default="data/processed")
    parser.add_argument("--train", default="data/splits/train.csv")
    parser.add_argument("--validation", default="data/splits/validation.csv")
    parser.add_argument("--test", default="data/splits/test.csv")
    parser.add_argument("--output", default="data/splits/test_clean.csv")
    parser.add_argument("--report", default="reports/clean_test_evaluation.md")
    args = parser.parse_args()
    create_clean_test_split(
        Path(args.audit), Path(args.data_root), Path(args.train), Path(args.validation),
        Path(args.test), Path(args.output), Path(args.report),
    )
    print(f"Created {args.output} and reports/clean_test_evaluation.md")


if __name__ == "__main__":
    main()