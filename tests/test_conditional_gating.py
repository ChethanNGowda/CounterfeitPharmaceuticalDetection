"""Unit tests for conditional Qwen3-VL vision verification gating.

Tests the confidence-based secondary verification policy:
1. Primary confidence < 0.70: Qwen skipped in auto mode; marked for manual review
2. Primary confidence [0.70, 0.90): Qwen3-VL automatically invoked
3. Primary confidence >= 0.90: Qwen skipped in auto mode (high-confidence fast path)
4. vision_mode='always': Qwen invoked regardless of confidence
5. vision_mode='never': Qwen skipped regardless of confidence
6. Quality gate failure: Qwen skipped regardless of mode
7. DecisionEngine synthesis across all conditional branches
"""

from pathlib import Path
from unittest.mock import MagicMock
import numpy as np
from PIL import Image
import pytest

from ml.inference.predict import predict_pipeline


def _make_dummy_image():
    arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
    return Image.fromarray(arr)


def _mock_primary(
    predicted_class="authentic",
    confidence=0.85,
    quality_valid=True,
    quality_reason=None,
):
    p_auth = confidence if predicted_class == "authentic" else 1.0 - confidence
    p_fake = 1.0 - p_auth
    status = predicted_class.upper() if confidence >= 0.70 else "NEEDS MANUAL REVIEW"
    reason = None if status != "NEEDS MANUAL REVIEW" else "Low confidence"
    q_dict = {
        "is_valid": quality_valid,
        "reason": quality_reason,
        "blur_score": 100.0,
        "brightness_mean": 128.0,
        "dimensions": [224, 224],
    }
    return {
        "image_path": "dummy.jpg",
        "prediction": predicted_class.upper(),
        "predicted_class": predicted_class,
        "authentic_probability": round(p_auth, 4),
        "counterfeit_probability": round(p_fake, 4),
        "confidence": round(confidence, 4),
        "status": status,
        "reason": reason,
        "probabilities": {"authentic": round(p_auth, 4), "counterfeit": round(p_fake, 4)},
        "model_name": "efficientnet_b0",
        "threshold": 0.70,
        "quality": q_dict,
    }


def _mock_verifier(assessment="AUTHENTIC", available=True, confidence="HIGH"):
    mock = MagicMock()
    mock.model_name = "qwen3-vl:4b"
    mock.base_url = "http://localhost:11434"
    if available:
        mock.verify_image.return_value = {
            "available": True,
            "status": "AVAILABLE",
            "assessment": assessment,
            "confidence": confidence,
            "image_quality": "GOOD",
            "recommendation": "AUTOMATED SCREENING" if assessment == "AUTHENTIC" else "MANUAL REVIEW",
            "raw_text": f"Assessment: {assessment}\nVisual Confidence: {confidence}",
            "reason": None,
            "reasoning": [f"Visual assessment indicates {assessment}."],
            "needs_human_verification": assessment != "AUTHENTIC",
            "warning": "Visual screening cannot establish chemical authenticity.",
            "model_name": "qwen3-vl:4b",
        }
    else:
        mock.verify_image.return_value = {
            "available": False,
            "status": "UNAVAILABLE",
            "assessment": "UNCERTAIN",
            "confidence": "LOW",
            "image_quality": "POOR",
            "recommendation": "MANUAL REVIEW",
            "reason": "Ollama service unavailable",
            "reasoning": ["Ollama service unavailable"],
            "needs_human_verification": True,
            "warning": "Secondary AI verification unavailable — result based on primary classifier.",
            "model_name": "qwen3-vl:4b",
            "raw_text": "",
        }
    return mock


# ---------------------------------------------------------------------------
# Gating Tests
# ---------------------------------------------------------------------------

def test_confidence_below_70_skips_qwen_auto_mode(monkeypatch):
    """Primary confidence < 0.70 must NOT invoke Qwen in auto mode."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.55),
    )
    verifier = _mock_verifier()

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="auto",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is False
    verifier.verify_image.assert_not_called()
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "low primary confidence" in result["secondary_reason"]


def test_confidence_70_to_90_invokes_qwen_auto_mode(monkeypatch):
    """Primary confidence in [0.70, 0.90) MUST invoke Qwen3-VL automatically."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.82, predicted_class="authentic"),
    )
    verifier = _mock_verifier(assessment="AUTHENTIC")

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="auto",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is True
    verifier.verify_image.assert_called_once()
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["needs_human_verification"] is False
    assert result["secondary_available"] is True


def test_confidence_90_or_above_skips_qwen_auto_mode(monkeypatch):
    """Primary confidence >= 0.90 must skip Qwen by default (fast path)."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.96, predicted_class="authentic"),
    )
    verifier = _mock_verifier()

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="auto",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is False
    verifier.verify_image.assert_not_called()
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["needs_human_verification"] is False
    assert "high-confidence" in result["secondary_reason"]


def test_vision_mode_always_forces_qwen_for_high_confidence(monkeypatch):
    """vision_mode='always' must invoke Qwen even with confidence >= 0.90."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.97, predicted_class="authentic"),
    )
    verifier = _mock_verifier(assessment="AUTHENTIC")

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="always",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is True
    verifier.verify_image.assert_called_once()
    assert "always" in result["secondary_reason"]


def test_vision_mode_never_skips_qwen_for_borderline_confidence(monkeypatch):
    """vision_mode='never' must NOT invoke Qwen even for 0.70-0.899 confidence."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.78, predicted_class="authentic"),
    )
    verifier = _mock_verifier()

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="never",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is False
    verifier.verify_image.assert_not_called()
    assert "never" in result["secondary_reason"]
    # Fallback to primary classifier:
    assert result["final_result"] == "LIKELY AUTHENTIC"


def test_quality_gate_failure_skips_qwen_in_any_mode(monkeypatch):
    """Quality check failure must reject immediately and skip Qwen even in 'always' mode."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(
            confidence=0.88,
            quality_valid=False,
            quality_reason="Severe Laplacian blur",
        ),
    )
    verifier = _mock_verifier()

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="always",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is False
    verifier.verify_image.assert_not_called()
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "quality check failed" in result["secondary_reason"]


def test_invalid_vision_mode_raises():
    """Unrecognized vision_mode must raise ValueError."""
    with pytest.raises(ValueError, match="Invalid vision_mode"):
        predict_pipeline(
            image_input=_make_dummy_image(),
            vision_mode="magic_mode",
        )


def test_borderline_contradiction_yields_suspicious(monkeypatch):
    """Primary AUTHENTIC (0.80) + Qwen COUNTERFEIT must yield SUSPICIOUS / NEEDS VERIFICATION."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.80, predicted_class="authentic"),
    )
    verifier = _mock_verifier(assessment="COUNTERFEIT")

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="auto",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is True
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert result["disagreement"] is True


def test_qwen_unavailable_borderline_preserves_primary_with_warning(monkeypatch):
    """Borderline confidence with Qwen unavailable preserves primary verdict with warning."""
    monkeypatch.setattr(
        "ml.inference.predict.predict",
        lambda *args, **kwargs: _mock_primary(confidence=0.84, predicted_class="authentic"),
    )
    verifier = _mock_verifier(available=False)

    result = predict_pipeline(
        image_input=_make_dummy_image(),
        vision_mode="auto",
        vision_verifier=verifier,
    )
    assert result["secondary_executed"] is True
    assert result["secondary_available"] is False
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert "unavailable" in result["warning"].lower()
