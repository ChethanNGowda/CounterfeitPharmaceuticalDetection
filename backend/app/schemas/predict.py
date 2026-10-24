"""FastAPI Pydantic schemas for counterfeit pharmaceutical screening API."""

from __future__ import annotations

from typing import Any, Optional, Union
from pydantic import BaseModel, Field

from ml.config import AVAILABLE_MODELS


class QualityMetrics(BaseModel):
    is_valid: bool
    reason: Optional[str] = None
    blur_score: float
    brightness_mean: float
    dimensions: list[int]
    aspect_ratio: Optional[float] = None
    contrast: Optional[float] = None
    color_mode: Optional[str] = "RGB"
    exposure_status: Optional[str] = None
    sharpness_status: Optional[str] = None
    suitability: Optional[str] = None


class VisualColorAnalysis(BaseModel):
    dominant_color: Optional[str] = None
    average_rgb: Optional[list[float]] = None
    consistency: Optional[str] = None
    visible_variation: Optional[str] = None


class VisualShapeAnalysis(BaseModel):
    object_detected: Optional[str] = None
    shape_type: Optional[str] = None
    circularity: Optional[float] = None
    aspect_ratio: Optional[float] = None
    symmetry: Optional[str] = None


class VisualSizeAnalysis(BaseModel):
    bounding_box: Optional[str] = None
    pixel_area: Optional[str] = None
    aspect_ratio: Optional[float] = None
    physical_scale_note: Optional[str] = None


class VisualSurfaceAnalysis(BaseModel):
    texture_variation: Optional[str] = None
    surface_uniformity: Optional[str] = None
    visible_spots: Optional[str] = None
    surface_irregularities: Optional[str] = None


class VisualMarkingsAnalysis(BaseModel):
    markings_visible: Optional[str] = None
    imprint_type: Optional[str] = None
    text_recognition: Optional[str] = None
    legibility: Optional[str] = None


class VisualEdgeAnalysis(BaseModel):
    edge_integrity: Optional[str] = None
    cracks: Optional[str] = None
    chipping: Optional[str] = None
    contour: Optional[str] = None


class VisualPackagingAnalysis(BaseModel):
    status: Optional[str] = None
    packaging_type: Optional[str] = None
    condition: Optional[str] = None


class VisualAnalysisReport(BaseModel):
    color: Optional[VisualColorAnalysis] = None
    shape: Optional[VisualShapeAnalysis] = None
    size: Optional[VisualSizeAnalysis] = None
    surface: Optional[VisualSurfaceAnalysis] = None
    markings: Optional[VisualMarkingsAnalysis] = None
    edges: Optional[VisualEdgeAnalysis] = None
    packaging: Optional[VisualPackagingAnalysis] = None
    error: Optional[str] = None


class QwenReviewDetails(BaseModel):
    available: bool = False
    status: Optional[str] = None
    assessment: Optional[str] = "SUSPICIOUS"  # AUTHENTIC, COUNTERFEIT, SUSPICIOUS, UNCERTAIN, UNAVAILABLE
    confidence: Optional[Union[float, str]] = 0.0
    reasoning: list[str] = Field(default_factory=list)
    needs_human_verification: bool = True
    warning: Optional[str] = None
    error: Optional[str] = None
    image_quality: Optional[str] = None
    recommendation: Optional[str] = None
    model_name: Optional[str] = None
    raw_text: Optional[str] = None
    tablet_shape: Optional[str] = None
    tablet_color: Optional[str] = None
    tablet_surface: Optional[str] = None
    tablet_markings: Optional[str] = None
    tablet_edges: Optional[str] = None
    observations_list: list[str] = Field(default_factory=list)
    concerns_list: list[str] = Field(default_factory=list)
    final_explanation: Optional[str] = None


