"""Validate raw experiment split, hash, group, and image invariants."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--split-dir", type=Path, default=Path("data/raw_training"))
    args = parser.parse_args()
    splits = {}
    for name in ("train", "validation", "test"):
        with (args.split_dir / f"{name}.csv").open(newline="", encoding="utf-8") as handle:
            splits[name] = list(csv.DictReader(handle))
    hashes = {name: {row["sha256"] for row in rows} for name, rows in splits.items()}
    groups = {name: {row["group_id"] for row in rows} for name, rows in splits.items()}
    hash_overlap = {f"{a}_{b}": len(hashes[a] & hashes[b]) for a, b in (("train", "validation"), ("train", "test"), ("validation", "test"))}
    group_overlap = {f"{a}_{b}": len(groups[a] & groups[b]) for a, b in (("train", "validation"), ("train", "test"), ("validation", "test"))}
    all_hashes = defaultdict(list)
    missing = []
    for split, rows in splits.items():
        for row in rows:
            all_hashes[row["sha256"]].append(split)
            if not (args.root / row["image_path"]).is_file():
                missing.append(row["image_path"])
    duplicate_groups = sum(len(values) > 1 for values in all_hashes.values())
    result = {"counts": {name: len(rows) for name, rows in splits.items()}, "hash_overlap": hash_overlap, "group_overlap": group_overlap, "duplicate_hash_groups": duplicate_groups, "missing_files": missing}
    print(result)
    if any(hash_overlap.values()) or any(group_overlap.values()) or duplicate_groups or missing:
        raise SystemExit("RAW SPLIT GATE FAILED")
    print("RAW SPLIT GATE PASSED")


if __name__ == "__main__":
    main()