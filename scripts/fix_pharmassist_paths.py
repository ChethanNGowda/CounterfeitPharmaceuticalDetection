import pandas as pd
from pathlib import Path

ROOT = Path(".")
DATA_DIR = ROOT / "data" / "pharmassist"
SPLIT_DIR = ROOT / "data" / "pharmassist_splits"

print("Scanning Pharmassist images...")
files = list(DATA_DIR.rglob("*"))

image_map = {}
for f in files:
    if f.is_file() and f.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
        image_map[f.name] = f.as_posix()

print(f"Images found: {len(image_map)}")

for split_name in ["train", "validation", "test"]:
    csv_path = SPLIT_DIR / f"{split_name}.csv"
    df = pd.read_csv(csv_path)

    fixed = 0
    missing = []

    for i, row in df.iterrows():
        filename = str(row["Filename"])

        if filename in image_map:
            df.at[i, "path"] = image_map[filename]
            fixed += 1
        else:
            missing.append(filename)

    df.to_csv(csv_path, index=False)

    print(f"\n{split_name}:")
    print(f"  Rows:   {len(df)}")
    print(f"  Fixed:  {fixed}")
    print(f"  Missing: {len(missing)}")

    if missing:
        print("  First missing files:")
        for name in missing[:10]:
            print(f"    {name}")

print("\n===== FINAL PATH CHECK =====")

for split_name in ["train", "validation", "test"]:
    df = pd.read_csv(SPLIT_DIR / f"{split_name}.csv")
    missing = [
        p for p in df["path"]
        if not (ROOT / str(p)).exists()
    ]

    print(f"{split_name}: {len(missing)} missing")

print("\nDone.")
