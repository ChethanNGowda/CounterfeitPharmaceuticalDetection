# Dataset Documentation

## Overview
This dataset contains images of pharmaceutical tablets for classification.

## Structure
- `data/raw/authentic/`: Genuine tablet images.
- `data/raw/counterfeit/`: Suspicious tablet images.

## Metadata
Each image is processed into a 36-dimensional feature vector saved in `data/processed/features.csv`.

## Splitting
- 70/15/15 split using `GroupShuffleSplit` to prevent sample leakage based on `sample_id`.
