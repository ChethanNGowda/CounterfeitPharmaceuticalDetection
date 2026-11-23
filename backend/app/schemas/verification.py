"""Request and response contracts for evidence-assisted product checks."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProductVerificationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    medicine_name: str = Field(default="", max_length=120)
    manufacturer: str = Field(default="", max_length=160)
    batch_number: str = Field(default="", max_length=80)
    manufacturing_date: str = Field(default="", max_length=40)
    expiry_date: str = Field(default="", max_length=40)
    strength: str = Field(default="", max_length=60)
    product_identifier: str = Field(default="", max_length=2048)

    @field_validator(
        "medicine_name",
        "manufacturer",
        "batch_number",
        "manufacturing_date",
        "expiry_date",
        "strength",
        "product_identifier",
    )
    @classmethod
    def reject_control_characters(cls, value: str) -> str:
        if any(ord(character) < 32 or ord(character) == 127 for character in value):
            raise ValueError("Control characters are not accepted.")
        return value.strip()


class VerificationSource(BaseModel):
    title: str
    url: str
    published_at: str | None = None
    retrieved_at: datetime
    excerpt: str = ""


class ProductVerificationResponse(BaseModel):
    status: Literal[
        "officially_verified",
        "potential_concern",
        "inconsistency_detected",
        "unable_to_verify",
    ]
    status_label: str
    explanation: str | None = None
    evidence_matches: list[str] = Field(default_factory=list)
    sources: list[VerificationSource] = Field(default_factory=list)
    ollama_available: bool = False
    warning: str
    disclaimer: str = (
        "A product-code or alert-list check cannot establish the identity, "
        "composition, dosage, safety, or authenticity of the physical medicine."
    )
