"""Image dataset discovery, grouped splitting, and preprocessing transforms."""

from __future__ import annotations

import csv
import json
import random
from pathlib import Path
from typing import Iterable

import torch
from sklearn.model_selection import GroupShuffleSplit
from torch.utils.data import Dataset
from torchvision.io import ImageReadMode, read_image
from torchvision import transforms

CLASS_NAMES = ("authentic", "counterfeit")
CLASS_TO_INDEX = {name: index for index, name in enumerate(CLASS_NAMES)}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
IMAGE_SIZE = 224
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


def _ensure_tensor_image(image: torch.Tensor | object) -> torch.Tensor:
    if isinstance(image, torch.Tensor):
        return image
    return transforms.PILToTensor()(image)


def seed_everything(seed: int) -> None:
    random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    if hasattr(torch.backends, "cudnn"):
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False


def class_balance(records: list[dict[str, str]]) -> dict[str, object]:
    counts = class_counts(records)
    total = len(records)
    proportions = {
        class_name: (count / total if total else 0.0)
        for class_name, count in counts.items()
    }
    return {"counts": counts, "proportions": proportions}


def _image_files(root: Path) -> Iterable[Path]:
    return (path for path in root.rglob("*") if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS)


def discover_records(raw_dir: Path, metadata_path: Path | None = None) -> list[dict[str, str]]:
    """Discover two-class images, optionally using metadata-defined group IDs."""
    metadata: dict[str, dict[str, str]] = {}
    if metadata_path and metadata_path.exists():
        with metadata_path.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                image_path = Path(row["image_path"]).as_posix()
                metadata[image_path] = row

    records: list[dict[str, str]] = []
    for class_name in CLASS_NAMES:
        class_dir = raw_dir / class_name
        if not class_dir.exists():
            continue
        for image_path in _image_files(class_dir):
            relative_path = image_path.relative_to(raw_dir).as_posix()
            extra = metadata.get(relative_path, metadata.get(image_path.as_posix(), {}))
            label = extra.get("label", class_name).strip().lower()
            if label not in CLASS_TO_INDEX:
                raise ValueError(f"Unsupported label {label!r} for {image_path}")
            group_id = extra.get("group_id", extra.get("sample_id", image_path.stem))
            records.append({
                "image_path": relative_path,
                "label": label,
                "group_id": group_id,
            })
    return records


def _has_all_classes(records: list[dict[str, str]]) -> bool:
    return {record["label"] for record in records} == set(CLASS_NAMES)


def create_splits(
    records: list[dict[str, str]],
    seed: int = 42,
    train_ratio: float = 0.70,
    validation_ratio: float = 0.15,
) -> dict[str, list[dict[str, str]]]:
    """Create deterministic group-disjoint splits with class-presence checks."""
    if not records:
        raise ValueError("No images found. Add labeled images under data/raw/authentic and data/raw/counterfeit.")
    if not _has_all_classes(records):
        raise ValueError("Both authentic and counterfeit classes are required.")
    groups = [record["group_id"] for record in records]
    for attempt in range(100):
        splitter = GroupShuffleSplit(n_splits=1, train_size=train_ratio, random_state=seed + attempt)
        train_indices, remainder_indices = next(splitter.split(records, groups=groups))
        remainder = [records[index] for index in remainder_indices]
        remainder_groups = [record["group_id"] for record in remainder]
        remainder_validation_ratio = validation_ratio / (1.0 - train_ratio)
        second = GroupShuffleSplit(n_splits=1, train_size=remainder_validation_ratio, random_state=seed + attempt)
        validation_indices, test_indices = next(second.split(remainder, groups=remainder_groups))
        splits = {
            "train": [records[index] for index in train_indices],
            "validation": [remainder[index] for index in validation_indices],
            "test": [remainder[index] for index in test_indices],
        }
        if all(_has_all_classes(items) for items in splits.values()):
            return splits
    raise ValueError("Could not create group-disjoint splits containing both classes; add more grouped samples.")


def write_splits(splits: dict[str, list[dict[str, str]]], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for split_name, records in splits.items():
        with (output_dir / f"{split_name}.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=["image_path", "label", "group_id"])
            writer.writeheader()
            writer.writerows(records)


def load_splits(split_dir: Path) -> dict[str, list[dict[str, str]]]:
    splits: dict[str, list[dict[str, str]]] = {}
    for split_name in ("train", "validation", "test"):
        path = split_dir / f"{split_name}.csv"
        if not path.exists():
            raise FileNotFoundError(f"Missing split file: {path}")
        with path.open(newline="", encoding="utf-8") as handle:
            splits[split_name] = list(csv.DictReader(handle))
    return splits


def save_split_manifest(splits: dict[str, list[dict[str, str]]], path: Path, seed: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"seed": seed, "splits": splits}, indent=2), encoding="utf-8")


def train_transform() -> transforms.Compose:
    return transforms.Compose([
        transforms.Lambda(_ensure_tensor_image),
        transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.75, 1.0), antialias=True),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(10),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.15),
        transforms.ConvertImageDtype(torch.float32),
        transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
    ])


def evaluation_transform() -> transforms.Compose:
    return transforms.Compose([
        transforms.Lambda(_ensure_tensor_image),
        transforms.Resize(256, antialias=True),
        transforms.CenterCrop(IMAGE_SIZE),
        transforms.ConvertImageDtype(torch.float32),
        transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
    ])


class PharmaceuticalImageDataset(Dataset):
    def __init__(self, records: list[dict[str, str]], raw_dir: Path, transform: transforms.Compose):
        self.records = records
        self.raw_dir = raw_dir
        self.transform = transform

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        record = self.records[index]
        image = read_image(
            str(self.raw_dir / record["image_path"]),
            mode=ImageReadMode.RGB,
        )
        return self.transform(image), CLASS_TO_INDEX[record["label"]]


def class_counts(records: list[dict[str, str]]) -> dict[str, int]:
    return {class_name: sum(record["label"] == class_name for record in records) for class_name in CLASS_NAMES}