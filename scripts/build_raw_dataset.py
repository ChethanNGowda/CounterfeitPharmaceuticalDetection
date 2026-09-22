"""Deduplicate audited raw candidates and create group-disjoint splits."""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import Counter
from pathlib import Path


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output-root", type=Path, default=Path("data/raw_training"))
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    output = args.output_root
    rows = read_rows(output / "candidate_manifest.csv")
    seen_hashes: set[str] = set()
    seen_phashes: set[str] = set()
    kept, excluded = [], []
    # Prefer C3PI's explicit reference originals, then retain the first raw image.
    rows.sort(key=lambda row: (0 if row["source_dataset"] == "c3pi" else 1, row["image_path"]))
    for row in rows:
        reason = ""
        if row["sha256"] in seen_hashes:
            reason = "exact_sha256_duplicate"
        elif row["perceptual_hash"] in seen_phashes:
            reason = "identical_perceptual_hash_duplicate"
        if reason:
            excluded.append({"image_path": row["image_path"], "source_dataset": row["source_dataset"], "reason": reason, "sha256": row["sha256"], "perceptual_hash": row["perceptual_hash"]})
            continue
        seen_hashes.add(row["sha256"])
        seen_phashes.add(row["perceptual_hash"])
        kept.append(row)

    # Group IDs already encode capture/product identity: C3PI NDC11 or source capture stem.
    groups = {}
    for row in kept:
        groups.setdefault(row["group_id"], []).append(row)
    group_items = list(groups.items())
    random.Random(args.seed).shuffle(group_items)
    target = {"train": 0.70 * len(kept), "validation": 0.15 * len(kept), "test": 0.15 * len(kept)}
    splits = {"train": [], "validation": [], "test": []}
    counts = Counter()
    for group_id, group_rows in sorted(group_items, key=lambda item: len(item[1]), reverse=True):
        split = min(splits, key=lambda name: len(splits[name]) / max(target[name], 1))
        splits[split].extend(group_rows)
        counts[split] += len(group_rows)
    for split, split_rows in splits.items():
        split_rows.sort(key=lambda row: row["image_path"])
        with (output / f"{split}.csv").open("w", newline="", encoding="utf-8") as handle:
            fields = ["image_path", "source_dataset", "label", "group_id", "sha256", "perceptual_hash", "medicine_id", "rxcui", "medicine_name", "source_split", "label_evidence"]
            writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(split_rows)
    report = {
        "policy": "One representative per SHA256 and exact perceptual hash; groups assigned to one split only.",
        "candidate_count": len(rows), "final_count": len(kept), "excluded_count": len(excluded),
        "exclusion_counts": Counter(item["reason"] for item in excluded),
        "label_counts": {split: Counter(row["label"] for row in split_rows) for split, split_rows in splits.items()},
        "split_counts": counts, "group_counts": {split: len({row["group_id"] for row in split_rows}) for split, split_rows in splits.items()},
        "excluded_images": excluded,
    }
    (output / "audit" / "raw_split_report.json").write_text(json.dumps(report, indent=2, default=lambda value: dict(value)), encoding="utf-8")
    (output / "duplicates" / "removed_duplicates.csv").parent.mkdir(parents=True, exist_ok=True)
    with (output / "duplicates" / "removed_duplicates.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "source_dataset", "reason", "sha256", "perceptual_hash"])
        writer.writeheader()
        writer.writerows(excluded)
    print(json.dumps({"candidate_count": len(rows), "final_count": len(kept), "excluded_count": len(excluded), "split_counts": counts, "label_counts": report["label_counts"]}, indent=2, default=lambda value: dict(value)))


if __name__ == "__main__":
    main()