"""Prepare unambiguous CreateML object annotations for image classification."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image

CLASS_NAMES = ("authentic", "counterfeit")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SOURCE_SPLITS = ("train", "valid", "test")
OUTPUT_SPLITS = {"train": "train", "valid": "valid", "test": "test"}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_split(source_root: Path, source_split: str) -> dict:
    split_root = source_root / source_split
    annotation_path = split_root / "_annotations.createml.json"
    records = json.loads(annotation_path.read_text(encoding="utf-8"))
    image_files = {
        path.name: path
        for path in split_root.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    }
    prepared = []
    ambiguous = []
    annotated_names = set()
    hashes = defaultdict(list)
    annotation_counts = Counter()

    for record in records:
        image_name = record["image"]
        annotated_names.add(image_name)
        image_path = image_files.get(image_name)
        if image_path is None:
            raise FileNotFoundError(f"Annotation has no image file: {source_split}/{image_name}")
        with Image.open(image_path) as image:
            image.verify()

        labels = [annotation["label"].strip().lower() for annotation in record.get("annotations", [])]
        annotation_counts.update(labels)
        label_set = set(labels)
        if label_set == {"authentic"} or label_set == {"counterfeit"}:
            label = next(iter(label_set))
            prepared.append({
                "source_image": image_name,
                "label": label,
                "annotation_count": len(labels),
                "sha256": _sha256(image_path),
                "source_path": str(image_path),
            })
            hashes[prepared[-1]["sha256"]].append(image_name)
        else:
            ambiguous.append({
                "image": image_name,
                "labels": sorted(label_set),
                "annotation_count": len(labels),
            })

    unannotated = sorted(set(image_files) - annotated_names)
    return {
        "records": records,
        "image_files": image_files,
        "prepared": prepared,
        "ambiguous": ambiguous,
        "unannotated": unannotated,
        "hashes": hashes,
        "annotation_counts": dict(annotation_counts),
    }


def _write_split_csv(records: list[dict[str, str]], path: Path, output_split: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "label", "group_id"])
        writer.writeheader()
        for record in records:
            writer.writerow({
                "image_path": f"{output_split}/{record['label']}/{record['source_image']}",
                "label": record["label"],
                "group_id": f"{output_split}:{Path(record['source_image']).stem}",
            })


def prepare_dataset(source_root: Path, output_root: Path, split_root: Path, report_path: Path) -> dict:
    audits = {split: _load_split(source_root, split) for split in SOURCE_SPLITS}
    output_root.mkdir(parents=True, exist_ok=True)
    prepared_by_split = {}

    for source_split, audit in audits.items():
        output_split = OUTPUT_SPLITS[source_split]
        prepared_by_split[source_split] = audit["prepared"]
        for record in audit["prepared"]:
            destination = output_root / output_split / record["label"] / record["source_image"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(record["source_path"], destination)

        csv_name = "validation.csv" if source_split == "valid" else f"{source_split}.csv"
        _write_split_csv(audit["prepared"], split_root / csv_name, output_split)

    hash_locations = defaultdict(list)
    for source_split, audit in audits.items():
        for record in audit["prepared"]:
            hash_locations[record["sha256"]].append((source_split, record["source_image"], record["label"]))
        for image_name in audit["unannotated"]:
            image_path = audit["image_files"][image_name]
            hash_locations[_sha256(image_path)].append((source_split, image_name, "unannotated"))

    cross_split_duplicates = [
        locations for locations in hash_locations.values()
        if len({location[0] for location in locations}) > 1
    ]
    within_split_duplicates = [
        locations for locations in hash_locations.values()
        if len({location[0] for location in locations}) == 1 and len(locations) > 1
    ]
    report = {
        "source_root": str(source_root),
        "output_root": str(output_root),
        "source_split_annotation_records": {
            split: len(audits[split]["records"]) for split in SOURCE_SPLITS
        },
        "source_split_annotation_counts": {
            split: sum(audits[split]["annotation_counts"].values()) for split in SOURCE_SPLITS
        },
        "source_split_image_files": {
            split: len(audits[split]["image_files"]) for split in SOURCE_SPLITS
        },
        "prepared_split_image_counts": {
            split: len(prepared_by_split[split]) for split in SOURCE_SPLITS
        },
        "prepared_split_class_counts": {
            split: {
                class_name: sum(record["label"] == class_name for record in prepared_by_split[split])
                for class_name in CLASS_NAMES
            }
            for split in SOURCE_SPLITS
        },
        "ambiguous_mixed_label_images": {
            split: audits[split]["ambiguous"] for split in SOURCE_SPLITS
        },
        "unannotated_images": {
            split: audits[split]["unannotated"] for split in SOURCE_SPLITS
        },
        "cross_split_content_duplicate_groups": cross_split_duplicates,
        "within_split_content_duplicate_groups": within_split_duplicates,
        "policy": {
            "included": "Only images whose annotations all have one supported label.",
            "excluded": "Mixed-label images and image files without annotations.",
            "split_preservation": "Original train/valid/test membership is preserved.",
        },
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--output-root", default="data/processed")
    parser.add_argument("--split-root", default="data/splits")
    parser.add_argument("--report", default="data/metadata/createml_audit.json")
    args = parser.parse_args()
    report = prepare_dataset(
        Path(args.source_root),
        Path(args.output_root),
        Path(args.split_root),
        Path(args.report),
    )
    print(json.dumps({
        "prepared_split_image_counts": report["prepared_split_image_counts"],
        "prepared_split_class_counts": report["prepared_split_class_counts"],
        "cross_split_duplicate_groups": len(report["cross_split_content_duplicate_groups"]),
        "within_split_duplicate_groups": len(report["within_split_content_duplicate_groups"]),
    }, indent=2))


if __name__ == "__main__":
    main()