"""FastAPI Pydantic schemas for counterfeit pharmaceutical screening API."""

from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, Field


class QualityMetrics(BaseModel):
    is_valid: bool
    reason: Optional[str] = None
    blur_score: float
    brightness_mean: float
    dimensions: list[int]


class PredictionResponse(BaseModel):
    prediction: str = Field(..., description="Screening outcome: AUTHENTIC, COUNTERFEIT, or UNKNOWN")
    authentic_probability: float = Field(..., ge=0.0, le=1.0)
    counterfeit_probability: float = Field(..., ge=0.0, le=1.0)
    confidence: float = Field(..., ge=0.0, le=1.0)
    status: str = Field(..., description="AUTHENTIC, COUNTERFEIT, or NEEDS MANUAL REVIEW")
    reason: Optional[str] = Field(None, description="Explanation when status is NEEDS MANUAL REVIEW")
    model_name: str
    threshold: float
    quality: Optional[QualityMetrics] = None


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "1.0.0"
    device: str
    default_model: str
    available_models: list[str]
