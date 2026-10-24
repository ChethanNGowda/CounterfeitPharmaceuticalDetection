# Counterfeit Pharmaceutical Detection

> Historical audit: some benchmark and inventory sections below describe earlier artifact locations. The current model directory structure and local checkpoint availability are documented in `external_models/PharmaAssist/README.md`.

## Final Project Audit & Technical Report

---

### 1. Project Overview

The **Counterfeit Pharmaceutical Detection** project is an artificial intelligence-assisted screening and triage system engineered to detect counterfeit prescription and over-the-counter medicine tablets from smartphone imagery. Counterfeit pharmaceuticals represent a severe global public health hazard, causing hundreds of thousands of preventable fatalities and massive economic losses annually.

This project implements a multi-stage, conservative screening pipeline designed to differentiate between:
- **Authentic** medicine samples,
- **Counterfeit** medicine samples, and
- **Suspicious / Needs Verification** samples requiring mandatory physical and laboratory chemical inspection.

The system combines:
1. An automated computer vision quality-screening layer (detecting blur, improper resolution, and extreme exposure).
2. A high-accuracy deep convolutional neural network (**EfficientNet-B0**) fine-tuned on standardized pharmaceutical images.
3. A secondary AI reasoning and review layer (**qwen3:8b** via local Ollama inference) that analyzes structured evidence from the primary classifier and image quality diagnostics to provide reasoned second-opinion evaluations.
4. A deterministic, conservative **Decision Engine** that handles model conflicts safely, preventing unverified claims of chemical genuineness from visual appearance alone.

> [!IMPORTANT]
> **Safety Notice:** AI-assisted preliminary screening only. Visual and convolutional appearance analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), or bioequivalence. Laboratory chemical testing remains the sole definitive standard.

---

### 2. Final Architecture

The end-to-end architecture is structured as a dual-pipeline screening system with fallback-safe execution:

```
                          Smartphone Tablet Image
                                    │
                                    ▼
                     OpenCV Quality & Format Precheck
              (Resolution ≥ 64x64, Blur Var ≥ 50, Brightness 15-245)
                                    │
                  ┌─────────────────┴─────────────────┐
                  │ [Pass Quality Checks]             │ [Fail Quality Checks]
                  ▼                                   ▼
      ┌───────────────────────┐         Direct Routing to:
      │ Preprocessing Layer   │         SUSPICIOUS / NEEDS VERIFICATION
      │ Resize (224x224),     │         (Reason: Poor Image Quality)
      │ ImageNet Mean/Std     │
      └───────────┬───────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │ EfficientNet-B0 (CNN) │
      │ Primary Visual        │
      │ Classifier            │
      │ (Outputs P_fake)      │
      └───────────┬───────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │ Evidence Builder      │
      │ Structures JSON:      │
      │ - Prediction & Probs  │
      │ - Confidence          │
      │ - Quality Diagnostics │
      └───────────┬───────────┘
                  │
                  ├───────────────────────────────────┐
                  ▼                                   ▼
      ┌───────────────────────┐         ┌───────────────────────────┐
      │ qwen3:8b (via Ollama) │         │ Ollama Offline / Timeout  │
      │ Secondary AI Reviewer │         │ Fallback Mode             │
      │ Returns: Assessment,  │         │ (Proceeds with primary    │
      │ Confidence, Reasoning │         │  classifier + warning)    │
      └───────────┬───────────┘         └─────────────┬─────────────┘
                  │                                   │
                  └─────────────────┬─────────────────┘
                                    ▼
                      ┌───────────────────────────┐
                      │     Decision Engine       │
                      │  Conservative Synthesis   │
                      │  Threshold T_conf = 0.70  │
                      └─────────────┬─────────────┘
                                    ▼
                           Final Output Payload
      - final_result: LIKELY AUTHENTIC | LIKELY COUNTERFEIT | SUSPICIOUS / NEEDS VERIFICATION
      - primary_model, prediction & confidence
      - qwen review details (available, assessment, confidence, reasoning, warning)
      - needs_human_verification (boolean)
      - Mandatory screening disclaimer
```

---

### 3. Models Used

