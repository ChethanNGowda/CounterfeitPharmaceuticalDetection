# Model and dataset notes

## Available inference

The current supported backend pharmaceutical inference checkpoint is
EfficientNet-B0 at
`external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt`.
The project audit records its class order as `authentic`, `counterfeit`, and
224x224 RGB ImageNet-normalized input. The inference implementation and
checkpoint registry are authoritative. No Android inference runtime or
converted checkpoint is included; offline AI screening is unavailable.

MobileNetV3-Large, Baseline CNN and GoldFormer are registered architectures,
but the current checkpoint audit marks their fine-tuned pharmaceutical
checkpoints unavailable. Registration does not mean usable trained model.

## Evaluation

The repository contains historical evaluation outputs, including
`reports/model_comparison.md` and independent checkpoint audits. These results
are bounded to their recorded dataset split, artifacts, and evaluation code.
They are not clinical evaluation, prospective field validation, regulatory
approval, calibration evidence, or a guarantee on new products or cameras.
This documentation does not repeat benchmark percentages as product claims.
See `reports/` for source manifests, evaluation outputs, and audit dates before
reproducing a result.

## Image processing and explanations

The Python service validates file type/size, decodes the image, performs the
existing quality checks, resizes and normalizes to the model contract, then
returns a preliminary classifier outcome. Quality thresholds and model
decision policy are implemented in `ml/` and should only change after
validation. Grad-CAM is available in the research/evaluation path where the
model supports it. A heatmap indicates regions influencing a model output; it
does not reveal ingredients or counterfeit evidence.

## Research references

- Tan, M. and Le, Q. V. “EfficientNet: Rethinking Model Scaling for
  Convolutional Neural Networks.” ICML 2019. [PMLR paper](https://proceedings.mlr.press/v97/tan19a.html).
- Howard, A. et al. “Searching for MobileNetV3.” ICCV 2019.
  [CVF paper](https://openaccess.thecvf.com/content_ICCV_2019/html/Howard_Searching_for_MobileNetV3_ICCV_2019_paper.html).
- Selvaraju, R. R. et al. “Grad-CAM: Visual Explanations from Deep Networks
  via Gradient-Based Localization.” ICCV 2017.
  [CVF paper](https://openaccess.thecvf.com/content_ICCV_2017/papers/Selvaraju_Grad-CAM_Visual_Explanations_ICCV_2017_paper.pdf).
- Google ML Kit. “Text recognition v2.”
  [Developer documentation](https://developers.google.com/ml-kit/vision/text-recognition/v2).
