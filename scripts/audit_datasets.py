"""Audit source datasets and the labeled binary manifests without modifying them."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd
from PIL import Image

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SPLITS = ("train", "validation", "test")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_group(path: str) -> str:
    """Collapse Roboflow-renamed variants to their pre-export capture name."""
    name = Path(path).name.lower()
    name = re.sub(r"\.(jpg|jpeg|png|bmp|webp)$", "", name)
    name = re.sub(r"\.rf\.[0-9a-f]+$", "", name)
    return re.sub(r"_(jpg|jpeg|png|bmp|webp)$", "", name)


def load_manifest(path: Path, data_root: Path, split: str) -> list[dict[str, object]]:
    frame = pd.read_csv(path, dtype=str).fillna("")
    required = {"image_path", "label", "group_id"}
    missing = required - set(frame.columns)
    if missing:
        raise ValueError(f"{path} is missing columns: {sorted(missing)}")
    rows = []
    for row in frame.to_dict("records"):
        image_path = data_root / row["image_path"]
        item = {
            "split": split,
            "image_path": row["image_path"],
            "label": row["label"],
            "group_id": row["group_id"],
            "source_group": source_group(row["image_path"]),
            "exists": image_path.is_file(),
            "sha256": "",
            "readable": False,
            "width": None,
            "height": None,
        }
        if image_path.is_file():
            try:
                item["sha256"] = sha256(image_path)
                with Image.open(image_path) as image:
                    image.verify()
                    item["width"], item["height"] = image.size
                    item["readable"] = True
            except Exception as exc:  # pragma: no cover - depends on image bytes
                item["error"] = str(exc)
        rows.append(item)
    return rows


def duplicate_groups(rows: list[dict[str, object]], key: str) -> list[dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        value = row.get(key)
        if value:
            grouped[str(value)].append(row)
    return [
        {"key": value, "files": items, "splits": sorted({item["split"] for item in items})}
        for value, items in grouped.items()
        if len(items) > 1
    ]


def csv_summary(root: Path) -> dict[str, object]:
    summary = {}
    for path in sorted(root.rglob("*.csv")):
        try:
            frame = pd.read_csv(path, low_memory=False)
            summary[str(path)] = {
                "rows": len(frame),
                "columns": list(frame.columns),
                "label_like_counts": {
                    column: frame[column].value_counts(dropna=False).head(20).to_dict()
                    for column in frame.columns
                    if any(token in column.lower() for token in ("label", "class", "counterfeit", "authentic"))
                },
            }
        except Exception as exc:
            summary[str(path)] = {"error": str(exc)}
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path, default=Path("outputs/audit/dataset_audit.json"))
    args = parser.parse_args()
    root = args.root.resolve()
    data_root = root / "data" / "processed"
    manifest_root = root / "data" / "splits"
    rows = []
    for split in SPLITS:
        rows.extend(load_manifest(manifest_root / f"{split}.csv", data_root, split))

    hashes = Counter(row["sha256"] for row in rows if row["sha256"])
    cross_hashes = [group for group in duplicate_groups(rows, "sha256") if len(group["splits"]) > 1]
    cross_source_groups = [group for group in duplicate_groups(rows, "source_group") if len(group["splits"]) > 1]
    report = {
        "policy": {
            "binary_training_source": "data/splits/{train,validation,test}.csv only",
            "c3pi_reference": "excluded from binary labels; reserved for reference matching",
            "pharmassist": "excluded from binary labels; medicine identity dataset only",
            "duplicate_grouping": "SHA256 plus normalized pre-Roboflow filename group",
        },
        "environment": {"data_root": str(data_root), "manifest_root": str(manifest_root)},
        "csv_files": csv_summary(root / "data"),
        "binary": {
            "rows": len(rows),
            "split_counts": Counter(row["split"] for row in rows),
            "label_counts": Counter(row["label"] for row in rows),
            "missing_files": [row["image_path"] for row in rows if not row["exists"]],
            "unreadable_files": [row for row in rows if row["exists"] and not row["readable"]],
            "unique_sha256": len(hashes),
            "exact_duplicate_groups": duplicate_groups(rows, "sha256"),
            "cross_split_exact_duplicate_groups": cross_hashes,
            "cross_split_source_groups": cross_source_groups,
            "group_overlap_by_manifest_id": {
                f"{left}_{right}": len(
                    {row["group_id"] for row in rows if row["split"] == left}
                    & {row["group_id"] for row in rows if row["split"] == right}
                )
                for left, right in (("train", "validation"), ("train", "test"), ("validation", "test"))
            },
        },
        "datasets": {
            "counterfeit_image_count": sum(1 for path in (root / "data" / "counterfeit").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS),
            "c3pi_reference_image_count": sum(1 for path in (root / "data" / "c3pi_reference" / "images").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS),
            "c3pi_raw_image_count": sum(1 for path in (root / "data" / "c3pi").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS),
            "pharmassist_image_count": sum(1 for path in (root / "data" / "pharmassist").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS),
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, default=lambda value: dict(value)), encoding="utf-8")
    print(json.dumps({"rows": len(rows), "missing": len(report["binary"]["missing_files"]), "unreadable": len(report["binary"]["unreadable_files"]), "cross_split_exact_groups": len(cross_hashes), "cross_split_source_groups": len(cross_source_groups)}, indent=2))
    if report["binary"]["missing_files"] or report["binary"]["unreadable_files"]:
        raise SystemExit("AUDIT FAILED: missing or unreadable binary image")


if __name__ == "__main__":
    main()