#### 1. EfficientNet-B0 (Primary Model)
- **Role:** Primary deep feature classifier.
- **Weights:** Base initialized from ImageNet-1k pretrained backbone (`external_models/PharmaAssist/weights/pretrained/efficientnet_b0.pth`, 20.4 MB); trained checkpoint fine-tuned on the pharmaceutical dataset (`external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt`, 15.6 MB).
- **Parameters:** ~4.0M trainable parameters; lightweight, highly efficient for edge and server inference.
- **Contract:** Input resolution 224x224 RGB, output binary logits `[authentic, counterfeit]`.
- **Status:** **ACTIVE / PRIMARY CLASSIFIER**.

#### 2. MobileNetV3-Large (Comparison Benchmark)
- **Role:** Lightweight mobile-optimized architectural benchmark.
- **Weights:** Initialized from `external_models/PharmaAssist/weights/pretrained/mobilenet_v3_large.pth` (21.1 MB); fine-tuned checkpoint at `external_models/PharmaAssist/weights/checkpoints/mobilenet_v3_large/best.pt` (16.2 MB).
- **Parameters:** ~4.2M parameters.
- **Contract:** Input resolution 224x224 RGB, output binary logits `[authentic, counterfeit]`.
- **Status:** **ACTIVE / REGISTERED COMPARISON MODEL**.

#### 3. Baseline CNN (Architectural Baseline)
- **Role:** 3-layer convolutional network baseline (Conv-BN-ReLU-Pool $\times$ 3 + Dropout + Linear) to demonstrate the concrete performance gain provided by transfer learning backbones over vanilla CNNs.
- **Weights:** Self-supervised pretraining at `external_models/PharmaAssist/weights/pretrained/baseline_cnn.pt` (378 KB); fine-tuned checkpoint at `external_models/PharmaAssist/weights/checkpoints/baseline_cnn/best.pt` (375 KB).
- **Parameters:** ~94K parameters.
- **Status:** **ACTIVE / REGISTERED BASELINE MODEL**.

#### 4. GoldFormer / GoldNet (Cross-Domain Transfer Benchmark)
- **Role:** Exploration of cross-domain counterfeit detection transfer from high-value physical goods (gold coins/bars) to pharmaceutical tablets.
- **Architecture:** Hybrid ResNet50 convolutional backbone + Swin Transformer (Swin-T) branch fused with cross-attention.
- **Weights:** Original gold-domain weights at `external_models/GoldNet/weights/GoldFormer_best.pth` (207.7 MB); fine-tuned pharmaceutical checkpoint at `external_models/PharmaAssist/weights/checkpoints/goldformer/goldformer_pharmaceutical_best.pt` (207.7 MB).
- **Parameters:** 54,297,277 parameters.
- **Input/Output:** 224x224 RGB, 2 classes `[authentic, counterfeit]`.
- **Status:** **ACTIVE / EXPERIMENTAL RESEARCH COMPARISON**.

#### 5. qwen3:8b (Secondary AI Reasoning & Review Layer)
- **Role:** Secondary AI reasoning and review layer deployed locally via Ollama (`http://localhost:11434`).
- **Nature:** Text-based large language model (5.2 GB parameter weights). Does NOT receive raw image pixels; receives structured statistical evidence from the primary visual classifier and image quality precheck.
- **Function:** Analyzes classification probabilities, confidence margins, and quality metrics to provide a cautious second-opinion review with structured justifications.
- **Safety Boundary:** Never claims chemical certainty; outputs structured JSON with mandatory verification flags.
- **Status:** **ACTIVE / SECONDARY AI REVIEWER**.

---

### 4. Dataset

All figures below are strictly verified from `data/full_training/audit/full_manifest_report.json` and official manifest files:

