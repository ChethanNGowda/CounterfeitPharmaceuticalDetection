"""Image quality and out-of-distribution screening before model inference."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Union

import cv2
import numpy as np
from PIL import Image

from ml.config import QUALITY_CONFIG


@dataclass
class QualityCheckResult:
    is_valid: bool
    reason: str | None
    blur_score: float
    brightness_mean: float
    width: int
    height: int

    def to_dict(self) -> dict:
        return {
            "is_valid": self.is_valid,
            "reason": self.reason,
            "blur_score": round(self.blur_score, 2),
            "brightness_mean": round(self.brightness_mean, 2),
            "dimensions": [self.width, self.height],
        }


def check_image_quality(
    image_input: Union[str, Path, Image.Image, np.ndarray],
    config: dict | None = None,
) -> QualityCheckResult:
    """Validate image suitability prior to classification."""
    cfg = config or QUALITY_CONFIG
    
    # 1. Load image to BGR / Grayscale numpy array
    if isinstance(image_input, (str, Path)):
        path = Path(image_input)
        if not path.is_file():
            return QualityCheckResult(
                is_valid=False,
                reason="File does not exist",
                blur_score=0.0,
                brightness_mean=0.0,
                width=0,
                height=0,
            )
        try:
            pil_img = Image.open(path).convert("RGB")
            cv_img = np.array(pil_img)[:, :, ::-1]  # RGB to BGR
        except Exception as err:
            return QualityCheckResult(
                is_valid=False,
                reason=f"Failed to read image or corrupted file: {err}",
                blur_score=0.0,
                brightness_mean=0.0,
                width=0,
                height=0,
            )
    elif isinstance(image_input, (bytes, bytearray)):
        try:
            import io
            pil_img = Image.open(io.BytesIO(image_input)).convert("RGB")
            cv_img = np.array(pil_img)[:, :, ::-1]
        except Exception as err:
            return QualityCheckResult(
                is_valid=False,
                reason=f"Failed to read image bytes or corrupted data: {err}",
                blur_score=0.0,
                brightness_mean=0.0,
                width=0,
                height=0,
            )
    elif isinstance(image_input, Image.Image):
        pil_img = image_input.convert("RGB")
        cv_img = np.array(pil_img)[:, :, ::-1]
    elif isinstance(image_input, np.ndarray):
        cv_img = image_input
        if cv_img.ndim == 2:
            cv_img = cv2.cvtColor(cv_img, cv2.COLOR_GRAY2BGR)
    else:
        return QualityCheckResult(
            is_valid=False,
            reason=f"Unsupported image input type: {type(image_input).__name__}",
            blur_score=0.0,
            brightness_mean=0.0,
            width=0,
            height=0,
        )

    height, width = cv_img.shape[:2]

    # 2. Check resolution
    if width < cfg.get("min_width", 64) or height < cfg.get("min_height", 64):
        return QualityCheckResult(
            is_valid=False,
            reason=f"Image resolution too low ({width}x{height}, minimum is {cfg['min_width']}x{cfg['min_height']})",
            blur_score=0.0,
            brightness_mean=0.0,
            width=width,
            height=height,
        )

    # 3. Convert to grayscale for blur and brightness analysis
    gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY) if cv_img.ndim == 3 else cv_img

    # 4. Blur check via Laplacian variance
    laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    min_blur = cfg.get("min_laplacian_var", 50.0)

    # 5. Brightness check
    brightness_mean = float(np.mean(gray))
    min_bright = cfg.get("min_brightness_mean", 15.0)
    max_bright = cfg.get("max_brightness_mean", 245.0)

    if brightness_mean < min_bright:
        return QualityCheckResult(
            is_valid=False,
            reason="Poor image quality: extreme underexposure / image too dark",
            blur_score=laplacian_var,
            brightness_mean=brightness_mean,
            width=width,
            height=height,
        )

    if brightness_mean > max_bright:
        return QualityCheckResult(
            is_valid=False,
            reason="Poor image quality: extreme overexposure / image washed out",
            blur_score=laplacian_var,
            brightness_mean=brightness_mean,
            width=width,
            height=height,
        )

    if laplacian_var < min_blur:
        return QualityCheckResult(
            is_valid=False,
            reason=f"Poor image quality: excessive blur (score {laplacian_var:.1f} < {min_blur})",
            blur_score=laplacian_var,
            brightness_mean=brightness_mean,
            width=width,
            height=height,
        )

    return QualityCheckResult(
        is_valid=True,
        reason=None,
        blur_score=laplacian_var,
        brightness_mean=brightness_mean,
        width=width,
        height=height,
    )
