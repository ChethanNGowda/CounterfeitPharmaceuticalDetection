import cv2
import numpy as np
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ImagePreprocessor:
    """Robust image preprocessing for pharmaceutical tablet images."""
    
    def __init__(self, target_size=(512, 512)):
        self.target_size = target_size

    def preprocess(self, image_path: str) -> np.ndarray:
        """
        Loads, validates, and preprocesses an image.
        
        Args:
            image_path: Path to the image file.
            
        Returns:
            Preprocessed image as a numpy array (float32, 0-1 range).
        """
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"File not found: {image_path}")

        # Supported extensions
        if not image_path.lower().endswith(('.jpg', '.jpeg', '.png')):
            raise ValueError(f"Unsupported file format: {image_path}")

        # Load image
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Failed to load or corrupted image: {image_path}")

        # Handle grayscale inputs (convert to BGR for consistency)
        if len(img.shape) == 2:
            img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
        
        # BGR -> RGB
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        # Resize
        img = cv2.resize(img, self.target_size, interpolation=cv2.INTER_AREA)

        # Denoising
        img = cv2.fastNlMeansDenoisingColored(img, None, 10, 10, 7, 21)

        # Contrast enhancement using CLAHE in LAB space
        lab = cv2.cvtColor(img, cv2.COLOR_RGB2LAB)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        lab[:, :, 0] = clahe.apply(lab[:, :, 0])
        img = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)

        # Normalization
        img = img.astype(np.float32) / 255.0

        return img
