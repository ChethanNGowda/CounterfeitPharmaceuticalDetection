"""Torchvision and custom model construction and unified checkpoint loading."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
from typing import Any, Optional

import torch
from torch import nn
from torchvision.models import efficientnet_b0, mobilenet_v3_large

from ml.config import CHECKPOINT_REGISTRY, PROJECT_ROOT


def normalize_model_name(name: str) -> str:
    """Normalize model string to standard identifier."""
    cleaned = name.strip().lower().replace("-", "_").replace(" ", "_")
    if cleaned in ("mobilenet", "mobilenetv3", "mobilenet_v3"):
        return "mobilenet_v3_large"
    if cleaned in ("efficientnet", "efficientnetb0"):
        return "efficientnet_b0"
    if cleaned in ("gold_former", "goldnet"):
        return "goldformer"
    return cleaned


def _build_baseline_cnn(num_classes: int = 2) -> nn.Module:
    """Baseline 3-layer convolutional network for comparison."""
    return nn.Sequential(
        nn.Conv2d(3, 32, 3, padding=1),
        nn.BatchNorm2d(32),
        nn.ReLU(),
        nn.MaxPool2d(2),
        nn.Conv2d(32, 64, 3, padding=1),
        nn.BatchNorm2d(64),
        nn.ReLU(),
        nn.MaxPool2d(2),
        nn.Conv2d(64, 128, 3, padding=1),
        nn.BatchNorm2d(128),
        nn.ReLU(),
        nn.AdaptiveAvgPool2d(1),
        nn.Flatten(),
        nn.Dropout(0.25),
        nn.Linear(128, num_classes),
    )


def _build_goldformer(checkpoint_path: Optional[Path] = None) -> nn.Module:
    """Dynamically load official GoldFormer architecture from external_models."""
    models_code_path = PROJECT_ROOT / "external_models" / "GoldNet" / "code" / "models.py"
    if not models_code_path.is_file():
        raise FileNotFoundError(f"GoldNet models.py not found at {models_code_path}")

    module_name = "external_goldnet_models"
    if module_name not in sys.modules:
        spec = importlib.util.spec_from_file_location(module_name, models_code_path)
        if spec is None or spec.loader is None:
            raise ImportError(f"Cannot import {models_code_path}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        spec.loader.exec_module(module)
    else:
        module = sys.modules[module_name]

    # Temporarily monkeypatch torchvision models to avoid online weight downloads
    orig_r50 = module.models.resnet50
    orig_swin = module.models.swin_t
    module.models.resnet50 = lambda *a, **kw: orig_r50(weights=None)
    module.models.swin_t = lambda *a, **kw: orig_swin(weights=None)
    try:
        model = module.build_model("goldformer")
    finally:
        module.models.resnet50 = orig_r50
        module.models.swin_t = orig_swin

    if checkpoint_path and Path(checkpoint_path).is_file():
        state = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
        model.load_state_dict(state, strict=True)

    return model


def build_model(
    model_name: str,
    pretrained_path: Optional[Path | str] = None,
    num_classes: int = 2,
) -> nn.Module:
    """Instantiate model architecture and optionally initialize with base weights."""
    norm_name = normalize_model_name(model_name)
    pretrained = Path(pretrained_path) if pretrained_path else None

    if norm_name == "mobilenet_v3_large":
        model = mobilenet_v3_large(weights=None)
        if pretrained and pretrained.is_file():
            ckpt = torch.load(pretrained, map_location="cpu", weights_only=False)
            state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
            state = {k.removeprefix("module."): v for k, v in state.items() if not k.startswith("classifier.")}
            model.load_state_dict(state, strict=False)
        classifier_index = 3
        classifier = model.classifier[classifier_index]
        if isinstance(classifier, nn.Linear):
            model.classifier[classifier_index] = nn.Linear(classifier.in_features, num_classes)
        return model

    if norm_name == "efficientnet_b0":
        model = efficientnet_b0(weights=None)
        if pretrained and pretrained.is_file():
            ckpt = torch.load(pretrained, map_location="cpu", weights_only=False)
            state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
            state = {k.removeprefix("module."): v for k, v in state.items() if not k.startswith("classifier.")}
            model.load_state_dict(state, strict=False)
        classifier_index = 1
        classifier = model.classifier[classifier_index]
        if isinstance(classifier, nn.Linear):
            model.classifier[classifier_index] = nn.Linear(classifier.in_features, num_classes)
        return model

    if norm_name == "baseline_cnn":
        model = _build_baseline_cnn(num_classes)
        if pretrained and pretrained.is_file():
            ckpt = torch.load(pretrained, map_location="cpu", weights_only=False)
            state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
            state = {k.removeprefix("module."): v for k, v in state.items() if not k.startswith("14.")}
            model.load_state_dict(state, strict=False)
        return model

    if norm_name == "goldformer":
        return _build_goldformer(pretrained)

    raise ValueError(f"Unsupported model: {model_name} (normalized: {norm_name})")


class CheckpointUnavailableError(FileNotFoundError):
    """Raised when an architecture is defined but its trained pharmaceutical checkpoint is unavailable."""
    pass


def is_model_available(model_name: str) -> bool:
    """Return True if a verified fine-tuned pharmaceutical checkpoint exists for the model."""
    norm_name = normalize_model_name(model_name)
    reg = CHECKPOINT_REGISTRY.get(norm_name, {})
    ckpt = reg.get("checkpoint")
    return bool(ckpt and Path(ckpt).is_file())


def get_model_status(model_name: str) -> dict[str, Any]:
    """Return explicit availability status and path details for a given model.

    Distinguishes between:
    - 'Fine-tuned classifier available'
    - 'Architecture available, but fine-tuned pharmaceutical checkpoint unavailable'
    - 'Architecture supported, but neither fine-tuned checkpoint nor pretrained weights are available'
    """
    norm_name = normalize_model_name(model_name)
    if norm_name not in CHECKPOINT_REGISTRY:
        return {
            "model_name": norm_name,
            "architecture_supported": False,
            "finetuned_available": False,
            "pretrained_available": False,
            "status": f"Unsupported model: '{model_name}'",
        }

    reg = CHECKPOINT_REGISTRY[norm_name]
    ckpt_file = reg.get("checkpoint")
    has_ckpt = bool(ckpt_file and Path(ckpt_file).is_file())
    pre_file = reg.get("pretrained")
    has_pre = bool(pre_file and Path(pre_file).is_file())

    if has_ckpt:
        status_msg = "Fine-tuned classifier available"
    elif has_pre:
        status_msg = "Architecture available, but fine-tuned pharmaceutical checkpoint unavailable"
    else:
        status_msg = "Architecture supported, but neither fine-tuned checkpoint nor pretrained weights are available"

    return {
        "model_name": norm_name,
        "architecture_supported": True,
        "finetuned_available": has_ckpt,
        "pretrained_available": has_pre,
        "checkpoint_path": str(ckpt_file) if ckpt_file else None,
        "expected_checkpoint": str(reg.get("expected_checkpoint", "")),
        "pretrained_path": str(pre_file) if pre_file else None,
        "status": status_msg,
    }


def load_classifier(
    model_name: Optional[str] = None,
    checkpoint_path: Optional[Path | str] = None,
    pretrained_path: Optional[Path | str] = None,
    device: Optional[torch.device] = None,
    num_classes: int = 2,
) -> nn.Module:
    """Unified checkpoint loader that handles all formats, registries, and architectures.

    Raises CheckpointUnavailableError if the requested fine-tuned pharmaceutical
    checkpoint does not exist on disk, explicitly refusing to silently substitute
    generic ImageNet pretrained weights as pharmaceutical classifiers.
    """
    dev = device or torch.device("cpu")

    # 1. Resolve model name and paths from registry if not explicitly provided
    if model_name:
        norm_name = normalize_model_name(model_name)
    elif checkpoint_path:
        # Probe checkpoint dictionary
        probe = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
        if isinstance(probe, dict):
            raw_name = probe.get("model") or probe.get("metadata", {}).get("model_name")
            if raw_name:
                norm_name = normalize_model_name(raw_name)
            else:
                norm_name = "efficientnet_b0"
        else:
            norm_name = "efficientnet_b0"
    else:
        norm_name = "efficientnet_b0"

    reg = CHECKPOINT_REGISTRY.get(norm_name, {})
    ckpt_file = Path(checkpoint_path) if checkpoint_path else reg.get("checkpoint")
    pre_file = Path(pretrained_path) if pretrained_path else reg.get("pretrained")

    if not ckpt_file or not Path(ckpt_file).is_file():
        status_info = get_model_status(norm_name)
        expected = reg.get("expected_checkpoint", ckpt_file)
        if status_info.get("pretrained_available"):
            msg = (
                f"Model '{norm_name}': Architecture available, but fine-tuned pharmaceutical "
                f"checkpoint unavailable (expected: {expected}). Generic pretrained weights exist at "
                f"'{status_info['pretrained_path']}', but will NOT be silently loaded as a counterfeit "
                f"pharmaceutical classifier."
            )
        else:
            msg = (
                f"Model '{norm_name}': Fine-tuned pharmaceutical checkpoint unavailable "
                f"(expected: {expected})."
            )
        raise CheckpointUnavailableError(msg)

    # 2. Build model architecture
    model = build_model(norm_name, pretrained_path=pre_file, num_classes=num_classes)

    # 3. Load trained fine-tuned state
    checkpoint = torch.load(ckpt_file, map_location=dev, weights_only=False)
    state = checkpoint.get("model_state_dict", checkpoint.get("state_dict", checkpoint))
    state = {k.removeprefix("module."): v for k, v in state.items()}

    model.load_state_dict(state, strict=True)
    model.model_name = norm_name
    model.to(dev)
    model.eval()
    return model


def freeze_backbone(model: nn.Module) -> None:
    for parameter in model.parameters():
        parameter.requires_grad = False
    if hasattr(model, "classifier"):
        for parameter in model.classifier.parameters():
            parameter.requires_grad = True


def unfreeze_last_features(model: nn.Module, blocks: int = 2) -> None:
    if hasattr(model, "features"):
        feature_modules = list(model.features.children())
        for module in feature_modules[-blocks:]:
            for parameter in module.parameters():
                parameter.requires_grad = True