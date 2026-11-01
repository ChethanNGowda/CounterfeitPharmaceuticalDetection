"""Classification metrics used by training and evaluation."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)


def classification_metrics(
    targets: list[int],
    predictions: list[int],
    class_names: tuple[str, ...],
    probabilities: list[float] | None = None,
) -> dict:
    if len(targets) != len(predictions):
        raise ValueError("Targets and predictions must have the same length.")
    if not targets:
        raise ValueError("Cannot calculate metrics for an empty evaluation set.")
    if probabilities is not None and len(probabilities) != len(targets):
        raise ValueError("Probabilities and targets must have the same length.")
    labels = list(range(len(class_names)))
    matrix = confusion_matrix(targets, predictions, labels=labels)
    result = {
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
    observed_classes = set(targets)
    if probabilities is not None and len(observed_classes) == 2 and len(class_names) == 2:
        result["roc_auc"] = float(roc_auc_score(targets, probabilities))
        result["pr_auc"] = float(average_precision_score(targets, probabilities))
    return result


def save_metrics(metrics: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")