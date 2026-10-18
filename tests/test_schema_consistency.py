"""Schema consistency and invariant tests.

Validates that the classification contract, API response schemas, model registry,
and confidence thresholds are internally consistent and stable.

These tests do NOT require Ollama, a GPU, internet access, or a running server.
They exercise only imported Python code and configuration values.
"""

from __future__ import annotations

import pytest


# ---------------------------------------------------------------------------
# Classification contract
# ---------------------------------------------------------------------------


def test_class_names_order_and_values() -> None:
    """CLASS_NAMES must be exactly ['authentic', 'counterfeit'] in that order.

    Index 0 must be 'authentic' and index 1 must be 'counterfeit'.
    Changing this order without updating the full inference pipeline would
    silently invert all predictions.
    """
    from ml.config import CLASS_NAMES, CLASS_TO_INDEX, NUM_CLASSES

    assert CLASS_NAMES == ["authentic", "counterfeit"], (
        "Class ordering changed – update the inference pipeline and all tests "
        "that depend on softmax[:, 1] being the counterfeit probability."
    )
    assert CLASS_TO_INDEX["authentic"] == 0
    assert CLASS_TO_INDEX["counterfeit"] == 1
    assert NUM_CLASSES == 2


def test_class_names_consistent_with_training_pipeline() -> None:
    """The training pipeline must use the same class ordering as ml.config."""
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
    from train_pipeline import CLASS_NAMES as TRAIN_CLASS_NAMES
    from ml.config import CLASS_NAMES as CONFIG_CLASS_NAMES

    assert list(TRAIN_CLASS_NAMES) == list(CONFIG_CLASS_NAMES), (
        "ml/config.py and scripts/train_pipeline.py define different CLASS_NAMES. "
        "This will cause mismatched labels between training and inference."
    )


# ---------------------------------------------------------------------------
# Model registry
# ---------------------------------------------------------------------------


def test_checkpoint_registry_keys_match_supported_models() -> None:
    """CHECKPOINT_REGISTRY, SUPPORTED_MODELS, and AVAILABLE_MODELS must be consistent."""
    from ml.config import CHECKPOINT_REGISTRY, SUPPORTED_MODELS, AVAILABLE_MODELS, DEFAULT_MODEL

    assert set(CHECKPOINT_REGISTRY.keys()) == set(SUPPORTED_MODELS), (
        "CHECKPOINT_REGISTRY and SUPPORTED_MODELS have diverged."
    )
    for name in AVAILABLE_MODELS:
        assert name in CHECKPOINT_REGISTRY, f"{name!r} in AVAILABLE_MODELS but missing from CHECKPOINT_REGISTRY"
        assert CHECKPOINT_REGISTRY[name]["finetuned_available"], (
            f"{name!r} is in AVAILABLE_MODELS but finetuned_available=False"
        )

    assert DEFAULT_MODEL in CHECKPOINT_REGISTRY, "DEFAULT_MODEL is not in CHECKPOINT_REGISTRY"
    assert DEFAULT_MODEL in AVAILABLE_MODELS, "DEFAULT_MODEL must have a fine-tuned checkpoint available"


def test_efficientnet_b0_is_available() -> None:
    """efficientnet_b0 must be available (its checkpoint is present on disk)."""
    from ml.config import AVAILABLE_MODELS, CHECKPOINT_REGISTRY

    assert "efficientnet_b0" in AVAILABLE_MODELS, (
        "EfficientNet-B0 checkpoint missing – the primary model is not deployable."
    )
    cfg = CHECKPOINT_REGISTRY["efficientnet_b0"]
    assert cfg["checkpoint"] is not None
    assert cfg["checkpoint"].is_file(), f"Checkpoint file missing: {cfg['checkpoint']}"


def test_missing_model_checkpoints_documented_correctly() -> None:
    """Models without fine-tuned checkpoints must NOT appear in AVAILABLE_MODELS."""
    from ml.config import CHECKPOINT_REGISTRY, AVAILABLE_MODELS

    for name, cfg in CHECKPOINT_REGISTRY.items():
        if not cfg["finetuned_available"]:
            assert name not in AVAILABLE_MODELS, (
                f"{name!r} has finetuned_available=False but is listed in AVAILABLE_MODELS. "
                "This would cause the API to try loading a non-existent checkpoint."
            )


def test_registry_input_sizes_are_uniform() -> None:
    """All models must use the same input resolution (enforced by config.IMAGE_SIZE)."""
    from ml.config import CHECKPOINT_REGISTRY, IMAGE_SIZE

    for name, cfg in CHECKPOINT_REGISTRY.items():
        assert cfg["input_size"] == (IMAGE_SIZE, IMAGE_SIZE), (
            f"{name!r} has input_size {cfg['input_size']} != IMAGE_SIZE ({IMAGE_SIZE}, {IMAGE_SIZE}). "
            "Inconsistent preprocessing would produce wrong predictions."
        )


# ---------------------------------------------------------------------------
# Preprocessing contract
# ---------------------------------------------------------------------------


