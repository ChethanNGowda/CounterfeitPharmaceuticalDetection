"""Validate full-data split isolation by groups and exact hashes."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--split-dir", type=Path, default=Path("data/full_training"))
    args = parser.parse_args()
    splits = {}
    for name in ("train", "validation", "test"):
        with (args.split_dir / f"{name}.csv").open(newline="", encoding="utf-8") as handle:
            splits[name] = list(csv.DictReader(handle))
    hash_sets = {name: {row["sha256"] for row in rows} for name, rows in splits.items()}
    group_sets = {name: {row["group_id"] for row in rows} for name, rows in splits.items()}
    hash_overlap = {f"{a}_{b}": len(hash_sets[a] & hash_sets[b]) for a, b in (("train", "validation"), ("train", "test"), ("validation", "test"))}
    group_overlap = {f"{a}_{b}": len(group_sets[a] & group_sets[b]) for a, b in (("train", "validation"), ("train", "test"), ("validation", "test"))}
    missing = [row["image_path"] for rows in splits.values() for row in rows if not (args.root / row["image_path"]).is_file()]
    result = {"counts": {name: len(rows) for name, rows in splits.items()}, "hash_overlap": hash_overlap, "group_overlap": group_overlap, "missing": len(missing)}
    print(result)
    if any(hash_overlap.values()) or any(group_overlap.values()) or missing:
        raise SystemExit("FULL SPLIT GATE FAILED")
    print("FULL SPLIT GATE PASSED")


if __name__ == "__main__":
    main()