"""Tablet Visual Feature Analysis Module.

Extracts measurable, deterministic visual features from pharmaceutical images:
- Color analysis (dominant color, RGB/HSV metrics, consistency)
- Shape analysis (contour, circularity, aspect ratio, symmetry)
- Size / Geometry (bounding box px, pixel area px², aspect ratio)
- Surface / Texture analysis (uniformity, spots, surface variations)
- Markings / Text / Imprint analysis (interior edge density, imprint visibility)
- Edge analysis (integrity, chipping, cracks, contour consistency)
- Packaging analysis (presence of blister pack or secondary packaging)

IMPORTANT SCIENTIFIC BOUNDARIES:
- Does NOT claim chemical authenticity or bioequivalence.
- Does NOT claim physical millimeter dimensions without a calibrated scale reference.
- Observations are visual measurements only, not proof of authenticity.
"""

from __future__ import annotations

import io
from pathlib import Path
from typing import Any, Optional, Union

import cv2
import numpy as np
from PIL import Image

# Known color centroids for visual color naming (RGB space)
COLOR_CENTROIDS = [
    ("White", (245, 245, 245)),
    ("Off-White / Cream", (230, 225, 210)),
    ("Light Pink", (240, 195, 205)),
    ("Pink", (225, 135, 165)),
    ("Red", (190, 45, 45)),
    ("Peach / Coral", (235, 160, 120)),
    ("Orange", (230, 140, 50)),
    ("Yellow", (230, 215, 60)),
    ("Light Yellow / Beige", (235, 225, 175)),
    ("Light Green", (140, 205, 145)),
    ("Green", (50, 140, 70)),
    ("Light Blue", (150, 195, 230)),
    ("Blue", (45, 100, 185)),
    ("Purple / Violet", (135, 80, 160)),
    ("Brown", (130, 85, 55)),
    ("Gray", (130, 130, 130)),
    ("Dark Gray / Black", (45, 45, 45)),
]


