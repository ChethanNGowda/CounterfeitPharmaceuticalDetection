import pandas as pd
from pathlib import Path
from sklearn.model_selection import train_test_split

SEED = 42

ROOT = Path(r"data/pharmassist/Pharmassist Dataset")
METADATA = ROOT / "metadata.csv"
OUT = Path(r"data/pharmassist_splits")

OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(METADATA)

raw = df[df["Image_Type"].str.lower() == "raw"].copy()
aug = df[df["Image_Type"].str.lower() == "augmented"].copy()

classes = sorted(df["Class_Label"].unique())

print("Classes:", len(classes))
print("Raw:", len(raw))
print("Augmented:", len(aug))

# 70/15/15 split of RAW images
train_raw, temp_raw = train_test_split(
    raw,
    test_size=0.30,
    random_state=SEED,
    stratify=raw["Class_Label"]
)

valid_raw, test_raw = train_test_split(
    temp_raw,
    test_size=0.50,
    random_state=SEED,
    stratify=temp_raw["Class_Label"]
)

# Augmented images go ONLY into training.
train = pd.concat([train_raw, aug], ignore_index=True)

# Shuffle training manifest
train = train.sample(frac=1, random_state=SEED).reset_index(drop=True)
valid = valid_raw.sample(frac=1, random_state=SEED).reset_index(drop=True)
test = test_raw.sample(frac=1, random_state=SEED).reset_index(drop=True)

# Add absolute project-relative paths
for frame in [train, valid, test]:
    frame["path"] = frame["Filename"].apply(
        lambda x: str(Path("data/pharmassist/Pharmassist Dataset") / x)
    )

# Save
train.to_csv(OUT / "train.csv", index=False)
valid.to_csv(OUT / "validation.csv", index=False)
test.to_csv(OUT / "test.csv", index=False)

print("\n===== SPLIT RESULTS =====")
print("Train:", len(train))
print("Validation:", len(valid))
print("Test:", len(test))

print("\n===== TRAIN SOURCE =====")
print(train["Image_Type"].value_counts().to_string())

print("\n===== VALIDATION SOURCE =====")
print(valid["Image_Type"].value_counts().to_string())

print("\n===== TEST SOURCE =====")
print(test["Image_Type"].value_counts().to_string())

print("\n===== CLASS COUNTS =====")

counts = pd.DataFrame({
    "train": train["Class_Label"].value_counts(),
    "validation": valid["Class_Label"].value_counts(),
    "test": test["Class_Label"].value_counts()
}).fillna(0).astype(int)

print(counts.to_string())

print("\n===== CLASS COVERAGE =====")
print("Train classes:", train["Class_Label"].nunique())
print("Validation classes:", valid["Class_Label"].nunique())
print("Test classes:", test["Class_Label"].nunique())

# Assertions
assert train["Class_Label"].nunique() == 53
assert valid["Class_Label"].nunique() == 53
assert test["Class_Label"].nunique() == 53

assert set(valid["Image_Type"]) == {"Raw"}
assert set(test["Image_Type"]) == {"Raw"}

assert set(
    valid["Filename"]
).isdisjoint(set(train["Filename"]))

assert set(
    test["Filename"]
).isdisjoint(set(train["Filename"]))

assert set(
    valid["Filename"]
).isdisjoint(set(test["Filename"]))

print("\nALL SPLIT CHECKS PASSED.")
print("Saved to:", OUT)
