import pytest
import numpy as np
from ml.features.feature_extractor import FeatureExtractor

@pytest.fixture
def extractor():
    return FeatureExtractor()

def test_feature_extraction_valid(extractor):
    img = np.random.rand(512, 512, 3).astype(np.float32)
    features = extractor.extract(img)
    assert len(features) == len(extractor.feature_names)
    assert not np.any(np.isnan(features))

def test_determinism(extractor):
    img = np.random.rand(512, 512, 3).astype(np.float32)
    f1 = extractor.extract(img)
    f2 = extractor.extract(img)
    assert np.array_equal(f1, f2)

def test_feature_names_match(extractor):
    img = np.random.rand(512, 512, 3).astype(np.float32)
    features = extractor.extract(img)
    assert len(features) == len(extractor.feature_names)
