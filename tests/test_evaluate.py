import csv

import pytest

from ml.evaluation.evaluate import evaluate
from ml.evaluation.evaluate import load_test_manifest


def test_explicit_test_manifest_is_loaded(tmp_path):
    manifest = tmp_path / "test_clean.csv"
    with manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "label", "group_id"])
        writer.writeheader()
        writer.writerow({"image_path": "test/authentic/image.jpg", "label": "authentic", "group_id": "test:image"})

    rows = load_test_manifest(tmp_path / "unused", str(manifest))

    assert rows == [{
        "image_path": "test/authentic/image.jpg",
        "label": "authentic",
        "group_id": "test:image",
    }]


def test_evaluate_accepts_legacy_checkpoint_shape(tmp_path, monkeypatch):
    class FakeModel:
        def to(self, device):
            return self

        def load_state_dict(self, state_dict):
            assert state_dict == {"weights": 1}

        def eval(self):
            return self

    monkeypatch.setattr("ml.evaluation.evaluate.build_model", lambda *args: FakeModel())
    monkeypatch.setattr(
        "ml.evaluation.evaluate.PharmaceuticalImageDataset",
        lambda *args: [],
    )
    checkpoint = tmp_path / "checkpoint.pt"
    import torch

    torch.save({"model": "efficientnet_b0", "state_dict": {"weights": 1}}, checkpoint)
    args = type(
        "Args",
        (),
        {
            "checkpoint": str(checkpoint),
            "pretrained_checkpoint": str(tmp_path / "pretrained.pt"),
            "cpu": True,
            "split_dir": str(tmp_path),
            "test_manifest": None,
            "raw_dir": str(tmp_path),
            "batch_size": 1,
            "output": None,
        },
    )()
    monkeypatch.setattr(
        "ml.evaluation.evaluate.load_test_manifest",
        lambda *args: [],
    )
    with pytest.raises(ValueError, match="empty"):
        evaluate(args)