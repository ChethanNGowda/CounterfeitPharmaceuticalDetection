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
    # Rule 4a: secondary was invoked but failed → needs_human=True per README §Qwen3-VL graceful degradation
    assert data["needs_human_verification"] is True
    assert "failed" in data["warning"].lower() or "unavailable" in data["warning"].lower()


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
    # Rule 4a: verify_image raised → pipeline produces available=False dict → needs_human=True
    assert data["needs_human_verification"] is True


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


def test_predict_endpoint_includes_visual_analysis():
    """Verify /predict returns visual_analysis and enhanced quality metrics."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "never"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "visual_analysis" in data
    va = data["visual_analysis"]
    assert va is not None
    assert "color" in va
    assert "shape" in va
    assert "size" in va
    assert "surface" in va
    assert "markings" in va
    assert "edges" in va
    assert "packaging" in va

    # Verify enhanced quality fields
    quality = data["quality"]
    assert "aspect_ratio" in quality
    assert "contrast" in quality
    assert "color_mode" in quality
    assert "exposure_status" in quality
    assert "sharpness_status" in quality
    assert "suitability" in quality


# ---------------------------------------------------------------------------
# Additional Stabilization & Milestone Tests
# ---------------------------------------------------------------------------

def test_root_info_endpoint():
    """GET / must return API information, usage guidance, and endpoints."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "name" in data
    assert "endpoints" in data
    assert "predict" in data["endpoints"]
    assert "verify" in data["endpoints"]
    assert "usage" in data
    assert "disclaimer" in data
    assert "supported_models" in data
    assert "default_model" in data


def test_predict_endpoint_empty_upload():
    """POST /predict with 0-byte upload must return 400 Bad Request."""
    buf = io.BytesIO(b"")
    response = client.post(
        "/predict",
        files={"file": ("empty.jpg", buf, "image/jpeg")},
    )
    assert response.status_code == 400
    assert "empty" in response.json()["detail"].lower()


def test_predict_endpoint_oversized_upload():
    """POST /predict exceeding 15MB limit must return 413 Payload Too Large."""
    # 16 MB dummy buffer
    oversized = io.BytesIO(b"\x00" * (16 * 1024 * 1024))
    response = client.post(
        "/predict",
        files={"file": ("huge.jpg", oversized, "image/jpeg")},
    )
    assert response.status_code == 413
    assert "exceeds" in response.json()["detail"].lower()


def test_predict_endpoint_unsupported_image_format():
    """POST /predict with GIF image format must return 415 Unsupported Media Type."""
    arr = np.zeros((100, 100, 3), dtype=np.uint8)
    gif_img = Image.fromarray(arr)
    buf = io.BytesIO()
    gif_img.save(buf, format="GIF")
    buf.seek(0)

    response = client.post(
        "/predict",
        files={"file": ("animation.gif", buf, "image/gif")},
    )
    assert response.status_code == 415


