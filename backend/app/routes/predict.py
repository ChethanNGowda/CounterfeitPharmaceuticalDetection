"""FastAPI route for pharmaceutical image prediction and secondary AI review."""

from __future__ import annotations

import io
import logging
from typing import Optional
from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status
from PIL import Image

from ml.config import CHECKPOINT_REGISTRY, DEFAULT_CONFIDENCE_THRESHOLD, DEFAULT_MODEL, SUPPORTED_MODELS
from ml.models.transfer_learning import CheckpointUnavailableError, get_model_status, normalize_model_name
from backend.app.schemas.predict import (
    AiHealthResponse,
    ModelsListResponse,
    ModelStatusItem,
    PredictionResponse,
    QwenHealthResponse,
)
from backend.app.services.classifier import ClassifierService

router = APIRouter()
logger = logging.getLogger(__name__)

ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/bmp",
}
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP", "BMP"}
MAX_UPLOAD_SIZE = 15 * 1024 * 1024  # 15 MB
MAX_IMAGE_DIMENSION = 10000


def _validate_image_content(content: bytes) -> None:
    """Validate the decoded image without exposing parser details to clients."""
    try:
        with Image.open(io.BytesIO(content)) as probe_img:
            img_format = (probe_img.format or "").upper()
            if img_format not in ALLOWED_IMAGE_FORMATS:
                raise HTTPException(
                    status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                    detail="Unsupported image format. Allowed formats: JPEG, PNG, WEBP, BMP.",
                )
            width, height = probe_img.size
            if width <= 0 or height <= 0 or max(width, height) > MAX_IMAGE_DIMENSION:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Image dimensions are invalid or exceed the supported limit.",
                )
            probe_img.verify()
    except HTTPException:
        raise
    except Exception:
        logger.exception("Uploaded image failed decoding or verification")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Corrupted or invalid image data.",
        )


@router.post("/predict", response_model=PredictionResponse, status_code=status.HTTP_200_OK)
@router.post("/verify", response_model=PredictionResponse, status_code=status.HTTP_200_OK)
async def predict_pharmaceutical(
    file: UploadFile = File(..., description="Multipart tablet image file"),
    threshold: float = Form(
        DEFAULT_CONFIDENCE_THRESHOLD,
        ge=0.50,
        le=1.0,
        description="Authentic-probability cutoff: below 50% indicates counterfeit; 50% through this cutoff requires review; above it indicates authentic.",
    ),
    model: Optional[str] = Form(DEFAULT_MODEL, description=f"Model name ({', '.join(SUPPORTED_MODELS)})"),
    enable_qwen: bool = Form(True, description="Enable secondary AI verification via local Ollama Qwen Vision"),
    enable_vision: Optional[bool] = Form(None, description="Alias for enable_qwen for backward compatibility"),
    vision_mode: Optional[str] = Form(None, description="Vision mode: 'auto' (conditional gating), 'always' (forced), 'never' (disabled)"),
):
    """Screen an uploaded pharmaceutical tablet image using dual-model pipeline.

    - Primary Model: EfficientNet-B0 visual classifier (99.88% test accuracy).
    - Secondary Review: configured Qwen Vision model (via local Ollama).
    - Decision Engine: authentic probability below 50% indicates counterfeit; 50%
      through the configured cutoff (70% by default) requires manual review; above
      that cutoff indicates authentic (subject to review safeguards).
    """
    if model:
        norm_model = normalize_model_name(model)
        if norm_model not in SUPPORTED_MODELS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported model '{model}'. Supported models: {', '.join(SUPPORTED_MODELS)}.",
            )
    if not file.content_type or file.content_type.lower() not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported or missing file format. Allowed types: JPEG, PNG, WEBP, BMP.",
        )

    try:
        content = await file.read()
    except Exception:
        logger.exception("Failed to read uploaded file")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to read uploaded file.",
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

    # Validate decoded content rather than trusting the multipart MIME header.
    _validate_image_content(content)

    # Use enable_vision if explicitly provided, otherwise enable_qwen
    run_qwen = enable_vision if enable_vision is not None else enable_qwen

    try:
        service = ClassifierService.get_instance()
    except (CheckpointUnavailableError, ImportError, ModuleNotFoundError, OSError, RuntimeError):
        logger.exception("Screening model could not be initialized")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Screening service is temporarily unavailable.",
        )
    except Exception:
        logger.exception("Unexpected screening service initialization failure")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Screening service failed to initialize.",
        )

    try:
        result = service.predict_image_bytes(
            image_bytes=content,
            filename=file.filename or "upload.jpg",
            model_name=model or DEFAULT_MODEL,
            threshold=threshold,
            vision_mode=vision_mode,
            enable_qwen=run_qwen,
        )
    except ValueError:
        logger.exception("Invalid screening request or image data")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid screening request or image data.",
        )
    except CheckpointUnavailableError as ckpt_err:
        logger.warning("Requested screening checkpoint is unavailable: %s", ckpt_err)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Requested screening model is unavailable.",
        )
    except (ImportError, ModuleNotFoundError, OSError):
        logger.exception("Screening dependency or resource is unavailable")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Screening service is temporarily unavailable.",
        )
    except RuntimeError:
        logger.exception("Screening inference failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Screening failed unexpectedly. Please try again.",
        )
    except Exception:
        logger.exception("Unexpected screening failure")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Screening failed unexpectedly. Please try again.",
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


@router.get("/ai/health", response_model=AiHealthResponse, tags=["Health"])
def ai_health():
    """Structured AI secondary review readiness and lifecycle status."""
    service = ClassifierService.get_instance()
    health_data = service.vision_verifier.get_health()
    return AiHealthResponse(**health_data)


@router.get("/health/qwen", response_model=QwenHealthResponse, tags=["Health"])
@router.get("/diagnostics/qwen", response_model=QwenHealthResponse, tags=["Health"])
def qwen_diagnostics():
    """Live diagnostic check for local Ollama and Qwen Vision model."""
    service = ClassifierService.get_instance()
    health_data = service.vision_verifier.get_health()
    return QwenHealthResponse(
        status=health_data["status"],
        available=health_data["available"],
        model_name=health_data["configured_model"],
        base_url=health_data["ollama_url"],
        installed_models=health_data["installed_models"],
        model_installed=health_data["model_installed"],
        vision_supported=health_data["vision_supported"],
        last_inference_time=health_data.get("last_inference_time"),
        last_error=health_data.get("last_error"),
        message=health_data["message"],
    )


@router.get("/models", response_model=ModelsListResponse, tags=["Information"])
def list_models():
    """Return registered model availability without unverified performance claims."""
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
        items.append(ModelStatusItem(
            model_name=name,
            architecture=reg.get("architecture", name),
            finetuned_available=status_info.get("finetuned_available", False),
            pretrained_available=status_info.get("pretrained_available", False),
            status=status_info.get("status", "Unknown"),
            description=reg.get("description", ""),
            expected_checkpoint="<registry path>",  # Do not expose full filesystem path
            checkpoint_sha256=sha,
            evaluated=False,
            metrics=None,
        ))

    return ModelsListResponse(
        total_models=len(items),
        available_models=[i.model_name for i in items if i.finetuned_available],
        models=items,
    )
