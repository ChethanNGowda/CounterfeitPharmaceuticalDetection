"""Centralized configuration for counterfeit pharmaceutical detection pipeline."""

from __future__ import annotations

import os
from pathlib import Path
import torch

# Base directories
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
MODELS_DIR = PROJECT_ROOT / "models"
OUTPUTS_DIR = PROJECT_ROOT / "outputs"
REPORTS_DIR = PROJECT_ROOT / "reports"
TEST_IMAGES_DIR = PROJECT_ROOT / "test_images"

# Dataset paths (actual working manifests under data/splits/)
SPLITS_DIR = DATA_DIR / "splits"
TRAIN_MANIFEST = SPLITS_DIR / "train.csv"
VAL_MANIFEST = SPLITS_DIR / "validation.csv"
TEST_MANIFEST = SPLITS_DIR / "test.csv"
TEST_CLEAN_MANIFEST = SPLITS_DIR / "test_clean.csv"
FULL_TRAINING_DIR = SPLITS_DIR  # Backward-compatibility alias

# Classification Contract
CLASS_NAMES = ["authentic", "counterfeit"]
CLASS_TO_INDEX = {name: index for index, name in enumerate(CLASS_NAMES)}
NUM_CLASSES = len(CLASS_NAMES)

# Preprocessing & Normalization
IMAGE_SIZE = 224
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

# Decision Thresholds
DEFAULT_CONFIDENCE_THRESHOLD = 0.70
DEFAULT_HIGH_CONFIDENCE_THRESHOLD = 0.90

# Checkpoint Registry
# Accurately reflects existing fine-tuned weights on disk.
# Generic ImageNet pretrained weights are NEVER claimed as trained pharmaceutical classifiers.
_EFF_CHECKPOINT = OUTPUTS_DIR / "full_data_training" / "checkpoints" / "20260922_183414_efficientnet_b0" / "best.pt"
_MOB_CHECKPOINT = OUTPUTS_DIR / "full_data_training" / "checkpoints" / "20260922_184205_mobilenet_v3_large" / "best.pt"
_BASE_CHECKPOINT = OUTPUTS_DIR / "full_data_training" / "checkpoints" / "20260922_182858_baseline_cnn" / "best.pt"
_GOLD_CHECKPOINT = OUTPUTS_DIR / "external_pretrained" / "goldformer" / "checkpoint" / "goldformer_pharmaceutical_best.pt"

CHECKPOINT_REGISTRY = {
    "efficientnet_b0": {
        "checkpoint": _EFF_CHECKPOINT if _EFF_CHECKPOINT.is_file() else None,
        "expected_checkpoint": _EFF_CHECKPOINT,
        "pretrained": MODELS_DIR / "efficientnet_b0.pth",
        "architecture": "efficientnet_b0",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
        "finetuned_available": _EFF_CHECKPOINT.is_file(),
        "pretrained_available": (MODELS_DIR / "efficientnet_b0.pth").is_file(),
        "description": "Fine-tuned EfficientNet-B0 pharmaceutical classifier (Active/Primary)",
    },
    "mobilenet_v3_large": {
        "checkpoint": _MOB_CHECKPOINT if _MOB_CHECKPOINT.is_file() else None,
        "expected_checkpoint": _MOB_CHECKPOINT,
        "pretrained": MODELS_DIR / "mobilenet_v3_large.pth",
        "architecture": "mobilenet_v3_large",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
        "finetuned_available": _MOB_CHECKPOINT.is_file(),
        "pretrained_available": (MODELS_DIR / "mobilenet_v3_large.pth").is_file(),
        "description": "MobileNetV3-Large (Backbone weights present; fine-tuned pharmaceutical checkpoint unavailable)",
    },
    "baseline_cnn": {
        "checkpoint": _BASE_CHECKPOINT if _BASE_CHECKPOINT.is_file() else None,
        "expected_checkpoint": _BASE_CHECKPOINT,
        "pretrained": OUTPUTS_DIR / "full_data_training" / "pretraining" / "baseline_cnn.pt",
        "architecture": "baseline_cnn",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
        "finetuned_available": _BASE_CHECKPOINT.is_file(),
        "pretrained_available": (OUTPUTS_DIR / "full_data_training" / "pretraining" / "baseline_cnn.pt").is_file(),
        "description": "Baseline 3-layer CNN (Fine-tuned pharmaceutical checkpoint unavailable)",
    },
    "goldformer": {
        "checkpoint": _GOLD_CHECKPOINT if _GOLD_CHECKPOINT.is_file() else None,
        "expected_checkpoint": _GOLD_CHECKPOINT,
        "pretrained": PROJECT_ROOT / "external_models" / "GoldNet" / "weights" / "GoldFormer_best.pth",
        "architecture": "goldformer",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
        "finetuned_available": _GOLD_CHECKPOINT.is_file(),
        "pretrained_available": (PROJECT_ROOT / "external_models" / "GoldNet" / "weights" / "GoldFormer_best.pth").is_file(),
        "description": "GoldFormer (Gold-domain weights present; fine-tuned pharmaceutical checkpoint unavailable)",
    },
}

SUPPORTED_MODELS = list(CHECKPOINT_REGISTRY.keys())
AVAILABLE_MODELS = [name for name, cfg in CHECKPOINT_REGISTRY.items() if cfg["finetuned_available"]]
DEFAULT_MODEL = "efficientnet_b0"

# Image Quality Check Thresholds
QUALITY_CONFIG = {
    "min_width": 64,
    "min_height": 64,
    "min_laplacian_var": 50.0,      # Images with variance below this are considered excessively blurry
    "min_brightness_mean": 15.0,    # Images darker than this are underexposed
    "max_brightness_mean": 245.0,   # Images brighter than this are overexposed
}

def get_device(force_cpu: bool = False) -> torch.device:
    """Return torch.device with CUDA auto-detection and CPU fallback."""
    if not force_cpu and torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")
