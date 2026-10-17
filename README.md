# Counterfeit Pharmaceutical Detection

**Image-Based Pharmaceutical Screening with Deep Learning and Vision-Language Verification**

> ⚠️ **Screening system only.** This tool flags suspicious samples for further investigation. It does not perform chemical analysis and cannot confirm or deny the identity of active pharmaceutical ingredients. A positive screen is not a laboratory result.

---

## Problem Statement

Counterfeit medicines are a global public-health threat. Visual differences between genuine and counterfeit tablets — such as irregular coatings, incorrect imprints, inconsistent coloration, or non-standard shapes — can be too subtle for reliable unaided inspection, especially at scale.

This project provides an **image-based screening approach** that uses a smartphone photograph and machine learning to flag samples warranting closer examination. It is designed as a decision-support tool, not a replacement for laboratory authentication.

---

## How It Works

A photograph of a pharmaceutical tablet is submitted to a two-stage AI pipeline:

```
Phone / Image Input
        │
        ▼
 Image Validation (format, file integrity)
        │
        ▼
 OpenCV Quality Gate
 (resolution, blur, brightness)
        │
        ▼
 EfficientNet-B0  ← fine-tuned pharmaceutical classifier
        │
        ▼
 Confidence Gate
 ┌──────────────────────────────────────────────┐
 │  confidence < 0.70                           │
 │  → SUSPICIOUS / NEEDS VERIFICATION          │
 │  (low primary confidence, manual review)    │
 │                                              │
 │  0.70 ≤ confidence < 0.90                   │
 │  → QwenVisionVerifier (qwen3-vl:4b)         │
 │    inspects the actual image                 │
 │                                              │
 │  confidence ≥ 0.90                           │
 │  → High-confidence fast path                │
 │    (Qwen skipped in auto mode)              │
 └──────────────────────────────────────────────┘
        │
        ▼
 DecisionEngine  ← single authoritative verdict
        │
        ▼
 Final Result
```

### Final result states

| Result | Meaning |
|---|---|
| `LIKELY AUTHENTIC` | Primary classifier and (if run) secondary vision agree the sample appears consistent with authentic characteristics. |
| `LIKELY COUNTERFEIT` | One or both classifiers indicate characteristics inconsistent with authentic samples. |
| `SUSPICIOUS / NEEDS VERIFICATION` | Conflicting evidence, low confidence, or image quality failure — manual laboratory verification is required. |

`needs_human_verification: true` is set whenever the result is not a clear high-confidence authentic determination, or when the secondary verifier and primary classifier disagree.

### Qwen3-VL is a secondary verifier, not the primary classifier

Qwen3-VL inspects the **actual image** — it is not given only JSON metadata. It provides a supporting opinion when the primary EfficientNet-B0 confidence falls in the borderline zone (0.70–0.90). If Qwen3-VL is unavailable or times out, the system degrades safely and returns the primary classifier result with an explicit warning.

---

## Model Performance

### EfficientNet-B0 (Primary Classifier — Production)

Evaluated on a **clean, deduplicated test split** (839 images — 5 exact train/test duplicates removed):

| Metric | Value |
|---|---|
| Accuracy | **99.64%** |
| Precision | 99.56% |
| Recall | 99.64% |
| Macro F1 | **99.60%** |
| F1 — Authentic | 99.73% |
| F1 — Counterfeit | 99.47% |
| Test split size | 839 images (555 authentic, 284 counterfeit) |

Confusion matrix on clean test split:

```
                  Predicted
                  Authentic  Counterfeit
Actual Authentic     553          2
Actual Counterfeit     1        283
```

Benchmark evaluation on the full test split (827 images, 0 cross-split duplicates):

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC | Params | Latency |
|---|---:|---:|---:|---:|---:|---:|---:|
| **EfficientNet-B0** | **99.88%** | 99.65% | **100.00%** | **99.82%** | **0.9993** | 4.0M | 35 ms |
| MobileNetV3-Large | 99.40% | 99.29% | 98.93% | 99.11% | 0.9993 | 4.2M | 22 ms |
| GoldFormer | 99.27% | 97.91% | 100.00% | 98.94% | 0.9993 | 54.3M | 146 ms |
| Baseline CNN | 86.58% | 74.57% | 91.81% | 82.30% | 0.9456 | 94K | 21 ms |

> Source: [`reports/model_comparison.md`](reports/model_comparison.md), [`reports/clean_test_metrics.json`](reports/clean_test_metrics.json)

### EfficientNet-B0 — Preprocessing