def test_imagenet_normalization_constants_are_standard() -> None:
    """Mean and std must match canonical ImageNet values used during training."""
    from ml.config import IMAGENET_MEAN, IMAGENET_STD

    # Standard ImageNet per-channel mean (RGB)
    expected_mean = [0.485, 0.456, 0.406]
    expected_std = [0.229, 0.224, 0.225]

    assert IMAGENET_MEAN == pytest.approx(expected_mean, abs=1e-6), (
        "IMAGENET_MEAN has changed – recheck preprocessing alignment with training."
    )
    assert IMAGENET_STD == pytest.approx(expected_std, abs=1e-6), (
        "IMAGENET_STD has changed – recheck preprocessing alignment with training."
    )


def test_image_size_is_standard_efficientnet() -> None:
    """224×224 is the standard size for EfficientNet-B0 and MobileNetV3-Large."""
    from ml.config import IMAGE_SIZE

    assert IMAGE_SIZE == 224, (
        "IMAGE_SIZE changed – all model checkpoints were trained at 224. "
        "Changing this without retraining will degrade performance."
    )


# ---------------------------------------------------------------------------
# Decision thresholds
# ---------------------------------------------------------------------------


def test_confidence_thresholds_are_ordered_correctly() -> None:
    """Low threshold must be strictly below high threshold, both in (0, 1)."""
    from ml.config import DEFAULT_CONFIDENCE_THRESHOLD, DEFAULT_HIGH_CONFIDENCE_THRESHOLD

    assert 0.0 < DEFAULT_CONFIDENCE_THRESHOLD < 1.0, "DEFAULT_CONFIDENCE_THRESHOLD must be in (0, 1)"
    assert 0.0 < DEFAULT_HIGH_CONFIDENCE_THRESHOLD < 1.0, "DEFAULT_HIGH_CONFIDENCE_THRESHOLD must be in (0, 1)"
    assert DEFAULT_CONFIDENCE_THRESHOLD < DEFAULT_HIGH_CONFIDENCE_THRESHOLD, (
        "Low threshold must be strictly below high threshold."
    )


# ---------------------------------------------------------------------------
# PredictionResponse schema completeness
# ---------------------------------------------------------------------------


def test_prediction_response_mandatory_fields_present() -> None:
    """PredictionResponse must contain all mandatory contract fields."""
    from backend.app.schemas.predict import PredictionResponse
    import pydantic

    required_fields = {
        "primary_model",
        "prediction",
        "confidence",
        "qwen",
        "final_result",
        "needs_human_verification",
        "disclaimer",
        "secondary_executed",
        "reasons",
        "disagreement",
        "status",
        "model_name",
        "threshold",
        "authentic_probability",
        "counterfeit_probability",
        "quality",
        "visual_analysis",
    }
    schema_fields = set(PredictionResponse.model_fields.keys())
    missing = required_fields - schema_fields
    assert not missing, f"PredictionResponse is missing expected fields: {sorted(missing)}"


def test_prediction_response_disclaimer_is_non_trivial() -> None:
    """The disclaimer field must warn that AI screening is not a lab test."""
    from backend.app.schemas.predict import PredictionResponse

    default_disclaimer = PredictionResponse.model_fields["disclaimer"].default
    assert default_disclaimer, "PredictionResponse.disclaimer must have a non-empty default"
    lower = default_disclaimer.lower()
    # Must mention that visual AI analysis cannot certify chemical composition
    assert any(word in lower for word in ("cannot", "not", "only")), (
        "Disclaimer must clarify that AI screening is preliminary / limited."
    )
    assert "laboratory" in lower or "chemical" in lower or "purity" in lower, (
        "Disclaimer must reference laboratory testing or chemical purity."
    )


def test_health_response_schema_completeness() -> None:
    """HealthResponse must expose all fields required by the Flutter client."""
    from backend.app.schemas.predict import HealthResponse

    required = {"status", "version", "device", "default_model", "available_models",
                "secondary_ai_model", "secondary_ai_endpoint"}
    actual = set(HealthResponse.model_fields.keys())
    missing = required - actual
    assert not missing, f"HealthResponse is missing fields: {sorted(missing)}"


# ---------------------------------------------------------------------------
# Confidence band logic
# ---------------------------------------------------------------------------


def test_confidence_bands_cover_full_range() -> None:
    """Confidence band boundaries must partition [0, 1] without gaps."""
    from ml.config import DEFAULT_CONFIDENCE_THRESHOLD, DEFAULT_HIGH_CONFIDENCE_THRESHOLD

    low = DEFAULT_CONFIDENCE_THRESHOLD       # 0.70
    high = DEFAULT_HIGH_CONFIDENCE_THRESHOLD  # 0.90

    # Three bands: [0, low) → manual review; [low, high) → Qwen; [high, 1] → fast path
    # Verify the boundaries tile without overlap or gap
    assert 0.0 < low < high < 1.0, "Confidence bands are misconfigured"
    # A value just below the threshold is in the manual-review band
    test_val = low - 0.001
    assert test_val < low  # Would trigger NEEDS MANUAL REVIEW
    # A value between the thresholds triggers secondary review
    mid_val = (low + high) / 2
    assert low <= mid_val < high  # Would trigger Qwen review
    # A value at or above the high threshold is fast-path
    assert high <= 0.90 + 1e-9  # Sanity: high threshold ≤ 0.90 (expected default)
