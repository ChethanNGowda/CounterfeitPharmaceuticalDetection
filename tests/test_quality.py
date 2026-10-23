"""Tests for image quality validation module."""

import numpy as np
from PIL import Image
import pytest
import torch
from torch import nn
from unittest.mock import patch

from ml.inference.predict import predict
from ml.preprocessing.quality_checker import QualityCheckResult
from ml.preprocessing.quality_checker import check_image_quality


def test_valid_image_passes_quality(tmp_path):
    img_path = tmp_path / "good.jpg"
    # Create image with high-contrast text / structure so it has plenty of edge details
    arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
    # Add sharp gradient
    arr[50:150, 50:150] = 255
    arr[100:120, 100:120] = 0
    Image.fromarray(arr).save(img_path)

    res = check_image_quality(img_path)
    assert res.is_valid is True
    assert res.reason is None
    assert res.width == 224
    assert res.height == 224


def test_tiny_resolution_fails(tmp_path):
    img_path = tmp_path / "tiny.jpg"
    Image.fromarray(np.ones((32, 32, 3), dtype=np.uint8) * 128).save(img_path)

    res = check_image_quality(img_path)
    assert res.is_valid is False
    assert "resolution too low" in res.reason


def test_extreme_darkness_fails(tmp_path):
    img_path = tmp_path / "dark.jpg"
    # Completely black image
    Image.fromarray(np.zeros((100, 100, 3), dtype=np.uint8)).save(img_path)

    res = check_image_quality(img_path)
    assert res.is_valid is False
    assert "underexposure" in res.reason


def test_extreme_brightness_fails(tmp_path):
    img_path = tmp_path / "bright.jpg"
    # Completely white washed out image
    Image.fromarray(np.ones((100, 100, 3), dtype=np.uint8) * 255).save(img_path)

    res = check_image_quality(img_path)
    assert res.is_valid is False
    assert "overexposure" in res.reason


def test_blurry_image_fails(tmp_path):
    img_path = tmp_path / "blurry.jpg"
    # Perfectly flat constant gray image (Laplacian variance = 0)
    arr = np.ones((100, 100, 3), dtype=np.uint8) * 120
    Image.fromarray(arr).save(img_path)

    res = check_image_quality(img_path)
    assert res.is_valid is False
    assert "excessive blur" in res.reason


def test_missing_file_fails():
    res = check_image_quality("non_existent_image_path.jpg")
    assert res.is_valid is False
    assert "does not exist" in res.reason


class _FixedClassifier(nn.Module):
    def forward(self, image):
        return torch.tensor([[3.0, 0.0]], device=image.device)


def test_moderate_blur_blocks_classifier_prediction():
    quality = QualityCheckResult(
        is_valid=False,
        reason="Poor image quality: excessive blur (score 18.3 < 50.0)",
        blur_score=18.3,
        brightness_mean=101.9,
        width=4096,
        height=3072,
        sharpness_status="Excessive Blur",
        suitability="UNSUITABLE (blur warning)",
    )
    image = Image.fromarray(np.full((224, 224, 3), 120, dtype=np.uint8))

    with patch("ml.inference.predict.check_image_quality", return_value=quality):
        result = predict(image, model=_FixedClassifier(), device=torch.device("cpu"))

    assert result["prediction"] == "UNKNOWN"
    assert result["confidence"] == 0.0
    assert result["authentic_probability"] == 0.0
    assert result["counterfeit_probability"] == 0.0
    assert result["status"] == "NEEDS MANUAL REVIEW"
    assert result["quality"]["is_valid"] is False
    assert "excessive blur" in result["quality"]["reason"]


def test_severe_blur_still_blocks_classifier():
    quality = QualityCheckResult(
        is_valid=False,
        reason="Poor image quality: excessive blur (score 2.0 < 50.0)",
        blur_score=2.0,
        brightness_mean=120.0,
        width=224,
        height=224,
        sharpness_status="Excessive Blur",
        suitability="UNSUITABLE (severe blur)",
    )
    image = Image.fromarray(np.full((224, 224, 3), 120, dtype=np.uint8))

    with patch("ml.inference.predict.check_image_quality", return_value=quality):
        result = predict(image, model=_FixedClassifier(), device=torch.device("cpu"))

    assert result["prediction"] == "UNKNOWN"
    assert result["confidence"] == 0.0
