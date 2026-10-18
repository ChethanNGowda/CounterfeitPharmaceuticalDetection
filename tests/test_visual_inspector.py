"""Unit tests for ml.inference.visual_inspector and enhanced quality checker metrics."""

import numpy as np
import cv2
from PIL import Image
import pytest

from ml.inference.visual_inspector import (
    analyze_visual_features,
    _match_color_name,
)
from ml.preprocessing.quality_checker import check_image_quality


def test_match_color_name_basic():
    """Verify that color matching returns valid pharma colors."""
    assert _match_color_name((255, 255, 255)) == "White"
    assert _match_color_name((0, 0, 255)) == "Blue"
    assert _match_color_name((255, 0, 0)) == "Red"
    assert _match_color_name((230, 215, 60)) == "Yellow"


def test_visual_analysis_solid_red_square(tmp_path):
    """Verify color analysis on a synthetic solid red image."""
    img_path = tmp_path / "red.png"
    arr = np.zeros((100, 100, 3), dtype=np.uint8)
    arr[:, :] = [190, 45, 45]
    Image.fromarray(arr).save(img_path)

    result = analyze_visual_features(img_path)
    assert result["color"]["dominant_color"] == "Red"
    assert result["color"]["consistency"] == "HIGH"
    assert len(result["color"]["average_rgb"]) == 3


def test_visual_analysis_preserves_two_tone_capsule_colors(tmp_path):
    """A blue-and-white capsule must not be reduced to a misleading average."""
    img_path = tmp_path / "two_tone_capsule.png"
    arr = np.full((220, 300, 3), 120, dtype=np.uint8)
    cv2.ellipse(arr, (90, 110), (70, 45), 0, 90, 270, (0, 130, 200), -1)
    cv2.ellipse(arr, (210, 110), (70, 45), 0, -90, 90, (245, 245, 245), -1)
    cv2.rectangle(arr, (90, 65), (210, 155), (245, 245, 245), -1)
    Image.fromarray(arr).save(img_path)

    color = analyze_visual_features(img_path)["color"]
    assert "White" in color["dominant_color"]
    assert "Blue / Teal" in color["dominant_color"]
    assert color["consistency"] == "MULTI-COLORED"
    assert "not a quality" in color["visible_variation"]


def test_visual_analysis_circular_pill(tmp_path):
    """Verify shape analysis on a synthetic high-contrast circle."""
    img_path = tmp_path / "circle.png"
    arr = np.zeros((200, 200, 3), dtype=np.uint8)
    # Draw a solid white circle in center with black background
    y, x = np.ogrid[:200, :200]
    mask = (x - 100) ** 2 + (y - 100) ** 2 <= 50 ** 2
    arr[mask] = 255
    Image.fromarray(arr).save(img_path)

    result = analyze_visual_features(img_path)
    assert result["shape"]["object_detected"] == "Tablet / Capsule"
    assert "Round" in result["shape"]["shape_type"]
    assert result["shape"]["circularity"] > 0.75


def test_visual_analysis_markings_pill(tmp_path):
    """Verify markings detection flags high-frequency interior edges."""
    img_path = tmp_path / "pill_with_markings.png"
    arr = np.zeros((200, 200, 3), dtype=np.uint8)
    y, x = np.ogrid[:200, :200]
    mask = (x - 100) ** 2 + (y - 100) ** 2 <= 70 ** 2
    arr[mask] = 200
    # Add high-contrast text-like score line / grooves in the center
    arr[98:102, 50:150] = 0
    arr[90:94, 70:130] = 0
    arr[106:110, 70:130] = 0
    Image.fromarray(arr).save(img_path)

    result = analyze_visual_features(img_path)
    assert "detected" in result["markings"]["markings_visible"].lower() or "possible" in result["markings"]["markings_visible"].lower()


def test_visual_analysis_blister_packaging(tmp_path):
    """Verify packaging analyzer detects multi-compartment blister packs."""
    img_path = tmp_path / "blister.png"
    arr = np.zeros((300, 300, 3), dtype=np.uint8)
    # Draw 4 separate circles simulating blister pack pockets
    y, x = np.ogrid[:300, :300]
    for cx, cy in [(75, 75), (225, 75), (75, 225), (225, 225)]:
        m = (x - cx) ** 2 + (y - cy) ** 2 <= 30 ** 2
        arr[m] = 200
    Image.fromarray(arr).save(img_path)

    result = analyze_visual_features(img_path)
    assert "Blister" in result["packaging"].get("packaging_type", "") or result["packaging"]["status"] == "VISIBLE / DETECTED"


def test_visual_analysis_full_pipeline_structure(tmp_path):
    """Test analyze_visual_features returns all required top-level sections."""
    img_path = tmp_path / "test_pill.png"
    arr = np.full((150, 150, 3), 240, dtype=np.uint8)
    # Draw dark oval
    y, x = np.ogrid[:150, :150]
    mask = ((x - 75) / 50) ** 2 + ((y - 75) / 30) ** 2 <= 1.0
    arr[mask] = [45, 100, 185]  # Blue oval
    Image.fromarray(arr).save(img_path)

    result = analyze_visual_features(img_path)
    for section in ["color", "shape", "size", "surface", "markings", "edges", "packaging"]:
        assert section in result, f"Missing section {section}"
    assert result["shape"]["shape_type"] in ("Oval / Oblong", "Capsule-like / Elongated", "Round / Oval")


def test_enhanced_quality_checker_fields(tmp_path):
    """Verify check_image_quality computes new metrics."""
    img_path = tmp_path / "bright.jpg"
    arr = np.zeros((120, 240, 3), dtype=np.uint8)
    arr[:, :, 0] = 180  # R
    arr[:, :, 1] = 90   # G
    arr[:, :, 2] = 40   # B
    arr[20:100, 20:200, :] = [20, 150, 220]
    Image.fromarray(arr).save(img_path)

    res = check_image_quality(img_path)
    d = res.to_dict()
    assert "aspect_ratio" in d
    assert d["aspect_ratio"] == 2.0  # 240 / 120
    assert "contrast" in d
    assert "color_mode" in d
    assert d["color_mode"] == "RGB"
    assert "exposure_status" in d
    assert "sharpness_status" in d
    assert "suitability" in d
