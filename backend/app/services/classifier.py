"""Inference and secondary AI reasoning review service for FastAPI backend."""

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
from ml.verification.decision_engine import make_decision
from ml.verification.qwen_reviewer import (
    QwenReviewer,
    build_evidence_payload,
)


class ClassifierService:
    """Manages loaded neural models and coordinates inference and Qwen review."""

    _instance: Optional[ClassifierService] = None

    def __init__(self):
        self.device = get_device()
        self.models = {}
        self.qwen_reviewer = QwenReviewer()
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
        enable_qwen: bool = True,
    ) -> dict:
        norm_name = normalize_model_name(model_name)
        if norm_name not in self.models:
            self.load_model(norm_name)

        model = self.models[norm_name]

        # 1. Read and validate PIL image
        try:
            pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise ValueError(f"Corrupted or invalid image data: {e}")

        # 2. Run primary deep convolutional inference
        primary_res = predict(
            image_input=pil_image,
            model=model,
            threshold=threshold,
            device=self.device,
            quality_check=True,
        )
        primary_res["image_path"] = filename
        primary_res["model_name"] = norm_name

        # 3. Run secondary AI reasoning review if requested and quality passed
        if enable_qwen:
            evidence = build_evidence_payload(primary_res, primary_res.get("quality"))
            try:
                qwen_review = self.qwen_reviewer.review_evidence(evidence)
            except Exception as qwen_exc:
                qwen_review = {
                    "available": False,
                    "assessment": "SUSPICIOUS",
                    "confidence": 0.0,
                    "reasoning": [f"Secondary reviewer error: {qwen_exc}"],
                    "needs_human_verification": True,
                    "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                    "error": str(qwen_exc),
                }
        else:
            qwen_review = {
                "available": False,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": ["Secondary AI verification disabled by request."],
                "needs_human_verification": False,
                "warning": "Secondary AI verification unavailable.",
            }

        # 4. Synthesize through conservative Decision Engine
        decision = make_decision(
            primary_result=primary_res,
            qwen_review=qwen_review,
            confidence_threshold=threshold,
        )

        # 5. Assemble unified output
        result = dict(primary_res)
        result.update({
            "primary_model": decision["primary_model"],
            "prediction": decision["prediction"],
            "confidence": decision["confidence"],
            "qwen": decision["qwen"],
            "final_result": decision["final_result"],
            "needs_human_verification": decision["needs_human_verification"],
            "warning": decision["warning"],
            "disclaimer": decision["disclaimer"],
        })

        return result
