import numpy as np
import cv2

def extract_color_features(image: np.ndarray) -> dict:
    """Extracts mean, std, and histograms for RGB, HSV, and LAB."""
    features = {}
    
    # RGB
    features['rgb_mean'] = np.mean(image, axis=(0, 1))
    features['rgb_std'] = np.std(image, axis=(0, 1))
    
    # HSV
    hsv = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)
    features['hsv_mean'] = np.mean(hsv, axis=(0, 1))
    features['hsv_std'] = np.std(hsv, axis=(0, 1))
    
    # LAB
    lab = cv2.cvtColor(image, cv2.COLOR_RGB2LAB)
    features['lab_mean'] = np.mean(lab, axis=(0, 1))
    features['lab_std'] = np.std(lab, axis=(0, 1))
    
    return features

