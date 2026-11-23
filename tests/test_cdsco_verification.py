from __future__ import annotations

import asyncio
import httpx
import pytest
from fastapi.testclient import TestClient

from backend.app.schemas.verification import ProductVerificationRequest
from backend.app.services import cdsco_verification as verification
from backend.app.routes import verification as verification_route
from backend.app.main import app


def _transport(*, html: str, pdf: bytes = b"%PDF-1.4 test") -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/opencms/opencms/en/Alerts/":
            return httpx.Response(
                200,
                text=html,
                headers={"content-type": "text/html; charset=utf-8"},
            )
        return httpx.Response(
            200,
            content=pdf,
            headers={"content-type": "application/pdf"},
        )

    return httpx.MockTransport(handler)


_ALERT_HTML = """<html><table><tr>
<td>List of drugs declared spurious for June 2026</td>
<td><a href="/opencms/resources/UploadCDSCOWeb/Alerts/spurious-june.pdf">Download</a></td>
<td>2026-Jun-15</td>
</tr></table></html>"""


def test_exact_batch_and_product_context_returns_potential_concern(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        verification,
        "_extract_pdf_text",
        lambda _: "SampleDrug Tablets 250 mg. Batch No: AB-123. Mfg by Example Labs.",
    )
    monkeypatch.setattr(verification, "_ollama_explanation", lambda *_: None)
    service = verification.CdscoVerificationService(
        transport=_transport(html=_ALERT_HTML)
    )

    result = asyncio.run(
        service.verify(
            ProductVerificationRequest(
                medicine_name="SampleDrug",
                manufacturer="Example Labs",
                batch_number="AB123",
            )
        )
    )

    assert result.status == "potential_concern"
    assert set(result.evidence_matches) == {
        "batch_number",
        "medicine_name",
        "manufacturer",
    }
    assert result.sources[0].url.startswith("https://www.cdsco.gov.in/opencms/")
    assert result.sources[0].retrieved_at.tzinfo is not None
    assert result.ollama_available is False
    assert result.explanation is None


def test_exact_batch_without_product_context_is_not_misreported_as_match(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(verification, "_extract_pdf_text", lambda _: "Batch: AB123")
    service = verification.CdscoVerificationService(
        transport=_transport(html=_ALERT_HTML)
    )

    result = asyncio.run(
        service.verify(
            ProductVerificationRequest(
                medicine_name="SampleDrug",
                manufacturer="Example Labs",
                batch_number="AB123",
            )
        )
    )

    assert result.status == "unable_to_verify"
    assert result.sources[0].excerpt.startswith("The batch text appears")
    assert "does not verify" in result.warning


def test_missing_batch_does_not_make_network_request() -> None:
    def fail_if_called(_: httpx.Request) -> httpx.Response:
        raise AssertionError("missing batch must not initiate a lookup")

    result = asyncio.run(
        verification.CdscoVerificationService(
            transport=httpx.MockTransport(fail_if_called)
        ).verify(ProductVerificationRequest(medicine_name="SampleDrug"))
    )

    assert result.status == "unable_to_verify"
    assert result.sources == []


def test_absent_alert_is_unable_to_verify_never_officially_verified(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(verification, "_extract_pdf_text", lambda _: "Different batch")
    result = asyncio.run(
        verification.CdscoVerificationService(
            transport=_transport(html=_ALERT_HTML)
        ).verify(ProductVerificationRequest(batch_number="AB123"))
    )

    assert result.status == "unable_to_verify"
    assert "does not verify" in result.warning


def test_external_links_in_official_html_are_not_fetched() -> None:
    requested: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requested.append(str(request.url))
        return httpx.Response(
            200,
            text=(
                '<table><tr><td>Spurious drug list</td>'
                '<td><a href="http://127.0.0.1/admin.pdf">Download</a></td></tr></table>'
            ),
            headers={"content-type": "text/html"},
        )

    result = asyncio.run(
        verification.CdscoVerificationService(
            transport=httpx.MockTransport(handler)
        ).verify(ProductVerificationRequest(batch_number="AB123"))
    )

    assert result.status == "unable_to_verify"
    assert requested == [verification.CDSCO_ALERTS_URL]


def test_unavailable_official_source_returns_safe_inconclusive_response() -> None:
    def unavailable(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("network down", request=request)

    result = asyncio.run(
        verification.CdscoVerificationService(
            transport=httpx.MockTransport(unavailable)
        ).verify(ProductVerificationRequest(batch_number="AB123"))
    )

    assert result.status == "unable_to_verify"
    assert result.sources[0].url == verification.CDSCO_ALERTS_URL
    assert "could not be reached" in result.warning


def test_official_source_parser_rejects_non_https_hosts_and_ports() -> None:
    assert verification._trusted_cdsco_url(verification.CDSCO_ALERTS_URL)
    assert not verification._trusted_cdsco_url("http://www.cdsco.gov.in/opencms/a.pdf")
    assert not verification._trusted_cdsco_url("https://cdsco.gov.in:8443/opencms/a.pdf")
    assert not verification._trusted_cdsco_url("https://127.0.0.1/opencms/a.pdf")


def test_product_verification_schema_rejects_control_chars_and_unknown_urls() -> None:
    with pytest.raises(ValueError):
        ProductVerificationRequest(batch_number="AB\n123")
    with pytest.raises(ValueError):
        ProductVerificationRequest(untrusted_url="http://127.0.0.1/secret")


def test_verification_route_has_structured_contract_and_no_user_url(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class FakeService:
        async def verify(self, request: ProductVerificationRequest):
            assert request.batch_number == "AB123"
            return verification.ProductVerificationResponse(
                status="unable_to_verify",
                status_label="Unable to verify",
                warning="No authoritative batch record found.",
            )

    monkeypatch.setattr(
        verification_route, "CdscoVerificationService", lambda: FakeService()
    )
    client = TestClient(app)

    response = client.post(
        "/verification/official-alerts",
        json={"medicine_name": "SampleDrug", "batch_number": "AB123"},
    )
    assert response.status_code == 200
    assert response.json()["status"] == "unable_to_verify"
    assert response.json()["sources"] == []

    invalid = client.post(
        "/verification/official-alerts",
        json={"batch_number": "AB123", "source_url": "http://127.0.0.1/"},
    )
    assert invalid.status_code == 422
    assert "127.0.0.1" not in invalid.text
