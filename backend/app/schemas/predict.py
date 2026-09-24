"""FastAPI Pydantic schemas for counterfeit pharmaceutical screening API."""

from __future__ import annotations

from typing import Any, Optional
from pydantic import BaseModel, Field


class QualityMetrics(BaseModel):
    is_valid: bool
    reason: Optional[str] = None
    blur_score: float
    brightness_mean: float
    dimensions: list[int]


class QwenReviewDetails(BaseModel):
    available: bool = False
    assessment: Optional[str] = "SUSPICIOUS"  # AUTHENTIC, COUNTERFEIT, SUSPICIOUS
    confidence: Optional[float] = 0.0
    reasoning: list[str] = Field(default_factory=list)
    needs_human_verification: bool = True
    warning: Optional[str] = None
    error: Optional[str] = None


class PredictionResponse(BaseModel):
    # Core multi-model response contract
    primary_model: str = Field("efficientnet_b0", description="Primary visual classifier architecture")
    prediction: str = Field(..., description="Screening prediction: AUTHENTIC, COUNTERFEIT, or UNKNOWN")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence of primary model")
    qwen: QwenReviewDetails = Field(default_factory=QwenReviewDetails, description="Secondary AI reasoning review from qwen3:8b")
    final_result: str = Field(..., description="Final synthesized verdict: LIKELY AUTHENTIC, LIKELY COUNTERFEIT, or SUSPICIOUS / NEEDS VERIFICATION")
    needs_human_verification: bool = Field(False, description="Whether manual physical verification is advised")
    warning: Optional[str] = Field(None, description="Operational or discrepancy warning message")
    disclaimer: str = Field(
        "AI-assisted preliminary screening only. Visual and convolutional appearance analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), or bioequivalence.",
        description="Mandatory non-laboratory screening disclaimer"
    )

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
    available_models: list[str]
    secondary_ai_model: str = "qwen3:8b"
    secondary_ai_endpoint: str = "http://localhost:11434"
