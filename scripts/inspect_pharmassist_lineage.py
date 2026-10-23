import pandas as pd
from pathlib import Path

p = Path(r"data\pharmassist\Pharmassist Dataset\metadata.csv")
df = pd.read_csv(p)

print("\n===== OBJECT ID ANALYSIS =====")
print("Unique Object_ID:", df["Object_ID"].nunique())
print("Total rows:", len(df))

print("\n===== OBJECT_ID DUPLICATES =====")
dupes = df[df["Object_ID"].duplicated(keep=False)].sort_values("Object_ID")

if len(dupes):
    print(dupes[
        ["Object_ID", "Filename", "Class_Label", "Image_Type",
         "Environment", "Lighting", "Preprocessing"]
    ].head(100).to_string(index=False))
else:
    print("No duplicate Object_ID values.")

print("\n===== PREPROCESSING VALUES =====")
print(df["Preprocessing"].value_counts(dropna=False).to_string())

print("\n===== ENVIRONMENT VALUES =====")
print(df["Environment"].value_counts(dropna=False).to_string())

print("\n===== LIGHTING VALUES =====")
print(df["Lighting"].value_counts(dropna=False).to_string())

print("\n===== RAW/AUGMENTED OBJECT ID OVERLAP =====")

raw_ids = set(
    df.loc[df["Image_Type"].str.lower() == "raw", "Object_ID"]
)

aug_ids = set(
    df.loc[df["Image_Type"].str.lower() == "augmented", "Object_ID"]
)

print("Raw Object_IDs:", len(raw_ids))
print("Augmented Object_IDs:", len(aug_ids))
print("Overlap:", len(raw_ids & aug_ids))

print("\n===== SAMPLE AUGMENTED ROWS =====")
print(
    df[df["Image_Type"].str.lower() == "augmented"]
    [["Object_ID", "Filename", "Class_Label", "Environment",
      "Lighting", "Preprocessing"]]
    .head(50)
    .to_string(index=False)
)

print("\n===== OBJECT_ID TYPE COUNTS =====")
object_types = (
    df.groupby("Object_ID")["Image_Type"]
      .apply(lambda x: ",".join(sorted(set(x))))
)

print(object_types.value_counts().to_string())