| Dataset Metric | Verified Count | Description |
|---|---:|---|
| **Total Images Discovered** | **68,988** | Complete corpus under `data/` including raw repositories |
| - Raw C3PI Images | 48,312 | Raw NLM C3PI National Library of Medicine images |
| - C3PI Reference Set | 4,392 | Standardized authentic reference photographs |
| - PharmAssist Dataset | 4,997 | Indian market branded pharmaceutical tablets |
| - Counterfeit Dataset | 5,743 | Real and synthetic counterfeit tablet images (Roboflow/CreateML) |
| **Excluded Images** | **58,437** | Excluded near-duplicates (51,794) and unverified/ambiguous labels (1,683 + others) |
| **Total Pipeline Images** | **10,551** | Clean deduplicated pool ($5,512 + 5,039 = 10,551$) |
| - **Supervised Dataset (Leakage-Controlled)** | **5,512** | Formally split with zero group/SHA-256 overlap |
| &nbsp;&nbsp;&nbsp;&nbsp;• Authentic | 3,602 | 65.3% class distribution |
| &nbsp;&nbsp;&nbsp;&nbsp;• Counterfeit | 1,910 | 34.7% class distribution |
| - **Self-Supervised Pool** | **5,039** | Dedicated pool used for self-supervised pretraining |
| **Training Split** | **3,858** | Supervised training set (`data/full_training/train.csv`) |
| **Validation Split** | **827** | Model selection and checkpoint saving (`data/full_training/validation.csv`) |
| **Test Split** | **827** | Final held-out evaluation (`data/full_training/test.csv`) |
| **Classes** | **2** | Class 0: `authentic`, Class 1: `counterfeit` |

> [!NOTE]
> **Dataset Math Reconciliation:** The total pipeline image pool consists of exactly $5,512$ supervised images plus $5,039$ self-supervised images, totaling $10,551$ images ($5,512 + 5,039 = 10,551$). The previously cited "8,897" figure referred to an earlier intermediate pretraining pool before final deduplication.

#### Preprocessing & Normalization Contract
- **Input Dimensions:** 224 $\times$ 224 pixels (RGB, 3 channels).
- **Normalization:** ImageNet distribution parameters:
  $$\mu = [0.485, 0.456, 0.406], \quad \sigma = [0.229, 0.224, 0.225]$$
- **Data Augmentation (Training Only):**
  - Random horizontal flipping ($p = 0.5$)
  - Random affine rotation ($\pm 8^\circ$)
  - Color jitter (Brightness $\pm 0.15$, Contrast $\pm 0.15$, Saturation $\pm 0.10$)

---

### 5. Training

Training parameters verified from training history logs and `scripts/train_pipeline.py`:

- **Approach:** Supervised transfer learning with class-imbalance weighting.
- **Optimizer:** AdamW ($\beta_1 = 0.9, \beta_2 = 0.999$, weight decay = $1 \times 10^{-2}$).
- **Base Learning Rate:** $3 \times 10^{-4}$.
- **Batch Size:** 8 physical $\times$ 2 accumulation steps = **16 effective batch size**.
- **Loss Function:** PyTorch `CrossEntropyLoss` with class weights adjusting for 1.88:1 authentic-to-counterfeit ratio.
- **Maximum Epochs:** 20 epochs with early stopping (patience = 4 validation checks).
- **Actual Training Epochs:**
  - EfficientNet-B0: 5 epochs (Best validation checkpoint at epoch 5).
  - MobileNetV3-Large: 7 epochs.
  - Baseline CNN: 20 epochs.
  - GoldFormer: 4 epochs fine-tuning.

---

### 6. Results

All results verified directly from `outputs/full_data_training/metrics/` and `outputs/external_pretrained/goldformer/metrics/`:

#### Validation vs. Test Metrics Comparison

| Model | Val Acc | Val F1 | Test Acc | Precision | Recall | Specificity | Test F1 | ROC-AUC | PR-AUC |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **Baseline CNN** | 84.76% | 80.06% | **86.58%** | 74.57% | 91.81% | 83.88% | **82.30%** | 0.9456 | 0.9203 |
| **EfficientNet-B0** | 99.52% | 99.29% | **99.88%** | **99.65%** | **100.00%** | **99.82%** | **99.82%** | **0.9988** | **0.9951** |
| **MobileNetV3-Large** | 99.64% | 99.46% | **99.40%** | 99.29% | 98.93% | 99.63% | **99.11%** | 0.9994 | 0.9983 |
| **GoldFormer (Hybrid)** | 99.27% | 98.94% | **99.27%** | 97.91% | 100.00% | 98.90% | **98.94%** | 0.9993 | 0.9984 |

#### Confirmation of Reported Primary Results
The previously reported performance:
- **Test Accuracy: 99.88%** on the project's held-out test set of 827 images.
- **F1 Score: 99.82%** on the held-out test set.

**VERIFIED.** These figures correspond directly to the test evaluation of `external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt` on `data/full_training/test.csv`.

