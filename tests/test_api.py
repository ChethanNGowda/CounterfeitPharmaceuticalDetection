"""Automated tests for FastAPI endpoints.

Tests the /health, /predict, and /verify endpoints against the current
PredictionResponse schema (post-qwen3:8b integration).
"""

import io
import numpy as np
from PIL import Image
import pytest
from fastapi.testclient import TestClient

from backend.app.main import app

client = TestClient(app)


def _make_synthetic_image_buf():
    """Create a synthetic tablet-like JPEG image as BytesIO."""
    arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
    arr[50:150, 50:150] = 255
    arr[100:120, 100:120] = 0
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)
    return buf


# ---------------------------------------------------------------------------
# /health endpoint
# ---------------------------------------------------------------------------

def test_health_check_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "device" in data
    assert "default_model" in data
    assert "available_models" in data


def test_health_includes_secondary_ai_fields():
    """Health response must expose secondary AI model name and endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert "secondary_ai_model" in data
    assert "secondary_ai_endpoint" in data
    assert "qwen3-vl" in data["secondary_ai_model"]
    assert data["secondary_ai_model"] == "qwen3-vl:4b"
    assert "11434" in data["secondary_ai_endpoint"]


# ---------------------------------------------------------------------------
# /predict endpoint
# ---------------------------------------------------------------------------

def test_predict_endpoint_valid_image():
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 0.50, "model": "efficientnet_b0", "enable_qwen": "false"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] in ("AUTHENTIC", "COUNTERFEIT", "UNKNOWN")
    assert data["status"] in ("AUTHENTIC", "COUNTERFEIT", "NEEDS MANUAL REVIEW")
    assert 0.0 <= data["confidence"] <= 1.0
    assert 0.0 <= data["authentic_probability"] <= 1.0
    assert 0.0 <= data["counterfeit_probability"] <= 1.0


def test_predict_endpoint_unsupported_media_type():
    buf = io.BytesIO(b"dummy text file content")
    response = client.post(
        "/predict",
        files={"file": ("notes.txt", buf, "text/plain")},
    )
    assert response.status_code == 415


def test_predict_endpoint_corrupted_image():
    buf = io.BytesIO(b"not an actual image byte stream")
    response = client.post(
        "/predict",
        files={"file": ("broken.jpg", buf, "image/jpeg")},
    )
    assert response.status_code == 400


def test_predict_endpoint_high_threshold_triggers_manual_review():
    """Threshold > 1.0 can never be met → NEEDS MANUAL REVIEW."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 1.01, "model": "efficientnet_b0"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "NEEDS MANUAL REVIEW"
    assert "below" in data["reason"].lower()


# ---------------------------------------------------------------------------
# /verify endpoint — new dual-model schema
# ---------------------------------------------------------------------------

def test_verify_endpoint_returns_new_contract_schema():
    """POST /verify (enable_qwen=false) must return new PredictionResponse contract keys."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/verify",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 0.70, "model": "efficientnet_b0", "enable_qwen": "false"},
    )
    assert response.status_code == 200
    data = response.json()

    # New primary model fields
    assert "primary_model" in data
    assert data["primary_model"] == "efficientnet_b0"

    # New final verdict field (was final_status in old schema)
    assert "final_result" in data
    assert data["final_result"] in (
        "LIKELY AUTHENTIC",
        "LIKELY COUNTERFEIT",
        "SUSPICIOUS / NEEDS VERIFICATION",
    )

    # Qwen nested object (was flat vision_verification fields in old schema)
    assert "qwen" in data
    assert "available" in data["qwen"]
    assert isinstance(data["qwen"]["available"], bool)
    assert "assessment" in data["qwen"]
    assert "reasoning" in data["qwen"]

    # needs_human_verification (was missing in old schema)
    assert "needs_human_verification" in data
    assert isinstance(data["needs_human_verification"], bool)

    # Disclaimer must always be present
    assert "disclaimer" in data
    assert len(data["disclaimer"]) > 10


def test_verify_endpoint_enable_vision_alias_works():
    """enable_vision=false is an alias for enable_qwen=false (backward compat)."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/verify",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 0.70, "enable_vision": "false"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "final_result" in data
    # When Qwen is disabled, qwen.available must be False
    assert data["qwen"]["available"] is False


