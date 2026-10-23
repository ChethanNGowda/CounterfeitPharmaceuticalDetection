"""Unit tests for QwenVisionVerifier — secondary AI visual verification layer."""

from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest

from ml.verification.qwen_verifier import (
    QwenVisionVerifier,
    parse_qwen_vision_output,
    synthesize_final_result,
    format_final_screening_result,
)


def test_parse_qwen_vision_output():
    sample_text = """==================================================
QWEN VISION VERIFICATION
========================

Assessment: AUTHENTIC

Visual Confidence: HIGH

Image Quality: GOOD

Tablet Analysis:
* Shape: Round
* Color: White
* Surface: Smooth
* Markings: Clear debossed 500
* Edges: Intact
* Other visible characteristics: None

Packaging Analysis:
Not visible.

Observations:
* Standard pharmaceutical tablet appearance.
* Markings are crisp.

Potential Concerns:
* None noted visually.

Recommendation:
AUTOMATED SCREENING

Final Explanation:
Visual features match standard pharmaceutical production."""

    parsed = parse_qwen_vision_output(sample_text)
    assert parsed["assessment"] == "AUTHENTIC"
    assert parsed["confidence"] == "HIGH"
    assert parsed["image_quality"] == "GOOD"
    assert parsed["recommendation"] == "AUTOMATED SCREENING"


def test_parse_qwen_vision_output_uncertain():
    sample_text = """Assessment: UNCERTAIN
Visual Confidence: LOW
Image Quality: POOR
Recommendation: MANUAL REVIEW
Final Explanation: Image is too blurry."""

    parsed = parse_qwen_vision_output(sample_text)
    assert parsed["assessment"] == "UNCERTAIN"
    assert parsed["confidence"] == "LOW"
    assert parsed["image_quality"] == "POOR"
    assert parsed["recommendation"] == "MANUAL REVIEW"


def test_qwen_vision_verifier_file_not_found():
    verifier = QwenVisionVerifier()
    res = verifier.verify_image("non_existent_file_xyz123.jpg")
    assert res["available"] is False
    assert res["status"] == "UNAVAILABLE"
    assert "not found" in res["reason"].lower()


def test_qwen_vision_verifier_invalid_image(tmp_path):
    bad_file = tmp_path / "bad.jpg"
    bad_file.write_bytes(b"not a real jpeg")
    verifier = QwenVisionVerifier()
    res = verifier.verify_image(bad_file)
    assert res["available"] is False
    assert res["status"] == "UNAVAILABLE"
    assert "invalid" in res["reason"].lower() or "unreadable" in res["reason"].lower()