> [!NOTE]
> 99.88% is the statistical accuracy on the held-out evaluation set of 827 images under laboratory-like photography conditions. It does not represent real-world pharmaceutical authenticity accuracy across uncontrolled field environments.

#### Test Set Confusion Matrix (827 images: 546 Authentic, 281 Counterfeit)

```
EfficientNet-B0 Confusion Matrix:
                 Predicted Authentic    Predicted Counterfeit
True Authentic          545 (TN)                1 (FP)
True Counterfeit          0 (FN)              281 (TP)
```
- **False Negative Rate:** 0.00% (No counterfeit was misclassified as authentic).
- **False Positive Rate:** 0.18% (Only 1 authentic tablet out of 546 was flagged as counterfeit).

---

### 7. Secondary AI Reasoning & Review Layer (qwen3:8b)

#### Architectural Role & Separation of Concerns
`qwen3:8b` serves as an analytical reasoning reviewer over statistical classifier outputs. It is a text-based LLM and does **not** process raw image pixels directly. The primary visual perception is handled exclusively by **EfficientNet-B0**.

#### Evidence Pipeline Flow
1. Image is processed by `OpenCV` quality precheck (resolution, blur, brightness).
2. Image is evaluated by `EfficientNet-B0`, producing softmax probabilities for `authentic` and `counterfeit`.
3. `build_evidence_payload()` converts classifier findings into structured JSON:
   ```json
   {
     "model": "efficientnet_b0",
     "prediction": "authentic",
     "authentic_probability": 0.872,
     "counterfeit_probability": 0.128,
     "confidence": 0.872,
     "image_quality": "good",
     "quality_checks": {
       "resolution_ok": true,
       "blur_ok": true,
       "brightness_ok": true
     }
   }
   ```
4. The payload is submitted to `http://localhost:11434/api/generate` with strict JSON schema instructions.
5. `qwen3:8b` evaluates the evidence and returns a structured second-opinion assessment.

#### Structured Output Contract
```json
{
  "assessment": "AUTHENTIC | COUNTERFEIT | SUSPICIOUS",
  "confidence": 0.0 to 1.0,
  "reasoning": [
    "Statistical evidence is consistent with authentic reference distribution.",
    "Confidence margin exceeds screening threshold."
  ],
  "needs_human_verification": false,
  "warning": "Visual analysis cannot establish chemical authenticity."
}
```

#### Fault Tolerance & Fallback Design
The `QwenReviewer` class implements comprehensive error handling:
- **HTTP 404 (Model Not Found):** Flags `available = False`, records error, returns safe fallback.
- **URLError / Network Refusal:** Ollama daemon offline handled gracefully without crashing the app.
- **Timeout (default 20.0s):** Aborts slow requests and falls back to primary classifier results.
- **Malformed / Non-JSON output:** Sanitizes markdown code fences; falls back to `SUSPICIOUS` if unparseable.
- **Fallback message:** `"Secondary AI verification unavailable — result based on primary classifier."`

---

### 8. Decision Engine

The **Decision Engine** (`ml/verification/decision_engine.py`) enforces a deterministic 4-rule conservative screening policy (confidence threshold $T = 0.70$):

| Rule | Trigger Condition | Primary Prediction | Qwen Assessment | Synthesized Final Result | Needs Human Verification | Rationale |
|---|---|---|---|---|:---:|---|
| **Rule 1** | Image quality check failed | Any | Any | `SUSPICIOUS / NEEDS VERIFICATION` | **True** | Severe blur, tiny resolution, or extreme exposure invalidates CNN features. Sample rejected. |
| **Rule 2** | Low confidence ($< 0.70$) | Any | Any | `SUSPICIOUS / NEEDS VERIFICATION` | **True** | Model uncertainty indicates borderline features; requires manual inspection. |
| **Rule 3A** | High confidence + Qwen agreed | Authentic | AUTHENTIC | `LIKELY AUTHENTIC` | **False** | Both primary classifier and secondary AI corroborate authentic findings. |
| **Rule 3B** | High confidence + Qwen agreed | Counterfeit | COUNTERFEIT | `LIKELY COUNTERFEIT` | **True** | Both models indicate counterfeit characteristics. Sample quarantined. |
| **Rule 3C** | High confidence + Qwen suspicious | Any | SUSPICIOUS | `SUSPICIOUS / NEEDS VERIFICATION` | **True** | Secondary reviewer flagged borderline evidence or quality caveats. |
| **Rule 3D** | High confidence + Conflict | Authentic | COUNTERFEIT | `SUSPICIOUS / NEEDS VERIFICATION` | **True** | Model disagreement triggers mandatory physical review. |
| **Rule 3E** | High confidence + Conflict | Counterfeit | AUTHENTIC | `SUSPICIOUS / NEEDS VERIFICATION` | **True** | Model disagreement triggers mandatory physical review. |
| **Rule 4A** | High confidence + Qwen offline | Authentic | Unavailable | `LIKELY AUTHENTIC` | **False** | Fallback to primary classifier; warning attached to response. |
| **Rule 4B** | High confidence + Qwen offline | Counterfeit | Unavailable | `LIKELY COUNTERFEIT` | **True** | Fallback to primary classifier; warning attached to response. |

