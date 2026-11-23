"""Evidence-assisted product checks against fixed official sources only."""

from fastapi import APIRouter

from backend.app.schemas.verification import (
    ProductVerificationRequest,
    ProductVerificationResponse,
)
from backend.app.services.cdsco_verification import CdscoVerificationService

router = APIRouter(prefix="/verification", tags=["Product information"])


@router.post(
    "/official-alerts",
    response_model=ProductVerificationResponse,
    summary="Check a batch against public CDSCO spurious-drug alerts",
)
async def check_official_alerts(
    request: ProductVerificationRequest,
) -> ProductVerificationResponse:
    """Look for a specific batch/product text match in official CDSCO PDFs.

    This endpoint never receives images or fetches a URL supplied by a caller.
    No match is always reported as unable to verify, never as genuine.
    """
    return await CdscoVerificationService().verify(request)
