"""Tests for unified model construction, checkpoint loading, and availability verification."""

from pathlib import Path
import pytest
import torch

from ml.config import CHECKPOINT_REGISTRY, SUPPORTED_MODELS
from ml.models.transfer_learning import (
    CheckpointUnavailableError,
    build_model,
    get_model_status,
    is_model_available,
    load_classifier,
    normalize_model_name,
)


@pytest.mark.parametrize("model_name", ["efficientnet_b0", "mobilenet_v3_large", "baseline_cnn"])
def test_build_model_forward_shape(model_name):
    """Verify that architecture construction produces valid (batch, 2) binary output logits."""
    model = build_model(model_name)
    x = torch.zeros(2, 3, 224, 224)
    out = model(x)
    if isinstance(out, tuple):
        out = out[0]
    assert tuple(out.shape) == (2, 2)


def test_load_finetuned_efficientnet_b0_success():
    """Verify that the primary fine-tuned EfficientNet-B0 pharmaceutical checkpoint loads successfully."""
    assert is_model_available("efficientnet_b0") is True
    status = get_model_status("efficientnet_b0")
    assert status["finetuned_available"] is True
    assert status["status"] == "Fine-tuned classifier available"

    model = load_classifier("efficientnet_b0", device=torch.device("cpu"))
    assert model is not None
    param_count = sum(p.numel() for p in model.parameters())
    assert param_count > 1000

    # Ensure forward pass works with loaded weights
    dummy_input = torch.zeros(1, 3, 224, 224)
    output = model(dummy_input)
    assert output.shape == (1, 2)


@pytest.mark.parametrize("model_name", ["mobilenet_v3_large", "baseline_cnn", "goldformer"])
def test_missing_finetuned_checkpoints_fail_gracefully(model_name):
    """Verify that missing fine-tuned pharmaceutical checkpoints fail gracefully with informative errors."""
    assert is_model_available(model_name) is False
    status = get_model_status(model_name)
    assert status["finetuned_available"] is False

    with pytest.raises(CheckpointUnavailableError) as exc_info:
        load_classifier(model_name, device=torch.device("cpu"))

    error_msg = str(exc_info.value)
    assert "fine-tuned pharmaceutical checkpoint unavailable" in error_msg.lower()
    assert normalize_model_name(model_name) in error_msg


def test_imagenet_pretrained_not_claimed_as_trained_classifier():
    """Verify that generic ImageNet pretrained weights are NEVER claimed as trained pharmaceutical classifiers."""
    status = get_model_status("mobilenet_v3_large")
    # Backbone weights exist, but fine-tuned weights do not
    assert status["pretrained_available"] is True
    assert status["finetuned_available"] is False
    assert status["status"] == "Architecture available, but fine-tuned pharmaceutical checkpoint unavailable"

    # Attempting to load as pharmaceutical classifier must raise CheckpointUnavailableError
    with pytest.raises(CheckpointUnavailableError) as exc_info:
        load_classifier("mobilenet_v3_large")

    error_text = str(exc_info.value)
    assert "will NOT be silently loaded as a counterfeit pharmaceutical classifier" in error_text


def test_model_registry_consistency_with_disk():
    """Verify that CHECKPOINT_REGISTRY flags strictly match files present on disk."""
    for model_name, cfg in CHECKPOINT_REGISTRY.items():
        ckpt = cfg.get("checkpoint")
        if cfg["finetuned_available"]:
            assert ckpt is not None
            assert Path(ckpt).is_file(), f"Model {model_name} claimed available but checkpoint file missing: {ckpt}"
        else:
            assert ckpt is None or not Path(ckpt).is_file(), f"Model {model_name} claimed unavailable but checkpoint exists: {ckpt}"

        pre = cfg.get("pretrained")
        if cfg["pretrained_available"]:
            assert pre is not None
            assert Path(pre).is_file(), f"Model {model_name} claimed pretrained available but file missing: {pre}"


def test_normalize_model_name():
    assert normalize_model_name("MobileNetV3") == "mobilenet_v3_large"
    assert normalize_model_name("EfficientNet-B0") == "efficientnet_b0"
    assert normalize_model_name("Baseline CNN") == "baseline_cnn"
    assert normalize_model_name("GoldFormer") == "goldformer"