---

### 9. Backend & API Contract

The backend is implemented with **FastAPI** (`backend/app/main.py`):

#### Endpoints

1. **`GET /health`** (and `GET /`)
   - Returns service operational status, active device, loaded models, and secondary AI configuration:
   ```json
   {
     "status": "ok",
     "version": "1.0.0",
     "device": "cpu",
     "default_model": "efficientnet_b0",
     "available_models": ["efficientnet_b0", "mobilenet_v3_large", "baseline_cnn", "goldformer"],
     "secondary_ai_model": "qwen3:8b",
     "secondary_ai_endpoint": "http://localhost:11434"
   }
   ```

2. **`POST /predict`** and **`POST /verify`**
   - **Method:** `POST` (multipart/form-data)
   - **Parameters:**
     - `file`: Image file (JPEG, PNG, WEBP, BMP)
     - `threshold`: Optional float (default: `0.70`)
     - `model`: Optional string (default: `"efficientnet_b0"`)
     - `enable_qwen`: Optional boolean (default: `true`, alias: `enable_vision`)
   - **Response Payload:**
   ```json
   {
     "primary_model": "efficientnet_b0",
     "prediction": "COUNTERFEIT",
     "confidence": 0.9981,
     "qwen": {
       "available": true,
       "assessment": "COUNTERFEIT",
       "confidence": 0.95,
       "reasoning": [
         "High counterfeit probability (99.81%) reported by primary classifier.",
         "Evidence indicates packaging/appearance anomaly."
       ],
       "needs_human_verification": true,
       "warning": "Visual analysis cannot establish chemical authenticity."
     },
     "final_result": "LIKELY COUNTERFEIT",
     "needs_human_verification": true,
     "warning": "Evidence indicates counterfeit medicine. Quarantine sample.",
     "status": "COUNTERFEIT",
     "reason": "Both primary visual classifier and secondary AI review indicate counterfeit characteristics.",
     "model_name": "efficientnet_b0",
     "threshold": 0.70,
     "authentic_probability": 0.0019,
     "counterfeit_probability": 0.9981,
     "quality": {
       "is_valid": true,
       "blur_score": 142.5,
       "brightness_mean": 128.4,
       "dimensions": [224, 224]
     },
     "disclaimer": "AI-assisted preliminary screening only. Visual and convolutional appearance analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), or bioequivalence. Laboratory chemical testing remains the sole definitive standard."
   }
   ```

---

### 10. Complete Model Inventory & Checksum Hashes

All model weights and fine-tuned checkpoints have been verified with SHA256 cryptographic hashes:

