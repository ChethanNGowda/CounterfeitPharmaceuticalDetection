"""FastAPI route for pharmaceutical image prediction and secondary AI review."""

from __future__ import annotations

import io
from typing import Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from PIL import Image

from ml.config import CHECKPOINT_REGISTRY, DEFAULT_CONFIDENCE_THRESHOLD, DEFAULT_MODEL, SUPPORTED_MODELS
from ml.models.transfer_learning import CheckpointUnavailableError, get_model_status, normalize_model_name
from backend.app.schemas.predict import ModelsListResponse, ModelStatusItem, PredictionResponse, QwenHealthResponse
from backend.app.services.classifier import ClassifierService

router = APIRouter()

ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/bmp",
}
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP", "BMP"}
MAX_UPLOAD_SIZE = 15 * 1024 * 1024  # 15 MB


@router.post("/predict", response_model=PredictionResponse, status_code=status.HTTP_200_OK)
@router.post("/verify", response_model=PredictionResponse, status_code=status.HTTP_200_OK)
async def predict_pharmaceutical(
    file: UploadFile = File(..., description="Multipart tablet image file"),
    threshold: float = Form(DEFAULT_CONFIDENCE_THRESHOLD, description="Confidence threshold between 0.0 and 1.0"),
    model: Optional[str] = Form(DEFAULT_MODEL, description=f"Model name ({', '.join(SUPPORTED_MODELS)})"),
    enable_qwen: bool = Form(True, description="Enable secondary AI verification via local Ollama qwen3-vl:4b"),
    enable_vision: Optional[bool] = Form(None, description="Alias for enable_qwen for backward compatibility"),
    vision_mode: Optional[str] = Form(None, description="Vision mode: 'auto' (conditional gating), 'always' (forced), 'never' (disabled)"),
):
    """Screen an uploaded pharmaceutical tablet image using dual-model pipeline.

    - Primary Model: EfficientNet-B0 visual classifier (99.88% test accuracy).
    - Secondary Review: qwen3-vl:4b (via local Ollama) performing visual inspection.
    - Decision Engine: Conservative synthesis yielding LIKELY AUTHENTIC, LIKELY COUNTERFEIT,
      or SUSPICIOUS / NEEDS VERIFICATION.
    """
    if model:
        norm_model = normalize_model_name(model)
        if norm_model not in SUPPORTED_MODELS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported model '{model}'. Supported models: {', '.join(SUPPORTED_MODELS)}.",
            )
    if file.content_type and file.content_type.lower() not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file format '{file.content_type}'. Allowed types: JPEG, PNG, WEBP, BMP.",
        )

    try:
        content = await file.read()
    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to read uploaded file: {err}",
        )

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty (0 bytes).",
        )

    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=f"Image upload exceeds maximum allowed size of 15MB ({len(content) / (1024 * 1024):.1f}MB uploaded).",
        )

    # Validate image readability and real format (do not trust content_type header alone)
    try:
        with Image.open(io.BytesIO(content)) as probe_img:
            img_format = (probe_img.format or "").upper()
            if img_format not in ALLOWED_IMAGE_FORMATS:
                raise HTTPException(
                    status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                    detail=f"Unsupported image format '{img_format}'. Allowed formats: JPEG, PNG, WEBP, BMP.",
                )
    except HTTPException:
        raise
    except Exception as img_err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Corrupted or invalid image data: {img_err}",
        )

    # Use enable_vision if explicitly provided, otherwise enable_qwen
    run_qwen = enable_vision if enable_vision is not None else enable_qwen

    service = ClassifierService.get_instance()
    try:
        result = service.predict_image_bytes(
            image_bytes=content,
            filename=file.filename or "upload.jpg",
            model_name=model or DEFAULT_MODEL,
            threshold=threshold,
            vision_mode=vision_mode,
            enable_qwen=run_qwen,
        )
    except ValueError as val_err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(val_err),
        )
    except CheckpointUnavailableError as ckpt_err:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Requested model checkpoint is unavailable: {ckpt_err}",
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference error: {exc}",
        )

    return PredictionResponse(
        # Multi-model core fields
        primary_model=result["primary_model"],
        prediction=result["prediction"],
        confidence=result["confidence"],
        qwen=result["qwen"],
        final_result=result["final_result"],
        needs_human_verification=result["needs_human_verification"],
        warning=result.get("warning"),
        disclaimer=result.get("disclaimer"),
        # Pipeline execution & synthesis fields
        secondary_executed=result.get("secondary_executed", False),
        secondary_reason=result.get("secondary_reason"),
        reasons=result.get("reasons", []),
        disagreement=result.get("disagreement", False),
        primary_prediction=result.get("primary_prediction"),
        primary_confidence=result.get("primary_confidence"),
        # Visual feature inspection report
        visual_analysis=result.get("visual_analysis"),
        # Backward-compatible fields
        status=result["status"],
        reason=result.get("reason"),
        model_name=result["model_name"],
        threshold=result["threshold"],
        authentic_probability=result["authentic_probability"],
        counterfeit_probability=result["counterfeit_probability"],
        quality=result.get("quality"),
    )


