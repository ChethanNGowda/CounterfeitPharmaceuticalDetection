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
    assert synth["final_status"] == "NEEDS MANUAL REVIEW"
    assert synth["disagreement"] is True
    assert "disagreement" in synth["reason"].lower()


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
    assert synth["final_status"] == "LIKELY AUTHENTIC"
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
    assert synth["final_status"] == "LIKELY COUNTERFEIT"
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
    assert synth["final_status"] == "NEEDS MANUAL REVIEW"


def test_synthesize_final_result_unavailable_fallback():
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
    assert synth["final_status"] == "LIKELY AUTHENTIC"
    assert "unavailable" in synth["reason"].lower()


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
    assert "Final Status: NEEDS MANUAL REVIEW" in formatted
