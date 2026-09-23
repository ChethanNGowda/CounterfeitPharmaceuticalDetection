"""Tests for CLI and inference pipeline."""

import csv
from pathlib import Path
import numpy as np
from PIL import Image
import pytest
import torch

from ml.inference.predict import predict
from test import format_single_image_output, run_batch_directory


def test_predict_single_image(tmp_path):
    img_path = tmp_path / "sample.jpg"
    arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
    arr[50:150, 50:150] = 255
    arr[100:120, 100:120] = 0
    Image.fromarray(arr).save(img_path)

    res = predict(img_path, model="efficientnet_b0", threshold=0.70, device=torch.device("cpu"))
    assert res["prediction"] in ("AUTHENTIC", "COUNTERFEIT")
    assert res["status"] in ("AUTHENTIC", "COUNTERFEIT", "NEEDS MANUAL REVIEW")
    assert 0.0 <= res["confidence"] <= 1.0

    output_str = format_single_image_output(res)
    assert "Image: sample.jpg" in output_str
    assert "Status:" in output_str


def test_run_batch_directory(tmp_path):
    img_dir = tmp_path / "images"
    img_dir.mkdir()
    for i in range(2):
        arr = np.random.randint(50, 200, (224, 224, 3), dtype=np.uint8)
        arr[50:150, 50:150] = 255
        Image.fromarray(arr).save(img_dir / f"img_{i}.jpg")

    out_csv = tmp_path / "batch.csv"
    results = run_batch_directory(img_dir, model_name="efficientnet_b0", threshold=0.70, device=torch.device("cpu"), output_csv=out_csv)

    assert len(results) == 2
    assert out_csv.is_file()
    with out_csv.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 2