def test_verify_endpoint_qwen_disabled_primary_confidence_fields():
    """When Qwen is disabled, EfficientNet confidence and probabilities are exposed."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/verify",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 0.50, "enable_qwen": "false"},
    )
    assert response.status_code == 200
    data = response.json()
    assert 0.0 <= data["confidence"] <= 1.0
    assert 0.0 <= data["authentic_probability"] <= 1.0
    assert 0.0 <= data["counterfeit_probability"] <= 1.0


def test_verify_endpoint_bad_image_returns_400():
    buf = io.BytesIO(b"not an image")
    response = client.post(
        "/verify",
        files={"file": ("broken.jpg", buf, "image/jpeg")},
    )
    assert response.status_code == 400


def test_predict_endpoint_quality_gate_rejection():
    """Sub-resolution image must be rejected by OpenCV quality gate before inference."""
    arr = np.random.randint(50, 200, (10, 10, 3), dtype=np.uint8)
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/predict",
        files={"file": ("tiny.jpg", buf, "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["quality"] is not None
    assert data["quality"]["is_valid"] is False
    assert data["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert data["needs_human_verification"] is True
    assert data["secondary_executed"] is False


def test_predict_endpoint_high_confidence_auto_mode_skips_qwen(monkeypatch):
    """Primary confidence >= 0.90 must skip Qwen in auto mode (fast path)."""
    from backend.app.services.classifier import ClassifierService

    service = ClassifierService.get_instance()

    def fake_predict(*args, **kwargs):
        return {
            "image_path": "fake.jpg",
            "prediction": "AUTHENTIC",
            "predicted_class": "authentic",
            "authentic_probability": 0.95,
            "counterfeit_probability": 0.05,
            "confidence": 0.95,
            "status": "AUTHENTIC",
            "reason": None,
            "probabilities": {"authentic": 0.95, "counterfeit": 0.05},
            "model_name": "efficientnet_b0",
            "threshold": 0.70,
            "quality": {"is_valid": True, "reason": None, "blur_score": 100.0, "brightness_mean": 128.0, "dimensions": [224, 224]},
        }

    monkeypatch.setattr("ml.inference.predict.predict", fake_predict)

    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "auto"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["confidence"] == 0.95
    assert data["secondary_executed"] is False
    assert "high-confidence" in data["secondary_reason"]
    assert data["final_result"] == "LIKELY AUTHENTIC"
    assert data["needs_human_verification"] is False


def test_predict_endpoint_borderline_confidence_auto_mode_executes_qwen(monkeypatch):
    """Primary confidence in [0.70, 0.90) must automatically invoke Qwen3-VL."""
    def fake_predict(*args, **kwargs):
        return {
            "image_path": "fake.jpg",
            "prediction": "AUTHENTIC",
            "predicted_class": "authentic",
            "authentic_probability": 0.82,
            "counterfeit_probability": 0.18,
            "confidence": 0.82,
            "status": "AUTHENTIC",
            "reason": None,
            "probabilities": {"authentic": 0.82, "counterfeit": 0.18},
            "model_name": "efficientnet_b0",
            "threshold": 0.70,
            "quality": {"is_valid": True, "reason": None, "blur_score": 100.0, "brightness_mean": 128.0, "dimensions": [224, 224]},
        }

    def fake_verify(*args, **kwargs):
        return {
            "available": True,
            "status": "AVAILABLE",
            "assessment": "AUTHENTIC",
            "confidence": "HIGH",
            "image_quality": "GOOD",
            "recommendation": "AUTOMATED SCREENING",
            "raw_text": "Assessment: AUTHENTIC\nVisual Confidence: HIGH",
            "reason": None,
            "reasoning": ["Tablet features match authentic baseline."],
            "needs_human_verification": False,
            "warning": "Visual screening cannot establish chemical authenticity.",
            "model_name": "qwen3-vl:4b",
        }

    monkeypatch.setattr("ml.inference.predict.predict", fake_predict)
    from backend.app.services.classifier import ClassifierService
    service = ClassifierService.get_instance()
    monkeypatch.setattr(service.vision_verifier, "verify_image", fake_verify)

    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "auto"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["confidence"] == 0.82
    assert data["secondary_executed"] is True
    assert data["qwen"]["available"] is True
    assert data["qwen"]["assessment"] == "AUTHENTIC"
    assert data["final_result"] == "LIKELY AUTHENTIC"
    assert data["needs_human_verification"] is False


def test_predict_endpoint_qwen_unavailable_graceful_fallback(monkeypatch):
    """When Qwen is unavailable, endpoint must not crash and fallback gracefully."""
    def fake_predict(*args, **kwargs):
        return {
            "image_path": "fake.jpg",
            "prediction": "AUTHENTIC",
            "predicted_class": "authentic",
            "authentic_probability": 0.85,
            "counterfeit_probability": 0.15,
            "confidence": 0.85,
            "status": "AUTHENTIC",
            "reason": None,
            "probabilities": {"authentic": 0.85, "counterfeit": 0.15},
            "model_name": "efficientnet_b0",
            "threshold": 0.70,
            "quality": {"is_valid": True, "reason": None, "blur_score": 100.0, "brightness_mean": 128.0, "dimensions": [224, 224]},
        }

    def fake_verify(*args, **kwargs):
        return {
            "available": False,
            "status": "UNAVAILABLE",
            "assessment": "UNCERTAIN",
            "confidence": "LOW",
            "image_quality": "POOR",
            "recommendation": "MANUAL REVIEW",
            "reason": "Ollama connection refused",
            "reasoning": ["Ollama connection refused"],
            "needs_human_verification": True,
            "warning": "Secondary AI verification unavailable — result based on primary classifier.",
            "model_name": "qwen3-vl:4b",
            "raw_text": "",
        }

    monkeypatch.setattr("ml.inference.predict.predict", fake_predict)
    from backend.app.services.classifier import ClassifierService
    service = ClassifierService.get_instance()
    monkeypatch.setattr(service.vision_verifier, "verify_image", fake_verify)

    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "auto"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["secondary_executed"] is True
    assert data["qwen"]["available"] is False
    assert data["final_result"] == "LIKELY AUTHENTIC"
    assert "unavailable" in data["warning"].lower()


def test_predict_endpoint_qwen_exception_handled_gracefully(monkeypatch):
    """When Qwen raises an exception, the request must not crash."""
    def fake_predict(*args, **kwargs):
        return {
            "image_path": "fake.jpg",
            "prediction": "AUTHENTIC",
            "predicted_class": "authentic",
            "authentic_probability": 0.85,
            "counterfeit_probability": 0.15,
            "confidence": 0.85,
            "status": "AUTHENTIC",
            "reason": None,
            "probabilities": {"authentic": 0.85, "counterfeit": 0.15},
            "model_name": "efficientnet_b0",
            "threshold": 0.70,
            "quality": {"is_valid": True, "reason": None, "blur_score": 100.0, "brightness_mean": 128.0, "dimensions": [224, 224]},
        }

    def broken_verify(*args, **kwargs):
        raise ConnectionResetError("Remote server closed connection")

    monkeypatch.setattr("ml.inference.predict.predict", fake_predict)
    from backend.app.services.classifier import ClassifierService
    service = ClassifierService.get_instance()
    monkeypatch.setattr(service.vision_verifier, "verify_image", broken_verify)

    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "auto"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["secondary_executed"] is True
    assert data["qwen"]["available"] is False
    assert data["final_result"] == "LIKELY AUTHENTIC"


def test_predict_endpoint_low_confidence_skips_qwen_and_requires_review(monkeypatch):
    """Primary confidence < 0.70 must skip Qwen in auto mode and mark for review."""
    def fake_predict(*args, **kwargs):
        return {
            "image_path": "fake.jpg",
            "prediction": "COUNTERFEIT",
            "predicted_class": "counterfeit",
            "authentic_probability": 0.45,
            "counterfeit_probability": 0.55,
            "confidence": 0.55,
            "status": "NEEDS MANUAL REVIEW",
            "reason": "Confidence 55.0% is below screening threshold 70.0%",
            "probabilities": {"authentic": 0.45, "counterfeit": 0.55},
            "model_name": "efficientnet_b0",
            "threshold": 0.70,
            "quality": {"is_valid": True, "reason": None, "blur_score": 100.0, "brightness_mean": 128.0, "dimensions": [224, 224]},
        }

    monkeypatch.setattr("ml.inference.predict.predict", fake_predict)

    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "auto"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["secondary_executed"] is False
    assert "low primary confidence" in data["secondary_reason"]
    assert data["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert data["needs_human_verification"] is True

