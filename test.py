"""Counterfeit Pharmaceutical Detection - Single-Image and Batch Inference CLI.

Supports:
    python test.py test_images\\medicine1.jpg
    python test.py test_images\\
    python test.py test_images\\ --model all
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys

import torch

from ml.config import (
    CHECKPOINT_REGISTRY,
    DEFAULT_CONFIDENCE_THRESHOLD,
    DEFAULT_MODEL,
    OUTPUTS_DIR,
    SUPPORTED_MODELS,
    get_device,
)
from ml.inference.predict import predict
from ml.models.transfer_learning import load_classifier, normalize_model_name

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def run_single_image(
    image_path: Path,
    model_name: str,
    threshold: float,
    device: torch.device,
    loaded_model=None,
) -> dict:
    """Run screening on one image and return dictionary."""
    return predict(
        image_input=image_path,
        model=loaded_model if loaded_model else model_name,
        threshold=threshold,
        device=device,
        quality_check=True,
    )


def format_single_image_output(result: dict) -> str:
    """Format single image prediction exactly as required."""
    img_name = Path(result["image_path"]).name
    pred = result["prediction"]
    auth_prob = result["authentic_probability"] * 100
    fake_prob = result["counterfeit_probability"] * 100
    conf = result["confidence"] * 100
    status = result["status"]
    reason = result.get("reason")

    lines = [
        f"Image: {img_name}",
        "",
        f"Prediction: {pred}",
        f"Authentic probability: {auth_prob:.2f}%",
        f"Counterfeit probability: {fake_prob:.2f}%",
        f"Confidence: {conf:.2f}%",
        "",
        "Status:",
        f"{status}",
    ]
    if reason and status == "NEEDS MANUAL REVIEW":
        lines.append(f"Reason: {reason}")

    lines.append("")
    lines.append("Note: AI-assisted preliminary screening only; does not replace laboratory authentication.")
    return "\n".join(lines)


def run_batch_directory(
    directory_path: Path,
    model_name: str,
    threshold: float,
    device: torch.device,
    output_csv: Path | None = None,
) -> list[dict]:
    """Process all supported images in a directory, print table, and save CSV."""
    image_files = sorted([
        f for f in directory_path.iterdir()
        if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS
    ])
    if not image_files:
        print(f"No supported images found in directory: {directory_path}")
        return []

    print(f"\nLoaded {len(image_files)} image(s) from {directory_path}\nUsing model: {model_name} (threshold: {threshold:.2f})\n")

    classifier = load_classifier(model_name, device=device)
    results = []

    # Table Header
    header = f"{'Image':<28} | {'Prediction':<12} | {'Authentic prob':<14} | {'Counterfeit prob':<16} | {'Confidence':<10} | {'Status':<20}"
    separator = "-" * len(header)
    print(header)
    print(separator)

    for img_path in image_files:
        res = predict(
            image_input=img_path,
            model=classifier,
            threshold=threshold,
            device=device,
            quality_check=True,
        )
        res["model_name"] = model_name
        results.append(res)

        img_str = img_path.name[:27]
        pred_str = res["prediction"]
        auth_str = f"{res['authentic_probability']*100:.2f}%"
        fake_str = f"{res['counterfeit_probability']*100:.2f}%"
        conf_str = f"{res['confidence']*100:.2f}%"
        stat_str = res["status"]

        print(f"{img_str:<28} | {pred_str:<12} | {auth_str:<14} | {fake_str:<16} | {conf_str:<10} | {stat_str:<20}")

    print(separator)

    # Save to outputs/predictions.csv
    csv_target = output_csv or (OUTPUTS_DIR / "predictions.csv")
    csv_target.parent.mkdir(parents=True, exist_ok=True)

    with csv_target.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=[
            "Image",
            "Prediction",
            "Authentic probability",
            "Counterfeit probability",
            "Confidence",
            "Status",
            "Reason",
            "Model",
        ])
        writer.writeheader()
        for r in results:
            writer.writerow({
                "Image": Path(r["image_path"]).name,
                "Prediction": r["prediction"],
                "Authentic probability": f"{r['authentic_probability']:.4f}",
                "Counterfeit probability": f"{r['counterfeit_probability']:.4f}",
                "Confidence": f"{r['confidence']:.4f}",
                "Status": r["status"],
                "Reason": r.get("reason") or "",
                "Model": r["model_name"],
            })

    print(f"\nSaved batch predictions to: {csv_target}")
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description="Test pharmaceutical images with trained screening models.")
    parser.add_argument("target", help="Path to image file or directory containing images")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Model to use ({', '.join(SUPPORTED_MODELS)}) or 'all'")
    parser.add_argument("--threshold", type=float, default=DEFAULT_CONFIDENCE_THRESHOLD, help="Confidence threshold")
    parser.add_argument("--output", default=None, help="Output CSV path for batch testing")
    parser.add_argument("--cpu", action="store_true", help="Force CPU inference")
    args = parser.parse_args()

    target_path = Path(args.target)
    if not target_path.exists():
        print(f"Error: Target path does not exist: {target_path}", file=sys.stderr)
        sys.exit(1)

    device = torch.device("cpu") if args.cpu else get_device()

    # Batch directory mode
    if target_path.is_dir():
        run_batch_directory(
            directory_path=target_path,
            model_name=normalize_model_name(args.model) if args.model != "all" else DEFAULT_MODEL,
            threshold=args.threshold,
            device=device,
            output_csv=Path(args.output) if args.output else None,
        )
        return

    # Single image mode
    if args.model.lower() == "all":
        print(f"=== Comparative Multi-Model Evaluation on {target_path.name} ===\n")
        for m in SUPPORTED_MODELS:
            print(f"--- Model: {m} ---")
            res = run_single_image(target_path, m, args.threshold, device)
            print(format_single_image_output(res))
            print()
    else:
        norm_name = normalize_model_name(args.model)
        res = run_single_image(target_path, norm_name, args.threshold, device)
        print(format_single_image_output(res))


if __name__ == "__main__":
    main()
