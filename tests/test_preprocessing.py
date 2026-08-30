import pytest
import os
import numpy as np
import cv2
from ml.preprocessing.image_preprocessor import ImagePreprocessor

@pytest.fixture
def preprocessor():
    return ImagePreprocessor(target_size=(256, 256))

@pytest.fixture
def sample_image_path(tmp_path):
    img_path = tmp_path / "test_tablet.jpg"
    # Create a synthetic image
    img = np.random.randint(0, 255, (500, 500, 3), dtype=np.uint8)
    cv2.imwrite(str(img_path), img)
    return str(img_path)

def test_valid_image(preprocessor, sample_image_path):
    img = preprocessor.preprocess(sample_image_path)
    assert img.shape == (256, 256, 3)
    assert img.dtype == np.float32
    assert img.min() >= 0.0
    assert img.max() <= 1.0

def test_invalid_path(preprocessor):
    with pytest.raises(FileNotFoundError):
        preprocessor.preprocess("nonexistent.jpg")

def test_unsupported_format(preprocessor, tmp_path):
    bad_file = tmp_path / "test.txt"
    bad_file.write_text("hello")
    with pytest.raises(ValueError, match="Unsupported file format"):
        preprocessor.preprocess(str(bad_file))

def test_deterministic_behavior(preprocessor, sample_image_path):
    img1 = preprocessor.preprocess(sample_image_path)
    img2 = preprocessor.preprocess(sample_image_path)
    assert np.array_equal(img1, img2)
