"""Fail-fast leakage gate for the manifests selected for training."""

from __future__ import annotations

import argparse
import csv
import hashlib
from collections import defaultdict
from pathlib import Path


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load(path: Path, root: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        row["sha256"] = file_hash(root / row["image_path"])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("data/processed"))
    parser.add_argument("--manifest-dir", type=Path, default=Path("outputs/clean_dataset"))
    args = parser.parse_args()
    splits = {name: load(args.manifest_dir / f"{name}.csv", args.root) for name in ("train", "validation", "test")}
    hashes = {name: {row["sha256"] for row in rows} for name, rows in splits.items()}
    overlaps = {
        f"{left}_{right}": len(hashes[left] & hashes[right])
        for left, right in (("train", "validation"), ("train", "test"), ("validation", "test"))
    }
    group_sets = {name: {row["group_id"] for row in rows} for name, rows in splits.items()}
    group_overlaps = {
        f"{left}_{right}": len(group_sets[left] & group_sets[right])
        for left, right in (("train", "validation"), ("train", "test"), ("validation", "test"))
    }
    all_hashes = defaultdict(list)
    for split, rows in splits.items():
        for row in rows:
            all_hashes[row["sha256"]].append(split)
    within = sum(1 for values in all_hashes.values() if len(values) > 1)
    result = {"counts": {name: len(rows) for name, rows in splits.items()}, "sha256_overlap": overlaps, "group_overlap": group_overlaps, "duplicate_hash_groups": within}
    print(result)
    if any(overlaps.values()) or any(group_overlaps.values()) or within != sum(len(rows) - len({row["sha256"] for row in rows}) for rows in splits.values()):
        raise SystemExit("LEAKAGE GATE FAILED")
    print("LEAKAGE GATE PASSED")


if __name__ == "__main__":
    main()