def test_predict_endpoint_unsupported_model_returns_400():
    """POST /predict with unrecognized model name must return 400."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"model": "nonexistent_model_xyz", "enable_qwen": "false"},
    )
    assert response.status_code == 400
    assert "unsupported" in response.json()["detail"].lower()


def test_predict_endpoint_missing_checkpoint_returns_503(monkeypatch):
    """POST /predict when model checkpoint is missing must return 503."""
    from ml.models.transfer_learning import CheckpointUnavailableError
    from backend.app.services.classifier import ClassifierService

    service = ClassifierService.get_instance()

    def fake_load(*args, **kwargs):
        raise CheckpointUnavailableError("Fine-tuned checkpoint not found on disk")

    monkeypatch.setattr(service, "load_model", fake_load)

    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"model": "mobilenet_v3_large", "enable_qwen": "false"},
    )
    assert response.status_code == 503
    assert "unavailable" in response.json()["detail"].lower()


def test_predict_endpoint_blurry_image_triggers_quality_gate():
    """Blurry image (Laplacian variance < 50.0) must be flagged for manual review."""
    # Flat image with minimal variation produces Laplacian var near 0
    arr = np.ones((224, 224, 3), dtype=np.uint8) * 128
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/predict",
        files={"file": ("blurry.jpg", buf, "image/jpeg")},
        data={"enable_qwen": "false"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["quality"]["is_valid"] is False
    assert "blur" in data["quality"]["reason"].lower()
    assert data["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert data["needs_human_verification"] is True


def test_predict_endpoint_extreme_dark_image_triggers_quality_gate():
    """Extreme dark image (mean brightness < 15) must fail quality check."""
    arr = np.ones((224, 224, 3), dtype=np.uint8) * 5
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/predict",
        files={"file": ("dark.jpg", buf, "image/jpeg")},
        data={"enable_qwen": "false"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["quality"]["is_valid"] is False
    assert "underexposure" in data["quality"]["reason"].lower() or "dark" in data["quality"]["reason"].lower()
    assert data["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"


def test_predict_endpoint_extreme_bright_image_triggers_quality_gate():
    """Extreme bright image (mean brightness > 245) must fail quality check."""
    arr = np.ones((224, 224, 3), dtype=np.uint8) * 250
    img = Image.fromarray(arr)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/predict",
        files={"file": ("bright.jpg", buf, "image/jpeg")},
        data={"enable_qwen": "false"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["quality"]["is_valid"] is False
    assert "overexposure" in data["quality"]["reason"].lower() or "washed" in data["quality"]["reason"].lower()
    assert data["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"


def test_app_startup_and_import():
    """Verify application title, version, and router configuration."""
    assert app.title == "Counterfeit Pharmaceutical Detection API"
    assert app.version == "1.0.0"
    paths = list(app.openapi()["paths"].keys())
    assert "/" in paths
    assert "/health" in paths
    assert "/predict" in paths
    assert "/verify" in paths


def test_root_endpoint_returns_api_info():
    """GET / must return API information, supported models, and usage."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "name" in data
    assert "version" in data
    assert "endpoints" in data
    assert "supported_models" in data
    assert "efficientnet_b0" in data["supported_models"]


def test_predict_endpoint_vision_mode_never_parameter():
    """Passing vision_mode='never' must execute fast path without secondary AI."""
    buf = _make_synthetic_image_buf()
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"vision_mode": "never"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["secondary_executed"] is False
    assert "never" in (data["secondary_reason"] or "").lower()


# ---------------------------------------------------------------------------
# GET /models endpoint
# ---------------------------------------------------------------------------

def test_models_endpoint_returns_all_registered_models():
    """GET /models must return all four registered model entries."""
    response = client.get("/models")
    assert response.status_code == 200
    data = response.json()
    assert "total_models" in data
    assert "available_models" in data
    assert "models" in data
    assert data["total_models"] == 4
    names = [m["model_name"] for m in data["models"]]
    assert "efficientnet_b0" in names
    assert "mobilenet_v3_large" in names
    assert "baseline_cnn" in names
    assert "goldformer" in names


def test_models_endpoint_only_efficientnet_available():
    """Only efficientnet_b0 should report finetuned_available=True (checkpoint on disk)."""
    response = client.get("/models")
    assert response.status_code == 200
    data = response.json()
    available = data["available_models"]
    assert "efficientnet_b0" in available
    for m in data["models"]:
        if m["model_name"] == "efficientnet_b0":
            assert m["finetuned_available"] is True
            assert m["checkpoint_sha256"] is not None
            assert len(m["checkpoint_sha256"]) == 64  # hex SHA-256
        else:
            assert m["finetuned_available"] is False
            assert m["checkpoint_sha256"] is None


def test_models_endpoint_all_models_have_metrics():
    """All four models must have benchmark metrics (efficientnet_b0: reproduced; others: historical)."""
    response = client.get("/models")
    assert response.status_code == 200
    data = response.json()
    for m in data["models"]:
        assert m["evaluated"] is True, f"{m['model_name']} should have metrics"
        metrics = m["metrics"]
        assert metrics is not None
        assert "accuracy" in metrics
        assert "recall" in metrics
        assert "roc_auc" in metrics
        assert "test_samples" in metrics
        assert "note" in metrics


def test_models_endpoint_unavailable_models_have_correct_status():
    """Models without checkpoints must show appropriate status string."""
    response = client.get("/models")
    data = response.json()
    for m in data["models"]:
        if not m["finetuned_available"]:
            assert "unavailable" in m["status"].lower() or "architecture supported" in m["status"].lower()


def test_models_endpoint_does_not_expose_filesystem_paths():
    """The /models endpoint must not expose real filesystem paths to app users."""
    response = client.get("/models")
    data = response.json()
    for m in data["models"]:
        # expected_checkpoint should be a placeholder, not a real Windows path
        assert "C:\\" not in m.get("expected_checkpoint", "")
        assert "/Users/" not in m.get("expected_checkpoint", "")
