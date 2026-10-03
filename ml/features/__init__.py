"""Legacy hand-crafted feature engineering package (colour / texture / shape).

This package was used during the prototype phase before deep transfer-learning
models (EfficientNet-B0, MobileNetV3-Large) became the primary classifiers.

Components:
  - feature_extractor.py  — FeatureExtractor: combines colour, texture, shape
  - color_features.py     — RGB / HSV / LAB colour statistics
  - texture_features.py   — LBP histogram, GLCM statistics
  - shape_features.py     — area, perimeter, circularity, aspect ratio

Retained for:
  - tests/test_features.py
  - scripts/build_dataset.py (legacy dataset construction)
  - Historical reference / benchmark comparison

The production EfficientNet-B0 inference pipeline does NOT use this package.
"""
