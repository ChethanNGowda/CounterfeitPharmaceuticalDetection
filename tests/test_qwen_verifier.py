"""Unit tests for QwenReviewer — secondary AI reasoning review layer.

Tests the QwenReviewer class in ml/verification/qwen_reviewer.py, which sends
structured EfficientNet evidence to qwen3:8b (text model) via Ollama for
secondary reasoning review.

NOTE: The old QwenVisualVerifier (qwen_verifier.py) used base64 image encoding
and a vision model that is no longer installed. These tests cover the current
text-evidence-based QwenReviewer instead.
"""

import io
import json
from unittest.mock import MagicMock, patch
import urllib.error

import pytest

from ml.verification.qwen_reviewer import (
    QwenReviewer,
    build_evidence_payload,
    clean_json_text,
    validate_qwen_response,
    review_screening_evidence,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _primary_result(predicted_class="authentic", confidence=0.88,
                    authentic_prob=0.88, counterfeit_prob=0.12, quality_valid=True):
    return {
        "model_name": "efficientnet_b0",
        "predicted_class": predicted_class,
        "prediction": predicted_class.upper(),
        "authentic_probability": authentic_prob,
        "counterfeit_probability": counterfeit_prob,
        "confidence": confidence,
        "quality": {
            "is_valid": quality_valid,
            "blur_score": 80.0,
            "brightness_mean": 128.0,
            "dimensions": [224, 224],
        },
    }


def _mock_ollama_response(assessment="AUTHENTIC", confidence=0.85, reasoning=None):
    """Build a mock Ollama HTTP response wrapping valid qwen JSON."""
    if reasoning is None:
        reasoning = ["Evidence consistent with authentic characteristics."]
    body_inner = {
        "assessment": assessment,
        "confidence": confidence,
        "reasoning": reasoning,
        "needs_human_verification": assessment != "AUTHENTIC",
        "warning": "Visual analysis cannot establish chemical authenticity.",
    }
    body_outer = {
        "model": "qwen3:8b",
        "response": json.dumps(body_inner),
    }
    mock_resp = MagicMock()
    mock_resp.getcode.return_value = 200
    mock_resp.read.return_value = json.dumps(body_outer).encode("utf-8")
    mock_resp.__enter__.return_value = mock_resp
    mock_resp.__exit__.return_value = False
    return mock_resp


# ---------------------------------------------------------------------------
# clean_json_text
# ---------------------------------------------------------------------------

def test_clean_json_text_strips_markdown_fence():
    raw = '```json\n{"assessment": "AUTHENTIC", "confidence": 0.9}\n```'
    result = clean_json_text(raw)
    parsed = json.loads(result)
    assert parsed["assessment"] == "AUTHENTIC"
    assert parsed["confidence"] == 0.9


def test_clean_json_text_extracts_from_surrounding_prose():
    raw = 'Sure! Here is the result:\n{"assessment": "SUSPICIOUS"}\nHope this helps!'
    result = clean_json_text(raw)
    assert json.loads(result) == {"assessment": "SUSPICIOUS"}


def test_clean_json_text_returns_as_is_when_already_clean():
    raw = '{"assessment": "COUNTERFEIT", "confidence": 0.95}'
    assert clean_json_text(raw) == raw.strip()


# ---------------------------------------------------------------------------
# validate_qwen_response
# ---------------------------------------------------------------------------

def test_validate_valid_authentic_response():
    data = {
        "assessment": "AUTHENTIC",
        "confidence": 0.87,
        "reasoning": ["Standard tablet shape.", "Clear imprint."],
        "needs_human_verification": False,
        "warning": "Visual analysis only.",
    }
    out = validate_qwen_response(data)
    assert out["available"] is True
    assert out["assessment"] == "AUTHENTIC"
    assert out["confidence"] == 0.87
    assert out["needs_human_verification"] is False
    assert len(out["reasoning"]) == 2


def test_validate_clamps_confidence_to_0_1():
    data = {"assessment": "COUNTERFEIT", "confidence": 2.5}
    out = validate_qwen_response(data)
    assert out["confidence"] == 1.0

    data2 = {"assessment": "COUNTERFEIT", "confidence": -0.5}
    out2 = validate_qwen_response(data2)
    assert out2["confidence"] == 0.0


def test_validate_normalises_unknown_assessment_to_suspicious():
    data = {"assessment": "MAYBE_FAKE", "confidence": 0.6}
    out = validate_qwen_response(data)
    assert out["assessment"] == "SUSPICIOUS"


def test_validate_handles_string_reasoning():
    data = {
        "assessment": "SUSPICIOUS",
        "confidence": 0.5,
        "reasoning": "Single string reason.",
    }
    out = validate_qwen_response(data)
    assert isinstance(out["reasoning"], list)
    assert len(out["reasoning"]) >= 1


def test_validate_fills_missing_reasoning():
    data = {"assessment": "AUTHENTIC", "confidence": 0.80}
    out = validate_qwen_response(data)
    assert isinstance(out["reasoning"], list)
    assert len(out["reasoning"]) >= 1


def test_validate_sets_needs_human_false_for_authentic():
    """Default: AUTHENTIC assessment → needs_human_verification = False (when not supplied)."""
    data = {"assessment": "AUTHENTIC", "confidence": 0.90}
    out = validate_qwen_response(data)
    assert out["needs_human_verification"] is False


def test_validate_sets_needs_human_true_for_counterfeit():
    data = {"assessment": "COUNTERFEIT", "confidence": 0.90}
    out = validate_qwen_response(data)
    assert out["needs_human_verification"] is True


# ---------------------------------------------------------------------------
# build_evidence_payload
# ---------------------------------------------------------------------------

def test_build_evidence_payload_structure():
    primary = _primary_result(predicted_class="authentic", confidence=0.88,
                               authentic_prob=0.88, counterfeit_prob=0.12)
    evidence = build_evidence_payload(primary)
    assert evidence["model"] == "efficientnet_b0"
    assert evidence["prediction"] == "authentic"
    assert 0.0 <= evidence["authentic_probability"] <= 1.0
    assert 0.0 <= evidence["counterfeit_probability"] <= 1.0
    assert 0.0 <= evidence["confidence"] <= 1.0
    assert "image_quality" in evidence
    assert "quality_checks" in evidence


def test_build_evidence_payload_counterfeit():
    primary = _primary_result(predicted_class="counterfeit", confidence=0.95,
                               authentic_prob=0.05, counterfeit_prob=0.95)
    evidence = build_evidence_payload(primary)
    assert evidence["prediction"] == "counterfeit"
    assert evidence["image_quality"] == "good"


def test_build_evidence_payload_bad_quality():
    primary = _primary_result(quality_valid=False)
    evidence = build_evidence_payload(primary)
    assert evidence["image_quality"] == "poor"


def test_build_evidence_payload_extra_quality_result():
    primary = _primary_result()
    quality = {
        "is_valid": True,
        "blur_score": 90.0,
        "brightness_mean": 130.0,
        "dimensions": [300, 300],
    }
    evidence = build_evidence_payload(primary, quality_result=quality)
    assert evidence["quality_checks"]["blur_ok"] is True
    assert evidence["quality_checks"]["resolution_ok"] is True


# ---------------------------------------------------------------------------
# QwenReviewer.review_evidence — error handling
# ---------------------------------------------------------------------------

def test_reviewer_handles_connection_error():
    """URLError (service unreachable) → fallback with available=False."""
    reviewer = QwenReviewer(base_url="http://127.0.0.1:99999", timeout=1.0)
    evidence = build_evidence_payload(_primary_result())
    result = reviewer.review_evidence(evidence)

    assert result["available"] is False
    assert result["assessment"] == "SUSPICIOUS"
    assert result["needs_human_verification"] is True
    assert "error" in result


def test_reviewer_handles_404_model_not_found():
    """HTTPError 404 → fallback with available=False."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result())

    with patch("urllib.request.urlopen") as mock_open:
        mock_open.side_effect = urllib.error.HTTPError(
            url="http://localhost:11434/api/generate",
            code=404,
            msg="Not Found",
            hdrs={},
            fp=io.BytesIO(b'{"error":"model not found"}'),
        )
        result = reviewer.review_evidence(evidence)

    assert result["available"] is False
    assert "404" in result.get("error", "")
    assert result["assessment"] == "SUSPICIOUS"


def test_reviewer_handles_timeout():
    """TimeoutError → fallback with available=False."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result())

    with patch("urllib.request.urlopen", side_effect=TimeoutError("timed out")):
        result = reviewer.review_evidence(evidence)

    assert result["available"] is False
    assert result["assessment"] == "SUSPICIOUS"
    assert any("timed out" in r.lower() for r in result["reasoning"])


def test_reviewer_handles_url_error():
    """Generic URLError (network unreachable) → fallback."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result())

    with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("Connection refused")):
        result = reviewer.review_evidence(evidence)

    assert result["available"] is False
    assert result["assessment"] == "SUSPICIOUS"


def test_reviewer_handles_empty_response():
    """Empty 'response' field → fallback with available=False."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result())

    body = json.dumps({"model": "qwen3:8b", "response": ""}).encode("utf-8")
    mock_resp = MagicMock()
    mock_resp.getcode.return_value = 200
    mock_resp.read.return_value = body
    mock_resp.__enter__.return_value = mock_resp
    mock_resp.__exit__.return_value = False

    with patch("urllib.request.urlopen", return_value=mock_resp):
        result = reviewer.review_evidence(evidence)

    assert result["available"] is False
    assert result["assessment"] == "SUSPICIOUS"


def test_reviewer_parses_valid_authentic_response():
    """Valid JSON from Ollama is parsed and validated correctly."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result(predicted_class="authentic", confidence=0.88))
    mock_resp = _mock_ollama_response("AUTHENTIC", 0.85)

    with patch("urllib.request.urlopen", return_value=mock_resp):
        result = reviewer.review_evidence(evidence)

    assert result["available"] is True
    assert result["assessment"] == "AUTHENTIC"
    assert 0.0 <= result["confidence"] <= 1.0
    assert isinstance(result["reasoning"], list)
    assert result["needs_human_verification"] is False


def test_reviewer_parses_valid_counterfeit_response():
    """Valid COUNTERFEIT JSON from Ollama is parsed correctly."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result(predicted_class="counterfeit", confidence=0.95,
                                                       authentic_prob=0.05, counterfeit_prob=0.95))
    mock_resp = _mock_ollama_response("COUNTERFEIT", 0.93,
                                      reasoning=["Irregular tablet shape.", "Smeared imprint text."])

    with patch("urllib.request.urlopen", return_value=mock_resp):
        result = reviewer.review_evidence(evidence)

    assert result["available"] is True
    assert result["assessment"] == "COUNTERFEIT"
    assert result["needs_human_verification"] is True
    assert len(result["reasoning"]) == 2


