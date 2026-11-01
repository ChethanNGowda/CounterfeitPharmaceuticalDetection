import io

import numpy as np
from PIL import Image
from fastapi.testclient import TestClient

from backend.app.main import app
from backend.app.services.classifier import ClassifierService
from ml.models.transfer_learning import CheckpointUnavailableError


client = TestClient(app)


def _image_bytes() -> bytes:
    image = Image.fromarray(np.full((224, 224, 3), 128, dtype=np.uint8))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def test_malformed_image_error_does_not_expose_parser_details():
    response = client.post(
        "/predict",
        files={"file": ("broken.png", io.BytesIO(b"not an image"), "image/png")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Corrupted or invalid image data."
    assert "Traceback" not in response.text


def test_image_dimensions_above_supported_limit_are_rejected():
    response = client.post(
        "/predict",
        files={"file": ("large.png", io.BytesIO(_large_image_bytes()), "image/png")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Image dimensions are invalid or exceed the supported limit."


def _large_image_bytes() -> bytes:
    image = Image.new("RGB", (10001, 1), color=(128, 128, 128))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def test_model_unavailable_error_is_safe(monkeypatch):
    class MissingModelService:
        def predict_image_bytes(self, **kwargs):
            raise CheckpointUnavailableError(r"C:\private\weights\missing.pt")

    monkeypatch.setattr(ClassifierService, "get_instance", lambda: MissingModelService())
    response = client.post(
        "/predict",
        files={"file": ("tablet.png", io.BytesIO(_image_bytes()), "image/png")},
        data={"enable_qwen": "false"},
    )

    assert response.status_code == 503
    assert response.json()["detail"] == "Requested screening model is unavailable."
    assert "private" not in response.text


def test_inference_error_is_safe(monkeypatch):
    class BrokenService:
        def predict_image_bytes(self, **kwargs):
            raise RuntimeError(r"failed at C:\private\model.pt with secret=hidden")

    monkeypatch.setattr(ClassifierService, "get_instance", lambda: BrokenService())
    response = client.post(
        "/verify",
        files={"file": ("tablet.png", io.BytesIO(_image_bytes()), "image/png")},
        data={"enable_qwen": "false"},
    )

    assert response.status_code == 500
    assert response.json()["detail"] == "Screening failed unexpectedly. Please try again."
    assert "private" not in response.text
    assert "hidden" not in response.text
