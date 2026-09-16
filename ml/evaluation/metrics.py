"""Classification metrics used by training and evaluation."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_score, recall_score


def classification_metrics(targets: list[int], predictions: list[int], class_names: tuple[str, ...]) -> dict:
    labels = list(range(len(class_names)))
    matrix = confusion_matrix(targets, predictions, labels=labels)
    return {
        "accuracy": float(accuracy_score(targets, predictions)),
        "precision": float(precision_score(targets, predictions, labels=labels, average="macro", zero_division=0)),
        "recall": float(recall_score(targets, predictions, labels=labels, average="macro", zero_division=0)),
        "macro_f1": float(f1_score(targets, predictions, labels=labels, average="macro", zero_division=0)),
        "per_class_f1": {
            name: float(score)
            for name, score in zip(class_names, f1_score(targets, predictions, labels=labels, average=None, zero_division=0))
        },
        "confusion_matrix": matrix.tolist(),
    }


def save_metrics(metrics: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")