def _match_color_name(rgb: tuple[float, float, float]) -> str:
    """Find closest human-readable color name using Euclidean distance in RGB space."""
    r, g, b = rgb
    best_name = "Undetermined"
    min_dist = float("inf")
    for name, c_rgb in COLOR_CENTROIDS:
        cr, cg, cb = c_rgb
        dist = np.sqrt((r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2)
        if dist < min_dist:
            min_dist = dist
            best_name = name
    return best_name


def _load_image_to_cv(image_input: Union[str, Path, Image.Image, bytes, bytearray, np.ndarray]) -> np.ndarray:
    """Safely load image input to RGB numpy array."""
    if isinstance(image_input, (str, Path)):
        with Image.open(Path(image_input)) as img:
            return np.array(img.convert("RGB"))
    elif isinstance(image_input, (bytes, bytearray)):
        with Image.open(io.BytesIO(image_input)) as img:
            return np.array(img.convert("RGB"))
    elif isinstance(image_input, Image.Image):
        return np.array(image_input.convert("RGB"))
    elif isinstance(image_input, np.ndarray):
        if image_input.ndim == 2:
            return cv2.cvtColor(image_input, cv2.COLOR_GRAY2RGB)
        elif image_input.shape[2] == 4:
            return cv2.cvtColor(image_input, cv2.COLOR_RGBA2RGB)
        return image_input
    raise ValueError(f"Unsupported image input type: {type(image_input).__name__}")


def analyze_visual_features(
    image_input: Union[str, Path, Image.Image, bytes, bytearray, np.ndarray]
) -> dict[str, Any]:
    """Perform deterministic visual feature inspection on a tablet image.

    Returns structured analysis of:
    - color
    - shape
    - size
    - surface
    - markings
    - edges
    - packaging
    """
    try:
        rgb_img = _load_image_to_cv(image_input)
    except Exception as err:
        return _make_error_visual_analysis(str(err))

    h_img, w_img = rgb_img.shape[:2]
    gray = cv2.cvtColor(rgb_img, cv2.COLOR_RGB2GRAY)
    total_pixels = float(h_img * w_img)

    # 1. Tablet / Object Segmentation
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Check background polarity from image perimeter
    border_pixels = np.concatenate([gray[0, :], gray[-1, :], gray[:, 0], gray[:, -1]])
    if np.median(border_pixels) > 128:
        thresh = cv2.bitwise_not(thresh)

    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Filter candidate contours by area (between 1.5% and 98% of image)
    valid_contours = []
    min_area = total_pixels * 0.015
    max_area = total_pixels * 0.98

    for cnt in contours:
        a = cv2.contourArea(cnt)
        if min_area <= a <= max_area:
            valid_contours.append((cnt, a))

    object_detected = len(valid_contours) > 0
    if object_detected:
        # Choose the largest central contour
        best_cnt = max(valid_contours, key=lambda x: x[1])[0]
        tablet_mask = np.zeros((h_img, w_img), dtype=np.uint8)
        cv2.drawContours(tablet_mask, [best_cnt], -1, 255, thickness=-1)
    else:
        # Fallback to central 60% window for color/texture metrics
        best_cnt = None
        tablet_mask = np.zeros((h_img, w_img), dtype=np.uint8)
        y1, y2 = int(h_img * 0.2), int(h_img * 0.8)
        x1, x2 = int(w_img * 0.2), int(w_img * 0.8)
        tablet_mask[y1:y2, x1:x2] = 255

    # 2. Color Analysis
    masked_pixels = rgb_img[tablet_mask > 0]
    if len(masked_pixels) > 0:
        mean_rgb = np.mean(masked_pixels, axis=0)
        std_rgb = np.std(masked_pixels, axis=0)
        mean_r, mean_g, mean_b = float(mean_rgb[0]), float(mean_rgb[1]), float(mean_rgb[2])

        # HSV values
        hsv_img = cv2.cvtColor(rgb_img, cv2.COLOR_RGB2HSV)
        masked_hsv = hsv_img[tablet_mask > 0]
        mean_hsv = np.mean(masked_hsv, axis=0)
        mean_h, mean_s, mean_v = float(mean_hsv[0]), float(mean_hsv[1]), float(mean_hsv[2])

        dom_name = _match_color_name((mean_r, mean_g, mean_b))
        overall_std = float(np.mean(std_rgb))

        if overall_std < 22.0:
            consistency = "HIGH"
            variation = "Uniform coloration across tablet surface"
        elif overall_std < 48.0:
            consistency = "MODERATE"
            variation = "Consistent appearance with minor shading/lighting variance"
        else:
            consistency = "LOW"
            variation = "Noticeable color variation, mottling, or multi-tone appearance"
    else:
        dom_name = "Unclear"
        mean_r, mean_g, mean_b = 0.0, 0.0, 0.0
        mean_h, mean_s, mean_v = 0.0, 0.0, 0.0
        consistency = "UNKNOWN"
        variation = "Insufficient segmented pixels"

    color_analysis = {
        "dominant_color": dom_name,
        "average_rgb": [round(mean_r, 1), round(mean_g, 1), round(mean_b, 1)],
        "average_hsv": [round(mean_h, 1), round(mean_s, 1), round(mean_v, 1)],
        "consistency": consistency,
        "visible_variation": variation,
        "disclaimer": "Color observed visually; no reference pharmaceutical color standard applied.",
    }

    # 3. Shape Analysis & 4. Size / Geometry
    if object_detected and best_cnt is not None:
        area = float(cv2.contourArea(best_cnt))
        perimeter = float(cv2.arcLength(best_cnt, True))
        circularity = float((4 * np.pi * area) / (perimeter ** 2)) if perimeter > 0 else 0.0
        x, y, w, h = cv2.boundingRect(best_cnt)
        aspect_ratio = float(w) / float(h) if h > 0 else 1.0

        # Symmetry estimate (Horizontal and Vertical IoU)
        cnt_mask = np.zeros((h, w), dtype=np.uint8)
        shifted_cnt = best_cnt - np.array([x, y])
        cv2.drawContours(cnt_mask, [shifted_cnt], -1, 255, -1)
        flipped_h = cv2.flip(cnt_mask, 1)
        flipped_v = cv2.flip(cnt_mask, 0)

        iou_h = np.sum((cnt_mask > 0) & (flipped_h > 0)) / max(1, np.sum((cnt_mask > 0) | (flipped_h > 0)))
        iou_v = np.sum((cnt_mask > 0) & (flipped_v > 0)) / max(1, np.sum((cnt_mask > 0) | (flipped_v > 0)))
        sym_score = float((iou_h + iou_v) / 2.0)

        if sym_score > 0.85:
            symmetry = "High symmetry"
        elif sym_score > 0.70:
            symmetry = "Moderate symmetry"
        else:
            symmetry = "Asymmetric / Irregular"

        # Shape geometry classification
        if circularity >= 0.78 and 0.82 <= aspect_ratio <= 1.22:
            shape_type = "Round / Circular"
        elif circularity >= 0.45 and (aspect_ratio >= 1.25 or aspect_ratio <= 0.80):
            shape_type = "Oval / Oblong"
        elif aspect_ratio >= 1.90 or aspect_ratio <= 0.52:
            shape_type = "Capsule-like / Elongated"
        elif circularity < 0.60:
            shape_type = "Irregular / Polyhedral"
        else:
            shape_type = "Round / Oval"

        shape_analysis = {
            "object_detected": "Tablet / Capsule",
            "shape_type": shape_type,
            "circularity": round(circularity, 2),
            "aspect_ratio": round(aspect_ratio, 2),
            "symmetry": symmetry,
            "description": f"Conforms to {shape_type.lower()} geometry with {symmetry.lower()}.",
        }

        size_analysis = {
            "bounding_box": f"{w} x {h} px",
            "pixel_area": f"{int(area):,} px^2",
            "aspect_ratio": round(aspect_ratio, 2),
            "physical_size": "Not measurable without scale reference (no physical scale standard in image)",
        }
    else:
        shape_analysis = {
            "object_detected": "Uncertain / Background dominant",
            "shape_type": "Uncertain",
            "circularity": 0.0,
            "aspect_ratio": 1.0,
            "symmetry": "N/A",
            "description": "No distinct isolated tablet segmented; pattern or packaging may dominate.",
        }
        size_analysis = {
            "bounding_box": f"{w_img} x {h_img} px",
            "pixel_area": f"{int(total_pixels):,} px^2",
            "aspect_ratio": round(float(w_img) / float(h_img), 2) if h_img > 0 else 1.0,
            "physical_size": "Not measurable without scale reference",
        }

    # 5. Surface & Texture Analysis
    gray_masked = gray[tablet_mask > 0]
    if len(gray_masked) > 0:
        # Texture variation via high-frequency Laplacian residuals
        lap_residual = cv2.Laplacian(gray, cv2.CV_64F)
        texture_std = float(np.std(lap_residual[tablet_mask > 0]))

        if texture_std < 15.0:
            texture_var = "Low (Smooth surface)"
            surface_desc = "Relatively uniform and smooth surface"
        elif texture_std < 38.0:
            texture_var = "Moderate (Standard matte/coated surface)"
            surface_desc = "Standard pharmaceutical surface with mild texture"
        else:
            texture_var = "High (Rough / Granular / Mottled)"
            surface_desc = "Noticeable granularity or surface irregularities detected"

        # Spot / inclusion detection via localized contrast deviations
        eroded_mask = cv2.erode(tablet_mask, np.ones((7, 7), np.uint8))
        if np.sum(eroded_mask) > 0:
            mean_int = float(np.mean(gray[eroded_mask > 0]))
            std_int = float(np.std(gray[eroded_mask > 0]))
            # Outlier intensity blobs
            dark_spots = (gray < (mean_int - 2.8 * std_int)) & (eroded_mask > 0)
            bright_spots = (gray > (mean_int + 2.8 * std_int)) & (eroded_mask > 0)
            spot_count = int(np.sum(dark_spots | bright_spots))
            has_spots = spot_count > (np.sum(eroded_mask > 0) * 0.005)
        else:
            has_spots = False

        surface_analysis = {
            "texture_variation": texture_var,
            "surface_uniformity": "Uniform" if texture_std < 25.0 else "Relatively uniform" if texture_std < 40.0 else "Irregular",
            "visible_spots": "Detected (surface spots/pigmentation)" if has_spots else "Not detected",
            "surface_irregularities": "Detected" if has_spots or texture_std > 40.0 else "Not detected",
            "description": surface_desc,
        }
    else:
        surface_analysis = {
            "texture_variation": "Undetermined",
            "surface_uniformity": "Undetermined",
            "visible_spots": "Not detected",
            "surface_irregularities": "Not detected",
            "description": "Insufficient pixels for surface texture extraction.",
        }

    # 6. Markings / Text / Imprint Analysis
    # Compute high-frequency edge gradients in the interior (excluding outer tablet boundary)
    if object_detected and best_cnt is not None:
        inner_mask = cv2.erode(tablet_mask, np.ones((11, 11), np.uint8))
        inner_pixel_count = int(np.sum(inner_mask > 0))
        if inner_pixel_count > 100:
            sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
            sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
            grad_mag = np.sqrt(sobelx ** 2 + sobely ** 2)
            interior_grad = grad_mag[inner_mask > 0]
            edge_density = float(np.mean(interior_grad > 35.0))

            if edge_density > 0.040:
                markings_visible = "YES (Imprint / Engraving detected)"
                imprint_type = "Debossed / Engraved contours present"
                text_recog = "UNCERTAIN (Secondary AI visual verification recommended)"
                legibility = "PARTIALLY VISIBLE / PENDING SECONDARY REVIEW"
                markings_desc = "High-frequency surface gradients indicate debossed imprint or score line."
            elif edge_density > 0.018:
                markings_visible = "POSSIBLE (Faint markings or surface texture)"
                imprint_type = "Low-relief surface patterns"
                text_recog = "UNCERTAIN (Contrast insufficient for automated OCR)"
                legibility = "FAIR / FAINT"
                markings_desc = "Subtle surface impressions observed; may require secondary AI or macro lens."
            else:
                markings_visible = "NO (Plain surface observed)"
                imprint_type = "None detected (Smooth tablet face)"
                text_recog = "NOT APPLICABLE"
                legibility = "N/A"
                markings_desc = "No prominent debossed imprints or markings detected on visible tablet face."
        else:
            markings_visible = "UNCERTAIN"
            imprint_type = "Undetermined"
            text_recog = "UNCERTAIN"
            legibility = "POOR"
            markings_desc = "Segmented interior too small for reliable imprint analysis."
    else:
        markings_visible = "UNCERTAIN"
        imprint_type = "Undetermined"
        text_recog = "UNCERTAIN"
        legibility = "POOR"
        markings_desc = "Tablet segmentation unavailable."

    markings_analysis = {
        "markings_visible": markings_visible,
        "imprint_type": imprint_type,
        "text_recognition": text_recog,
        "legibility": legibility,
        "description": markings_desc,
    }

    # 7. Edge Analysis
    if object_detected and best_cnt is not None:
        hull = cv2.convexHull(best_cnt)
        hull_area = float(cv2.contourArea(hull))
        solidity = (area / hull_area) if hull_area > 0 else 1.0

        if solidity >= 0.96:
            edge_integrity = "INTACT"
            cracks = "Not detected"
            chipping = "Not detected"
            contour_desc = "Consistent and smooth perimeter contour"
        elif solidity >= 0.90:
            edge_integrity = "MOSTLY INTACT"
            cracks = "Not detected"
            chipping = "Minor edge notch or peripheral indentation observed"
            contour_desc = "Slightly irregular perimeter"
        else:
            edge_integrity = "COMPROMISED / IRREGULAR"
            cracks = "Potential perimeter defect or indentation"
            chipping = "Chipping or edge irregularity detected"
            contour_desc = "Noticeably irregular contour"

        edge_analysis = {
            "edge_integrity": edge_integrity,
            "cracks": cracks,
            "chipping": chipping,
            "contour": contour_desc,
            "solidity": round(solidity, 2),
        }
    else:
        edge_analysis = {
            "edge_integrity": "UNCERTAIN",
            "cracks": "Not detected",
            "chipping": "Not detected",
            "contour": "Unclear / Object not segmented",
            "solidity": 0.0,
        }

    # 8. Packaging Analysis
    # Check for blister foil patterns or secondary packaging elements
    if not object_detected or (len(valid_contours) > 3):
        # Multiple repetitive contours or no central single tablet indicates potential blister/strip
        packaging_analysis = {
            "status": "VISIBLE / DETECTED",
            "packaging_type": "Blister pack / Packaging elements detected in frame",
            "damage": "Not detected",
            "reason": "Image contains multi-unit blister pack or secondary packaging structures.",
        }
    else:
        packaging_analysis = {
            "status": "NOT VISIBLE",
            "reason": "Image contains isolated tablet only; no blister pack or retail box in frame.",
        }

    return {
        "color": color_analysis,
        "shape": shape_analysis,
        "size": size_analysis,
        "surface": surface_analysis,
        "markings": markings_analysis,
        "edges": edge_analysis,
        "packaging": packaging_analysis,
    }


def _make_error_visual_analysis(reason: str) -> dict[str, Any]:
    """Return safe empty visual analysis when image loading fails."""
    return {
        "color": {"dominant_color": "Unclear", "consistency": "UNKNOWN", "visible_variation": reason},
        "shape": {"object_detected": "Error", "shape_type": "Unclear", "circularity": 0.0, "aspect_ratio": 1.0, "symmetry": "N/A"},
        "size": {"bounding_box": "0 x 0 px", "pixel_area": "0 px^2", "aspect_ratio": 1.0, "physical_size": "Not measurable"},
        "surface": {"texture_variation": "Undetermined", "surface_uniformity": "Undetermined", "visible_spots": "Not detected", "surface_irregularities": "Not detected"},
        "markings": {"markings_visible": "UNCERTAIN", "imprint_type": "None", "text_recognition": "UNCERTAIN", "legibility": "POOR"},
        "edges": {"edge_integrity": "UNCERTAIN", "cracks": "Not detected", "chipping": "Not detected", "contour": "Unclear"},
        "packaging": {"status": "NOT VISIBLE", "reason": reason},
    }
