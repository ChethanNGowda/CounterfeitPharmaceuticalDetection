"""Authenticated, idempotent synchronization endpoint."""

from __future__ import annotations

import base64
import binascii
import io
import logging
from pathlib import Path

from fastapi import APIRouter, Header, HTTPException, status
from PIL import Image

from backend.app.schemas.sync import SyncRecordRequest, SyncRecordResponse
from backend.app.services.sync_store import SyncStore

router = APIRouter(prefix="/sync", tags=["Synchronization"])
logger = logging.getLogger(__name__)
store = SyncStore()

MAX_RECORD_PAYLOAD = 256 * 1024
MAX_IMAGE_SIZE = 15 * 1024 * 1024
ALLOWED_MEDIA_TYPES = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/bmp": "bmp",
}


def _decode_image(request: SyncRecordRequest) -> tuple[bytes | None, str | None]:
    if request.image_base64 is None:
        if request.image_media_type or request.client_file_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Image metadata requires an image payload.",
            )
        return None, None
    if not request.image_upload_consent:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image upload requires explicit consent.",
        )
    if request.image_media_type not in ALLOWED_MEDIA_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported image format.",
        )
    try:
        image_bytes = base64.b64decode(request.image_base64, validate=True)
    except (ValueError, binascii.Error):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image payload is not valid base64.",
        )
    if not image_bytes or len(image_bytes) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Image payload exceeds the 15 MB limit.",
        )
    try:
        with Image.open(io.BytesIO(image_bytes)) as image:
            if image.format not in {"JPEG", "PNG", "WEBP", "BMP"}:
                raise ValueError
            image.verify()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image payload is invalid or corrupted.",
        )
    return image_bytes, ALLOWED_MEDIA_TYPES[request.image_media_type]


@router.post(
    "/records",
    response_model=SyncRecordResponse,
    status_code=status.HTTP_201_CREATED,
)
def synchronize_record(
    request: SyncRecordRequest,
    authorization: str | None = Header(default=None),
) -> SyncRecordResponse:
    device_id = store.authenticate(authorization)
    if device_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Valid device credentials are required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if len(request.model_dump_json()) > MAX_RECORD_PAYLOAD:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Synchronization record exceeds the size limit.",
        )
    image_bytes, extension = _decode_image(request)
    payload = request.model_dump(
        mode="json", exclude={"image_base64", "client_file_name"}
    )
    payload["screening_verified"] = False
    try:
        server_id, duplicate, synchronized_at = store.save_record(
            device_id,
            request.client_record_id,
            payload,
            image_bytes,
            extension,
        )
    except ValueError as exc:
        if str(exc) == "idempotency_conflict":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Client record ID was already synchronized with different data.",
            )
        raise
    except Exception:
        logger.exception("Synchronization record persistence failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Synchronization could not be durably stored.",
        )
    return SyncRecordResponse(
        server_record_id=server_id,
        client_record_id=request.client_record_id,
        synchronized_at=synchronized_at,
        duplicate=duplicate,
        image_stored=image_bytes is not None,
        message="Record synchronized as unverified client metadata.",
    )
