"""Counterfeit Pharmaceutical Detection - Single-Image and Batch Inference CLI.

Integrates:
1. Primary Specialized Pharmaceutical ML Classifier (EfficientNet-B0)
2. Secondary AI Visual Verification Layer (Qwen Vision via Ollama)
3. Conservative Screening Synthesis

Usage:
    python test.py test_images\\fake_image.png
    python test.py test_images\\sample_authentic_c3pi.jpg
    python test.py test_images\\ --model all
    python test.py test_images\\fake_image.png --no-vision
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
from ml.inference.predict import predict, predict_pipeline
from ml.models.transfer_learning import (
    get_model_status,
    is_model_available,
    load_classifier,
    normalize_model_name,
)
from ml.verification.qwen_verifier import (
    DEFAULT_OLLAMA_BASE_URL,
    DEFAULT_OLLAMA_TIMEOUT,
    DEFAULT_OLLAMA_VISION_MODEL,
    QwenVisionVerifier,
    format_final_screening_result,
)

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def run_single_image(
    image_path: Path,
    model_name: str,
    threshold: float,
    device: torch.device,
    loaded_model=None,
    vision_mode: str = "auto",
    verifier: Optional[QwenVisionVerifier] = None,
) -> dict:
    """Run screening on one image using the unified detection pipeline."""
    return predict_pipeline(
        image_input=image_path,
        model=loaded_model if loaded_model else model_name,
        threshold=threshold,
        vision_mode=vision_mode,
        vision_verifier=verifier,
        device=device,
        quality_check=True,
    )


if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def _bar(value_pct: float, width: int = 28) -> str:
    """Render a filled/empty progress bar for a probability percentage."""
    filled = int(round(value_pct / 100 * width))
    empty = width - filled
    return "#" * filled + "-" * empty


def format_single_image_output(
    result: dict,
    qwen_verification: dict | None = None,
    verifier: QwenVisionVerifier | None = None,
) -> str:
    """Format single image prediction as a professional pharmaceutical screening report."""
    img_name = Path(result["image_path"]).name
    pred = result.get("primary_prediction") or result.get("prediction", "UNKNOWN")
    auth_prob = float(result.get("authentic_probability", 0.0)) * 100
    fake_prob = float(result.get("counterfeit_probability", 0.0)) * 100
    conf = float(result.get("confidence", 0.0)) * 100
    status = result.get("status", "UNKNOWN")
    sec_executed = result.get("secondary_executed", False)
    sec_reason = result.get("secondary_reason")
    qwen_data = qwen_verification if qwen_verification is not None else result.get("qwen") or {}
    quality = result.get("quality") or {}
    va = result.get("visual_analysis") or {}
    final_res = result.get("final_result", result.get("final_status", "SUSPICIOUS / NEEDS VERIFICATION"))

    W = 60
    sep = "=" * W

    lines = []

    # ─── Header ───────────────────────────────────────────────────
    lines.append("+" + "=" * (W - 2) + "+")
    title = "COUNTERFEIT PHARMACEUTICAL SCREENING REPORT"
    lines.append("|" + title.center(W - 2) + "|")
    lines.append("+" + "=" * (W - 2) + "+")
    lines.append("")

    # ─── Section helper ───────────────────────────────────────────
    def section(heading: str) -> None:
        lines.append(heading)
        lines.append("-" * W)

    def field(label: str, value: str, width: int = 26) -> None:
        lines.append(f"   {label:<{width}} {value}")

    # ─── IMAGE ────────────────────────────────────────────────────
    section("IMAGE")
    lines.append(f"   Image: {img_name}")
    if quality.get("dimensions"):
        dims = quality["dimensions"]
        field("Dimensions:", f"{dims[0]} x {dims[1]} px")
        ar = quality.get("aspect_ratio", round(dims[0] / max(dims[1], 1), 2))
        field("Aspect Ratio:", f"{ar}")
    field("Color Mode:", quality.get("color_mode", "RGB"))
    field("Brightness:", f"{quality.get('brightness_mean', 0.0):.1f} / 255")
    field("Contrast (std):", f"{quality.get('contrast', 0.0):.1f}")
    field("Sharpness:", f"Laplacian var {quality.get('blur_score', 0.0):.1f}")
    field("Exposure:", quality.get("exposure_status", "-"))
    field("Image Quality:", quality.get("sharpness_status", "-"))
    suitability = quality.get("suitability", "SUITABLE FOR ANALYSIS") if quality.get("is_valid", True) else quality.get("suitability", "UNSUITABLE")
    field("Suitability:", suitability)
    lines.append("")

    # ─── PRIMARY AI ───────────────────────────────────────────────
    section("PRIMARY AI - EfficientNet-B0")
    field("Prediction:", pred)
    field("Confidence:", f"{conf:.2f}%")
    field("Status:", status)
    lines.append("")
    lines.append(f"   Authentic   {_bar(auth_prob)} {auth_prob:.2f}%")
    lines.append(f"   Counterfeit {_bar(fake_prob)} {fake_prob:.2f}%")
    lines.append("")

    # ─── VISUAL FEATURE ANALYSIS ──────────────────────────────────
    section("VISUAL FEATURE ANALYSIS")
    if va and not va.get("error"):
        color = va.get("color", {})
        field("Dominant Color:", color.get("dominant_color", "-"))
        rgb = color.get("average_rgb", [])
        if rgb:
            field("Average RGB:", f"R={rgb[0]:.0f}  G={rgb[1]:.0f}  B={rgb[2]:.0f}")
        field("Color Consistency:", color.get("consistency", "-"))
        field("Color Variation:", color.get("visible_variation", "-"))
        lines.append("")
        shape = va.get("shape", {})
        field("Object Detected:", shape.get("object_detected", "-"))
        field("Shape:", shape.get("shape_type", "-"))
        field("Circularity:", str(shape.get("circularity", "-")))
        field("Symmetry:", shape.get("symmetry", "-"))
        lines.append("")
        size = va.get("size", {})
        field("Bounding Box:", size.get("bounding_box", "-"))
        field("Pixel Area:", size.get("pixel_area", "-"))
        field("Physical Size:", "Not measurable without scale reference")
        lines.append("")
        surf = va.get("surface", {})
        field("Texture Variation:", surf.get("texture_variation", "-"))
        field("Surface Uniformity:", surf.get("surface_uniformity", "-"))
        field("Visible Spots:", surf.get("visible_spots", "Not detected"))
        field("Irregularities:", surf.get("surface_irregularities", "Not detected"))
        lines.append("")
        mrk = va.get("markings", {})
        field("Markings Visible:", mrk.get("markings_visible", "-"))
        field("Imprint Type:", mrk.get("imprint_type", "-"))
        field("Text Recognition:", mrk.get("text_recognition", "-"))
        field("Legibility:", mrk.get("legibility", "-"))
        lines.append("")
        edges = va.get("edges", {})
        field("Edge Integrity:", edges.get("edge_integrity", "-"))
        field("Cracks:", edges.get("cracks", "Not detected"))
        field("Chipping:", edges.get("chipping", "Not detected"))
        field("Contour:", edges.get("contour", "-"))
        lines.append("")
        pkg = va.get("packaging", {})
        field("Packaging:", pkg.get("status", "NOT VISIBLE"))
        if pkg.get("status", "") != "NOT VISIBLE":
            field("Packaging Type:", pkg.get("packaging_type", "-"))
    else:
        lines.append("   Visual feature analysis unavailable.")
        if va.get("error"):
            lines.append(f"   Reason: {va['error']}")
    lines.append("")

    # ─── SECONDARY AI — QWEN3-VL ──────────────────────────────────
    section("SECONDARY AI - Qwen3-VL:4b")
    if sec_executed and qwen_data:
        qwen_avail = qwen_data.get("available", False)
        if qwen_avail:
            field("Status:", "EXECUTED")
            field("Assessment:", qwen_data.get("assessment", "UNCERTAIN"))
            field("Visual Confidence:", qwen_data.get("confidence", "-"))
            field("Image Quality (Qwen):", qwen_data.get("image_quality", "-"))
            # Tablet analysis sub-fields from Qwen
            tablet_shape = qwen_data.get("tablet_shape", "")
            tablet_color = qwen_data.get("tablet_color", "")
            tablet_surface = qwen_data.get("tablet_surface", "")
            tablet_markings = qwen_data.get("tablet_markings", "")
            tablet_edges = qwen_data.get("tablet_edges", "")
            if any([tablet_shape, tablet_color, tablet_surface, tablet_markings, tablet_edges]):
                lines.append("")
                lines.append("   Qwen Tablet Observations:")
                if tablet_shape:
                    lines.append(f"     Shape    : {tablet_shape}")
                if tablet_color:
                    lines.append(f"     Color    : {tablet_color}")
                if tablet_surface:
                    lines.append(f"     Surface  : {tablet_surface}")
                if tablet_markings:
                    lines.append(f"     Markings : {tablet_markings}")
                if tablet_edges:
                    lines.append(f"     Edges    : {tablet_edges}")
            obs_list = qwen_data.get("observations_list", [])
            if obs_list:
                lines.append("")
                lines.append("   Observations:")
                for obs in obs_list:
                    lines.append(f"     * {obs}")
            concerns_list = qwen_data.get("concerns_list", [])
            if concerns_list:
                lines.append("")
                lines.append("   Potential Visual Concerns:")
                for c in concerns_list:
                    lines.append(f"     * {c}")
            fe = qwen_data.get("final_explanation", "")
            if fe:
                lines.append("")
                lines.append(f"   Final Explanation: {fe}")
        else:
            lines.append("   Status: UNAVAILABLE")
            lines.append(f"   Reason: {qwen_data.get('reason', 'Ollama service unreachable or timed out.')}")
    else:
        lines.append("   Status: NOT RUN")
        if sec_reason:
            lines.append(f"   Reason: {sec_reason}")
    lines.append("")

    # ─── DECISION ENGINE ──────────────────────────────────────────
    section("DECISION ENGINE")
    field("Primary Prediction:", pred)
    field("Primary Confidence:", f"{conf:.2f}%")
    if sec_executed and qwen_data:
        qwen_avail = qwen_data.get("available", False)
        field("Secondary Assessment:", qwen_data.get("assessment", "UNCERTAIN") if qwen_avail else "UNAVAILABLE")
    else:
        field("Secondary Assessment:", "NOT RUN")
    disagree = result.get("disagreement", False)
    field("Models Agree:", "YES" if not disagree else "NO - CONFLICT DETECTED")
    field("Human Verification Required:", "YES" if result.get("needs_human_verification") else "NO")
    lines.append("")

    # ─── FINAL RESULT ─────────────────────────────────────────────
    section("FINAL SCREENING RESULT")
    lines.append("")
    # Prominent result display
    if "AUTHENTIC" in final_res and "SUSPICIOUS" not in final_res:
        marker = "[AUTHENTIC]"
    elif "COUNTERFEIT" in final_res:
        marker = "[!] ALERT: LIKELY COUNTERFEIT"
    else:
        marker = "[?] SUSPICIOUS / NEEDS VERIFICATION"
    lines.append(f"   {marker}")
    lines.append("")
    if result.get("warning") and result.get("warning") != result.get("reason"):
        lines.append(f"   Warning: {result['warning']}")
    reason_text = result.get("reason") or (result.get("reasons", [None])[0] if result.get("reasons") else None)
    if reason_text:
        lines.append("")
        lines.append("   Reason:")
        for rline in (reason_text.split(". ") if len(reason_text) > 80 else [reason_text]):
            lines.append(f"     {rline.strip()}")
    lines.append("")

    # ─── DISCLAIMER ───────────────────────────────────────────────
    section("IMPORTANT")
    lines.append("   AI-assisted visual screening only.")
    lines.append("   Visual inspection cannot establish chemical composition,")
    lines.append("   bioequivalence, or laboratory-grade authenticity.")
    lines.append("   Laboratory verification is required for confirmation.")

    return "\n".join(lines)



def run_batch_directory(
    directory_path: Path,
    model_name: str,
    threshold: float,
    device: torch.device,
    output_csv: Path | None = None,
) -> list[dict]:
    """Process all supported images in a directory with the primary ML classifier."""
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
    parser = argparse.ArgumentParser(
        description="Test pharmaceutical images with primary ML classifier and Qwen Vision verification."
    )
    parser.add_argument("target", help="Path to image file or directory containing images")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Primary model to use ({', '.join(SUPPORTED_MODELS)}) or 'all'")
    parser.add_argument("--threshold", type=float, default=DEFAULT_CONFIDENCE_THRESHOLD, help="Confidence threshold (default: 0.70)")
    parser.add_argument("--output", default=None, help="Output CSV path for batch testing")
    parser.add_argument("--cpu", action="store_true", help="Force CPU inference for primary ML model")
    parser.add_argument(
        "--vision-mode",
        choices=["auto", "always", "never"],
        default="auto",
        help="Vision verification mode: 'auto' (conditional gating [0.70, 0.90)), 'always' (force Qwen), 'never' (skip Qwen)",
    )
    parser.add_argument("--no-vision", action="store_true", help="Disable secondary Qwen Vision verification (alias for --vision-mode never)")
    parser.add_argument("--vision-model", default=None, help="Ollama vision model (default: auto-detected, e.g. qwen3-vl:4b)")
    parser.add_argument("--ollama-url", default=DEFAULT_OLLAMA_BASE_URL, help=f"Ollama base URL (default: {DEFAULT_OLLAMA_BASE_URL})")
    parser.add_argument("--timeout", type=float, default=DEFAULT_OLLAMA_TIMEOUT, help=f"Ollama timeout in seconds (default: {DEFAULT_OLLAMA_TIMEOUT})")
    args = parser.parse_args()

    target_path = Path(args.target)
    if not target_path.exists():
        print(f"Error: Target path does not exist: {target_path}", file=sys.stderr)
        sys.exit(1)

    device = torch.device("cpu") if args.cpu else get_device()
    vision_mode = "never" if args.no_vision else args.vision_mode

    # Batch directory mode (primary classifier only)
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
    verifier = None
    if vision_mode != "never":
        verifier = QwenVisionVerifier(
            base_url=args.ollama_url,
            model_name=args.vision_model,
            timeout=args.timeout,
        )

    if args.model.lower() == "all":
        print(f"=== Comparative Multi-Model Evaluation on {target_path.name} ===\n")
        for m in SUPPORTED_MODELS:
            print(f"--- Model: {m} ---")
            if not is_model_available(m):
                status_info = get_model_status(m)
                print(f"Status: UNAVAILABLE ({status_info['status']})")
                print("Skipping inference: Fine-tuned pharmaceutical checkpoint not found on disk.\n")
                continue
            res = run_single_image(
                target_path,
                m,
                args.threshold,
                device,
                vision_mode=vision_mode,
                verifier=verifier,
            )
            print(format_single_image_output(res, verifier=verifier))
            print()
    else:
        norm_name = normalize_model_name(args.model)
        res = run_single_image(
            target_path,
            norm_name,
            args.threshold,
            device,
            vision_mode=vision_mode,
            verifier=verifier,
        )
        print(format_single_image_output(res, verifier=verifier))


if __name__ == "__main__":
    main()
