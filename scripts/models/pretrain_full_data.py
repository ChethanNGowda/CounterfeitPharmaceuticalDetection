"""Self-supervised rotation pretraining over non-test full-data images."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms

from train_pipeline import build_model


class RotationDataset(Dataset):
    def __init__(self, rows, root):
        self.rows = rows
        self.root = root
        self.transform = transforms.Compose([transforms.Resize((224, 224)), transforms.RandomHorizontalFlip(), transforms.ToTensor(), transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])])

    def __len__(self):
        return len(self.rows) * 4

    def __getitem__(self, index):
        row = self.rows[index // 4]
        rotation = index % 4
        with Image.open(self.root / row["image_path"]) as image:
            image = self.transform(image.convert("RGB"))
        return torch.rot90(image, rotation, (1, 2)), rotation


def read(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", type=Path, default=Path("."))
    parser.add_argument("--manifest-dir", type=Path, default=Path("data/full_training"))
    parser.add_argument("--output-dir", type=Path, default=Path("outputs/full_data_training/pretraining"))
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--batch-size", type=int, default=16)
    args = parser.parse_args()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    self_rows = read(args.manifest_dir / "self_supervised_manifest.csv")
    train_rows = read(args.manifest_dir / "train.csv")
    rows = self_rows + train_rows
    loader = DataLoader(RotationDataset(rows, args.data_root), batch_size=args.batch_size, shuffle=True, num_workers=4, pin_memory=device.type == "cuda", persistent_workers=True)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary = {"images_used": len(rows), "self_supervised_images": len(self_rows), "supervised_train_images": len(train_rows), "device": str(device), "models": {}}
    for name in ("baseline_cnn", "efficientnet_b0", "mobilenet_v3_large"):
        model = build_model(name)
        if name == "baseline_cnn":
            feature_dim = 128
            model[-1] = nn.Linear(feature_dim, 4)
        else:
            feature_dim = model.classifier[-1].in_features
            model.classifier[-1] = nn.Linear(feature_dim, 4)
        model.to(device)
        optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4, weight_decay=1e-4)
        criterion = nn.CrossEntropyLoss()
        history = []
        for epoch in range(1, args.epochs + 1):
            model.train(); total = 0.0; correct = 0; count = 0
            for images, labels in loader:
                images, labels = images.to(device, non_blocking=True), labels.to(device, non_blocking=True)
                optimizer.zero_grad(set_to_none=True)
                with torch.autocast(device_type=device.type, enabled=device.type == "cuda"):
                    logits = model(images)
                    loss = criterion(logits, labels)
                loss.backward(); optimizer.step()
                total += loss.item() * labels.size(0); correct += (logits.argmax(1) == labels).sum().item(); count += labels.size(0)
            record = {"epoch": epoch, "loss": total / count, "accuracy": correct / count}; history.append(record); print(name, record)
        path = args.output_dir / f"{name}.pt"
        torch.save({"model_state_dict": model.state_dict(), "model": name, "pretraining": "rotation_prediction", "images_used": len(rows)}, path)
        (args.output_dir / f"{name}_history.json").write_text(json.dumps(history, indent=2), encoding="utf-8")
        summary["models"][name] = {"checkpoint": str(path), "history": history}
    (args.output_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()