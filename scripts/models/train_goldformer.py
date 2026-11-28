"""Fine-tune the official GoldFormer checkpoint on the pharmaceutical split."""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from sklearn.metrics import average_precision_score, classification_report, confusion_matrix, roc_auc_score
from torch import nn
from torch.cuda.amp import GradScaler
from torch.utils.data import DataLoader, Dataset, WeightedRandomSampler
from torchvision import transforms

CLASS_NAMES = ["authentic", "counterfeit"]


def load_official_model(checkpoint: Path):
    model_path = Path("external_models/GoldNet/code/models.py").resolve()
    spec = importlib.util.spec_from_file_location("goldnet_models_train", model_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["goldnet_models_train"] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    model = module.build_model("goldformer")
    state = torch.load(checkpoint, map_location="cpu", weights_only=True)
    model.load_state_dict(state, strict=True)
    return model


class ManifestDataset(Dataset):
    def __init__(self, rows, root: Path, training: bool):
        self.rows, self.root = rows, root
        ops = [transforms.Resize((224, 224))]
        if training:
            ops += [transforms.RandomHorizontalFlip(), transforms.RandomRotation(8), transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.1)]
        ops += [transforms.ToTensor(), transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])]
        self.transform = transforms.Compose(ops)

    def __len__(self): return len(self.rows)

    def __getitem__(self, index):
        row = self.rows[index]
        with Image.open(self.root / row["image_path"]) as image:
            tensor = self.transform(image.convert("RGB"))
        return tensor, CLASS_NAMES.index(row["label"]), row["image_path"]


def read_manifest(path):
    with path.open(newline="", encoding="utf-8") as handle: return list(csv.DictReader(handle))


def calculate_metrics(targets, probabilities):
    predictions = (probabilities >= 0.5).astype(int)
    matrix = confusion_matrix(targets, predictions, labels=[0, 1])
    tn, fp, fn, tp = matrix.ravel()
    precision = tp / max(tp + fp, 1); recall = tp / max(tp + fn, 1); specificity = tn / max(tn + fp, 1)
    f1 = 2 * precision * recall / max(precision + recall, 1e-12)
    return {"accuracy": float((tn + tp) / matrix.sum()), "precision": float(precision), "recall_sensitivity": float(recall), "specificity": float(specificity), "f1": float(f1), "roc_auc": float(roc_auc_score(targets, probabilities)), "pr_auc": float(average_precision_score(targets, probabilities)), "confusion_matrix": matrix.tolist(), "classification_report": classification_report(targets, predictions, target_names=CLASS_NAMES, output_dict=True, zero_division=0)}


