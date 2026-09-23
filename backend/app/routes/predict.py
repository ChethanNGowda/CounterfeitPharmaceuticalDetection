"""FastAPI route for pharmaceutical image prediction."""

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
async def predict_pharmaceutical(
    file: UploadFile = File(..., description="Multipart tablet image file"),
    threshold: float = Form(DEFAULT_CONFIDENCE_THRESHOLD, description="Confidence threshold between 0.0 and 1.0"),
    model: Optional[str] = Form(DEFAULT_MODEL, description=f"Model name ({', '.join(SUPPORTED_MODELS)})"),
):
    """Screen an uploaded pharmaceutical tablet image.

    Returns binary screening result (AUTHENTIC or COUNTERFEIT), confidence,
    class probabilities, and status (or NEEDS MANUAL REVIEW for low confidence or poor image quality).
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

    service = ClassifierService.get_instance()
    try:
        result = service.predict_image_bytes(
            image_bytes=content,
            filename=file.filename or "upload.jpg",
            model_name=model or DEFAULT_MODEL,
            threshold=threshold,
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
        prediction=result["prediction"],
        authentic_probability=result["authentic_probability"],
        counterfeit_probability=result["counterfeit_probability"],
        confidence=result["confidence"],
        status=result["status"],
        reason=result.get("reason"),
        model_name=result["model_name"],
        threshold=result["threshold"],
        quality=result.get("quality"),
    )
