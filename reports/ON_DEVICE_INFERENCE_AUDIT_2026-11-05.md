# On-device inference audit

**Date:** 2026-11-05  
**Repository:** `ChethanNGowda/CounterfeitPharmaceuticalDetection`  
**Scope:** EfficientNet-B0 inspection, Python reference inference, and Android conversion readiness.

## Phase 1: model inspection

The available fine-tuned checkpoint is:

```text
external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt
```

| Property | Verified value |
|---|---|
| File size | 16,319,845 bytes (15.6 MiB) |
| SHA-256 | `50d6b874e3fc59f4ac36bf836e7384b82c1d449108f64a55f8760dba05469f68` |
| Architecture | TorchVision EfficientNet-B0 |
| Checkpoint fields | `model_state_dict`, `model`, `class_names`, `seed` |
| Class mapping | index 0 `authentic`, index 1 `counterfeit` |
| Input | RGB, 224×224 |
| Normalization | ImageNet mean `(0.485, 0.456, 0.406)`, std `(0.229, 0.224, 0.225)` |
| Decision policy | authentic probability `<0.50` counterfeit indication; `0.50–0.70` review; `>0.70` authentic indication |
| Device used | CPU |

The checkpoint loaded successfully with `torch.load(..., weights_only=True)`.
The Python inference path uses the same architecture and preprocessing as the
backend classifier.

## Python reference predictions

These are reference outputs from `ml.inference.predict.predict` using the
current checkpoint and `quality_check=True`; they are not Android results.

| Image | Prediction | Authentic probability | Status | Quality |
|---|---|---:|---|---|
| `test_images/sample_authentic_c3pi.jpg` | AUTHENTIC | 0.8720 | AUTHENTIC | valid |
| `test_images/sample_counterfeit.jpg` | COUNTERFEIT | 0.0000 | COUNTERFEIT | valid |
| `test_images/medicine1.jpg` | AUTHENTIC | 0.7871 | AUTHENTIC | valid |
| `test_images/medicine1_mild_blur.jpg` | UNKNOWN | 0.0000 | NEEDS MANUAL REVIEW | invalid quality |
| `test_images/medicine1_compressed.jpg` | AUTHENTIC | 0.6226 | NEEDS MANUAL REVIEW | valid |
| `test_images/sample_non_tablet_ood.jpg` | COUNTERFEIT | 0.3299 | COUNTERFEIT | valid |

## Phase 2 blocker

The Flutter application currently declares no TensorFlow Lite, ONNX Runtime
Mobile, ExecuTorch, or other Android inference runtime. The current Python
environment also has no `onnx`, `onnxruntime`, TensorFlow, LiteRT, or
`onnx2tf` package available for a conversion attempt. The `.pt` checkpoint is
therefore not an Android-loadable model artifact.

No conversion, quantization, or local prediction implementation was added.
This is intentional: enabling local AI without a validated conversion/runtime
would silently substitute an unvalidated provider and could fabricate or
mismatch screening results.

Offline-only mode remains useful for local image selection, notes, history, and
reports, but it explicitly reports that AI screening is unavailable. Automatic
and backend-preferred modes continue to use the configured FastAPI service.

## Validation status

- Python checkpoint load: passed.
- Python reference inference: passed for the six listed images.
- Flutter analysis: passed.
- Flutter tests: 46 passed.
- Android debug APK: built; local build size was 170,464,921 bytes.
- Android model conversion: not performed because the required runtime/export
  toolchain is unavailable.
- Android local inference parity: not performed.
- Physical-device offline AI validation: not performed.
- Local inference latency and memory: not measured because no local runtime
  exists.

Before enabling offline AI, a future phase must select and add a supported
runtime, convert the exact checkpoint, compare representative Android outputs
with these Python references, and validate on the available physical device
with network access disabled.
