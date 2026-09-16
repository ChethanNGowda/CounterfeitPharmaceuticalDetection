"""Train a two-class torchvision transfer-learning model."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from torch import nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import ReduceLROnPlateau
from torch.utils.data import DataLoader

from ml.evaluation.metrics import classification_metrics
from ml.models.transfer_learning import build_model, freeze_backbone, unfreeze_last_features
from ml.training.data import (
    CLASS_NAMES, IMAGENET_MEAN, IMAGENET_STD, IMAGE_SIZE, PharmaceuticalImageDataset,
    class_balance, class_counts, create_splits, discover_records, evaluation_transform, load_splits,
    save_split_manifest, seed_everything, train_transform, write_splits,
)


def _run_epoch(model, loader, criterion, device, optimizer=None):
    training = optimizer is not None
    model.train(training)
    total_loss = 0.0
    targets: list[int] = []
    predictions: list[int] = []
    for images, labels in loader:
        images = images.to(device, non_blocking=device.type == "cuda")
        labels = labels.to(device, non_blocking=device.type == "cuda")
        with torch.set_grad_enabled(training):
            logits = model(images)
            loss = criterion(logits, labels)
            if training:
                optimizer.zero_grad(set_to_none=True)
                loss.backward()
                optimizer.step()
        total_loss += loss.item() * labels.size(0)
        targets.extend(labels.cpu().tolist())
        predictions.extend(logits.argmax(dim=1).cpu().tolist())
    metrics = classification_metrics(targets, predictions, CLASS_NAMES)
    metrics["loss"] = total_loss / len(loader.dataset)
    return metrics


def build_training_metadata(
    args: argparse.Namespace,
    device: torch.device,
    split_balance: dict[str, object],
    validation_metrics: dict,
    test_metrics: dict,
    best_epoch: int | None,
    history: list[dict],
) -> dict:
    return {
        "model_name": args.model,
        "class_mapping": {name: index for index, name in enumerate(CLASS_NAMES)},
        "input_size": [IMAGE_SIZE, IMAGE_SIZE],
        "normalization": {"mean": IMAGENET_MEAN, "std": IMAGENET_STD},
        "device": str(device),
        "seed": args.seed,
        "training_configuration": vars(args),
        "validation_metrics": validation_metrics,
        "test_metrics": test_metrics,
        "best_epoch": best_epoch,
        "class_balance": split_balance,
        "history": history,
    }


def train(args: argparse.Namespace) -> Path:
    seed_everything(args.seed)
    device = torch.device("cuda" if torch.cuda.is_available() and not args.cpu else "cpu")
    raw_dir = Path(args.raw_dir)
    split_dir = Path(args.split_dir)
    if args.create_splits:
        records = discover_records(raw_dir, Path(args.metadata) if args.metadata else None)
        splits = create_splits(records, seed=args.seed)
        write_splits(splits, split_dir)
        save_split_manifest(splits, split_dir / "manifest.json", args.seed)
    else:
        splits = load_splits(split_dir)

    counts = class_counts(splits["train"])
    if any(count == 0 for count in counts.values()):
        raise ValueError(f"Training split is missing a class: {counts}")
    split_balance = {name: class_balance(records) for name, records in splits.items()}
    weights = torch.tensor([len(splits["train"]) / (len(CLASS_NAMES) * counts[name]) for name in CLASS_NAMES], dtype=torch.float32, device=device)
    model = build_model(args.model, Path(args.pretrained_checkpoint)).to(device)
    freeze_backbone(model)
    loader_options = {
        "batch_size": args.batch_size,
        "num_workers": args.workers,
        "pin_memory": device.type == "cuda",
    }
    if args.workers > 0:
        loader_options["persistent_workers"] = True
        loader_options["prefetch_factor"] = 2
    train_loader = DataLoader(
        PharmaceuticalImageDataset(splits["train"], raw_dir, train_transform()),
        shuffle=True,
        **loader_options,
    )
    validation_loader = DataLoader(
        PharmaceuticalImageDataset(splits["validation"], raw_dir, evaluation_transform()),
        shuffle=False,
        **loader_options,
    )
    test_loader = DataLoader(
        PharmaceuticalImageDataset(splits["test"], raw_dir, evaluation_transform()),
        shuffle=False,
        **loader_options,
    )
    criterion = nn.CrossEntropyLoss(weight=weights)
    optimizer = AdamW((parameter for parameter in model.parameters() if parameter.requires_grad), lr=args.learning_rate, weight_decay=args.weight_decay)
    scheduler = ReduceLROnPlateau(optimizer, mode="min", factor=0.3, patience=2)
    output_dir = Path(args.output_dir) / args.model
    output_dir.mkdir(parents=True, exist_ok=True)
    best_loss = float("inf")
    stale_epochs = 0
    best_validation_metrics = None
    best_epoch = None
    best_path = output_dir / "best.pt"
    history = []
    for epoch in range(1, args.epochs + 1):
        train_metrics = _run_epoch(model, train_loader, criterion, device, optimizer)
        validation_metrics = _run_epoch(model, validation_loader, criterion, device)
        scheduler.step(validation_metrics["loss"])
        history.append({"epoch": epoch, "train": train_metrics, "validation": validation_metrics})
        if validation_metrics["loss"] < best_loss:
            best_loss = validation_metrics["loss"]
            stale_epochs = 0
            best_validation_metrics = validation_metrics
            best_epoch = epoch
            torch.save({"model_state_dict": model.state_dict(), "metadata": {"model_name": args.model, "class_names": CLASS_NAMES}}, best_path)
        else:
            stale_epochs += 1
        if epoch == args.unfreeze_epoch:
            unfreeze_last_features(model)
            optimizer = AdamW((parameter for parameter in model.parameters() if parameter.requires_grad), lr=args.learning_rate / 10, weight_decay=args.weight_decay)
            scheduler = ReduceLROnPlateau(optimizer, mode="min", factor=0.3, patience=2)
        if stale_epochs >= args.patience:
            break
    checkpoint = torch.load(best_path, map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    test_metrics = _run_epoch(model, test_loader, criterion, device)
    metadata = build_training_metadata(
        args,
        device,
        split_balance,
        best_validation_metrics,
        test_metrics,
        best_epoch,
        history,
    )
    torch.save({"model_state_dict": model.state_dict(), "metadata": metadata}, best_path)
    (output_dir / "metadata.json").write_text(json.dumps(metadata, indent=2, default=str), encoding="utf-8")
    return best_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", choices=["mobilenet_v3_large", "efficientnet_b0"], required=True)
    parser.add_argument("--pretrained-checkpoint", required=True)
    parser.add_argument("--raw-dir", default="data/raw")
    parser.add_argument("--split-dir", default="data/splits")
    parser.add_argument("--metadata")
    parser.add_argument("--output-dir", default="runs")
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--patience", type=int, default=6)
    parser.add_argument("--unfreeze-epoch", type=int, default=3)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--cpu", action="store_true")
    parser.add_argument("--create-splits", action=argparse.BooleanOptionalAction, default=True)
    args = parser.parse_args()
    print(f"Saved best checkpoint to {train(args)}")


if __name__ == "__main__":
    main()