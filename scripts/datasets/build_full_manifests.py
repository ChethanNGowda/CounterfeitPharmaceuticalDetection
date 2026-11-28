"""Repair audited roles and create full-data supervised/self-supervised manifests."""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd


FIELDS = ["image_path", "source_dataset", "label", "data_role", "group_id", "medicine_id", "rxcui", "medicine_name", "label_evidence", "status", "exclusion_reason", "sha256", "perceptual_hash", "width", "height", "readable"]


def read(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def stem(value: str) -> str:
    name = Path(value).stem.lower()
    if ".rf." in name:
        name = name.split(".rf.", 1)[0]
    return name


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output-root", type=Path, default=Path("data/full_training"))
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    output = args.output_root
    rows = read(output / "all_images_manifest.csv")
    annotation_map = {}
    for split in ("train", "valid", "test"):
        path = args.root / "data" / "counterfeit" / split / "_annotations.createml.json"
        for item in json.loads(path.read_text(encoding="utf-8")):
            annotation_map[f"data/counterfeit/{split}/{item['image']}"] = {str(annotation.get("label", "")).lower() for annotation in item.get("annotations", [])}
    c3pi = pd.read_csv(args.root / "data/c3pi/table.csv", dtype=str).fillna("")
    c3pi_map = {}
    for record in c3pi.to_dict("records"):
        for column in ("RXNAV ORIGINAL", "RXNAV 1024", "RXNAV 800", "RXNAV 600", "RXNAV 300", "RXNAV 120", "RXBASE ORIGINAL", "RXBASE 1024", "RXBASE 800", "RXBASE 600", "RXBASE 300", "RXBASE 120"):
            relative = record.get(column, "")
            if relative:
                c3pi_map[f"data/c3pi/{relative}"] = (record, column == "RXNAV ORIGINAL")
    reference_map = {}
    metadata = pd.read_csv(args.root / "data/c3pi_reference/metadata.csv", dtype=str).fillna("")
    for record in metadata.to_dict("records"):
        reference_map[record["image"]] = record
    excluded = []
    for row in rows:
        path = row["image_path"]
        row.update(label="", data_role="unknown", source_dataset="unknown", label_evidence="", exclusion_reason="", status="candidate")
        if path in annotation_map:
            labels = annotation_map[path]
            row.update(source_dataset="counterfeit", group_id=f"counterfeit:{stem(path)}", label_evidence="CreateML image-level annotation")
            if labels in ({"authentic"}, {"counterfeit"}):
                row.update(label=next(iter(labels)), data_role="supervised")
            else:
                row.update(status="excluded", exclusion_reason="ambiguous_whole_image_label")
        elif path in c3pi_map:
            record, canonical = c3pi_map[path]
            row.update(source_dataset="c3pi", label="authentic", medicine_id=record["ndc11"], rxcui=record["rxcui"], medicine_name=record["name"], group_id=f"c3pi:ndc11:{record['ndc11']}", label_evidence="C3PI reference metadata")
            row.update(data_role="self_supervised_reference" if canonical else "duplicate", exclusion_reason="alternate_resolution_or_rxbase_copy" if not canonical else "")
        elif path.startswith("data/c3pi_reference/"):
            record = reference_map.get(Path(path).name, {})
            row.update(source_dataset="c3pi_reference", label="authentic", data_role="self_supervised_reference", medicine_id=record.get("ndc11", ""), rxcui=record.get("rxcui", ""), medicine_name=record.get("name", ""), group_id=f"c3pi_reference:{record.get('ndc11', Path(path).stem)}", label_evidence="C3PI reference collection")
        elif path.startswith("data/pharmassist/"):
            row.update(source_dataset="pharmassist", data_role="self_supervised_unknown", group_id=f"pharmassist:{stem(path)}", label_evidence="Medicine identity metadata is not authenticity")
        elif path.startswith(("data/processed/", "data/splits/", "data/raw_training/")):
            row.update(source_dataset="derived_project", data_role="duplicate", status="excluded", exclusion_reason="derived_or_prior_experiment_copy")
        else:
            row.update(status="excluded", exclusion_reason="unmapped_unknown_image")
    seen_hash = set()
    seen_phash = set()
    for row in sorted(rows, key=lambda item: (0 if item["data_role"] == "supervised" else 1, item["image_path"])):
        if row["status"] == "excluded":
            continue
        if row["sha256"] in seen_hash:
            row.update(status="excluded", data_role="duplicate", exclusion_reason="exact_sha256_duplicate")
        elif row["perceptual_hash"] in seen_phash and row["source_dataset"] in {"c3pi", "c3pi_reference"}:
            row.update(status="excluded", data_role="duplicate", exclusion_reason="near_duplicate_reference_image")
        else:
            seen_hash.add(row["sha256"])
            seen_phash.add(row["perceptual_hash"])
    supervised = [row for row in rows if row["status"] == "candidate" and row["data_role"] == "supervised" and row["label"] in {"authentic", "counterfeit"}]
    representation = [row for row in rows if row["status"] == "candidate" and row["data_role"] in {"self_supervised_reference", "self_supervised_unknown"}]
    all_excluded = [row for row in rows if row["status"] == "excluded"]
    with (output / "all_images_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    for name, selected in (("supervised_manifest.csv", supervised), ("self_supervised_manifest.csv", representation), ("excluded_manifest.csv", all_excluded)):
        with (output / name).open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(selected)
    groups = defaultdict(list)
    for row in supervised:
        groups[row["group_id"]].append(row)
    group_items = list(groups.items())
    random.Random(args.seed).shuffle(group_items)
    splits = {"train": [], "validation": [], "test": []}
    targets = {"train": .70 * len(supervised), "validation": .15 * len(supervised), "test": .15 * len(supervised)}
    for _, group_rows in sorted(group_items, key=lambda item: len(item[1]), reverse=True):
        split = min(splits, key=lambda name: len(splits[name]) / max(targets[name], 1))
        splits[split].extend(group_rows)
    for name, selected in splits.items():
        with (output / f"{name}.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDS, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(selected)
    report = {"all_images": len(rows), "supervised": len(supervised), "self_supervised": len(representation), "excluded": len(all_excluded), "labels": Counter(row["label"] for row in supervised), "split_counts": {name: len(selected) for name, selected in splits.items()}, "exclusion_reasons": Counter(row["exclusion_reason"] for row in all_excluded)}
    (output / "audit" / "full_manifest_report.json").write_text(json.dumps(report, indent=2, default=lambda value: dict(value)), encoding="utf-8")
    print(json.dumps(report, indent=2, default=lambda value: dict(value)))


if __name__ == "__main__":
    main()