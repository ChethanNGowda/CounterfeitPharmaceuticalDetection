import json
import random
from pathlib import Path

import pandas as pd
import torch
from PIL import Image
from torch import nn
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from torchvision import models, transforms

SEED = 42
random.seed(SEED)
torch.manual_seed(SEED)

ROOT = Path(__file__).resolve().parents[2]
SPLIT_DIR = ROOT / "data" / "pharmassist_splits"
PRETRAINED = ROOT / "external_models" / "PharmaAssist" / "weights" / "pretrained" / "mobilenet_v3_large.pth"
RUN_DIR = ROOT / "external_models" / "PharmaAssist" / "training_runs" / "pharmassist_mobilenet_v3_large"
RUN_DIR.mkdir(parents=True, exist_ok=True)

BATCH_SIZE = 16
EPOCHS = 25
LR = 1e-4
NUM_WORKERS = 0
IMAGE_SIZE = 224

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device: {device}")

if device.type == "cuda":
    print(f"GPU: {torch.cuda.get_device_name(0)}")

train_df = pd.read_csv(SPLIT_DIR / "train.csv")
val_df = pd.read_csv(SPLIT_DIR / "validation.csv")
test_df = pd.read_csv(SPLIT_DIR / "test.csv")

classes = sorted(train_df["Class_Label"].unique())
class_to_idx = {name: i for i, name in enumerate(classes)}

print(f"Classes: {len(classes)}")
print(f"Train: {len(train_df)}")
print(f"Validation: {len(val_df)}")
print(f"Test: {len(test_df)}")

with open(RUN_DIR / "classes.json", "w", encoding="utf-8") as f:
    json.dump(
        {
            "classes": classes,
            "class_to_idx": class_to_idx
        },
        f,
        indent=2,
        ensure_ascii=False
    )


class PharmassistDataset(Dataset):
    def __init__(self, dataframe, transform):
        self.df = dataframe.reset_index(drop=True)
        self.transform = transform

    def __len__(self):
        return len(self.df)

    def __getitem__(self, index):
        row = self.df.iloc[index]

        image_path = ROOT / row["path"]
        image = Image.open(image_path).convert("RGB")
        image = self.transform(image)

        label = class_to_idx[row["Class_Label"]]

        return image, label


train_transform = transforms.Compose([
    transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.RandomRotation(10),
    transforms.ColorJitter(
        brightness=0.15,
        contrast=0.15,
        saturation=0.10,
        hue=0.02
    ),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])

eval_transform = transforms.Compose([
    transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])

train_dataset = PharmassistDataset(train_df, train_transform)
val_dataset = PharmassistDataset(val_df, eval_transform)
test_dataset = PharmassistDataset(test_df, eval_transform)

# Weighted sampling helps classes with fewer training images.
counts = train_df["Class_Label"].value_counts()
weights = train_df["Class_Label"].map(
    lambda x: 1.0 / counts[x]
).values

sampler = WeightedRandomSampler(
    weights=torch.as_tensor(weights, dtype=torch.double),
    num_samples=len(weights),
    replacement=True
)

train_loader = DataLoader(
    train_dataset,
    batch_size=BATCH_SIZE,
    sampler=sampler,
    num_workers=NUM_WORKERS,
    pin_memory=(device.type == "cuda")
)

val_loader = DataLoader(
    val_dataset,
    batch_size=BATCH_SIZE,
    shuffle=False,
    num_workers=NUM_WORKERS,
    pin_memory=(device.type == "cuda")
)

test_loader = DataLoader(
    test_dataset,
    batch_size=BATCH_SIZE,
    shuffle=False,
    num_workers=NUM_WORKERS,
    pin_memory=(device.type == "cuda")
)