def run_epoch(model, loader, criterion, device, optimizer, scaler, accumulation, training):
    model.train(training); total_loss = 0.0; targets = []; probabilities = []; paths = []
    if training: optimizer.zero_grad(set_to_none=True)
    for step, (images, labels, batch_paths) in enumerate(loader):
        images, labels = images.to(device, non_blocking=True), labels.to(device, non_blocking=True)
        with torch.autocast(device_type=device.type, enabled=device.type == "cuda"):
            logits, _ = model(images)
            loss = criterion(logits, labels) / accumulation
        if training:
            scaler.scale(loss).backward()
            if (step + 1) % accumulation == 0 or step + 1 == len(loader):
                scaler.step(optimizer); scaler.update(); optimizer.zero_grad(set_to_none=True)
        total_loss += loss.item() * accumulation * labels.size(0)
        targets.extend(labels.cpu().numpy()); probabilities.extend(torch.softmax(logits, 1)[:, 1].detach().cpu().numpy()); paths.extend(batch_paths)
    return total_loss / len(loader.dataset), np.asarray(targets), np.asarray(probabilities), paths


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=12); parser.add_argument("--patience", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=4); parser.add_argument("--accumulation", type=int, default=2)
    parser.add_argument("--learning-rate", type=float, default=1e-5); parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--checkpoint", type=Path, default=Path("external_models/GoldNet/weights/GoldFormer_best.pth"))
    args = parser.parse_args()
    torch.manual_seed(args.seed); np.random.seed(args.seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    project_root = Path(__file__).resolve().parent.parent
    output = project_root / "external_models" / "PharmaAssist" / "training_runs" / "goldformer"
    checkpoint_output = project_root / "external_models" / "PharmaAssist" / "weights" / "checkpoints" / "goldformer"
    for name in ("metrics", "predictions", "confusion_matrix", "reports"): (output / name).mkdir(parents=True, exist_ok=True)
    checkpoint_output.mkdir(parents=True, exist_ok=True)
    rows = {name: read_manifest(Path("data/full_training") / f"{name}.csv") for name in ("train", "validation", "test")}
    loaders = {}
    counts = [sum(row["label"] == label for row in rows["train"]) for label in CLASS_NAMES]
    weights = [1 / counts[CLASS_NAMES.index(row["label"])] for row in rows["train"]]
    loaders["train"] = DataLoader(ManifestDataset(rows["train"], Path("."), True), batch_size=args.batch_size, sampler=WeightedRandomSampler(weights, len(weights), replacement=True), num_workers=2, pin_memory=True, persistent_workers=True)
    for name in ("validation", "test"): loaders[name] = DataLoader(ManifestDataset(rows[name], Path("."), False), batch_size=args.batch_size, shuffle=False, num_workers=2, pin_memory=True, persistent_workers=True)
    model = load_official_model(args.checkpoint).to(device)
    criterion = nn.CrossEntropyLoss(weight=torch.tensor([sum(counts) / (2 * count) for count in counts], device=device))
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate, weight_decay=1e-4)
    scaler = GradScaler(enabled=device.type == "cuda")
    best_path = checkpoint_output / "goldformer_pharmaceutical_best.pt"; history = []; best_f1 = -1; stale = 0; started = time.perf_counter()
    for epoch in range(1, args.epochs + 1):
        train_loss, _, _, _ = run_epoch(model, loaders["train"], criterion, device, optimizer, scaler, args.accumulation, True)
        val_loss, val_targets, val_probabilities, _ = run_epoch(model, loaders["validation"], criterion, device, optimizer, scaler, args.accumulation, False)
        validation = calculate_metrics(val_targets, val_probabilities); history.append({"epoch": epoch, "train_loss": train_loss, "validation_loss": val_loss, "validation": validation})
        print(f"epoch {epoch}: train_loss={train_loss:.4f} val_loss={val_loss:.4f} val_acc={validation['accuracy']:.4f} val_f1={validation['f1']:.4f}")
        if validation["f1"] > best_f1:
            best_f1 = validation["f1"]; stale = 0; torch.save({"model_state_dict": model.state_dict(), "model": "goldformer", "class_names": CLASS_NAMES, "seed": args.seed, "source_checkpoint": str(args.checkpoint)}, best_path)
        else: stale += 1
        if stale >= args.patience: break
    checkpoint = torch.load(best_path, map_location=device, weights_only=False); model.load_state_dict(checkpoint["model_state_dict"])
    test_start = time.perf_counter(); _, targets, probabilities, paths = run_epoch(model, loaders["test"], criterion, device, optimizer, scaler, args.accumulation, False); inference_seconds = time.perf_counter() - test_start
    test = calculate_metrics(targets, probabilities); result = {"model": "GoldFormer", "source_domain": "authentic/counterfeit gold images", "fine_tuning_domain": "pharmaceutical images", "parameter_count": sum(parameter.numel() for parameter in model.parameters()), "training_seconds": time.perf_counter() - started, "epoch_count": len(history), "best_validation": history[int(np.argmax([item["validation"]["f1"] for item in history]))]["validation"], "test": test, "inference_seconds": inference_seconds, "inference_seconds_per_image": inference_seconds / len(targets), "strict_source_checkpoint_load": True, "source_checkpoint": str(args.checkpoint)}
    (output / "metrics" / "goldformer_metrics.json").write_text(json.dumps(result, indent=2), encoding="utf-8"); (output / "metrics" / "goldformer_history.json").write_text(json.dumps(history, indent=2), encoding="utf-8"); (output / "confusion_matrix" / "goldformer.csv").write_text("true_label,predicted_authentic,predicted_counterfeit\nauthentic," + str(test["confusion_matrix"][0][0]) + "," + str(test["confusion_matrix"][0][1]) + "\ncounterfeit," + str(test["confusion_matrix"][1][0]) + "," + str(test["confusion_matrix"][1][1]) + "\n", encoding="utf-8")
    with (output / "predictions" / "goldformer.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "true_label", "counterfeit_probability", "prediction"]); writer.writeheader(); writer.writerows({"image_path": path, "true_label": CLASS_NAMES[target], "counterfeit_probability": float(probability), "prediction": CLASS_NAMES[int(probability >= .5)]} for path, target, probability in zip(paths, targets, probabilities))
    print(json.dumps({"best_checkpoint": str(best_path), "test": test}, indent=2))


if __name__ == "__main__": main()
