"""FastAPI Application Entry Point for Counterfeit Pharmaceutical Detection Screening API."""

from __future__ import annotations

from contextlib import asynccontextmanager
import logging
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ml.config import DEFAULT_MODEL, SUPPORTED_MODELS, get_device
from backend.app.routes.predict import router as predict_router
from backend.app.routes.sync import router as sync_router
from backend.app.schemas.predict import ApiInfoResponse, HealthResponse
from backend.app.services.classifier import ClassifierService

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Preload default model on startup
    try:
        ClassifierService.get_instance()
    except Exception:
        logger.exception("Default screening model could not be preloaded")
    yield


app = FastAPI(
    title="Counterfeit Pharmaceutical Detection API",
    description=(
        "AI-assisted preliminary screening system for detecting counterfeit pharmaceutical tablets. "
        "Intended for preliminary smartphone triage, not certified chemical laboratory testing."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

def _cors_origins() -> list[str]:
    configured = os.getenv("CORS_ALLOWED_ORIGINS", "")
    return [origin.strip() for origin in configured.split(",") if origin.strip()]


# Mobile clients do not require CORS. Browser clients must opt in explicitly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predict_router, prefix="", tags=["Screening"])
app.include_router(sync_router)


@app.get("/", response_model=ApiInfoResponse, tags=["Information"])
def api_info():
    """Basic API information, usage guidance, and supported endpoints."""
    return ApiInfoResponse()


@app.get("/health", response_model=HealthResponse, tags=["Health"])
def health_check():
    """Lightweight operational health check.

    Always returns HTTP 200. Reports model and secondary AI availability in the
    response body so callers can detect degraded-mode operation without treating
    it as a hard server error.
    """
    dev = get_device()
    secondary_model = "qwen3.5:4b"
    secondary_endpoint = "http://localhost:11434"
    secondary_status = None
    secondary_avail = None
    try:
        service = ClassifierService.get_instance()
        secondary_model = service.vision_verifier.model_name
        secondary_endpoint = service.vision_verifier.base_url
        ai_health = service.vision_verifier.get_health()
        secondary_status = ai_health.get("status")
        secondary_avail = ai_health.get("available")
    except Exception:
        logger.exception("Health check could not inspect the screening service")
    return HealthResponse(
        status="ok",
        version="1.0.0",
        device=str(dev),
        default_model=DEFAULT_MODEL,
        available_models=SUPPORTED_MODELS,
        secondary_ai_model=secondary_model,
        secondary_ai_endpoint=secondary_endpoint,
        secondary_ai_status=secondary_status,
        secondary_ai_available=secondary_avail,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=False)
