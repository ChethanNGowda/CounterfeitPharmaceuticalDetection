"""Tests for image quality validation module."""

import numpy as np
from PIL import Image
import pytest

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
