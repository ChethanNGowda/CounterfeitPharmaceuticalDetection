"""Train the audited binary dataset with compact torchvision models."""

from __future__ import annotations

import argparse
import csv
import json
import random
import time
from datetime import datetime
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from sklearn.metrics import average_precision_score, classification_report, confusion_matrix, precision_recall_curve, roc_auc_score, roc_curve
from torch import nn
from torch.cuda.amp import GradScaler
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision import models, transforms

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_WEIGHTS = PROJECT_ROOT / "external_models" / "PharmaAssist" / "weights"

CLASS_NAMES = ["authentic", "counterfeit"]
MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]


def seed_everything(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


class ManifestDataset(Dataset):
    def __init__(self, rows: list[dict[str, str]], root: Path, training: bool):
        self.rows = rows
        self.root = root
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.RandomHorizontalFlip() if training else transforms.Lambda(lambda image: image),
            transforms.RandomRotation(8) if training else transforms.Lambda(lambda image: image),
            transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.1) if training else transforms.Lambda(lambda image: image),
            transforms.ToTensor(),
            transforms.Normalize(MEAN, STD),
        ])

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int):
        row = self.rows[index]
        with Image.open(self.root / row["image_path"]) as image:
            tensor = self.transform(image.convert("RGB"))
        return tensor, CLASS_NAMES.index(row["label"]), row["image_path"]


def read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build_model(name: str, self_supervised_checkpoint: Path | None = None) -> nn.Module:
    if name == "baseline_cnn":
        model = nn.Sequential(
            nn.Conv2d(3, 32, 3, padding=1), nn.BatchNorm2d(32), nn.ReLU(), nn.MaxPool2d(2),
            nn.Conv2d(32, 64, 3, padding=1), nn.BatchNorm2d(64), nn.ReLU(), nn.MaxPool2d(2),
            nn.Conv2d(64, 128, 3, padding=1), nn.BatchNorm2d(128), nn.ReLU(), nn.AdaptiveAvgPool2d(1),
            nn.Flatten(), nn.Dropout(0.25), nn.Linear(128, 2),
        )
        if self_supervised_checkpoint:
            checkpoint = torch.load(self_supervised_checkpoint, map_location="cpu", weights_only=False)
            state = {key: value for key, value in checkpoint["model_state_dict"].items() if not key.startswith("14.")}
            model.load_state_dict(state, strict=False)
        return model
    if name == "efficientnet_b0":
        model = models.efficientnet_b0(weights=None)
        checkpoint = torch.load(MODEL_WEIGHTS / "pretrained" / "efficientnet_b0.pth", map_location="cpu", weights_only=True)
        model.load_state_dict({key: value for key, value in checkpoint.items() if not key.startswith("classifier.")}, strict=False)
        if self_supervised_checkpoint:
            checkpoint = torch.load(self_supervised_checkpoint, map_location="cpu", weights_only=False)
            state = {key: value for key, value in checkpoint["model_state_dict"].items() if not key.startswith("classifier.")}
            model.load_state_dict(state, strict=False)
        model.classifier[-1] = nn.Linear(model.classifier[-1].in_features, 2)
        return model
    if name == "mobilenet_v3_large":
        model = models.mobilenet_v3_large(weights=None)
        checkpoint = torch.load(MODEL_WEIGHTS / "pretrained" / "mobilenet_v3_large.pth", map_location="cpu", weights_only=True)
        model.load_state_dict({key: value for key, value in checkpoint.items() if not key.startswith("classifier.")}, strict=False)
        if self_supervised_checkpoint:
            checkpoint = torch.load(self_supervised_checkpoint, map_location="cpu", weights_only=False)
            state = {key: value for key, value in checkpoint["model_state_dict"].items() if not key.startswith("classifier.")}
            model.load_state_dict(state, strict=False)
        model.classifier[-1] = nn.Linear(model.classifier[-1].in_features, 2)
        return model
    raise ValueError(name)


def metrics(targets: np.ndarray, probabilities: np.ndarray) -> dict[str, object]:
    predictions = (probabilities >= 0.5).astype(int)
    matrix = confusion_matrix(targets, predictions, labels=[0, 1])
    tn, fp, fn, tp = matrix.ravel()
    precision = tp / max(tp + fp, 1)
    recall = tp / max(tp + fn, 1)
    specificity = tn / max(tn + fp, 1)
    f1 = 2 * precision * recall / max(precision + recall, 1e-12)
    result = {
        "accuracy": float((tn + tp) / max(matrix.sum(), 1)), "precision": float(precision),
        "recall_sensitivity": float(recall), "specificity": float(specificity), "f1": float(f1),
        "roc_auc": float(roc_auc_score(targets, probabilities)) if len(np.unique(targets)) == 2 else None,
        "pr_auc": float(average_precision_score(targets, probabilities)), "confusion_matrix": matrix.tolist(),
        "classification_report": classification_report(targets, predictions, target_names=CLASS_NAMES, output_dict=True, zero_division=0),
    }
    return result


def run_epoch(model, loader, criterion, device, optimizer, scaler, accumulation: int, train: bool):
    model.train(train)
    total_loss = 0.0
    targets, probabilities, paths = [], [], []
    if train:
        optimizer.zero_grad(set_to_none=True)
    for step, (images, labels, batch_paths) in enumerate(loader):
        images, labels = images.to(device), labels.to(device)
        with torch.autocast(device_type=device.type, enabled=device.type == "cuda"):
            logits = model(images)
            loss = criterion(logits, labels) / accumulation
        if train:
            scaler.scale(loss).backward()
            if (step + 1) % accumulation == 0 or step + 1 == len(loader):
                scaler.step(optimizer)
                scaler.update()
                optimizer.zero_grad(set_to_none=True)
        total_loss += loss.item() * accumulation * len(labels)
        targets.extend(labels.cpu().numpy())
        probabilities.extend(torch.softmax(logits, dim=1)[:, 1].detach().cpu().numpy())
        paths.extend(batch_paths)
    return total_loss / len(loader.dataset), np.asarray(targets), np.asarray(probabilities), paths


