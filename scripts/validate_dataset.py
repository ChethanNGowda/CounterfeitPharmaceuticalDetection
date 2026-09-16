import os
import argparse
from pathlib import Path

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def validate_dataset(raw_dir: Path = Path("data/raw")):
    
    # Check directory structure
    if not (raw_dir / "authentic").exists() or not (raw_dir / "counterfeit").exists():
        print("Error: Missing 'authentic' or 'counterfeit' directories in data/raw/")
        return False
        
    # Check for empty folders
    authentic_images = [path for path in (raw_dir / "authentic").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS]
    counterfeit_images = [path for path in (raw_dir / "counterfeit").rglob("*") if path.suffix.lower() in IMAGE_EXTENSIONS]
    
    if not authentic_images and not counterfeit_images:
        print("Warning: Dataset is empty.")
    
    print(f"Validation Report:")
    print(f"- Authentic images found: {len(authentic_images)}")
    print(f"- Counterfeit images found: {len(counterfeit_images)}")
    
    return True


def validate_prepared_dataset(data_root: Path = Path("data/processed")) -> bool:
    """Validate the preserved train/valid/test classification directories."""
    split_names = ("train", "valid", "test")
    valid = True
    for split in split_names:
        split_root = data_root / split
        if not split_root.exists():
            print(f"Error: Missing prepared split directory: {split_root}")
            valid = False
            continue
        counts = {}
        for label in ("authentic", "counterfeit"):
            label_root = split_root / label
            images = [path for path in label_root.rglob("*") if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS]
            counts[label] = len(images)
            if not images:
                print(f"Error: Prepared split has no {label} images: {label_root}")
                valid = False
        print(f"Prepared {split}: authentic={counts['authentic']}, counterfeit={counts['counterfeit']}, total={sum(counts.values())}")
    return valid


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepared-root", type=Path)
    args = parser.parse_args()
    result = validate_prepared_dataset(args.prepared_root) if args.prepared_root else validate_dataset()
    if not result:
        exit(1)
