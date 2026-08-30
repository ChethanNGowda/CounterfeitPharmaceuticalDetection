import numpy as np
import cv2
from skimage.feature import local_binary_pattern, graycomatrix, graycoprops

def extract_texture_features(image: np.ndarray) -> dict:
    """Extracts LBP and GLCM features from a grayscale version of the image."""
    gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY).astype(np.uint32)
    features = {}
    
    # LBP
    lbp = local_binary_pattern(gray, 8, 1, method='uniform')
    hist, _ = np.histogram(lbp.ravel(), bins=10, range=(0, 10))
    features['lbp_hist'] = hist / (hist.sum() + 1e-6)
    
    # GLCM
    glcm = graycomatrix(gray, distances=[5], angles=[0], levels=256, symmetric=True, normed=True)
    features['glcm_contrast'] = graycoprops(glcm, 'contrast')[0, 0]
    features['glcm_homogeneity'] = graycoprops(glcm, 'homogeneity')[0, 0]
    features['glcm_energy'] = graycoprops(glcm, 'energy')[0, 0]
    features['glcm_correlation'] = graycoprops(glcm, 'correlation')[0, 0]
    
    return features

