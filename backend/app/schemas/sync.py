"""Versioned contracts for authenticated record synchronization."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class SyncRecordRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    api_version: str = Field("v1", pattern=r"^v1$")
    client_record_id: str = Field(..., min_length=1, max_length=128)
    client_created_at: datetime
    operating_mode: str = Field(..., min_length=1, max_length=32)
    provider: str = Field(..., min_length=1, max_length=32)
    sync_status: str = Field(..., min_length=1, max_length=32)
    screening_metadata: dict[str, Any] = Field(default_factory=dict)
    notes: str | None = Field(None, max_length=4000)
    image_upload_consent: bool = False
    image_base64: str | None = None
    image_media_type: str | None = None
    client_file_name: str | None = Field(None, max_length=255)

    @field_validator("client_record_id")
    @classmethod
    def validate_record_id(cls, value: str) -> str:
        if any(char in value for char in ("/", "\\", "\x00")):
            raise ValueError("client_record_id contains a forbidden character")
        return value.strip()


class SyncRecordResponse(BaseModel):
    api_version: str = "v1"
    server_record_id: str
    client_record_id: str
    synchronized_at: datetime
    duplicate: bool
    image_stored: bool
    screening_verified: bool = False
    message: str
