import json
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image
from torch.utils.data import Dataset, DataLoader
from torchvision import models, transforms
from sklearn.metrics import accuracy_score, precision_recall_fscore_support, confusion_matrix


ROOT = Path(".")
SPLIT_DIR = ROOT / "data" / "pharmassist_splits"
RUN_DIR = ROOT / "runs" / "pharmassist_mobilenet_v3_large"
OUTPUT_DIR = ROOT / "reports" / "pharmassist"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print(f"Device: {device}")

if device.type == "cuda":
    print(f"GPU: {torch.cuda.get_device_name(0)}")


# -----------------------------
# Classes
# -----------------------------

with open(
    RUN_DIR / "classes.json",
    "r",
    encoding="utf-8"
) as f:
    class_data = json.load(f)

classes = class_data["classes"]
class_to_idx = class_data["class_to_idx"]

idx_to_class = {
    int(v): k
    for k, v in class_to_idx.items()
}

NUM_CLASSES = len(classes)

print(f"Classes: {NUM_CLASSES}")


# -----------------------------
# Test dataset
# -----------------------------

test_df = pd.read_csv(
    SPLIT_DIR / "test.csv"
)


class TestDataset(Dataset):

    def __init__(self, dataframe):

        self.df = dataframe.reset_index(drop=True)

        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])

    def __len__(self):
        return len(self.df)

    def __getitem__(self, index):

        row = self.df.iloc[index]

        image_path = ROOT / str(row["path"])

        image = Image.open(
            image_path
        ).convert("RGB")

        image = self.transform(image)

        label = class_to_idx[
            row["Class_Label"]
        ]

        return image, label


dataset = TestDataset(test_df)

loader = DataLoader(
    dataset,
    batch_size=16,
    shuffle=False,
    num_workers=0,
    pin_memory=(device.type == "cuda")
)


# -----------------------------
# Build 53-class model
# -----------------------------

model = models.mobilenet_v3_large(
    weights=None
)

# IMPORTANT:
# Default MobileNetV3 has 1000 ImageNet classes.
# Our trained checkpoint has 53 medicine classes.

in_features = model.classifier[-1].in_features

model.classifier[-1] = torch.nn.Linear(
    in_features,
    NUM_CLASSES
)


# -----------------------------
# Load trained checkpoint
# -----------------------------

checkpoint = torch.load(
    RUN_DIR / "best.pt",
    map_location="cpu"
)

state_dict = checkpoint["state_dict"]

model.load_state_dict(
    state_dict
)

model = model.to(device)
model.eval()


print("Loaded 53-class checkpoint successfully.")
print(f"Test images: {len(test_df)}")


# -----------------------------
# Inference
# -----------------------------

all_labels = []
all_predictions = []
all_top5 = []
all_probabilities = []


with torch.no_grad():

    for images, labels in loader:

        images = images.to(
            device,
            non_blocking=True
        )

        outputs = model(images)

        probabilities = torch.softmax(
            outputs,
            dim=1
        )

        predictions = probabilities.argmax(
            dim=1
        )

        top5 = probabilities.topk(
            min(5, NUM_CLASSES),
            dim=1
        ).indices

        all_labels.extend(
            labels.numpy().tolist()
        )

        all_predictions.extend(
            predictions.cpu().numpy().tolist()
        )

        all_top5.extend(
            top5.cpu().numpy().tolist()
        )

        all_probabilities.extend(
            probabilities.cpu().numpy().tolist()
        )


y_true = np.array(all_labels)
y_pred = np.array(all_predictions)


# -----------------------------
# Metrics
# -----------------------------

top1_accuracy = accuracy_score(
    y_true,
    y_pred
)

top5_correct = sum(
    true_label in top5
    for true_label, top5
    in zip(y_true, all_top5)
)

top5_accuracy = (
    top5_correct / len(y_true)
)


precision, recall, f1, support = (
    precision_recall_fscore_support(
        y_true,
        y_pred,
        labels=list(range(NUM_CLASSES)),
        zero_division=0
    )
)


macro_precision = precision.mean()
macro_recall = recall.mean()
macro_f1 = f1.mean()


