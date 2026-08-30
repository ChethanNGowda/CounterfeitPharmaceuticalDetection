import pandas as pd
import os
from pathlib import Path
from ml.preprocessing.image_preprocessor import ImagePreprocessor
from ml.features.feature_extractor import FeatureExtractor
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def build_dataset():
    raw_dir = Path("data/raw")
    output_path = Path("data/processed/features.csv")
    preprocessor = ImagePreprocessor()
    extractor = FeatureExtractor()
    
    data = []
    
    # Iterate over authentic/counterfeit folders
    for label in ["authentic", "counterfeit"]:
        label_dir = raw_dir / label
        if not label_dir.exists():
            continue
            
        for img_path in label_dir.glob("*.*"):
            if img_path.suffix.lower() not in ['.jpg', '.jpeg', '.png']:
                continue
                
            try:
                img = preprocessor.preprocess(str(img_path))
                features = extractor.extract(img)
                
                row = {
                    "sample_id": img_path.stem,
                    "label": 0 if label == "authentic" else 1,
                    "image_path": str(img_path)
                }
                # Add features
                for i, name in enumerate(extractor.feature_names):
                    row[name] = features[i]
                data.append(row)
                logger.info(f"Processed: {img_path}")
            except Exception as e:
                logger.error(f"Failed to process {img_path}: {e}")
                
    df = pd.DataFrame(data)
    df.to_csv(output_path, index=False)
    logger.info(f"Dataset saved to {output_path}. Total samples: {len(df)}")

if __name__ == "__main__":
    build_dataset()
