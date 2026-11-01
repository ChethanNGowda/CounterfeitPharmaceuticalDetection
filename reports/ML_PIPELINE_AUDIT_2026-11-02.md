# Machine-learning pipeline audit

**Audit date:** 2026-11-02  
**Repository:** `ChethanNGowda/CounterfeitPharmaceuticalDetection`  
**Scope:** Manifests, labels, split separation, duplicate/leakage evidence, preprocessing, training/evaluation code, metrics, model artifacts, and Grad-CAM.

## Verified manifest counts

The binary manifests under `data/splits/` resolve against `data/processed/` and all referenced files currently exist:

| Manifest | Authentic | Counterfeit | Total |
|---|---:|---:|---:|
| `train.csv` | 2,500 | 1,350 | 3,850 |
| `validation.csv` | 558 | 292 | 850 |
| `test.csv` | 558 | 286 | 844 |
| `test_clean.csv` | 555 | 284 | 839 |

`data/pharmassist_splits/` is a separate 53-class medicine-identity dataset with 4,382 train, 307 validation, and 308 test rows. It is not the binary counterfeit/authentic manifest consumed by `ml/training/data.py`.

## Leakage and separation

- Manifest `group_id` values have zero train/validation, train/test, and validation/test overlap in the current binary manifests.
- The existing SHA-256 audit found **12 exact duplicate groups crossing the original splits** (7 train/validation and 5 train/test). These are documented in `reports/duplicate_leakage_audit.md`.
- `test_clean.csv` removes the 5 exact duplicate test files and has zero SHA-256 overlap with train or validation.
- The audit found **184 cross-split perceptual-hash candidates**. They are candidates, not proven duplicates, and remain in the clean evaluation by explicit policy. Clean-test metrics must therefore not be described as fully near-duplicate-free.

## Preprocessing and training

- Training uses ImageNet normalization with random crop/flip/rotation/color jitter.
- Validation and test use deterministic resize/center-crop normalization.
- `ml/training/train.py` seeds Python and Torch through `seed_everything`; the default seed is 42 and is stored in checkpoint metadata.
- Split creation uses `GroupShuffleSplit` and retries seeds until every split contains both classes.
- The test split is loaded only for final evaluation in the training script; validation loss selects the checkpoint.
- No retraining or data download was performed for this audit.

## Evaluation and artifacts

Available fine-tuned artifact (deployment-format checkpoint; it has `model`, `class_names`, `seed`, and `model_state_dict` fields but no full evaluation metadata):

- EfficientNet-B0: `external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt`

The evaluation loader accepts both this deployment checkpoint shape and the richer training checkpoint shape, but no current metric was generated from it during this audit because the required pretrained/evaluation configuration was not recorded alongside the artifact.

Fine-tuned comparison artifacts unavailable in the current checkout:

- MobileNetV3-Large
- Baseline CNN
- GoldFormer

Their historical metrics must remain labeled historical/unavailable rather than reproduced current results. The existing clean-test report contains only classification metrics and still inherits the retained near-duplicate-candidate limitation.

Evaluation now records ROC-AUC and PR-AUC only when binary targets and probability scores are available. Missing classes do not produce fabricated AUC values.

## Grad-CAM

`ml/evaluation/explainability.py` loads the requested registered checkpoint, applies the same 224x224 RGB ImageNet normalization used by inference, targets the deepest convolutional feature layer, and generates a heatmap from the selected model output. Grad-CAM is available only for models with a supported convolutional target layer; unavailable checkpoints fail rather than substituting another model.

## Prioritized follow-up

### P0

- None verified.

### P1

- Rebuild/group a future evaluation split after manual review of the 184 perceptual-hash candidates before making generalization claims.
- Run separate validated evaluations for comparison architectures only after their fine-tuned checkpoints are actually present.
- Pin and record the full runtime dependency lock (including Torch/torchvision) for reproducible metric reproduction.

### P2

- Add a manifest provenance field linking each evaluation report to its exact CSV and checkpoint SHA-256.
- Add automated Grad-CAM smoke tests using a small synthetic convolutional model.
- Replace legacy scripts that use `weights_only=False` with safe checkpoint loading where their file formats permit it.
