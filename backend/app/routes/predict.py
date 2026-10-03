"""FastAPI route for pharmaceutical image prediction and secondary AI review."""

from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from ml.config import DEFAULT_CONFIDENCE_THRESHOLD, DEFAULT_MODEL, SUPPORTED_MODELS
from backend.app.schemas.predict import PredictionResponse
from backend.app.services.classifier import ClassifierService

router = APIRouter()

ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/bmp",
}


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
        # Backward-compatible fields
        status=result["status"],
        reason=result.get("reason"),
        model_name=result["model_name"],
        threshold=result["threshold"],
        authentic_probability=result["authentic_probability"],
        counterfeit_probability=result["counterfeit_probability"],
        quality=result.get("quality"),
    )
