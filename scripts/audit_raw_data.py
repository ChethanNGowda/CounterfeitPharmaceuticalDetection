"""Audit raw sources and build a reviewable candidate manifest."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
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


def perceptual_hash(path: Path) -> str:
    with Image.open(path) as image:
        image = image.convert("L").resize((9, 8))
        pixels = list(image.getdata())
    bits = [pixels[row * 9 + column] > pixels[row * 9 + column + 1] for row in range(8) for column in range(8)]
    return "".join("1" if bit else "0" for bit in bits)


def image_info(path: Path) -> tuple[str, str, int, int]:
    digest = sha256(path)
    with Image.open(path) as image:
        image.verify()
    return digest, perceptual_hash(path), image.width if hasattr(image, "width") else 0, image.height if hasattr(image, "height") else 0


def annotate_counterfeit(root: Path) -> tuple[list[dict[str, str]], Counter, list[dict[str, str]]]:
    candidates, reasons = [], Counter()
    excluded = []
    for split in ("train", "valid", "test"):
        split_root = root / split
        annotation_path = split_root / "_annotations.createml.json"
        records = json.loads(annotation_path.read_text(encoding="utf-8"))
        for record in records:
            labels = {str(item.get("label", "")).lower() for item in record.get("annotations", [])}
            path = split_root / record["image"]
            if labels == {"authentic"} or labels == {"counterfeit"}:
                label = next(iter(labels))
                candidates.append({"image_path": str(path), "source_dataset": "counterfeit", "label": label, "group_id": f"counterfeit:{path.stem.rsplit('.rf.', 1)[0]}", "medicine_id": "", "source_split": split, "label_evidence": "CreateML image annotations"})
            else:
                reason = "mixed_authentic_counterfeit_annotations" if "authentic" in labels and "counterfeit" in labels else "missing_or_unknown_annotation_label"
                reasons[reason] += 1
                excluded.append({"image_path": str(path), "source_dataset": "counterfeit", "reason": reason, "labels": ";".join(sorted(labels))})
    return candidates, reasons, excluded


def c3pi_candidates(root: Path) -> tuple[list[dict[str, str]], Counter, list[dict[str, str]]]:
    frame = pd.read_csv(root / "table.csv", dtype=str).fillna("")
    candidates, reasons, excluded = [], Counter(), []
    for record in frame.to_dict("records"):
        relative = record.get("RXNAV ORIGINAL", "")
        path = root / relative.replace("image/images/", "image/images/")
        if not relative or not path.is_file():
            reasons["missing_rxnav_original"] += 1
            excluded.append({"source_dataset": "c3pi", "medicine_id": record.get("ndc11", ""), "reason": "missing_rxnav_original", "image_path": relative})
            continue
        candidates.append({"image_path": str(path), "source_dataset": "c3pi", "label": "authentic", "group_id": f"c3pi:ndc11:{record.get('ndc11', '')}", "medicine_id": record.get("ndc11", ""), "rxcui": record.get("rxcui", ""), "medicine_name": record.get("name", ""), "source_split": "reference", "label_evidence": "C3PI RXNAV reference original"})
    return candidates, reasons, excluded


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output-root", type=Path, default=Path("data/raw_training"))
    args = parser.parse_args()
    output = args.output_root
    audit_dir = output / "audit"
    audit_dir.mkdir(parents=True, exist_ok=True)
    counterfeit, counterfeit_reasons, excluded = annotate_counterfeit(args.root / "data" / "counterfeit")
    c3pi, c3pi_reasons, c3pi_excluded = c3pi_candidates(args.root / "data" / "c3pi")
    excluded.extend(c3pi_excluded)
    candidates = counterfeit + c3pi
    rows, corrupt = [], []
    for item in candidates:
        path = args.root / item["image_path"]
        try:
            digest = sha256(path)
            with Image.open(path) as image:
                image.verify()
            phash = perceptual_hash(path)
            item.update({"sha256": digest, "perceptual_hash": phash})
            rows.append(item)
        except Exception as exc:
            corrupt.append({"image_path": item["image_path"], "source_dataset": item["source_dataset"], "reason": "corrupt_or_unreadable", "error": str(exc)})
    excluded.extend(corrupt)
    exact = defaultdict(list)
    perceptual = defaultdict(list)
    for row in rows:
        exact[row["sha256"]].append(row)
        perceptual[row["perceptual_hash"]].append(row)
    exact_groups = [items for items in exact.values() if len(items) > 1]
    perceptual_groups = [items for items in perceptual.values() if len(items) > 1]
    report = {
        "source_policy": {"counterfeit": "single-label CreateML annotations only; mixed-label frames excluded", "c3pi": "one RXNAV ORIGINAL per NDC11; RXBASE/NLM and other resolutions excluded", "pharmassist": "excluded because Class_Label identifies medicine, not authenticity"},
        "discovered": {"counterfeit_files": sum(1 for path in (args.root / "data" / "counterfeit").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS), "c3pi_files": sum(1 for path in (args.root / "data" / "c3pi").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS), "c3pi_records": 4392, "pharmassist_files": sum(1 for path in (args.root / "data" / "pharmassist").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS)},
        "candidate_counts": {"counterfeit_single_label": len(counterfeit), "c3pi_rxnav_original": len(c3pi), "valid_hashed_candidates": len(rows), "excluded": len(excluded)},
        "valid_label_counts": Counter(row["label"] for row in rows),
        "exclusion_reasons": Counter(item["reason"] for item in excluded) | counterfeit_reasons | c3pi_reasons,
        "exact_duplicate_groups": exact_groups,
        "perceptual_hash_groups": perceptual_groups,
        "cross_source_exact_duplicate_groups": [items for items in exact_groups if len({item["source_dataset"] for item in items}) > 1],
    }
    with (output / "candidate_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
        fields = ["image_path", "source_dataset", "label", "group_id", "medicine_id", "rxcui", "medicine_name", "source_split", "label_evidence", "sha256", "perceptual_hash"]
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    (audit_dir / "raw_audit.json").write_text(json.dumps(report, indent=2, default=lambda value: dict(value)), encoding="utf-8")
    (audit_dir / "exclusions.json").write_text(json.dumps(excluded, indent=2), encoding="utf-8")
    print(json.dumps({"discovered": report["discovered"], "candidates": report["candidate_counts"], "labels": dict(report["valid_label_counts"]), "exclusions": dict(report["exclusion_reasons"]), "exact_duplicate_groups": len(exact_groups), "perceptual_hash_groups": len(perceptual_groups)}, indent=2))
    if corrupt:
        raise SystemExit("AUDIT FAILED: corrupt candidate images found")


if __name__ == "__main__":
    main()