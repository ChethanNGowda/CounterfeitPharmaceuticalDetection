import pandas as pd
from pathlib import Path

root = Path(r"data\pharmassist\Pharmassist Dataset")
metadata = root / "metadata.csv"

df = pd.read_csv(metadata)

# Find every image file recursively
image_files = {
    p.name.lower(): p
    for p in root.rglob("*")
    if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
}

df["exists"] = df["Filename"].astype(str).str.lower().isin(image_files)

print("\n===== FILE VERIFICATION =====")
print("Metadata rows:", len(df))
print("Image files found:", len(image_files))
print("Referenced files found:", int(df["exists"].sum()))
print("Missing files:", int((~df["exists"]).sum()))

print("\n===== RAW FILE VERIFICATION =====")
raw = df[df["Image_Type"].str.lower() == "raw"]
print("Raw metadata rows:", len(raw))
print("Raw files found:", int(raw["exists"].sum()))
print("Raw missing:", int((~raw["exists"]).sum()))

print("\n===== AUGMENTED FILE VERIFICATION =====")
aug = df[df["Image_Type"].str.lower() == "augmented"]
print("Augmented metadata rows:", len(aug))
print("Augmented files found:", int(aug["exists"].sum()))
print("Augmented missing:", int((~aug["exists"]).sum()))

if (~df["exists"]).any():
    print("\n===== MISSING FILES =====")
    print(
        df.loc[~df["exists"],
               ["Object_ID", "Filename", "Class_Label", "Image_Type"]]
        .to_string(index=False)
    )

print("\n===== RAW CLASS COUNTS =====")
print(
    raw.groupby("Class_Label")
       .size()
       .sort_values()
       .to_string()
)
