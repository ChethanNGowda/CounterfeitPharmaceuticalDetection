import os
import re
import json
import pandas as pd
from pathlib import Path
from collections import Counter

ROOT = Path("data/pharmassist/Pharmassist Dataset")
METADATA = ROOT / "metadata.csv"
OUTPUT = Path("reports/pharmassist_audit.json")

df = pd.read_csv(METADATA)

print("Rows:", len(df))
print("Classes:", df["Class_Label"].nunique())
print("Image types:")
print(df["Image_Type"].value_counts().to_string())

print("\nColumns:")
print(df.columns.tolist())

print("\nSample filenames:")
for x in df["Filename"].head(30):
    print(x)

# Analyze filename patterns
def normalize_name(name):
    name = str(name)
    stem = Path(name).stem

    # Remove common augmentation suffixes
    patterns = [
        r'[_-]aug(?:mented)?[_-]?\d*$',
        r'[_-]augmentation[_-]?\d*$',
        r'[_-]\d+$',
        r'\(\d+\)$',
    ]

    base = stem
    for pattern in patterns:
        base = re.sub(pattern, '', base, flags=re.IGNORECASE)

    return base.lower()

df["possible_group"] = df["Filename"].apply(normalize_name)

group_sizes = df.groupby(["Class_Label", "possible_group"]).size()

print("\nLargest possible source groups:")
print(group_sizes.sort_values(ascending=False).head(30).to_string())

print("\nRaw images by class:")
print(
    df[df["Image_Type"].str.lower() == "raw"]
    .groupby("Class_Label")
    .size()
    .sort_values()
    .to_string()
)

audit = {
    "rows": int(len(df)),
    "classes": int(df["Class_Label"].nunique()),
    "image_types": {
        str(k): int(v)
        for k, v in df["Image_Type"].value_counts().items()
    },
    "columns": df.columns.tolist(),
    "possible_groups": int(df["possible_group"].nunique()),
    "largest_possible_groups": [
        {
            "class": str(idx[0]),
            "group": str(idx[1]),
            "count": int(value)
        }
        for idx, value in group_sizes.sort_values(ascending=False).head(50).items()
    ]
}

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(audit, indent=2), encoding="utf-8")

print("\nAudit saved to:", OUTPUT)