@router.get("/health/qwen", response_model=QwenHealthResponse, tags=["Health"])
@router.get("/diagnostics/qwen", response_model=QwenHealthResponse, tags=["Health"])
def qwen_diagnostics():
    """Live diagnostic check for local Ollama and Qwen Vision model."""
    import json
    import urllib.error
    import urllib.request

    service = ClassifierService.get_instance()
    verifier = service.vision_verifier
    base_url = verifier.base_url
    model_name = verifier.model_name

    try:
        req = urllib.request.Request(f"{base_url}/api/tags")
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        models = [m.get("name", "") for m in data.get("models", [])]

        has_model = any(model_name == m or m.startswith(model_name) for m in models)
        if has_model:
            return QwenHealthResponse(
                status="READY",
                available=True,
                model_name=model_name,
                base_url=base_url,
                installed_models=models,
                message=f"Qwen Vision model '{model_name}' is installed and responsive.",
            )
        else:
            return QwenHealthResponse(
                status="MODEL_NOT_INSTALLED",
                available=False,
                model_name=model_name,
                base_url=base_url,
                installed_models=models,
                message=f"Ollama is running, but model '{model_name}' is not installed. Run 'ollama pull {model_name}'.",
            )
    except urllib.error.URLError:
        return QwenHealthResponse(
            status="OLLAMA_UNREACHABLE",
            available=False,
            model_name=model_name,
            base_url=base_url,
            installed_models=[],
            message=f"Cannot connect to Ollama at {base_url}. Ensure the Ollama service is running.",
        )
    except Exception as exc:
        return QwenHealthResponse(
            status="ERROR",
            available=False,
            model_name=model_name,
            base_url=base_url,
            installed_models=[],
            message=f"Diagnostic error: {exc}",
        )


# ── Saved benchmark metrics for unavailable models ─────────────────────────
# Sourced from reports/model_comparison.md (benchmark run 2026-09-23, test.csv, 827 images)
# These are NOT current reproduced metrics — treat as historical benchmarks only.
_BENCHMARK_METRICS: dict = {
    "efficientnet_b0": {
        "accuracy": 0.9988, "precision": 0.9965, "recall": 1.0000,
        "macro_f1": 0.9982, "specificity": 0.9982, "roc_auc": 0.9993,
        "test_samples": 827,
        "note": (
            "REPRODUCED 2026-10-18 on test_clean.csv (839 images): "
            "accuracy=99.76%, recall=100.00%, specificity=99.64%, ROC-AUC=0.99999"
        ),
    },
    "mobilenet_v3_large": {
        "accuracy": 0.9940, "precision": 0.9929, "recall": 0.9893,
        "macro_f1": 0.9911, "specificity": 0.9963, "roc_auc": 0.9993,
        "test_samples": 827,
        "note": "Historical benchmark 2026-09-23 — fine-tuned checkpoint not on disk",
    },
    "goldformer": {
        "accuracy": 0.9927, "precision": 0.9791, "recall": 1.0000,
        "macro_f1": 0.9894, "specificity": 0.9890, "roc_auc": 0.9993,
        "test_samples": 827,
        "note": "Historical benchmark 2026-09-23 — fine-tuned checkpoint not on disk",
    },
    "baseline_cnn": {
        "accuracy": 0.8658, "precision": 0.7457, "recall": 0.9181,
        "macro_f1": 0.8230, "specificity": 0.8388, "roc_auc": 0.9456,
        "test_samples": 827,
        "note": "Historical benchmark 2026-09-23 — fine-tuned checkpoint not on disk",
    },
}


@router.get("/models", response_model=ModelsListResponse, tags=["Information"])
def list_models():
    """Return registration status, checkpoint availability, and benchmark metrics for all models.

    Metrics for models whose checkpoints are no longer present on disk are historical results
    from the original benchmark run (2026-09-23, test.csv, 827 images). Only efficientnet_b0
    has been reproduced from the current checkpoint (2026-10-18, test_clean.csv, 839 images).
    Checkpoint paths are not exposed in full to avoid leaking filesystem layout.
    """
    import hashlib

    def _sha256(path) -> str | None:
        try:
            h = hashlib.sha256()
            with open(path, "rb") as f:
                while chunk := f.read(65536):
                    h.update(chunk)
            return h.hexdigest()
        except Exception:
            return None

    items = []
    for name, reg in CHECKPOINT_REGISTRY.items():
        status_info = get_model_status(name)
        ckpt_path = reg.get("expected_checkpoint")
        ckpt_exists = ckpt_path and ckpt_path.is_file()
        sha = _sha256(str(ckpt_path)) if ckpt_exists else None
        metrics = _BENCHMARK_METRICS.get(name)
        items.append(ModelStatusItem(
            model_name=name,
            architecture=reg.get("architecture", name),
            finetuned_available=status_info.get("finetuned_available", False),
            pretrained_available=status_info.get("pretrained_available", False),
            status=status_info.get("status", "Unknown"),
            description=reg.get("description", ""),
            expected_checkpoint="<registry path>",  # Do not expose full filesystem path
            checkpoint_sha256=sha,
            evaluated=metrics is not None,
            metrics=metrics,
        ))

    return ModelsListResponse(
        total_models=len(items),
        available_models=[i.model_name for i in items if i.finetuned_available],
        models=items,
    )
