"""Automated tests for FastAPI endpoints."""

import io
import numpy as np
from PIL import Image
import pytest
from fastapi.testclient import TestClient

from backend.app.main import app

client = TestClient(app)


def test_health_check_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "device" in data
    assert "default_model" in data
    assert "available_models" in data


def test_predict_endpoint_valid_image(tmp_path):
    # Create valid synthetic image
    arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
    arr[50:150, 50:150] = 255
    arr[100:120, 100:120] = 0
    img = Image.fromarray(arr)

    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 0.50, "model": "efficientnet_b0"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] in ("AUTHENTIC", "COUNTERFEIT")
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
    arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
    arr[50:150, 50:150] = 255
    img = Image.fromarray(arr)

    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    # Threshold 1.01 can never be met by probability <= 1.0
    response = client.post(
        "/predict",
        files={"file": ("tablet.jpg", buf, "image/jpeg")},
        data={"threshold": 1.01, "model": "efficientnet_b0"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "NEEDS MANUAL REVIEW"
    assert "below" in data["reason"].lower()
