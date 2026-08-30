import os
from pathlib import Path

def validate_dataset():
    raw_dir = Path("data/raw")
    
    # Check directory structure
    if not (raw_dir / "authentic").exists() or not (raw_dir / "counterfeit").exists():
        print("Error: Missing 'authentic' or 'counterfeit' directories in data/raw/")
        return False
        
    # Check for empty folders
    authentic_images = list((raw_dir / "authentic").glob("*.*"))
    counterfeit_images = list((raw_dir / "counterfeit").glob("*.*"))
    
    if not authentic_images and not counterfeit_images:
        print("Warning: Dataset is empty.")
    
    print(f"Validation Report:")
    print(f"- Authentic images found: {len(authentic_images)}")
    print(f"- Counterfeit images found: {len(counterfeit_images)}")
    
    return True

if __name__ == "__main__":
    if not validate_dataset():
        exit(1)
