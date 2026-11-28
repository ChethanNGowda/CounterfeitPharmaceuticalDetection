"""Audit every image under data/ and create the full-data experiment manifest."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd
from PIL import Image

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def ahash(path: Path) -> str:
    with Image.open(path) as image:
        image = image.convert("L").resize((8, 8))
        pixels = list(image.getdata())
    average = sum(pixels) / len(pixels)
    return "".join("1" if pixel >= average else "0" for pixel in pixels)


def normalized_stem(path: Path) -> str:
    value = path.stem.lower()
    value = re.sub(r"\.rf\.[0-9a-f]+$", "", value)
    return re.sub(r"[_-](jpg|jpeg|png|bmp|webp)$", "", value)


def make_annotation_map(root: Path) -> tuple[dict[str, set[str]], set[str]]:
    labels: dict[str, set[str]] = {}
    for split in ("train", "valid", "test"):
        annotation_file = root / "data" / "counterfeit" / split / "_annotations.createml.json"
        if not annotation_file.exists():
            continue
        for item in json.loads(annotation_file.read_text(encoding="utf-8")):
            labels[str(Path("counterfeit") / split / item["image"])] = {str(annotation.get("label", "")).lower() for annotation in item.get("annotations", [])}
    return labels, {path for path, values in labels.items() if values in ({"authentic"}, {"counterfeit"})}


def c3pi_map(root: Path) -> dict[str, dict[str, str]]:
    frame = pd.read_csv(root / "data/c3pi/table.csv", dtype=str).fillna("")
    mapping = {}
    for record in frame.to_dict("records"):
        for column in ("RXNAV ORIGINAL", "RXNAV 1024", "RXNAV 800", "RXNAV 600", "RXNAV 300", "RXNAV 120", "RXBASE ORIGINAL", "RXBASE 1024", "RXBASE 800", "RXBASE 600", "RXBASE 300", "RXBASE 120"):
            relative = record.get(column, "")
            if relative:
                mapping[str(Path("c3pi") / relative)] = {"medicine_id": record.get("ndc11", ""), "rxcui": record.get("rxcui", ""), "medicine_name": record.get("name", ""), "variant": column, "canonical": "true" if column == "RXNAV ORIGINAL" else "false"}
    return mapping


def classify(path: Path, root: Path, annotations: dict[str, set[str]], c3pi: dict[str, dict[str, str]]) -> dict[str, str]:
    relative = path.relative_to(root).as_posix()
    item = {"image_path": relative, "source_dataset": "unknown", "label": "", "data_role": "unknown", "group_id": normalized_stem(path), "medicine_id": "", "rxcui": "", "medicine_name": "", "label_evidence": "", "status": "candidate", "exclusion_reason": ""}
    if relative.startswith("data/"):
        relative = relative[5:]
    if relative in annotations:
        labels = annotations[relative]
        item["source_dataset"] = "counterfeit"
        item["group_id"] = f"counterfeit:{normalized_stem(path)}"
        if labels == {"authentic"} or labels == {"counterfeit"}:
            item.update(label=next(iter(labels)), data_role="supervised", label_evidence="CreateML image-level annotation")
        else:
            item.update(data_role="unknown", label_evidence="mixed or missing CreateML image annotation", exclusion_reason="ambiguous_whole_image_label")
        return item
    if relative.startswith("c3pi/") and relative in c3pi:
        metadata = c3pi[relative]
        item.update(source_dataset="c3pi", label="authentic", data_role="self_supervised_reference" if metadata["canonical"] == "true" else "duplicate", group_id=f"c3pi:ndc11:{metadata['medicine_id']}", medicine_id=metadata["medicine_id"], rxcui=metadata["rxcui"], medicine_name=metadata["medicine_name"], label_evidence="C3PI RXNAV reference metadata", exclusion_reason="alternate_resolution_or_rxbase_copy" if metadata["canonical"] != "true" else "")
        return item
    if relative.startswith("c3pi_reference/"):
        filename = path.name
        item.update(source_dataset="c3pi_reference", label="authentic", data_role="self_supervised_reference", label_evidence="C3PI reference collection", group_id=f"c3pi_reference:{filename.rsplit('_RXNAVIMAGE', 1)[0]}")
        return item
    if relative.startswith("pharmassist/"):
        item.update(source_dataset="pharmassist", data_role="self_supervised_unknown", label_evidence="Class_Label is medicine identity, not authenticity", group_id=f"pharmassist:{normalized_stem(path)}")
        return item
    if relative.startswith("processed/") or relative.startswith("splits/") or relative.startswith("raw_training/"):
        item.update(source_dataset="derived_project", data_role="duplicate", exclusion_reason="derived_or_prior_experiment_copy")
    return item


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output-root", type=Path, default=Path("data/full_training"))
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output_root
    output.mkdir(parents=True, exist_ok=True)
    annotations, _ = make_annotation_map(root)
    c3pi = c3pi_map(root)
    image_paths = sorted(path for path in (root / "data").rglob("*") if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS)
    rows, errors = [], []
    for path in image_paths:
        item = classify(path, root, annotations, c3pi)
        try:
            item["sha256"] = sha256(path)
            item["perceptual_hash"] = ahash(path)
            with Image.open(path) as image:
                item["width"], item["height"] = image.size
                image.verify()
            item["readable"] = "true"
        except Exception as exc:
            item.update(readable="false", status="corrupt", exclusion_reason="corrupt_or_unreadable", error=str(exc))
            errors.append(item)
        rows.append(item)
    exact = defaultdict(list)
    for row in rows:
        if row.get("sha256"):
            exact[row["sha256"]].append(row["image_path"])
    for paths in exact.values():
        if len(paths) > 1:
            for image_path in paths[1:]:
                row = next(item for item in rows if item["image_path"] == image_path)
                if row["data_role"] != "supervised":
                    row["status"], row["data_role"], row["exclusion_reason"] = "duplicate", "duplicate", "exact_sha256_duplicate"
    fields = ["image_path", "source_dataset", "label", "data_role", "group_id", "medicine_id", "rxcui", "medicine_name", "label_evidence", "status", "exclusion_reason", "sha256", "perceptual_hash", "width", "height", "readable"]
    with (output / "all_images_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    (output / "audit").mkdir(exist_ok=True)
    report = {"total_images_discovered": len(rows), "source_counts": Counter(row["source_dataset"] for row in rows), "role_counts": Counter(row["data_role"] for row in rows), "label_counts": Counter(row["label"] for row in rows if row["label"]), "readability": Counter(row.get("readable") for row in rows), "exact_duplicate_groups": sum(len(paths) > 1 for paths in exact.values()), "exact_duplicate_images_beyond_first": sum(len(paths) - 1 for paths in exact.values() if len(paths) > 1), "corrupt_images": len(errors)}
    (output / "audit" / "full_data_audit.json").write_text(json.dumps(report, indent=2, default=lambda value: dict(value)), encoding="utf-8")
    print(json.dumps(report, indent=2, default=lambda value: dict(value)))
    if errors:
        raise SystemExit("AUDIT FAILED: corrupt images found")


if __name__ == "__main__":
    main()