def test_reviewer_handles_malformed_json_response():
    """If Ollama returns non-JSON text, available=True with SUSPICIOUS and error key."""
    reviewer = QwenReviewer()
    evidence = build_evidence_payload(_primary_result())

    body_outer = {"model": "qwen3:8b", "response": "Sorry, I cannot answer that."}
    mock_resp = MagicMock()
    mock_resp.getcode.return_value = 200
    mock_resp.read.return_value = json.dumps(body_outer).encode("utf-8")
    mock_resp.__enter__.return_value = mock_resp
    mock_resp.__exit__.return_value = False

    with patch("urllib.request.urlopen", return_value=mock_resp):
        result = reviewer.review_evidence(evidence)

    # JSONDecodeError → available=True but SUSPICIOUS and error key present
    assert result["assessment"] == "SUSPICIOUS"
    assert result["needs_human_verification"] is True
    assert "error" in result


def test_reviewer_default_model_and_url():
    """Default reviewer uses qwen3:8b model and localhost Ollama."""
    reviewer = QwenReviewer()
    assert "qwen3" in reviewer.model_name
    assert "11434" in reviewer.base_url


def test_reviewer_custom_timeout():
    reviewer = QwenReviewer(timeout=5.0)
    assert reviewer.timeout == 5.0


# ---------------------------------------------------------------------------
# review_screening_evidence convenience helper
# ---------------------------------------------------------------------------

def test_review_screening_evidence_connection_error():
    """Helper function also gracefully handles connection errors."""
    primary = _primary_result(predicted_class="counterfeit", confidence=0.95,
                               authentic_prob=0.05, counterfeit_prob=0.95)
    result = review_screening_evidence(
        primary,
        base_url="http://127.0.0.1:99999",
        timeout=1.0,
    )
    assert result["available"] is False
    assert result["assessment"] == "SUSPICIOUS"


def test_review_screening_evidence_valid_mock():
    """Helper function returns parsed result from mocked Ollama."""
    primary = _primary_result(predicted_class="authentic", confidence=0.88)
    mock_resp = _mock_ollama_response("AUTHENTIC", 0.88)

    with patch("urllib.request.urlopen", return_value=mock_resp):
        result = review_screening_evidence(primary)

    assert result["available"] is True
    assert result["assessment"] == "AUTHENTIC"
    assert isinstance(result["reasoning"], list)
