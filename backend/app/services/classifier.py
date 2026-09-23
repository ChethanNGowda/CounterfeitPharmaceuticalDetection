"""Inference service for FastAPI backend."""

from __future__ import annotations

import io
from typing import Optional
from PIL import Image
import torch

from ml.config import (
    DEFAULT_CONFIDENCE_THRESHOLD,
    DEFAULT_MODEL,
    SUPPORTED_MODELS,
    get_device,
)
from ml.inference.predict import predict
from ml.models.transfer_learning import load_classifier, normalize_model_name


class ClassifierService:
    """Manages loaded models and coordinates inference."""

    _instance: Optional[ClassifierService] = None

    def __init__(self):
        self.device = get_device()
        self.models = {}
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
    ) -> dict:
        norm_name = normalize_model_name(model_name)
        if norm_name not in self.models:
            self.load_model(norm_name)

        model = self.models[norm_name]

        # Read into PIL image
        try:
            pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise ValueError(f"Corrupted or invalid image data: {e}")

        # Run inference
        result = predict(
            image_input=pil_image,
            model=model,
            threshold=threshold,
            device=self.device,
            quality_check=True,
        )
        result["image_path"] = filename
        result["model_name"] = norm_name
        return result
