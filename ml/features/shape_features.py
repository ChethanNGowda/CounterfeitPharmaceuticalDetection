import numpy as np
import cv2

def extract_shape_features(image: np.ndarray) -> dict:
    """Extracts shape features based on tablet segmentation."""
    # Convert image to grayscale for thresholding
    gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    _, binary = cv2.threshold(gray, 0.5, 1.0, cv2.THRESH_BINARY)
    binary = (binary * 255).astype(np.uint8)
    
    # Find contours
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    features = {
        'area': 0.0,
        'perimeter': 0.0,
        'circularity': 0.0,
        'aspect_ratio': 0.0
    }
    
    if contours:
        cnt = max(contours, key=cv2.contourArea)
        area = cv2.contourArea(cnt)
        perimeter = cv2.arcLength(cnt, True)
        
        if perimeter > 0:
            features['area'] = area
            features['perimeter'] = perimeter
            features['circularity'] = (4 * np.pi * area) / (perimeter ** 2) if perimeter > 0 else 0
            x, y, w, h = cv2.boundingRect(cnt)
            features['aspect_ratio'] = float(w) / h if h != 0 else 0
            
    return features

