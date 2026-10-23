import os
import pandas as pd
from sklearn.model_selection import GroupShuffleSplit

INPUT = "data/c3pi_reference/metadata.csv"
OUTPUT = "data/c3pi_reference/splits"

df = pd.read_csv(INPUT)

# Create a safe grouping key.
# Use medicine name when available; otherwise fall back to NDC11.
df["group"] = df["name"].fillna("").astype(str).str.strip()

missing_name = df["group"] == ""
df.loc[missing_name, "group"] = (
    "NDC_" + df.loc[missing_name, "ndc11"].astype(str)
)

print("Total images:", len(df))
print("Unique groups:", df["group"].nunique())
print("Missing medicine names:", missing_name.sum())

# 70% train / 30% temporary
split1 = GroupShuffleSplit(
    n_splits=1,
    test_size=0.30,
    random_state=42
)

train_idx, temp_idx = next(
    split1.split(df, groups=df["group"])
)

train = df.iloc[train_idx].copy()
temp = df.iloc[temp_idx].copy()

# Split temporary 50/50 -> 15% validation / 15% test
split2 = GroupShuffleSplit(
    n_splits=1,
    test_size=0.50,
    random_state=42
)

val_idx, test_idx = next(
    split2.split(temp, groups=temp["group"])
)

val = temp.iloc[val_idx].copy()
test = temp.iloc[test_idx].copy()

# Remove internal grouping column
train = train.drop(columns=["group"])
val = val.drop(columns=["group"])
test = test.drop(columns=["group"])

# Create directories
for folder in ["train", "val", "test"]:
    os.makedirs(os.path.join(OUTPUT, folder), exist_ok=True)

# Save CSVs
train.to_csv(os.path.join(OUTPUT, "train.csv"), index=False)
val.to_csv(os.path.join(OUTPUT, "val.csv"), index=False)
test.to_csv(os.path.join(OUTPUT, "test.csv"), index=False)

# Verification
train_groups = set(
    df.iloc[train_idx]["group"]
)
val_groups = set(
    df.iloc[temp_idx].iloc[val_idx]["group"]
)
test_groups = set(
    df.iloc[temp_idx].iloc[test_idx]["group"]
)

print()
print("========== SPLIT ==========")
print(f"TRAIN: {len(train)} images")
print(f"VAL:   {len(val)} images")
print(f"TEST:  {len(test)} images")
print(f"TOTAL: {len(train) + len(val) + len(test)} images")

print()
print("Unique groups:")
print("TRAIN:", len(train_groups))
print("VAL:  ", len(val_groups))
print("TEST: ", len(test_groups))

print()
print("========== OVERLAP CHECK ==========")
print("Train/Val:", len(train_groups & val_groups))
print("Train/Test:", len(train_groups & test_groups))
print("Val/Test:", len(val_groups & test_groups))

print()
if (
    len(train) + len(val) + len(test) == len(df)
    and len(train_groups & val_groups) == 0
    and len(train_groups & test_groups) == 0
    and len(val_groups & test_groups) == 0
):
    print("PASS: Split is valid.")
else:
    print("ERROR: Split verification failed.")
