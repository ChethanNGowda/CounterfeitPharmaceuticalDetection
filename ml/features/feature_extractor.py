import numpy as np
from ml.features.color_features import extract_color_features
from ml.features.texture_features import extract_texture_features
from ml.features.shape_features import extract_shape_features

class FeatureExtractor:
    def __init__(self):
        self.feature_names = []
        self._build_feature_names()

    def _build_feature_names(self):
        # Define names based on the structure of the combined vector
        self.feature_names = [
            'rgb_m_r', 'rgb_m_g', 'rgb_m_b',
            'rgb_s_r', 'rgb_s_g', 'rgb_s_b',
            'hsv_m_h', 'hsv_m_s', 'hsv_m_v',
            'hsv_s_h', 'hsv_s_s', 'hsv_s_v',
            'lab_m_l', 'lab_m_a', 'lab_m_b',
            'lab_s_l', 'lab_s_a', 'lab_s_b',
            *[f'lbp_{i}' for i in range(10)],
            'glcm_contrast', 'glcm_homogeneity', 'glcm_energy', 'glcm_correlation',
            'area', 'perimeter', 'circularity', 'aspect_ratio'
        ]

    def extract(self, image: np.ndarray) -> np.ndarray:
        """Extracts and combines all features into a deterministic vector."""
        color = extract_color_features(image)
        texture = extract_texture_features(image)
        shape = extract_shape_features(image)
        
        vector = np.concatenate([
            color['rgb_mean'], color['rgb_std'],
            color['hsv_mean'], color['hsv_std'],
            color['lab_mean'], color['lab_std'],
            texture['lbp_hist'],
            [texture['glcm_contrast'], texture['glcm_homogeneity'], texture['glcm_energy'], texture['glcm_correlation']],
            [shape['area'], shape['perimeter'], shape['circularity'], shape['aspect_ratio']]
        ])
        
        # Validation
        if np.any(np.isnan(vector)) or np.any(np.isinf(vector)):
            raise ValueError("Feature vector contains NaN or Inf values")
            
        return vector
