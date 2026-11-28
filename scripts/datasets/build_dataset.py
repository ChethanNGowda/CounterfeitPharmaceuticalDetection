"""Build a versioned, leakage-free binary manifest from the audited labeled data."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_group(image_path: str) -> str:
    name = Path(image_path).name.lower()
    name = re.sub(r"\.(jpg|jpeg|png|bmp|webp)$", "", name)
    name = re.sub(r"\.rf\.[0-9a-f]+$", "", name)
    return re.sub(r"_(jpg|jpeg|png|bmp|webp)$", "", name)


def read_rows(path: Path, root: Path, split: str) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        image = root / row["image_path"]
        row["_split"] = split
        row["_sha256"] = sha256(image)
        row["_source_group"] = source_group(row["image_path"])
    return rows


def build(input_dir: Path, data_root: Path, output_dir: Path, report_path: Path) -> None:
    original = {
        split: read_rows(input_dir / f"{split}.csv", data_root, split)
        for split in ("train", "validation", "test")
    }
    assigned_hashes: set[str] = set()
    assigned_groups: set[str] = set()
    kept: dict[str, list[dict[str, str]]] = {split: [] for split in original}
    excluded: list[dict[str, str]] = []
    # Preserve source split priority: train, then validation, then test.
    for split in ("train", "validation", "test"):
        for row in original[split]:
            reasons = []
            if row["_sha256"] in assigned_hashes:
                reasons.append("exact_sha256_duplicate_of_earlier_split")
            if row["_source_group"] in assigned_groups:
                reasons.append("normalized_capture_group_of_earlier_split")
            if reasons:
                excluded.append({
                    "split": split,
                    "image_path": row["image_path"],
                    "label": row["label"],
                    "sha256": row["_sha256"],
                    "source_group": row["_source_group"],
                    "reasons": ";".join(reasons),
                })
                continue
            kept[split].append(row)
            assigned_hashes.add(row["_sha256"])
            assigned_groups.add(row["_source_group"])

    output_dir.mkdir(parents=True, exist_ok=True)
    for split, rows in kept.items():
        with (output_dir / f"{split}.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=["image_path", "label", "group_id"])
            writer.writeheader()
            writer.writerows({key: row[key] for key in writer.fieldnames} for row in rows)
    report = {
        "source_manifests": {split: str(input_dir / f"{split}.csv") for split in original},
        "output_manifests": {split: str(output_dir / f"{split}.csv") for split in kept},
        "policy": "Original train rows retained; validation/test rows excluded when exact SHA256 or normalized capture group was already assigned to an earlier split.",
        "counts": {"original": {split: len(rows) for split, rows in original.items()}, "kept": {split: len(rows) for split, rows in kept.items()}, "excluded": len(excluded)},
        "labels": {split: {label: sum(row["label"] == label for row in rows) for label in ("authentic", "counterfeit")} for split, rows in kept.items()},
        "excluded_images": excluded,
        "excluded_datasets": {
            "c3pi_reference": "Reference-only authentic images; no binary counterfeit label was invented.",
            "c3pi": "Raw multi-resolution exports; excluded to avoid duplicate resolutions and unlabeled binary conversion.",
            "pharmassist": "Medicine identity/classification data; Class_Label is not an authenticity label.",
        },
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"kept": report["counts"]["kept"], "excluded": len(excluded), "labels": report["labels"]}, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--data-root", type=Path, default=Path("data/processed"))
    parser.add_argument("--output-dir", type=Path, default=Path("outputs/clean_dataset"))
    parser.add_argument("--report", type=Path, default=Path("outputs/audit/clean_dataset_manifest.json"))
    args = parser.parse_args()
    build(args.input_dir, args.data_root, args.output_dir, args.report)


if __name__ == "__main__":
    main()
    raise SystemExit(0)

import pandas as pd
import os
from pathlib import Path
from ml.preprocessing.image_preprocessor import ImagePreprocessor
from ml.features.feature_extractor import FeatureExtractor
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def build_dataset():
    raw_dir = Path("data/raw")
    output_path = Path("data/processed/features.csv")
    preprocessor = ImagePreprocessor()
    extractor = FeatureExtractor()
    
    data = []
    
    # Iterate over authentic/counterfeit folders
    for label in ["authentic", "counterfeit"]:
        label_dir = raw_dir / label
        if not label_dir.exists():
            continue
            
        for img_path in label_dir.glob("*.*"):
            if img_path.suffix.lower() not in ['.jpg', '.jpeg', '.png']:
                continue
                
            try:
                img = preprocessor.preprocess(str(img_path))
                features = extractor.extract(img)
                
                row = {
                    "sample_id": img_path.stem,
                    "label": 0 if label == "authentic" else 1,
                    "image_path": str(img_path)
                }
                # Add features
                for i, name in enumerate(extractor.feature_names):
                    row[name] = features[i]
                data.append(row)
                logger.info(f"Processed: {img_path}")
            except Exception as e:
                logger.error(f"Failed to process {img_path}: {e}")
                
    df = pd.DataFrame(data)
    df.to_csv(output_path, index=False)
    logger.info(f"Dataset saved to {output_path}. Total samples: {len(df)}")

if __name__ == "__main__":
    build_dataset()
