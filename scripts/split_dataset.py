import pandas as pd
import numpy as np
from sklearn.model_selection import GroupShuffleSplit
from pathlib import Path
import sys

def split_dataset():
    input_path = Path("data/processed/features.csv")
    if not input_path.exists():
        print("Dataset features.csv not found. Please run build_dataset.py first.")
        sys.exit(0)
        
    df = pd.read_csv(input_path)
    if df.empty:
        print("Dataset is empty. Cannot perform split.")
        sys.exit(0)
        
    if df["label"].nunique() < 2:
        print("Dataset contains only one class. Splitting requires at least two classes.")
        sys.exit(0)

    if df["sample_id"].nunique() < 3:
        print("Insufficient samples to perform a reliable split.")
        sys.exit(0)
    
    # We use sample_id as a grouping factor to prevent leakage
    gss = GroupShuffleSplit(n_splits=1, train_size=0.7, random_state=42)
    
    try:
        train_idx, temp_idx = next(gss.split(df, groups=df["sample_id"]))
        train_df = df.iloc[train_idx]
        temp_df = df.iloc[temp_idx]
        
        val_idx, test_idx = next(gss.split(temp_df, groups=temp_df["sample_id"]))
        val_df = temp_df.iloc[val_idx]
        test_df = temp_df.iloc[test_idx]
        
        train_df.to_csv("data/splits/train.csv", index=False)
        val_df.to_csv("data/splits/val.csv", index=False)
        test_df.to_csv("data/splits/test.csv", index=False)
        
        print(f"Splits saved. Train: {len(train_df)}, Val: {len(val_df)}, Test: {len(test_df)}")
    except Exception as e:
        print(f"Error during splitting: {e}")
        sys.exit(1)

if __name__ == "__main__":
    split_dataset()
