"""FastAPI Application Entry Point for Counterfeit Pharmaceutical Detection Screening API."""

from __future__ import annotations

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from ml.config import DEFAULT_MODEL, SUPPORTED_MODELS, get_device
from backend.app.routes.predict import router as predict_router
from backend.app.schemas.predict import ApiInfoResponse, HealthResponse
from backend.app.services.classifier import ClassifierService


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Preload default model on startup
    ClassifierService.get_instance()
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

# Enable CORS for mobile and web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predict_router, prefix="", tags=["Screening"])


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
    try:
        service = ClassifierService.get_instance()
        secondary_model = service.vision_verifier.model_name
        secondary_endpoint = service.vision_verifier.base_url
    except Exception:
        pass  # Degraded mode — return basic health information
    return HealthResponse(
        status="ok",
        version="1.0.0",
        device=str(dev),
        default_model=DEFAULT_MODEL,
        available_models=SUPPORTED_MODELS,
        secondary_ai_model=secondary_model,
        secondary_ai_endpoint=secondary_endpoint,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=False)
