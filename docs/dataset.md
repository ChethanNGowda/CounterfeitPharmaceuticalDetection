# Dataset Documentation

## Overview
This dataset contains images of pharmaceutical tablets for classification.

## Structure
The source CreateML/Roboflow dataset is preserved outside the repository. The prepared classification dataset is stored as:

- `data/processed/train/authentic/`
- `data/processed/train/counterfeit/`
- `data/processed/valid/authentic/`
- `data/processed/valid/counterfeit/`
- `data/processed/test/authentic/`
- `data/processed/test/counterfeit/`

The current experiment has two visual classes only: `authentic` and `counterfeit`. Low-confidence predictions are reported as `NEEDS MANUAL REVIEW`; this is a review status, not a third trained class.

The preparation script preserves the original Roboflow split. Mixed-label images and files without annotations are excluded from whole-image classification and recorded in `data/metadata/createml_audit.json`.

## Metadata
Each image is processed into a 36-dimensional feature vector saved in `data/processed/features.csv`.

## Splitting
- 70/15/15 split using `GroupShuffleSplit` to prevent sample leakage based on `sample_id`.
- The PyTorch pipeline writes group-disjoint `train.csv`, `validation.csv`, and `test.csv` files under `data/splits/`.
