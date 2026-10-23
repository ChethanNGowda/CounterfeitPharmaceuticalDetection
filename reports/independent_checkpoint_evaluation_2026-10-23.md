# Independent checkpoint evaluation (2026-10-23)

## Scope

Evaluated the configured `efficientnet_b0` checkpoint against all 839 rows in `data/splits/test_clean.csv`. This is the repository's labeled, duplicate-clean test set (555 authentic, 284 counterfeit), not 1,000 newly collected online photos. Each file was loaded from `data/processed/`, transformed with `ml.inference.predict.get_inference_transform`, and inferred with the configured checkpoint on CUDA. Class order is read from `ml.config.CLASS_NAMES`: index 0 authentic, index 1 counterfeit.

## Results

Confusion matrix (rows actual, columns predicted; authentic, counterfeit):

```text
[[553, 2],
 [  0, 284]]
```

Raw classifier accuracy was 837/839 (99.76%). Authentic recall was 99.64%; counterfeit recall was 100.00%. The pipeline's existing quality gate rejected 18/839 images (2.15%) before inference, so those images must receive no authenticity verdict. On the remaining 821 quality-accepted images, the classifier got 819 correct (99.76% conditional accuracy). This is a single held-out split result, not evidence that the system can chemically authenticate medicines or generalize to every medicine, package, camera, or supply chain.

## Errors inspected

- `test/authentic/IMG20231204183256_jpg.rf.ad8b4adc6c44087afcb6b4d143941f06.jpg`: labeled authentic, predicted counterfeit at 85.18% confidence. This is a package image rather than a close tablet-only image.
- `test/authentic/IMG_20251016_154125_702_jpg.rf.fee56c825940562d93509174c43b8818.jpg`: labeled authentic, predicted counterfeit at 57.20% confidence. This is also a package image.

These cases indicate dataset/model coverage limitations for packaging photos. No per-image override or weight change was made because that would hide the errors without validating a correction. The existing confidence policy should send the second case for manual review; the first remains a high-confidence false counterfeit and needs more representative, reliably labeled packaging data and retraining before a defensible fix.

## Online image data limitation

Public image sources found do not supply a 1,000-image ground-truth counterfeit/authentic set suitable for this test. The DEA page provides a small awareness collection of described authentic/counterfeit examples, while the NLM C3PI/RxIMAGE collection is for pill identification and contains no counterfeit labels. Unlabeled web images cannot be scored as correct or incorrect, so they were not counted as validation examples.