| Model Architecture | Artifact Type | File Path | File Size | SHA256 Checksum |
|---|---|---|---:|---|
| **EfficientNet-B0** | Base Weights | `external_models/PharmaAssist/weights/pretrained/efficientnet_b0.pth` | 20.4 MB | `7f5810bc96def8f7552d5b7e68d53c4786f81167d28291b21c0d90e1fca14934` |
| **EfficientNet-B0** | Fine-Tuned Checkpoint | `external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt` | 15.6 MB | `50d6b87446545b74c4a45610e2d14cb80927956799052d9a6cbf84cb84e1b9b9` |
| **MobileNetV3-Large** | Base Weights | `external_models/PharmaAssist/weights/pretrained/mobilenet_v3_large.pth` | 21.1 MB | `5c1a416349c4cf298f2a6a5e2600ed0ee55e604713578f5e74e6bc8bcaef7997` |
| **MobileNetV3-Large** | Fine-Tuned Checkpoint | `external_models/PharmaAssist/weights/checkpoints/mobilenet_v3_large/best.pt` | 16.2 MB | `58d1c5a5ff79199d794685ff8a6f44d18fa7b2a65f57788426176378c257321e` |
| **Baseline CNN** | Pretrained Checkpoint | `external_models/PharmaAssist/weights/pretrained/baseline_cnn.pt` | 378 KB | `a90688856bc0a8677c7c34b8c66a4bc2c8d234bafe66db88ff96387063d91cf9` |
| **Baseline CNN** | Fine-Tuned Checkpoint | `external_models/PharmaAssist/weights/checkpoints/baseline_cnn/best.pt` | 375 KB | `3b4c3ce3fa446506d2003cffeb426e257ef9a622a5509744c69818ae504958f3` |
| **GoldFormer** | Domain Base Weights | `external_models/GoldNet/weights/GoldFormer_best.pth` | 207.7 MB | `9544e642cbe86064f7dfa7322a30ca4d9a3b2b51ee2bc36bba7130206277b21e` |
| **GoldFormer** | Fine-Tuned Checkpoint | `external_models/PharmaAssist/weights/checkpoints/goldformer/goldformer_pharmaceutical_best.pt` | 207.7 MB | `576add1a26b28d6fa8e95085e933446059b02a7b8ea01997d5a570081d0be64d` |
| **qwen3:8b** | Ollama Model Weights | Local Ollama manifest (`qwen3:8b`) | 5.2 GB | Managed via local Ollama daemon |

---

### 11. Automated Test Suite Verification

The complete automated test suite runs under pytest (`pytest tests/ -v`):

```
========================= 92 passed, 10 warnings in 57.65s =========================
Pass Rate: 100% (92 of 92 tests passing)
Failures:  0
```

#### Test Suite Breakdown

| Test File | Test Count | Scope & Components Verified |
|---|---:|---|
| `tests/test_api.py` | 9 | `/health`, `/predict`, `/verify`, error codes (400, 415), high threshold fallback, dual-model contract schema, and secondary AI config reporting |
| `tests/test_decision_engine.py` | 16 | Conservative Decision Engine rules: quality failure, low confidence threshold, authentic/counterfeit agreement, conflict handling, qwen unavailable fallback, output key invariants, and helper function wrappers |
| `tests/test_qwen_verifier.py` | 21 | Secondary AI reviewer: markdown strip, JSON extraction, confidence clamping, assessment normalization, fallback reasoning, evidence payload structure, HTTP 404, URLError, timeouts, and mocked Ollama responses |
| `tests/test_unified_models.py` | 8 | Forward-pass tensor shapes for EfficientNet-B0, MobileNetV3-Large, and Baseline CNN; unified checkpoint loader for all 4 architectures (including GoldFormer); model name normalization |
| `tests/test_transfer_learning.py` | 8 | Classifier shapes, reproducible training contract, ImageNet normalization, zero-worker dataloader loading, and probability bounds |
| `tests/test_quality.py` | 6 | Image quality checks: resolution threshold, blur variance, darkness, brightness, and missing file error handling |
| `tests/test_features.py` | 3 | Handcrafted feature extraction, deterministic outputs, and feature name alignment |
| `tests/test_preprocessing.py` | 4 | Image preprocessing pipeline, format support, invalid path handling, and deterministic transforms |
| `tests/test_inference_cli.py` | 2 | Single-image CLI prediction and batch directory prediction execution |
| `tests/test_evaluate.py` | 1 | Explicit test manifest loading and integrity verification |
| **Total** | **92** | **100% Passing Coverage** |

#### Real Image Inference Verification

| Test Image | Origin | Primary Model Prediction | Confidence | Secondary AI (qwen3:8b) | Synthesized Verdict | Needs Human Verification |
|---|---|---|---:|---|---|:---:|
| `sample_authentic_c3pi.jpg` | C3PI Reference Library | AUTHENTIC | 87.20% | AUTHENTIC (87.20%) | **LIKELY AUTHENTIC** | **False** |
| `verified_counterfeit.jpg` | Held-Out Test Set | COUNTERFEIT | 99.81% | Fallback / Unavailable | **LIKELY COUNTERFEIT** | **True** |

