"""Tests for unified model construction and loading."""

import pytest
import torch
from ml.config import SUPPORTED_MODELS
from ml.models.transfer_learning import build_model, load_classifier, normalize_model_name


@pytest.mark.parametrize("model_name", ["efficientnet_b0", "mobilenet_v3_large", "baseline_cnn"])
def test_build_model_forward_shape(model_name):
    model = build_model(model_name)
    x = torch.zeros(2, 3, 224, 224)
    out = model(x)
    if isinstance(out, tuple):
        out = out[0]
    assert tuple(out.shape) == (2, 2)


@pytest.mark.parametrize("model_name", SUPPORTED_MODELS)
def test_load_classifier_loads_successfully(model_name):
    model = load_classifier(model_name, device=torch.device("cpu"))
    assert model is not None
    param_count = sum(p.numel() for p in model.parameters())
    assert param_count > 1000


def test_normalize_model_name():
    assert normalize_model_name("MobileNetV3") == "mobilenet_v3_large"
    assert normalize_model_name("EfficientNet-B0") == "efficientnet_b0"
    assert normalize_model_name("Baseline CNN") == "baseline_cnn"
    assert normalize_model_name("GoldFormer") == "goldformer"