# -----------------------------
# Confusion matrix
# -----------------------------

cm = confusion_matrix(
    y_true,
    y_pred,
    labels=list(range(NUM_CLASSES))
)

cm_df = pd.DataFrame(
    cm,
    index=classes,
    columns=classes
)

cm_df.to_csv(
    OUTPUT_DIR / "confusion_matrix.csv"
)


# -----------------------------
# Per-class metrics
# -----------------------------

class_results = []

for i, class_name in enumerate(classes):

    class_results.append({
        "class": class_name,
        "precision": float(precision[i]),
        "recall": float(recall[i]),
        "f1": float(f1[i]),
        "support": int(support[i])
    })


class_results_df = pd.DataFrame(
    class_results
)

class_results_df.to_csv(
    OUTPUT_DIR / "per_class_metrics.csv",
    index=False
)


# -----------------------------
# Mistakes
# -----------------------------

mistakes = []

for i in range(len(y_true)):

    if y_true[i] == y_pred[i]:
        continue

    probabilities = np.array(
        all_probabilities[i]
    )

    top_indices = probabilities.argsort()[::-1][:5]

    mistakes.append({
        "filename": test_df.iloc[i]["Filename"],
        "actual": idx_to_class[int(y_true[i])],
        "predicted": idx_to_class[int(y_pred[i])],
        "confidence": float(
            probabilities[y_pred[i]]
        ),
        "top5": " | ".join(
            f"{idx_to_class[int(j)]}:{probabilities[j] * 100:.2f}%"
            for j in top_indices
        )
    })


mistakes_df = pd.DataFrame(
    mistakes
)

mistakes_df.to_csv(
    OUTPUT_DIR / "mistakes.csv",
    index=False
)


# -----------------------------
# Final JSON
# -----------------------------

results = {
    "model": "MobileNetV3-Large",
    "dataset": "Pharmassist",
    "classes": NUM_CLASSES,
    "test_images": len(test_df),
    "correct_predictions": int(
        len(test_df) - len(mistakes)
    ),
    "incorrect_predictions": int(
        len(mistakes)
    ),
    "top1_accuracy": float(
        top1_accuracy
    ),
    "top5_accuracy": float(
        top5_accuracy
    ),
    "macro_precision": float(
        macro_precision
    ),
    "macro_recall": float(
        macro_recall
    ),
    "macro_f1": float(
        macro_f1
    )
}


with open(
    OUTPUT_DIR / "test_metrics.json",
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        results,
        f,
        indent=2
    )


# -----------------------------
# Console output
# -----------------------------

print()
print("=" * 50)
print(" PHARMASSIST TEST EVALUATION")
print("=" * 50)

print()
print(f"Classes:                 {NUM_CLASSES}")
print(f"Test images:             {len(test_df)}")
print(
    f"Correct predictions:     "
    f"{len(test_df) - len(mistakes)}"
)
print(
    f"Incorrect predictions:   "
    f"{len(mistakes)}"
)

print()
print(
    f"Top-1 Accuracy:          "
    f"{top1_accuracy * 100:.2f}%"
)

print(
    f"Top-5 Accuracy:          "
    f"{top5_accuracy * 100:.2f}%"
)

print(
    f"Macro Precision:         "
    f"{macro_precision * 100:.2f}%"
)

print(
    f"Macro Recall:            "
    f"{macro_recall * 100:.2f}%"
)

print(
    f"Macro F1:                "
    f"{macro_f1 * 100:.2f}%"
)

print()
print("=" * 50)
print(" LOWEST F1 CLASSES")
print("=" * 50)

print(
    class_results_df
    .sort_values("f1")
    .head(10)
    .to_string(index=False)
)

print()
print("=" * 50)
print(" TEST ERRORS")
print("=" * 50)

if mistakes:

    for mistake in mistakes[:20]:

        print(
            f"{mistake['actual']} -> "
            f"{mistake['predicted']} "
            f"({mistake['confidence'] * 100:.2f}%)"
        )

else:

    print("No incorrect predictions.")

print()
print("Reports saved to:")
print(OUTPUT_DIR)
