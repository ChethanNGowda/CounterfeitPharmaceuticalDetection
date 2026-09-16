"""Torchvision model construction and checkpoint loading."""

from __future__ import annotations

from pathlib import Path

import torch
from torch import nn
from torchvision.models import efficientnet_b0, mobilenet_v3_large


def build_model(model_name: str, checkpoint_path: Path, num_classes: int = 2) -> nn.Module:
    if model_name == "mobilenet_v3_large":
        model = mobilenet_v3_large(weights=None)
        classifier_index = 3
    elif model_name == "efficientnet_b0":
        model = efficientnet_b0(weights=None)
        classifier_index = 1
    else:
        raise ValueError(f"Unsupported model: {model_name}")

    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
    state_dict = checkpoint.get("state_dict", checkpoint.get("model_state_dict", checkpoint))
    state_dict = {key.removeprefix("module."): value for key, value in state_dict.items()}
    model.load_state_dict(state_dict, strict=True)
    classifier = model.classifier[classifier_index]
    if not isinstance(classifier, nn.Linear):
        raise TypeError(f"Unexpected classifier in {model_name}: {type(classifier).__name__}")
    model.classifier[classifier_index] = nn.Linear(classifier.in_features, num_classes)
    return model


def freeze_backbone(model: nn.Module) -> None:
    for parameter in model.parameters():
        parameter.requires_grad = False
    for parameter in model.classifier.parameters():
        parameter.requires_grad = True


def unfreeze_last_features(model: nn.Module, blocks: int = 2) -> None:
    feature_modules = list(model.features.children())
    for module in feature_modules[-blocks:]:
        for parameter in module.parameters():
            parameter.requires_grad = True