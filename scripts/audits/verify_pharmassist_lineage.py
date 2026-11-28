import pandas as pd
from pathlib import Path
from collections import Counter

p = Path(r"data\pharmassist\Pharmassist Dataset\metadata.csv")
df = pd.read_csv(p)

# Remove Roboflow's .rf.<hash> suffix
df["Source_Name"] = (
    df["Filename"]
    .astype(str)
    .str.replace(r"\.rf\.[a-f0-9]+$", "", regex=True)
)

# Check source names that occur multiple times
groups = df.groupby(["Class_Label", "Source_Name"])

summary = groups.agg(
    Images=("Filename", "count"),
    Types=("Image_Type", lambda x: ",".join(sorted(set(x))))
).reset_index()

print("\n===== SOURCE GROUP ANALYSIS =====")
print("Unique source groups:", len(summary))
print("Total images:", len(df))

print("\nSource groups containing multiple images:")
multi = summary[summary["Images"] > 1]
print("Count:", len(multi))

print("\nLargest source groups:")
print(
    multi.sort_values("Images", ascending=False)
    .head(50)
    .to_string(index=False)
)

print("\n===== SOURCE GROUPS MIXING CLASSES =====")

cross_class = (
    df.groupby("Source_Name")["Class_Label"]
    .nunique()
)

mixed = cross_class[cross_class > 1]

print("Source names appearing in multiple classes:", len(mixed))

if len(mixed):
    print("\nExamples:")
    for source in mixed.index[:30]:
        print(
            "\nSOURCE:", source,
            "\n",
            df[df["Source_Name"] == source][
                ["Filename", "Class_Label", "Image_Type"]
            ].to_string(index=False)
        )

print("\n===== RAW + AUGMENTED GROUPS =====")

type_sets = (
    df.groupby(["Class_Label", "Source_Name"])["Image_Type"]
    .apply(lambda x: set(x))
)

both = type_sets[type_sets.apply(
    lambda x: "Raw" in x and "Augmented" in x
)]

print("Groups containing both Raw and Augmented:", len(both))

print("\n===== AUGMENTED-ONLY GROUPS =====")
aug_only = type_sets[type_sets.apply(
    lambda x: x == {"Augmented"}
)]
print("Count:", len(aug_only))

print("\n===== RAW-ONLY GROUPS =====")
raw_only = type_sets[type_sets.apply(
    lambda x: x == {"Raw"}
)]
print("Count:", len(raw_only))

print("\n===== GROUP SIZE DISTRIBUTION =====")
print(
    summary["Images"]
    .value_counts()
    .sort_index()
    .to_string()
)
