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
    assert "qwen3" in data["secondary_ai_model"]
    assert "11434" in data["secondary_ai_endpoint"]


# ---------------------------------------------------------------------------
# /predict endpoint
# ---------------------------------------------------------------------------

def test_predict_endpoint_valid_image():
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 0.50, "model": "efficientnet_b0"},
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
