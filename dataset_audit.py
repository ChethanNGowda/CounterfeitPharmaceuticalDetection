import os
import glob
import pandas as pd

BASE = "data"
IMG_EXT = {".jpg", ".jpeg", ".png", ".webp"}

def files_in(path):
    return [
        f for f in glob.glob(os.path.join(path, "**", "*"), recursive=True)
        if os.path.isfile(f)
    ]

def images_in(path):
    return [
        f for f in files_in(path)
        if os.path.splitext(f)[1].lower() in IMG_EXT
    ]

print("=" * 70)
print("COUNTERFEIT PHARMACEUTICAL DETECTION - DATASET AUDIT")
print("=" * 70)

# ------------------------------------------------------------------
# DIRECTORIES
# ------------------------------------------------------------------
print("\n[1] DATA DIRECTORIES\n")

dirs = sorted(
    d for d in os.listdir(BASE)
    if os.path.isdir(os.path.join(BASE, d))
)

for d in dirs:
    path = os.path.join(BASE, d)
    all_files = files_in(path)
    imgs = images_in(path)
    print(f"{d}")
    print(f"  Files : {len(all_files):,}")
    print(f"  Images: {len(imgs):,}")

# ------------------------------------------------------------------
# CSV FILES
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[2] CSV FILES")
print("=" * 70)

csvs = sorted(glob.glob(os.path.join(BASE, "**", "*.csv"), recursive=True))

for path in csvs:
    rel = os.path.relpath(path, BASE)

    try:
        df = pd.read_csv(path, low_memory=False)

        print(f"\n{rel}")
        print(f"  Rows    : {len(df):,}")
        print(f"  Columns : {len(df.columns)}")
        print(f"  Fields  : {df.columns.tolist()}")

        # Detect likely class/label fields
        possible = [
            c for c in df.columns
            if any(
                word in str(c).lower()
                for word in [
                    "label",
                    "class",
                    "counterfeit",
                    "authentic",
                    "fake",
                    "genuine",
                    "target"
                ]
            )
        ]

        if possible:
            print("  Possible label fields:")
            for col in possible:
                print(f"    {col}")
                print(df[col].value_counts(dropna=False).head(20).to_string())
        else:
            print("  Possible label fields: NONE")

    except Exception as e:
        print(f"\n{rel}")
        print(f"  ERROR reading CSV: {e}")

# ------------------------------------------------------------------
# COUNTERFEIT
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[3] COUNTERFEIT DATA")
print("=" * 70)

counterfeit_dir = os.path.join(BASE, "counterfeit")

if os.path.isdir(counterfeit_dir):
    counterfeit_imgs = images_in(counterfeit_dir)

    print(f"Counterfeit folder images: {len(counterfeit_imgs):,}")

    if counterfeit_imgs:
        print("\nFirst 20 files:")
        for f in counterfeit_imgs[:20]:
            print(" ", os.path.relpath(f, counterfeit_dir))

        print("\nSubfolders:")
        for item in sorted(os.listdir(counterfeit_dir)):
            p = os.path.join(counterfeit_dir, item)
            if os.path.isdir(p):
                print(
                    f"  {item}: {len(images_in(p)):,} images"
                )
else:
    print("Counterfeit folder does not exist.")

# ------------------------------------------------------------------
# PHARMASSIST
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[4] PHARMASSIST DATA")
print("=" * 70)

pharmassist_dir = os.path.join(BASE, "pharmassist")

if os.path.isdir(pharmassist_dir):
    pharmassist_imgs = images_in(pharmassist_dir)
    print(f"PharmAssist images: {len(pharmassist_imgs):,}")

    print("\nSubfolders:")
    for item in sorted(os.listdir(pharmassist_dir)):
        p = os.path.join(pharmassist_dir, item)
        if os.path.isdir(p):
            print(
                f"  {item}: {len(images_in(p)):,} images"
            )
else:
    print("PharmAssist folder does not exist.")

# ------------------------------------------------------------------
# C3PI REFERENCE
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[5] C3PI REFERENCE DATA")
print("=" * 70)

ref_images = os.path.join(BASE, "c3pi_reference", "images")
ref_splits = os.path.join(BASE, "c3pi_reference", "splits")

print(f"Reference images: {len(images_in(ref_images)):,}")

for split in ["train", "val", "test"]:
    path = os.path.join(ref_splits, f"{split}.csv")

    if os.path.isfile(path):
        df = pd.read_csv(path, low_memory=False)
        print(f"{split:5}: {len(df):,} rows")
    else:
        print(f"{split:5}: MISSING")

# ------------------------------------------------------------------
# RAW C3PI
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[6] RAW C3PI")
print("=" * 70)

c3pi_dir = os.path.join(BASE, "c3pi")

if os.path.isdir(c3pi_dir):
    print(f"Total C3PI images/files: {len(images_in(c3pi_dir)):,}")
else:
    print("C3PI folder missing.")

# ------------------------------------------------------------------
# TOTAL PROJECT IMAGE COUNT
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[7] TOTAL IMAGE COUNTS")
print("=" * 70)

all_project_images = images_in(BASE)

print(f"All images under data/: {len(all_project_images):,}")

# ------------------------------------------------------------------
# CURRENT TRAINING DATA STATUS
# ------------------------------------------------------------------
print("\n" + "=" * 70)
print("[8] CURRENT TRAINING STATUS")
print("=" * 70)

print("C3PI RXNAV reference images : 4,392 expected")
print("C3PI split                  : 3,109 train / 654 val / 629 test")
print("Binary counterfeit labels   : must be verified from actual data")
print("")

print("=" * 70)
print("AUDIT COMPLETE")
print("=" * 70)