def build_model():
    model = models.mobilenet_v3_large(weights=None)

    checkpoint = torch.load(
        PRETRAINED,
        map_location="cpu"
    )

    if isinstance(checkpoint, dict) and "state_dict" in checkpoint:
        checkpoint = checkpoint["state_dict"]

    cleaned = {}
    for key, value in checkpoint.items():
        key = key.replace("module.", "")
        cleaned[key] = value

    model.load_state_dict(cleaned, strict=False)

    in_features = model.classifier[-1].in_features

    model.classifier[-1] = nn.Linear(
        in_features,
        len(classes)
    )

    return model


model = build_model().to(device)

criterion = nn.CrossEntropyLoss()

optimizer = torch.optim.AdamW(
    model.parameters(),
    lr=LR,
    weight_decay=1e-4
)

scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
    optimizer,
    mode="max",
    factor=0.5,
    patience=2
)


def run_epoch(loader, training):
    model.train(training)

    total_loss = 0.0
    correct = 0
    total = 0

    for images, labels in loader:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        if training:
            optimizer.zero_grad(set_to_none=True)

        with torch.set_grad_enabled(training):
            outputs = model(images)
            loss = criterion(outputs, labels)

            if training:
                loss.backward()
                optimizer.step()

        total_loss += loss.item() * images.size(0)

        predictions = outputs.argmax(dim=1)
        correct += (predictions == labels).sum().item()
        total += labels.size(0)

    return total_loss / total, correct / total


best_val = 0.0
best_epoch = 0
patience = 6
epochs_without_improvement = 0

history = []

for epoch in range(1, EPOCHS + 1):
    train_loss, train_acc = run_epoch(train_loader, True)
    val_loss, val_acc = run_epoch(val_loader, False)

    scheduler.step(val_acc)

    current_lr = optimizer.param_groups[0]["lr"]

    print(
        f"Epoch {epoch:02d}/{EPOCHS} | "
        f"train_loss={train_loss:.4f} "
        f"train_acc={train_acc*100:.2f}% | "
        f"val_loss={val_loss:.4f} "
        f"val_acc={val_acc*100:.2f}% | "
        f"lr={current_lr:.2e}"
    )

    history.append({
        "epoch": epoch,
        "train_loss": train_loss,
        "train_accuracy": train_acc,
        "validation_loss": val_loss,
        "validation_accuracy": val_acc,
        "learning_rate": current_lr
    })

    if val_acc > best_val:
        best_val = val_acc
        best_epoch = epoch
        epochs_without_improvement = 0

        torch.save(
            {
                "model_name": "mobilenet_v3_large",
                "num_classes": len(classes),
                "classes": classes,
                "class_to_idx": class_to_idx,
                "state_dict": model.state_dict(),
                "epoch": epoch,
                "validation_accuracy": val_acc
            },
            RUN_DIR / "best.pt"
        )

        print(f"  -> Saved best model ({best_val*100:.2f}%)")
    else:
        epochs_without_improvement += 1

    if epochs_without_improvement >= patience:
        print("Early stopping.")
        break


with open(RUN_DIR / "history.json", "w", encoding="utf-8") as f:
    json.dump(history, f, indent=2)

# Load best checkpoint for final test evaluation.
checkpoint = torch.load(
    RUN_DIR / "best.pt",
    map_location=device
)

model.load_state_dict(checkpoint["state_dict"])

test_loss, test_acc = run_epoch(test_loader, False)

results = {
    "model": "mobilenet_v3_large",
    "classes": len(classes),
    "best_epoch": best_epoch,
    "best_validation_accuracy": best_val,
    "test_loss": test_loss,
    "test_accuracy": test_acc,
    "train_images": len(train_df),
    "validation_images": len(val_df),
    "test_images": len(test_df)
}

with open(RUN_DIR / "results.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)

print()
print("===== FINAL RESULTS =====")
print(f"Best validation accuracy: {best_val*100:.2f}%")
print(f"Test accuracy:            {test_acc*100:.2f}%")
print(f"Best epoch:               {best_epoch}")
print()
print(f"Saved model:")
print(RUN_DIR / "best.pt")
print()
print("Medicine classes saved:")
print(RUN_DIR / "classes.json")