| Property | Value |
|---|---|
| Input size | 224 × 224 |
| Colour space | RGB |
| Normalization | ImageNet (mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]) |
| Checkpoint | `outputs/full_data_training/checkpoints/20260922_183414_efficientnet_b0/best.pt` |
| Classification threshold | 0.70 |
| High-confidence threshold | 0.90 |

### Secondary Verifier — Qwen3-VL (`qwen3-vl:4b`)

Qwen3-VL is a **vision-language model** that inspects the actual pharmaceutical image. It is invoked only for borderline-confidence predictions (0.70 ≤ confidence < 0.90 in `auto` mode). It runs locally via [Ollama](https://ollama.com) and does not send images to external servers.

---

## Dataset

| Split | Images | Authentic | Counterfeit |
|---|---:|---:|---:|
| Train | — | — | — |
| Validation | — | — | — |
| Test | 844 | 558 | 286 |
| Test (clean, dedup) | 839 | 555 | 284 |

Manifests: `data/splits/{train,validation,test,test_clean}.csv`

Duplicate and near-duplicate leakage was audited at training time. 5 exact cross-split duplicates were identified and removed from the clean test split. The trained checkpoint was not modified. See [`reports/duplicate_leakage_audit.md`](reports/duplicate_leakage_audit.md) and [`reports/clean_test_evaluation.md`](reports/clean_test_evaluation.md).

---

## Quick Start

### Prerequisites

```bash
pip install -r requirements.txt
```

For secondary Qwen3-VL verification, install [Ollama](https://ollama.com) and pull the model:

```bash
ollama pull qwen3-vl:4b
```

### CLI — Single Image

```bash
# Auto mode: Qwen3-VL invoked for borderline confidence [0.70, 0.90)
python test.py test_images/sample_authentic_c3pi.jpg

# Always run Qwen3-VL secondary verification
python test.py image.jpg --vision-mode always

# Fast path: skip Qwen3-VL
python test.py image.jpg --vision-mode never
python test.py image.jpg --no-vision   # alias
```

### FastAPI Backend

```powershell
# Start production API server on Windows
.venv\Scripts\uvicorn.exe backend.app.main:app --host 127.0.0.1 --port 8000

# Interactive Swagger UI documentation
http://127.0.0.1:8000/docs
```

Endpoints:

| Method | Path | Response Type | Description |
|---|---|---|---|
| `GET` | `/` | `ApiInfoResponse` | Basic API information, supported models, and usage guidance |
| `GET` | `/health` | `HealthResponse` | Operational health check, active device, and Ollama status |
| `POST` | `/predict` | `PredictionResponse` | Upload tablet image, receive dual-model screening report |
| `POST` | `/verify` | `PredictionResponse` | Fully compatible alias for `/predict` |

#### Upload Constraints
- **Max File Size:** 15 MB (enforced with HTTP 413)
- **Supported Formats:** JPEG, PNG, WEBP, BMP (enforced with HTTP 415)
- **Quality Requirements:** Minimum 64×64 px, blur variance ≥ 50.0, brightness 15–245

#### Example Request (PowerShell)
```powershell
curl.exe -X POST "http://127.0.0.1:8000/predict" `
  -F "file=@test_images/sample_authentic_c3pi.jpg" `
  -F "vision_mode=auto"
```

#### Example Prediction Response
```json
{
  "primary_model": "efficientnet_b0",
  "prediction": "AUTHENTIC",
  "confidence": 0.872,
  "final_result": "LIKELY AUTHENTIC",
  "needs_human_verification": false,
  "status": "AUTHENTIC",
  "secondary_executed": false,
  "secondary_reason": "Skipped: secondary verification disabled by vision mode 'never'",
  "visual_analysis": {
    "color": {
      "dominant_color": "Light Pink",
      "average_rgb": [212.4, 185.1, 192.3],
      "consistency": "Uniform"
    },
    "shape": { "shape_type": "Round / Circular", "circularity": 0.88 },
    "edges": { "edge_integrity": "Intact", "cracks": "None detected" },
    "packaging": { "status": "Single Tablet / No Blister" }
  },
  "disclaimer": "AI-assisted preliminary screening only. Visual and convolutional appearance analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), or bioequivalence."
}
```

### Run Tests

```powershell
.venv\Scripts\python.exe -m pytest -q
```

Current Test Status: **143 passed / 0 failed / 0 skipped** (100% pass rate in ~19s)

---

## 80% Project Completion Milestone

| Component / Deliverable | Status | Weight | Progress | Notes |
|---|:---:|:---:|:---:|---|
| **Dataset Curation & Deduplication** | **Completed** | 15% | 15% / 15% | 68,988 collected, 10,551 clean, 5,512 leakage-controlled split |
| **Primary Classifier (EfficientNet-B0)** | **Completed** | 20% | 20% / 20% | 99.88% test accuracy, 100% recall on held-out test split |
| **Comparative Benchmarking** | **Completed** | 10% | 10% / 10% | MobileNetV3-Large (99.40%), GoldFormer (99.27%), Baseline CNN (86.58%) |
| **Image Quality & Visual Inspection** | **Completed** | 10% | 10% / 10% | Resolution, blur, exposure gates + 17 color centroids inspector |
| **Secondary AI Verification (Ollama)** | **Completed** | 10% | 10% / 10% | qwen3-vl:4b vision verifier + qwen3:8b evidence reviewer |
| **Conservative Decision Engine** | **Completed** | 5% | 5% / 5% | 4 deterministic rules, 0.70 & 0.90 thresholds, conflict safety |
| **FastAPI Backend & API Contract** | **Completed** | 10% | 10% / 10% | GET /, GET /health, POST /predict, POST /verify, validation |
| **Automated Testing Suite** | **Completed** | 5% | 5% / 5% | 143 tests passing across unit, integration, and API suites |
| **Frontend Mobile/Web GUI** | *Planned* | 10% | 0% / 10% | User-facing mobile / web camera interface |
| **OCR & GS1 Barcode Verification** | *Planned* | 5% | 0% / 5% | Packaging NDC text extraction & 2D DataMatrix scanning |
| **Production Docker Deployment** | *Planned* | 5% | 0% / 5% | Containerized cloud/edge packaging and rate-limiting |
| **TOTAL** | **MILESTONE REACHED** | **100%** | **85% / 100%** | **Core ML & API complete; exceeds 80% milestone** |

---

## Project Structure

```
.
├── ml/
│   ├── config.py                  # Thresholds, paths, checkpoint registry
│   ├── inference/
│   │   └── predict.py             # predict() + predict_pipeline() — production inference
│   ├── models/
│   │   └── transfer_learning.py   # EfficientNet-B0 / MobileNetV3 loader
│   ├── preprocessing/
│   │   ├── quality_checker.py     # OpenCV image quality gate (production)
│   │   └── image_preprocessor.py  # [LEGACY] 512×512 CLAHE pipeline — NOT used in inference
│   ├── verification/
│   │   ├── decision_engine.py     # Authoritative verdict synthesis
│   │   ├── qwen_verifier.py       # QwenVisionVerifier — production (qwen3-vl:4b)
│   │   └── qwen_reviewer.py       # [LEGACY] QwenReviewer — text-evidence reviewer (qwen3:8b)
│   ├── features/                  # [LEGACY] Hand-crafted colour/texture/shape features
│   ├── evaluation/                # Evaluation scripts and metrics
│   └── training/                  # Training pipeline
├── backend/
│   └── app/                       # FastAPI application
├── tests/                         # Pytest test suite (125 tests)
├── scripts/                       # Dataset preparation and evaluation utilities
├── data/splits/                   # Dataset manifests (CSV)
├── outputs/                       # Model checkpoints
├── reports/                       # Evaluation reports and metrics
└── test_images/                   # Sample images for manual testing
```

---

## Architecture Notes

### Single decision authority

`DecisionEngine.evaluate()` is the only place where final verdicts are computed. `predict_pipeline()` calls it; nothing else constructs verdicts independently.

### Missing checkpoint safety

`load_classifier()` raises `CheckpointUnavailableError` if a requested fine-tuned checkpoint does not exist on disk. Generic ImageNet pretrained weights are never silently used as pharmaceutical classifiers.

### Qwen3-VL graceful degradation

If Qwen3-VL times out or is unavailable, the pipeline returns the primary classifier result with `needs_human_verification: True` and an explicit warning. No inference is blocked by Qwen3-VL availability.

---

## Limitations and Intended Use

- This system is a **screening tool**, not a laboratory instrument.
- It cannot detect chemical substitutions, dosage fraud, or contamination that does not produce visible surface differences.
- High model confidence does not constitute a certificate of authenticity.
- Results should be used to **prioritise samples for laboratory testing**, not to replace it.
- Performance on in-the-wild smartphone images may differ from the controlled-capture training dataset.

---

## Acknowledgements

Dataset images sourced from publicly available pharmaceutical image collections. EfficientNet-B0 and MobileNetV3-Large architectures via [torchvision](https://github.com/pytorch/vision). Secondary vision verification via [Ollama](https://ollama.com) and [Qwen3-VL](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct).
