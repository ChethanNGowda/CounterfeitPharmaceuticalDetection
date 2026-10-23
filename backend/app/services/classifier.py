"""Inference and secondary AI vision verification service for FastAPI backend."""

from __future__ import annotations

import io
from typing import Optional
from PIL import Image
import torch

from ml.config import (
    DEFAULT_CONFIDENCE_THRESHOLD,
    DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
    DEFAULT_MODEL,
    get_device,
)
from ml.inference.predict import predict_pipeline
from ml.models.transfer_learning import load_classifier, normalize_model_name
from ml.verification.qwen_verifier import QwenVisionVerifier


class ClassifierService:
    """Manages loaded neural models and coordinates inference and Qwen Vision verification."""

    _instance: Optional[ClassifierService] = None

    def __init__(self):
        self.device = get_device()
        self.models = {}
        self.vision_verifier = QwenVisionVerifier()
        # Backward-compatibility alias
        self.qwen_reviewer = self.vision_verifier
        # Pre-load default model
        self.load_model(DEFAULT_MODEL)

    @classmethod
    def get_instance(cls) -> ClassifierService:
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def load_model(self, model_name: str):
        norm_name = normalize_model_name(model_name)
        if norm_name not in self.models:
            self.models[norm_name] = load_classifier(norm_name, device=self.device)
        return self.models[norm_name]

    def predict_image_bytes(
        self,
        image_bytes: bytes,
        filename: str = "upload.jpg",
        model_name: str = DEFAULT_MODEL,
        threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
        high_threshold: float = DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
        vision_mode: Optional[str] = None,
        enable_qwen: bool = True,
    ) -> dict:
        norm_name = normalize_model_name(model_name)
        if norm_name not in self.models:
            self.load_model(norm_name)

        model = self.models[norm_name]

        # 1. Pre-flight validate image readability before passing bytes to pipeline.
        # Note: PIL.Image.verify() must be called on a freshly-opened image because
        # it exhausts the internal stream pointer and marks the image as verified/closed.
        # We only need to confirm the bytes are a decodable image; the pipeline handles
        # corrupted images gracefully via the quality gate.
        try:
            img_probe = Image.open(io.BytesIO(image_bytes))
            img_probe.verify()  # raises if image is truncated/corrupt
        except Exception as e:
            raise ValueError(f"Corrupted or invalid image data: {e}")

        # 2. Determine effective vision mode
        if not enable_qwen:
            effective_vision_mode = "never"
        elif vision_mode:
            effective_vision_mode = vision_mode.lower().strip()
        else:
            effective_vision_mode = "auto"

        # 3. Execute authoritative end-to-end pipeline
        result = predict_pipeline(
            image_input=image_bytes,
            model=model,
            threshold=threshold,
            high_threshold=high_threshold,
            vision_mode=effective_vision_mode,
            vision_verifier=self.vision_verifier,
            device=self.device,
            quality_check=True,
        )
        result["image_path"] = filename
        result["model_name"] = norm_name

        return result
