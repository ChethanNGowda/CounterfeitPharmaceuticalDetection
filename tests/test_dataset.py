import pytest
import pandas as pd
import numpy as np
import os
from pathlib import Path
from scripts.split_dataset import split_dataset

@pytest.fixture
def dummy_features(tmp_path):
    d = tmp_path / "data" / "processed"
    d.mkdir(parents=True)
    f = d / "features.csv"
    # Create synthetic dataset with groups (sample_id) to test splitting
    df = pd.DataFrame({
        "sample_id": [1, 1, 2, 2, 3, 3, 4, 4],
        "label": [0, 0, 1, 1, 0, 0, 1, 1],
        "image_path": ["a", "b", "c", "d", "e", "f", "g", "h"]
    })
    # Add 36 dummy feature columns
    for i in range(36):
        df[f"feature_{i}"] = np.random.rand(8)
    df.to_csv(f, index=False)
    return f

def test_split_files_exist(monkeypatch, dummy_features, tmp_path):
    # Monkeypatch paths
    monkeypatch.chdir(tmp_path)
    os.makedirs("data/splits", exist_ok=True)
    
    # Run split
    split_dataset()
    
    assert Path("data/splits/train.csv").exists()
    assert Path("data/splits/val.csv").exists()
    assert Path("data/splits/test.csv").exists()

def test_leakage_prevention(monkeypatch, dummy_features, tmp_path):
    monkeypatch.chdir(tmp_path)
    os.makedirs("data/splits", exist_ok=True)
    split_dataset()
    
    train = pd.read_csv("data/splits/train.csv")
    val = pd.read_csv("data/splits/val.csv")
    test = pd.read_csv("data/splits/test.csv")
    
    # Check that sample_ids in train are not in val or test
    train_ids = set(train["sample_id"].unique())
    val_ids = set(val["sample_id"].unique())
    test_ids = set(test["sample_id"].unique())
    
    assert train_ids.isdisjoint(val_ids)
    assert train_ids.isdisjoint(test_ids)
    assert val_ids.isdisjoint(test_ids)

def test_empty_features(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    # create empty feature file
    d = tmp_path / "data" / "processed"
    d.mkdir(parents=True)
    pd.DataFrame().to_csv(d / "features.csv")
    
    with pytest.raises(SystemExit):
        split_dataset()