def test_synthesize_final_result_disagreement():
    primary = {
        "prediction": "COUNTERFEIT",
        "confidence": 0.95,
        "status": "COUNTERFEIT",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "AUTHENTIC",
        "confidence": "HIGH",
        "recommendation": "AUTOMATED SCREENING",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert synth["needs_human_verification"] is True
    assert synth["disagreement"] is True
    assert "conflicting" in synth["reason"].lower() or "disagreement" in synth["reason"].lower()


def test_synthesize_final_result_corroborated_authentic():
    primary = {
        "prediction": "AUTHENTIC",
        "confidence": 0.92,
        "status": "AUTHENTIC",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "AUTHENTIC",
        "confidence": "HIGH",
        "recommendation": "AUTOMATED SCREENING",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "LIKELY AUTHENTIC"
    assert synth["needs_human_verification"] is False
    assert synth["disagreement"] is False


def test_synthesize_final_result_corroborated_counterfeit():
    primary = {
        "prediction": "COUNTERFEIT",
        "confidence": 0.98,
        "status": "COUNTERFEIT",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "COUNTERFEIT",
        "confidence": "HIGH",
        "recommendation": "MANUAL REVIEW",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "LIKELY COUNTERFEIT"
    assert synth["needs_human_verification"] is True
    assert synth["disagreement"] is False


def test_synthesize_final_result_low_confidence_triggers_review():
    primary = {
        "prediction": "AUTHENTIC",
        "confidence": 0.55,
        "status": "NEEDS MANUAL REVIEW",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "AUTHENTIC",
        "confidence": "HIGH",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert synth["needs_human_verification"] is True


def test_synthesize_final_result_qwen_uncertain_high_confidence_counterfeit():
    """High-confidence primary counterfeit (>= 90%) is preserved when Qwen is merely uncertain."""
    primary = {
        "prediction": "COUNTERFEIT",
        "confidence": 0.9981,
        "status": "COUNTERFEIT",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "UNCERTAIN",
        "confidence": "LOW",
        "recommendation": "MANUAL REVIEW",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "LIKELY COUNTERFEIT"
    assert synth["needs_human_verification"] is True
    assert "uncertain" in synth["reason"].lower()


def test_synthesize_final_result_qwen_uncertain_high_confidence_authentic():
    """High-confidence primary authentic (>= 90%) is preserved when Qwen is merely uncertain."""
    primary = {
        "prediction": "AUTHENTIC",
        "confidence": 0.94,
        "status": "AUTHENTIC",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "UNCERTAIN",
        "confidence": "LOW",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "LIKELY AUTHENTIC"
    assert synth["needs_human_verification"] is False


def test_synthesize_final_result_qwen_uncertain_preserves_valid_primary_prediction():
    """An uncertain secondary opinion does not replace a valid primary class."""
    primary = {
        "prediction": "COUNTERFEIT",
        "confidence": 0.78,
        "status": "COUNTERFEIT",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "UNCERTAIN",
        "confidence": "LOW",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "LIKELY COUNTERFEIT"
    assert synth["needs_human_verification"] is True


def test_synthesize_final_result_unavailable_fallback():
    """Qwen outage warns, while a valid primary authentic result is preserved."""
    primary = {
        "prediction": "AUTHENTIC",
        "confidence": 0.88,
        "status": "AUTHENTIC",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": False,
        "status": "UNAVAILABLE",
    }
    synth = synthesize_final_result(primary, qwen)
    assert synth["final_result"] == "LIKELY AUTHENTIC"
    assert synth["needs_human_verification"] is False
    assert "unavailable" in synth["warning"].lower()


def test_format_final_screening_result():
    primary = {
        "prediction": "COUNTERFEIT",
        "confidence": 0.5446,
        "status": "NEEDS MANUAL REVIEW",
        "quality": {"is_valid": True},
    }
    qwen = {
        "available": True,
        "assessment": "UNCERTAIN",
    }
    formatted = format_final_screening_result(primary, qwen)
    assert "FINAL SCREENING RESULT" in formatted
    assert "Primary ML Prediction: COUNTERFEIT" in formatted
    assert "Primary ML Confidence: 54.46%" in formatted
    assert "Qwen Visual Assessment: UNCERTAIN" in formatted
    assert "Final Result: SUSPICIOUS / NEEDS VERIFICATION" in formatted



def test_parser_does_not_read_choice_list_as_an_assessment():
    parsed = parse_qwen_vision_output(
        "Assessment: AUTHENTIC / COUNTERFEIT / UNCERTAIN\n"
        "Visual Confidence: LOW / MEDIUM / HIGH\n"
        "Image Quality: GOOD / FAIR / POOR\n"
    )
    assert parsed["assessment"] == "UNCERTAIN"
    assert parsed["confidence"] == "LOW"
    assert parsed["image_quality"] == "FAIR"


def test_qwen_vision_request_uses_structured_output_and_ignores_thinking(monkeypatch):
    import io
    import json
    from PIL import Image

    response_content = json.dumps({
        "assessment": "UNCERTAIN",
        "confidence": "LOW",
        "image_quality": "FAIR",
        "recommendation": "MANUAL REVIEW",
        "tablet_shape": "round",
        "tablet_color": "white",
        "tablet_surface": "unclear",
        "tablet_markings": "not readable",
        "tablet_edges": "unclear",
        "tablet_other": "",
        "packaging_analysis": "not visible",
        "observations_list": ["A round tablet is visible."],
        "concerns_list": ["Markings cannot be read."],
        "final_explanation": "Visual evidence is insufficient.",
    })
    captured = {}

    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self):
            return json.dumps({
                "message": {
                    "content": response_content,
                    "thinking": "Assessment: AUTHENTIC / COUNTERFEIT / UNCERTAIN",
                }
            }).encode()

    def fake_urlopen(request, timeout):
        captured["payload"] = json.loads(request.data)
        captured["timeout"] = timeout
        return FakeResponse()

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)
    image = Image.new("RGB", (64, 64), "white")
    image_bytes = io.BytesIO()
    image.save(image_bytes, format="JPEG")

    result = QwenVisionVerifier(model_name="qwen3.5:4b").verify_image(
        image_bytes.getvalue()
    )

    assert result["available"] is True
    assert result["assessment"] == "UNCERTAIN"
    assert result["needs_human_verification"] is True
    assert captured["payload"]["format"]["type"] == "object"
    assert captured["payload"]["think"] is False
    assert captured["timeout"] == 180.0


def test_qwen_reasoning_without_answer_is_unavailable_not_a_prediction(monkeypatch):
    import io
    import json
    from PIL import Image

    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def read(self):
            return json.dumps({
                "message": {
                    "content": "",
                    "thinking": "Assessment: AUTHENTIC / COUNTERFEIT / UNCERTAIN",
                }
            }).encode()

    monkeypatch.setattr("urllib.request.urlopen", lambda *_args, **_kwargs: FakeResponse())
    image = Image.new("RGB", (64, 64), "white")
    image_bytes = io.BytesIO()
    image.save(image_bytes, format="JPEG")

    result = QwenVisionVerifier(model_name="qwen3-vl:4b").verify_image(
        image_bytes.getvalue()
    )

    assert result["available"] is False
    assert result["assessment"] == "UNCERTAIN"
    assert "no structured answer" in result["reason"].lower()



def test_legacy_ollama_config_prefers_discovered_vision_model_and_safe_timeout(monkeypatch):
    import ml.verification.qwen_verifier as qwen_module

    monkeypatch.delenv("OLLAMA_VISION_MODEL", raising=False)
    monkeypatch.setenv("OLLAMA_MODEL", "qwen3-vl:4b")
    monkeypatch.setenv("OLLAMA_TIMEOUT", "12.0")
    monkeypatch.setattr(
        qwen_module, "_detect_vision_model", lambda _base_url: "qwen3.5:4b"
    )

    verifier = QwenVisionVerifier()

    assert verifier.model_name == "qwen3.5:4b"
    assert verifier.timeout == 180.0
