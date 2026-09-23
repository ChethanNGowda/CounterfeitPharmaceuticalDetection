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

# Dataset paths
FULL_TRAINING_DIR = DATA_DIR / "full_training"
TRAIN_MANIFEST = FULL_TRAINING_DIR / "train.csv"
VAL_MANIFEST = FULL_TRAINING_DIR / "validation.csv"
TEST_MANIFEST = FULL_TRAINING_DIR / "test.csv"

# Classification Contract
CLASS_NAMES = ["authentic", "counterfeit"]
CLASS_TO_INDEX = {name: index for index, name in enumerate(CLASS_NAMES)}
NUM_CLASSES = len(CLASS_NAMES)

# Preprocessing & Normalization
IMAGE_SIZE = 224
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

# Decision Threshold
DEFAULT_CONFIDENCE_THRESHOLD = 0.70

# Default Checkpoint Registry
CHECKPOINT_REGISTRY = {
    "efficientnet_b0": {
        "checkpoint": OUTPUTS_DIR / "full_data_training" / "checkpoints" / "20260922_183414_efficientnet_b0" / "best.pt",
        "pretrained": MODELS_DIR / "efficientnet_b0.pth",
        "architecture": "efficientnet_b0",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
    },
    "mobilenet_v3_large": {
        "checkpoint": OUTPUTS_DIR / "full_data_training" / "checkpoints" / "20260922_184205_mobilenet_v3_large" / "best.pt",
        "pretrained": MODELS_DIR / "mobilenet_v3_large.pth",
        "architecture": "mobilenet_v3_large",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
    },
    "baseline_cnn": {
        "checkpoint": OUTPUTS_DIR / "full_data_training" / "checkpoints" / "20260922_182858_baseline_cnn" / "best.pt",
        "pretrained": OUTPUTS_DIR / "full_data_training" / "pretraining" / "baseline_cnn.pt",
        "architecture": "baseline_cnn",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
    },
    "goldformer": {
        "checkpoint": OUTPUTS_DIR / "external_pretrained" / "goldformer" / "checkpoint" / "goldformer_pharmaceutical_best.pt",
        "pretrained": PROJECT_ROOT / "external_models" / "GoldNet" / "weights" / "GoldFormer_best.pth",
        "architecture": "goldformer",
        "input_size": (IMAGE_SIZE, IMAGE_SIZE),
    },
}

SUPPORTED_MODELS = list(CHECKPOINT_REGISTRY.keys())
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