def train_one(name: str, args: argparse.Namespace, device: torch.device) -> dict[str, object]:
    seed_everything(args.seed)
    root = Path(args.data_root)
    manifest_dir = Path(args.manifest_dir)
    rows = {split: read_manifest(manifest_dir / f"{split}.csv") for split in ("train", "validation", "test")}
    train_dataset = ManifestDataset(rows["train"], root, True)
    loaders = {
        "train": DataLoader(train_dataset, batch_size=args.batch_size, sampler=WeightedRandomSampler([1 / sum(item["label"] == candidate["label"] for candidate in rows["train"]) for item in rows["train"]], len(train_dataset), replacement=True), num_workers=0),
        "validation": DataLoader(ManifestDataset(rows["validation"], root, False), batch_size=args.batch_size, shuffle=False, num_workers=0),
        "test": DataLoader(ManifestDataset(rows["test"], root, False), batch_size=args.batch_size, shuffle=False, num_workers=0),
    }
    self_checkpoint = Path(args.self_supervised_dir) / f"{name}.pt" if args.self_supervised_dir else None
    model = build_model(name, self_checkpoint).to(device)
    counts = [sum(row["label"] == label for row in rows["train"]) for label in CLASS_NAMES]
    criterion = nn.CrossEntropyLoss(weight=torch.tensor([sum(counts) / (2 * count) for count in counts], device=device))
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate, weight_decay=1e-4)
    scaler = GradScaler(enabled=device.type == "cuda")
    output = Path(args.output_dir) / f"{datetime.now():%Y%m%d_%H%M%S}_{name}"
    output.mkdir(parents=True, exist_ok=False)
    history, best_score, stale = [], -1.0, 0
    started = time.perf_counter()
    best_path = output / "best.pt"
    for epoch in range(1, args.epochs + 1):
        train_loss, _, _, _ = run_epoch(model, loaders["train"], criterion, device, optimizer, scaler, args.accumulation, True)
        val_loss, targets, probabilities, _ = run_epoch(model, loaders["validation"], criterion, device, optimizer, scaler, args.accumulation, False)
        val_metrics = metrics(targets, probabilities)
        record = {"epoch": epoch, "train_loss": train_loss, "validation_loss": val_loss, "validation": val_metrics}
        history.append(record)
        score = val_metrics["f1"]
        print(f"{name} epoch {epoch}: train_loss={train_loss:.4f} val_loss={val_loss:.4f} val_f1={score:.4f}")
        if score > best_score:
            best_score, stale = score, 0
            torch.save({"model_state_dict": model.state_dict(), "model": name, "class_names": CLASS_NAMES, "seed": args.seed}, best_path)
        else:
            stale += 1
        if stale >= args.patience:
            break
    checkpoint = torch.load(best_path, map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    _, targets, probabilities, paths = run_epoch(model, loaders["test"], criterion, device, optimizer, scaler, args.accumulation, False)
    test_metrics = metrics(targets, probabilities)
    threshold_rows = []
    for threshold in np.arange(0.1, 1.0, 0.05):
        predictions = (probabilities >= threshold).astype(int)
        matrix = confusion_matrix(targets, predictions, labels=[0, 1])
        threshold_rows.append({"threshold": float(threshold), "tn": int(matrix[0, 0]), "fp": int(matrix[0, 1]), "fn": int(matrix[1, 0]), "tp": int(matrix[1, 1])})
    (output / "history.json").write_text(json.dumps(history, indent=2), encoding="utf-8")
    (output / "metrics.json").write_text(json.dumps({"model": name, "epoch_count": len(history), "training_seconds": time.perf_counter() - started, "best_validation": history[np.argmax([item["validation"]["f1"] for item in history])]["validation"], "test": test_metrics, "thresholds": threshold_rows}, indent=2), encoding="utf-8")
    with (output / "predictions.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "true_label", "counterfeit_probability", "prediction"])
        writer.writeheader()
        writer.writerows({"image_path": path, "true_label": CLASS_NAMES[target], "counterfeit_probability": float(probability), "prediction": CLASS_NAMES[int(probability >= 0.5)]} for path, target, probability in zip(paths, targets, probabilities))
    return {"model": name, "checkpoint": str(best_path), "output": str(output), "best_validation": history[np.argmax([item["validation"]["f1"] for item in history])]["validation"], "test": test_metrics}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", nargs="+", default=["baseline_cnn", "efficientnet_b0", "mobilenet_v3_large"])
    parser.add_argument("--manifest-dir", default="outputs/clean_dataset")
    parser.add_argument("--output-dir", default=str(PROJECT_ROOT / "external_models" / "PharmaAssist" / "training_runs"))
    parser.add_argument("--data-root", default="data/processed")
    parser.add_argument("--self-supervised-dir")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--patience", type=int, default=4)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--accumulation", type=int, default=2)
    parser.add_argument("--learning-rate", type=float, default=3e-4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--cpu", action="store_true")
    args = parser.parse_args()
    device = torch.device("cuda" if torch.cuda.is_available() and not args.cpu else "cpu")
    print(f"Device: {device}; GPU: {torch.cuda.get_device_name(0) if device.type == 'cuda' else 'none'}")
    results = [train_one(name, args, device) for name in args.models]
    Path(args.output_dir).mkdir(parents=True, exist_ok=True)
    Path(args.output_dir, "run_summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