class PredictionResponse(BaseModel):
    # Core multi-model response contract
    primary_model: str = Field("efficientnet_b0", description="Primary visual classifier architecture")
    prediction: str = Field(..., description="Screening prediction: AUTHENTIC, COUNTERFEIT, or UNKNOWN")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence of primary model")
    qwen: QwenReviewDetails = Field(default_factory=QwenReviewDetails, description="Secondary AI vision verification review from local Qwen Vision")
    final_result: str = Field(..., description="Final synthesized verdict: LIKELY AUTHENTIC, LIKELY COUNTERFEIT, or SUSPICIOUS / NEEDS VERIFICATION")
    needs_human_verification: bool = Field(False, description="Whether manual physical verification is advised")
    warning: Optional[str] = Field(None, description="Operational or discrepancy warning message")
    disclaimer: str = Field(
        "AI-assisted preliminary screening only. Visual and convolutional appearance analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), or bioequivalence.",
        description="Mandatory non-laboratory screening disclaimer"
    )

    # Standardized pipeline execution fields
    secondary_executed: bool = Field(False, description="Whether secondary vision verification was executed")
    secondary_reason: Optional[str] = Field(None, description="Reason why secondary verification was executed or skipped")
    reasons: list[str] = Field(default_factory=list, description="Structured decision reasons")
    disagreement: bool = Field(False, description="Whether primary classifier and secondary AI disagreed")
    primary_prediction: Optional[str] = Field(None, description="Primary prediction: AUTHENTIC, COUNTERFEIT, or UNKNOWN")
    primary_confidence: Optional[float] = Field(None, description="Confidence of primary model")

    # Visual feature inspection report
    visual_analysis: Optional[VisualAnalysisReport] = Field(None, description="Deterministic visual feature analysis of the tablet/packaging")

    # Backward-compatible fields
    status: str = Field(..., description="AUTHENTIC, COUNTERFEIT, or NEEDS MANUAL REVIEW")
    reason: Optional[str] = Field(None, description="Explanation when status is NEEDS MANUAL REVIEW")
    model_name: str = "efficientnet_b0"
    threshold: float = Field(
        0.70,
        description="Authentic-probability cutoff; 50% through this value is manual review, above it indicates authentic.",
    )
    authentic_probability: float = Field(0.0, ge=0.0, le=1.0)
    counterfeit_probability: float = Field(0.0, ge=0.0, le=1.0)
    quality: Optional[QualityMetrics] = None


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "1.0.0"
    device: str
    default_model: str
    available_models: list[str] = Field(default_factory=lambda: AVAILABLE_MODELS)
    secondary_ai_model: str = "qwen3.5:4b"
    secondary_ai_endpoint: str = "http://localhost:11434"


class ModelStatusItem(BaseModel):
    model_name: str
    architecture: str
    finetuned_available: bool
    pretrained_available: bool
    status: str
    description: str
    expected_checkpoint: str
    checkpoint_sha256: Optional[str] = None
    evaluated: bool = False
    metrics: Optional[dict[str, Any]] = None


class ModelsListResponse(BaseModel):
    total_models: int
    available_models: list[str]
    models: list[ModelStatusItem]


class QwenHealthResponse(BaseModel):
    status: str = "READY"  # READY, OLLAMA_UNREACHABLE, MODEL_NOT_INSTALLED, ERROR
    available: bool = True
    model_name: str = "qwen3.5:4b"
    base_url: str = "http://localhost:11434"
    installed_models: list[str] = Field(default_factory=list)
    message: str = "Qwen Vision secondary review is ready."


class ApiInfoResponse(BaseModel):
    name: str = "Counterfeit Pharmaceutical Detection API"
    version: str = "1.0.0"
    status: str = "ok"
    description: str = (
        "AI-assisted preliminary screening system for detecting counterfeit pharmaceutical tablets. "
        "Intended for preliminary smartphone triage, not certified chemical laboratory testing."
    )
    docs_url: str = "/docs"
    endpoints: dict[str, str] = Field(
        default_factory=lambda: {
            "root": "GET /",
            "health": "GET /health",
            "predict": "POST /predict",
            "verify": "POST /verify (alias for /predict)",
        }
    )
    supported_models: list[str] = Field(default_factory=lambda: AVAILABLE_MODELS)
    default_model: str = "efficientnet_b0"
    thresholds: dict[str, float] = Field(
        default_factory=lambda: {
            "counterfeit_authentic_probability_cutoff": 0.50,
            "authentic_probability_cutoff": 0.70,
        }
    )
    usage: str = (
        "Submit a multipart/form-data POST request to /predict or /verify with an image 'file'. "
        "Optional parameters: 'threshold' (authentic-probability cutoff, 0.50-1.0; default 0.70), 'model' (model name), 'vision_mode' ('auto'|'always'|'never'), "
        "'enable_qwen' (bool)."
    )
    disclaimer: str = (
        "AI-assisted preliminary screening only. Visual and convolutional appearance analysis CANNOT "
        "certify chemical purity, active pharmaceutical ingredients (API), or bioequivalence. "
        "Laboratory chemical testing remains the sole definitive standard."
    )
