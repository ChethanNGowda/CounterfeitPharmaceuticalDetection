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


class PredictionResponse(BaseModel):
    # Core multi-model response contract
    primary_model: str = Field("efficientnet_b0", description="Primary visual classifier architecture")
    prediction: str = Field(..., description="Screening prediction: AUTHENTIC, COUNTERFEIT, or UNKNOWN")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence of primary model")
    qwen: QwenReviewDetails = Field(default_factory=QwenReviewDetails, description="Secondary AI vision verification review from qwen3-vl:4b")
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

    # Backward-compatible fields
    status: str = Field(..., description="AUTHENTIC, COUNTERFEIT, or NEEDS MANUAL REVIEW")
    reason: Optional[str] = Field(None, description="Explanation when status is NEEDS MANUAL REVIEW")
    model_name: str = "efficientnet_b0"
    threshold: float = 0.70
    authentic_probability: float = Field(0.0, ge=0.0, le=1.0)
    counterfeit_probability: float = Field(0.0, ge=0.0, le=1.0)
    quality: Optional[QualityMetrics] = None


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "1.0.0"
    device: str
    default_model: str
    available_models: list[str] = Field(default_factory=lambda: AVAILABLE_MODELS)
    secondary_ai_model: str = "qwen3-vl:4b"
    secondary_ai_endpoint: str = "http://localhost:11434"
