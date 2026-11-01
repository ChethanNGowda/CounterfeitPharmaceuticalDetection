import csv
import hashlib
from pathlib import Path

import pytest

from ml.evaluation.metrics import classification_metrics
from ml.training.data import create_splits


def _hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_current_binary_manifests_have_expected_classes_and_no_clean_test_hash_overlap():
    root = Path("data/processed")
    rows_by_split = {}
    for split in ("train", "validation", "test", "test_clean"):
        with Path("data/splits", f"{split}.csv").open(newline="", encoding="utf-8") as handle:
            rows_by_split[split] = list(csv.DictReader(handle))
        assert {row["label"] for row in rows_by_split[split]} == {"authentic", "counterfeit"}
        assert all((root / row["image_path"]).is_file() for row in rows_by_split[split])

    clean_hashes = {_hash(root / row["image_path"]) for row in rows_by_split["test_clean"]}
    train_hashes = {_hash(root / row["image_path"]) for row in rows_by_split["train"]}
    validation_hashes = {_hash(root / row["image_path"]) for row in rows_by_split["validation"]}
    assert not clean_hashes & train_hashes
    assert not clean_hashes & validation_hashes


def test_grouped_split_creation_is_deterministic_and_group_disjoint():
    records = [
        {"image_path": f"{label}/{index}.jpg", "label": label, "group_id": f"group-{index}"}
        for index, label in enumerate(["authentic", "counterfeit"] * 10)
    ]
    first = create_splits(records, seed=7)
    second = create_splits(records, seed=7)
    assert first == second
    groups = {name: {row["group_id"] for row in rows} for name, rows in first.items()}
    assert not groups["train"] & groups["validation"]
    assert not groups["train"] & groups["test"]
    assert not groups["validation"] & groups["test"]


def test_grouped_split_rejects_missing_class():
    records = [
        {"image_path": f"{index}.jpg", "label": "authentic", "group_id": str(index)}
        for index in range(6)
    ]
    with pytest.raises(ValueError, match="Both authentic and counterfeit"):
        create_splits(records)


def test_metrics_include_auc_only_when_binary_scores_support_them():
    result = classification_metrics(
        [0, 0, 1, 1],
        [0, 1, 1, 1],
        ("authentic", "counterfeit"),
        probabilities=[0.1, 0.6, 0.7, 0.9],
    )
    assert "roc_auc" in result
    assert "pr_auc" in result
    assert result["confusion_matrix"] == [[1, 1], [0, 2]]

    single_class = classification_metrics(
        [0, 0],
        [0, 1],
        ("authentic", "counterfeit"),
        probabilities=[0.1, 0.6],
    )
    assert "roc_auc" not in single_class
    assert "pr_auc" not in single_class


def test_metrics_reject_length_mismatch_and_empty_inputs():
    with pytest.raises(ValueError, match="same length"):
        classification_metrics([0], [], ("authentic", "counterfeit"))
    with pytest.raises(ValueError, match="empty"):
        classification_metrics([], [], ("authentic", "counterfeit"))