---

### 12. Repository Cleanup Plan & Hygiene

The active model assets have been consolidated under `external_models/PharmaAssist/weights/`. GoldNet and TrueMeds remain intact as external reference projects. See `external_models/PharmaAssist/README.md` for the current directory conventions and preserved model inventory.

| Directory | Current role |
|---|---|
| `external_models/PharmaAssist/weights/` | First-party pretrained weights and available fine-tuned classifiers |
| `external_models/PharmaAssist/training_runs/` | Local generated model training artifacts |
| `external_models/GoldNet/`, `external_models/TrueMeds/` | Preserved upstream project sources |
| `ml/`, `backend/`, `frontend/flutter_app/` | Application and model source code |
| `data/`, `reports/` | Datasets/manifests and evaluation artifacts |
| `.venv/`, `.git/` | Preserve local environment and version history |

---

### 13. Limitations

1. **Visual-Only Screening:**
   Computer vision detects anomalies in shape, color, scoring, and surface appearance. It **cannot** measure chemical composition, active pharmaceutical ingredients (API), purity, or bioequivalence.
2. **Confidence $\neq$ Chemical Authenticity:**
   A high neural network confidence score indicates visual conformity with the authentic training distribution, not chemical certification.
3. **Lighting, Specular Reflection, and Glare:**
   Blister pack foil and glossy tablet coatings cause localized specular highlights that can degrade CNN feature extraction.
4. **Domain Artifact Risk:**
   Authentic training images originate predominantly from high-resolution standardized C3PI clinical captures, whereas counterfeit images originate from diverse mobile/crowdsourced repositories. High classification scores may partially reflect domain lighting artifacts.
5. **Secondary AI Fallback Dependency:**
   `qwen3:8b` relies on a running local Ollama instance. When Ollama is unavailable or times out, the system safely falls back to the primary classifier with explicit warnings, but loses the explanatory reasoning review.

---

### 14. Future Improvements

1. **Integrated Optical Character Recognition (OCR):**
   Combine PaddleOCR or Tesseract with the pipeline to cross-reference extracted NDC (National Drug Code) numbers and batch formats against national regulatory databases.
2. **Barcode / GS1 DataMatrix Verification:**
   Incorporate automatic scanning and validation of GS1 2D DataMatrix serial codes required by the Drug Supply Chain Security Act (DSCSA).
3. **Mobile On-Device Deployment:**
   Quantize EfficientNet-B0 to 8-bit integers (INT8) via ONNX Runtime / CoreML / TensorFlow Lite for offline execution on edge mobile devices.
4. **Handheld Spectroscopic Sensor Integration:**
   Pair camera triage with portable NIR (near-infrared) or Raman spectroscopy to combine visual appearance inspection with molecular chemical verification.

---

### 15. Final Project Status Scorecard

| Component | Status | Verification Summary |
|---|:---:|---|
| **Primary Classifier (EfficientNet-B0)** | **COMPLETE** | Loaded, verified, 99.88% test accuracy, 99.82% F1 score on held-out test set. |
| **MobileNetV3 & Baseline CNN Comparison** | **COMPLETE** | Loaded, verified, registered in unified model loader. |
| **GoldFormer Cross-Domain Model** | **COMPLETE** | Instantiated via GoldNet architecture; fine-tuned weights verified. |
| **Secondary AI Reviewer (qwen3:8b)** | **COMPLETE** | Integrated via Ollama; structured JSON evidence review, timeouts, and fallbacks verified. |
| **Conservative Decision Engine** | **COMPLETE** | Implemented with 4-rule deterministic policy; model conflict resolution active. |
| **FastAPI Backend & API Endpoints** | **COMPLETE** | `/predict`, `/verify`, and `/health` endpoints functional and fully tested. |
| **Automated Test Suite** | **COMPLETE** | 92 of 92 automated tests passing without failure (100%). |
| **Security & Hygiene** | **COMPLETE** | `.env.example` created, `.gitignore` updated, zero hardcoded secrets. |
| **Dataset Lineage & Math** | **COMPLETE** | $5,512$ supervised $+ 5,039$ self-supervised $= 10,551$ total verified. |
