# PharmaAssist

**An Image-Based Preliminary Pharmaceutical Screening System**

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-green.svg)]()
[![Framework](https://img.shields.io/badge/Framework-Flutter-blue.svg)]()
[![Backend](https://img.shields.io/badge/Backend-FastAPI-teal.svg)]()
[![Python](https://img.shields.io/badge/Python-3.12-yellow.svg)]()

PharmaAssist is an image-based **preliminary pharmaceutical screening** system. It accepts a medicine photograph, validates the upload and image quality, runs the available visual classifier, and returns a confidence-qualified screening outcome for human follow-up.

It combines a Flutter Android application, a FastAPI backend, computer vision, deep-learning classification and optional local vision-language model assistance.

PharmaAssist is designed to support preliminary inspection and awareness. It is not a laboratory authentication instrument.

> **Safety limitation**
>
> Image-based predictions cannot establish a medicine's chemical composition, active pharmaceutical ingredient, dosage, safety, regulatory approval, or definitive authenticity.
>
> Do not take, discard, quarantine, release, or prescribe a medicine based only on this application.
>
> Suspicious, inconclusive, and poor-quality cases require a pharmacist, health-authority, or certified laboratory review.

---

## Project Information

| Detail | Information |
|---|---|
| Project | PharmaAssist |
| Developer | Chethan N. |
| GitHub | [ChethanNGowda](https://github.com/ChethanNGowda) |
| Repository | [CounterfeitPharmaceuticalDetection](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection) |
| Application | PharmaAssist |
| Platform | Android |
| Frontend | Flutter / Dart |
| Backend | Python / FastAPI |
| Machine Learning | PyTorch / EfficientNet-B0 |
| Database | SQLite (optional synchronization) |
| License | Apache License 2.0 (proposed) |
| Development Year | 2026 |

## About the Project

Counterfeit pharmaceutical products are a significant public-health concern. Identifying suspicious medicine packaging through ordinary visual inspection can be difficult.

PharmaAssist explores how computer vision and machine learning can assist with preliminary pharmaceutical packaging screening.

The application provides:

- Medicine image capture and gallery selection.
- Image validation and quality assessment.
- AI-assisted preliminary screening.
- Confidence-qualified screening outcomes.
- Optional Qwen Vision advisory review.
- Medicine information and OCR-assisted extraction.
- Packaging inspection tools.
- Expiry tracking and alerts.
- Screening history and report generation.
- System diagnostics and backend connectivity.
- Optional authenticated record synchronization.

The system is intended for educational, research and preliminary screening purposes.

---

## Features

### 1. AI Pharmaceutical Screening

- Image-based pharmaceutical screening.
- EfficientNet-B0 primary classifier.
- Confidence-qualified decision engine.
- Image preprocessing and validation.
- Optional Qwen Vision advisory review.
- Explicit handling of unavailable models and failed inference.
- Human-review safeguards for ambiguous results.

### 2. Medicine Information Management

- Medicine packaging image capture.
- OCR-assisted text extraction.
- Batch number extraction.
- Manufacturing and expiry date extraction.
- Strength and dosage-form extraction.
- Manufacturer information extraction.
- Editable medicine information profiles.

### 3. Expiry Tracker

- Expiry-date monitoring.
- Countdown-based expiry information.
- Visual expiry alerts.
- Green, amber and red alert indicators.

### 4. Packaging Inspection

- Seven-point packaging inspection checklist.
- Packaging and capture guide.
- Dual-photo comparison.
- Side-by-side image inspection.
- Pinch-to-zoom functionality from 0.8x to 5.0x.
- Screening insights dashboard.

### 5. Records and Reports

- Screening history.
- Multi-field search.
- Status filtering.
- Date filtering.
- Detailed screening records.
- PDF report exports.
- CSV report exports.
- TXT report exports.
- Local persistence.

### 6. System Diagnostics

- AI diagnostics and model information.
- Model registry inspection.
- Backend health monitoring.
- Qwen service diagnostics.
- Backend URL configuration.
- Settings and synchronization management.

---

## Repository Structure

| Path | Purpose |
|---|---|
| `backend/app/` | FastAPI application, routes, schemas and service integration |
| `ml/` | Preprocessing, model registry, inference, decision engine, training, evaluation and explainability |
| `data/splits/` | Binary authentic/counterfeit CSV manifests |
| `data/processed/` | Images referenced by binary manifests |
| `external_models/PharmaAssist/` | Pretrained and fine-tuned model artifacts |
| `scripts/` | Dataset, duplicate, CLI and audit utilities |
| `frontend/flutter_app/` | Android Flutter client |
| `tests/` | Python backend and ML regression tests |
| `reports/` | Evidence-based audits and historical reports |
| `.github/workflows/` | Continuous integration workflows |

---

## Architecture

```text
Flutter Android Client
        |
        | Multipart HTTP
        v
FastAPI Backend
        |
        +-- MIME, size and image validation
        |
        +-- OpenCV image-quality checks
        |
        +-- Registered primary classifier
        |
        +-- Optional Ollama / Qwen advisory review
        |
        +-- Confidence-qualified decision engine
        |
        v
Screening Response
        |
        +-- Preliminary result
        +-- Confidence information
        +-- Image quality status
        +-- Human-review requirements
        +-- Screening metadata
```

The default registered primary model is `efficientnet_b0`.

The API model registry also knows about:

- `efficientnet_b0`
- `mobilenet_v3_large`
- `baseline_cnn`
- `goldformer`

A registered architecture does not necessarily have an available fine-tuned pharmaceutical checkpoint.

The Flutter client currently does not package an Android inference runtime or converted classifier.

Offline-only mode supports local records, notes, image handling and reports but explicitly does not perform AI screening.

Local AI must not be enabled until model conversion, Python parity and physical-device offline validation are complete.

See `reports/ON_DEVICE_INFERENCE_AUDIT_2026-11-05.md`.

---

## Current Verified State

### Model Artifacts

The current checkout contains:

**Fine-tuned EfficientNet-B0**

```text
external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt
```

**Generic pretrained weights**

```text
external_models/PharmaAssist/weights/pretrained/
```

**GoldNet / GoldFormer weights**

```text
external_models/GoldNet/weights/
```

Fine-tuned MobileNetV3-Large, baseline CNN and GoldFormer pharmaceutical checkpoints are not present in the current checkout.

Their historical metrics must not be presented as current or reproduced results.

Missing checkpoints cause the API to return an unavailable-service error rather than a fallback prediction.

### Dataset Manifests

The binary manifests currently resolve against `data/processed/`, and all referenced files exist.

| Manifest | Authentic | Counterfeit | Total |
|---|---:|---:|---:|
| `train.csv` | 2,500 | 1,350 | 3,850 |
| `validation.csv` | 558 | 292 | 850 |
| `test.csv` | 558 | 286 | 844 |
| `test_clean.csv` | 555 | 284 | 839 |

`data/pharmassist_splits/` is a separate 53-class medicine-identity dataset, not the binary classifier dataset.

### Dataset Leakage Audit

The leakage audit found:

- 12 exact duplicate groups crossing the original binary splits.
- 7 train/validation overlaps.
- 5 train/test overlaps.
- `test_clean.csv` removes the five exact duplicate test files.
- No SHA-256 overlap remains between the clean test set and train/validation.
- 184 cross-split perceptual-hash candidates remain.

Perceptual-hash candidates indicate similarity, not confirmed duplicates.

No leakage-free generalization claim should be made from the current artifacts.

Audit documentation:

- `reports/ML_PIPELINE_AUDIT_2026-11-02.md`
- `reports/duplicate_leakage_audit.md`

### Reproduction Status

The current audit did not retrain models or claim to reproduce historical accuracy, ROC-AUC, PR-AUC or benchmark-comparison figures.

Verified results cover:

- Manifest counts.
- File existence.
- Split-overlap checks.
- Model artifact availability.
- Automated test results.

Historical metrics should not be presented as newly reproduced results.

---

## Technology Stack

| Component | Technology |
|---|---|
| Android application | Flutter |
| Programming language | Dart |
| Backend framework | FastAPI |
| Backend language | Python |
| Machine learning | PyTorch |
| Primary classifier | EfficientNet-B0 |
| Image processing | OpenCV |
| Secondary vision review | Qwen Vision |
| Local model service | Ollama |
| Local storage | SQLite / SharedPreferences |
| API communication | HTTP / HTTPS |
| Report generation | PDF / CSV / TXT |
| Version control | Git / GitHub |

---

## Installation and Setup

### Requirements

**Python Backend**

- Python 3.12
- pip
- Git
- Compatible PyTorch installation

**Flutter Android Application**

- Flutter 3.47.7 or compatible stable release
- Dart SDK
- Android SDK tools
- Android platform/build tools
- Java 17

### Windows Setup

Clone the repository:

```powershell
git clone https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection.git
```

Navigate into the repository:

```powershell
cd CounterfeitPharmaceuticalDetection
```

### Python Backend Setup

Create a virtual environment:

```powershell
py -3.12 -m venv .venv
```

Upgrade pip:

```powershell
.\.venv\Scripts\python.exe -m pip install --upgrade pip
```

Install dependencies:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

PyTorch may select CUDA automatically when a compatible installation and driver are available.

Otherwise, the application uses CPU inference.

Do not install a CUDA wheel blindly. Choose the PyTorch build appropriate for the machine using the official PyTorch installation instructions.

Direct Python dependencies are pinned in `requirements.txt`. Recreate the virtual environment rather than mixing packages into a system interpreter.

### Flutter Setup

Verify Flutter:

```powershell
flutter --version
flutter doctor
```

Navigate into the Flutter application:

```powershell
cd frontend\flutter_app
```

Install dependencies:

```powershell
flutter pub get
```

The Android application ID is:

```text
com.chethan.pharmaassist.pharma_assist
```

Camera and internet permissions are declared in the main Android manifest.

Debug builds may use cleartext HTTP for local development. Production deployments should use HTTPS.

---

## Model Installation

The default deployment checkpoint must exist at:

```text
external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt
```

The generic pretrained file used by model construction is:

```text
external_models/PharmaAssist/weights/pretrained/efficientnet_b0.pth
```

Do not commit private or redistributable weights.

If a checkpoint is absent or cannot be loaded, the backend logs the detailed server-side failure and returns a sanitized `503` response.

The system never fabricates a prediction.

---

## Running the Backend

From the repository root:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

For a physical phone on the same private LAN, bind to all interfaces:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

Configure the phone with the computer's private LAN IPv4 address.

### Health and Documentation Endpoints

```powershell
curl.exe http://127.0.0.1:8000/
```

```powershell
curl.exe http://127.0.0.1:8000/health
```

```powershell
curl.exe http://127.0.0.1:8000/models
```

```powershell
curl.exe http://127.0.0.1:8000/health/qwen
```

Swagger UI:

```text
http://127.0.0.1:8000/docs
```

---

## Screening API

`/verify` is a compatibility alias for `/predict`.

The upload field is `file`.

Optional form fields include:

- `threshold`
- `model`
- `enable_qwen`
- `enable_vision`
- `vision_mode`

Example:

```powershell
curl.exe -X POST "http://127.0.0.1:8000/predict" `
  -F "file=@test_images\sample_authentic_c3pi.jpg" `
  -F "vision_mode=never"
```

### Supported Image Formats

- JPEG
- PNG
- WEBP
- BMP

### Image Validation

| Validation | Limit |
|---|---|
| Maximum upload size | 15 MB |
| Minimum dimensions | 64 × 64 |
| Maximum image dimension | 10,000 pixels |
| Laplacian sharpness threshold | 50.0 |
| Brightness range | 15–245 |

Uploads are decoded and verified server-side.

Invalid requests return explicit 4xx responses.

Model or dependency failures return sanitized 5xx responses.

---

## Decision Semantics

The decision engine uses authentic probability rather than a generic confidence label.

| Authentic Probability | Screening Result | Human Review |
|---|---|---|
| Below 0.50 | LIKELY COUNTERFEIT / counterfeit indication | Required |
| 0.50 through configured cutoff | SUSPICIOUS / NEEDS VERIFICATION | Required |
| Above configured cutoff (default 0.70) | LIKELY AUTHENTIC / authentic indication | Safeguards still apply |

Exact boundaries are review conditions.

Poor image quality remains visible in the response even when a documented diagnostic path provides a provisional classifier suggestion.

The following conditions remain review-required:

- Model disagreement.
- Malformed secondary responses.
- Secondary-service outage.
- Ambiguous results.
- Poor-quality or inconclusive images.

Qwen is advisory evidence only and cannot override the primary decision policy.

An authentic indication means only that the image resembles reference examples. It is never proof of genuine composition, correct dosage, safety or regulatory approval.

---

## Ollama and Qwen Vision

Qwen is optional and runs through a local Ollama service.

Install Ollama separately, start its service and pull the model configured by the backend.

Default model:

```powershell
ollama pull qwen3.5:4b
```

Verify the local service:

```powershell
curl.exe http://127.0.0.1:11434/api/tags
```

### Vision Modes

| Mode | Behaviour |
|---|---|
| `auto` | Conditional secondary review |
| `always` | Requests secondary review for every scan |
| `never` | Disables secondary review |

If Ollama is offline or times out, the API reports degraded secondary review and preserves the human-review requirement where policy calls for it.

The primary API remains usable when the optional service is unavailable.

### Troubleshooting

**Connection refused**

Start Ollama and confirm port `11434`.

**Model not found**

Run:

```powershell
ollama pull qwen3.5:4b
```

Verify the configured model name.

**Slow CPU review**

Use `vision_mode=never` or allow a longer request timeout.

**Phone cannot reach backend**

- Use the computer's private LAN IPv4 address.
- Allow port 8000 through the private Windows Firewall profile.
- Keep both devices on the same network.

---

## Flutter Application

Navigate to:

```powershell
cd frontend\flutter_app
```

Install dependencies:

```powershell
flutter pub get
```

Run analysis:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

Build the release APK:

```powershell
flutter build apk --release
```

Release APK output:

```text
frontend/flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

The verified release APK size is approximately 53.9 MB.

### Application Navigation

PharmaAssist uses a five-destination bottom navigation architecture with Material 3 and a unified teal, blue and soft-mint visual identity.

**1. Home**

- Primary scan call-to-action.
- Screening volume statistics.
- Recent activity timeline.
- Quick actions.

**2. Scan**

- High-contrast corner-bracket viewfinder.
- Flash and camera toggle.
- Gallery selection.
- Image quality checks.
- Real-time backend and offline status indicators.

**3. Medicine**

- Medicine Information management.
- On-device OCR regex extraction.
- Batch number extraction.
- Manufacturing and expiry dates.
- Strength and dosage form.
- Manufacturer information.
- Interactive edit/save modal.
- Expiry Tracker with countdowns and visual alerts.

**4. Records**

- Unified inspection history.
- Multi-field search.
- Status filter chips.
- Date filters.
- Detailed record view.
- PDF, CSV and TXT report exports.

**5. More**

Central hub for additional functionality.

Packaging and Clinical Insights:

- Screening Insights dashboard.
- Seven-Point Packaging Checklist.
- Dual Photo Comparison.
- Packaging and Capture Guide.

System Diagnostics:

- AI Diagnostics / Model Lab.
- Settings and Sync.
- About and Compliance.

### Backend Configuration

The backend URL is configurable in Settings and persisted locally.

The source default is:

```text
http://127.0.0.1:8000
```

Build-time override example:

```powershell
flutter run --dart-define=PHARMA_API_BASE_URL=http://10.0.2.2:8000
```

Use `10.0.2.2` from an Android emulator to reach the host computer.

For a physical phone, configure the computer's private LAN URL.

Failed requests do not create history records or show a false success screen.

---

## Optional Record Synchronization

PharmaAssist supports an optional authenticated record synchronization API.

Endpoint:

```text
POST /sync/records
```

The endpoint stores authenticated client history metadata without running screening or treating client predictions as verified evidence.

### Synchronization Security

- Individual device bearer credentials.
- Device-scoped idempotency keys.
- PBKDF2-HMAC-SHA256 stored credential hashes.
- Optional image payloads with explicit consent.
- Server-side image validation.
- Duplicate request handling.
- Conflict detection.

The client record ID is used as a device-scoped idempotency key.

Optional image payloads require explicit consent and are validated before storage.

### Synchronization Administration

Provision a device:

```powershell
python -m backend.sync_admin --db data\pharma_sync.sqlite3 provision phone-001
```

Revoke a device:

```powershell
python -m backend.sync_admin --db data\pharma_sync.sqlite3 revoke phone-001
```

See:

- `BACKEND_SYNC_API_2026-11-05.md`
- `DEPLOYMENT_READINESS_2026-11-07.md`

These documents contain the synchronization contract, environment variables, storage limits, deployment requirements, APK integrity procedure and physical-device test plan.

Flutter upload integration remains intentionally deferred.

---

## Training, Evaluation and Leakage Checks

No training is required to run the existing deployment checkpoint.

Do not launch expensive retraining without confirming available compute and dataset authorization.

### Training

Create deterministic grouped splits from a labeled raw dataset:

```powershell
.\.venv\Scripts\python.exe -m ml.training.train `
  --model efficientnet_b0 `
  --pretrained-checkpoint external_models\PharmaAssist\weights\pretrained\efficientnet_b0.pth `
  --raw-dir data\raw `
  --split-dir data\splits `
  --seed 42 `
  --cpu
```

The training module uses:

- Seed 42 by default.
- Grouped `GroupShuffleSplit`.
- Separate augmentation and evaluation transforms.
- Validation loss for checkpoint selection.
- Test split exclusively for final evaluation.

### Dataset Auditing

```powershell
.\.venv\Scripts\python.exe scripts\audit_datasets.py
```

Duplicate checks:

```powershell
.\.venv\Scripts\python.exe scripts\check_duplicates.py `
  --root data\processed `
  --manifest-dir data\splits
```

The duplicate script defaults to `outputs/clean_dataset`. Therefore, the explicit `--manifest-dir data\splits` argument is required for the current manifests.

The duplicate script checks SHA-256 and group overlap. It does not prove that perceptual-hash candidates are duplicates.

### Evaluation

Evaluate an existing compatible checkpoint without retraining:

```powershell
.\.venv\Scripts\python.exe -m ml.evaluation.evaluate `
  --checkpoint external_models\PharmaAssist\weights\checkpoints\efficientnet_b0\best.pt `
  --pretrained-checkpoint external_models\PharmaAssist\weights\pretrained\efficientnet_b0.pth `
  --raw-dir data\processed `
  --test-manifest data\splits\test_clean.csv `
  --cpu
```

The evaluator emits classification metrics and emits ROC-AUC/PR-AUC only when binary targets and valid probability scores support them.

The current deployment checkpoint does not contain full training metadata, so complete historical metric reproduction still requires matching model configuration and preprocessing evidence.

Do not label old reports as newly reproduced.

---

## Tests and Validation

### Python Backend Tests

Run from the repository root:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Focused ML checks:

```powershell
.\.venv\Scripts\python.exe -m pytest tests\test_ml_audit.py tests\test_evaluate.py
```

### Flutter Tests

```powershell
cd frontend\flutter_app
flutter analyze
flutter test
```

### Current Verified Test Results

| Component | Result |
|---|---|
| Flutter analysis | 0 issues |
| Flutter tests | 71 passed |
| Flutter failures | 0 |
| Python tests | 213 passed |
| Python failures | 0 |
| Release APK | 53.9 MB |

Python tests cover backend routes, schemas, ML model registry, decision engine, quality validation and synchronization administration.

These are automated software validation results, not evidence of pharmaceutical authentication accuracy.

---

## Continuous Integration

GitHub Actions workflow:

```text
.github/workflows/ci.yml
```

The workflow runs on pushes to `main` and pull requests.

It:

- Installs pinned Python dependencies.
- Runs backend and ML contract tests.
- Installs locked Flutter dependencies.
- Runs Flutter analysis.
- Runs Flutter tests.

CI does not require private datasets, model downloads, a GPU, secrets or an Ollama daemon.

A failed command fails its job. No check is converted to a success-shaped fallback.

---

## Manual Real-Device Release Checklist

Automated checks cannot validate camera hardware, Android permissions, local network routing or the complete field workflow.

Before distributing an APK, perform these checks on a real, non-production test device.

1. Grant camera permission and capture a clear medicine image.
2. Select an image from the gallery, preview it, retake or replace it, and verify that unsupported, empty, tiny or oversized files are rejected.
3. Configure an HTTPS backend, test the connection and confirm the health status and model registry display.
4. Configure a private-LAN HTTP backend only for a debug build.
5. Complete a successful scan and confirm the result, sample ID, medicine name, notes, image preview, disclaimer, report copy and history record.
6. Stop the backend or disable the network and confirm a timeout or connection error does not create a false success or history record.
7. Exercise authentic-indicated, counterfeit-indicated, inconclusive, poor-quality and manual-review responses using controlled test fixtures.
8. Verify history deletion, the 50-record limit, PDF/CSV/TXT export, app restart persistence and navigation across all five destinations.
9. Verify the Medicine tab, OCR extraction, edit/save workflow and expiry alert banners.
10. Verify More hub tools, Screening Insights, the seven-point packaging checklist and dual-photo comparison.
11. Confirm no sensitive patient or prescription information is entered into sample IDs, notes, logs or exported metadata.

---

## Privacy, Security and Responsible Use

- Images are sent only to the backend URL configured by the user.
- Qwen review is intended to run through local Ollama; verify network configuration before using sensitive images.
- Local history contains sample metadata and result JSON.
- Do not place patient, prescription or personally identifying information in sample IDs or notes.
- Keep secrets, private datasets, private model weights, local configuration and credentials out of Git.
- Production deployments should use HTTPS, restricted CORS origins, network access controls, authentication and appropriate retention policies.
- The backend logs detailed operational failures server-side but sanitizes client-facing errors.
- Do not expose server logs publicly.
- This system is decision support for triage, not a substitute for a pharmacist, regulator or certified analytical laboratory.

---

## Known Limitations

- The current binary dataset has exact cross-split duplicates in the original manifests.
- Perceptual-hash candidates remain in the clean evaluation.
- Fine-tuned comparison checkpoints are unavailable.
- No current audit result certifies historical accuracy or generalization.
- Grad-CAM supports registered architectures with a supported convolutional target layer.
- Unavailable checkpoints and unsupported target layers fail explicitly.
- Android cleartext access is intended for debug/local development only.
- Camera image quality depends on lighting, focus, glare, framing and device hardware.
- Offline-only mode does not perform AI screening.
- The application cannot verify chemical composition, dosage, safety or regulatory approval.

---

# Developer and Credits

**PharmaAssist is independently developed and maintained by Chethan N.**

The project combines application development, backend engineering, machine learning, image processing and Android integration.

### Original Developer

**Chethan N.**

- GitHub: [@ChethanNGowda](https://github.com/ChethanNGowda)
- Project: [PharmaAssist](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection)
- Repository: CounterfeitPharmaceuticalDetection

### Acknowledgements

PharmaAssist builds upon open-source technologies and frameworks, including:

- Flutter
- Dart
- Python
- FastAPI
- PyTorch
- OpenCV
- Ollama
- Qwen

All third-party projects retain their respective ownership, copyright notices and licensing terms.

---

# Version History and Updates

PharmaAssist is an actively maintained development project.

Updates may include:

- New application features.
- UI/UX improvements.
- Machine-learning improvements.
- Backend API improvements.
- Performance optimizations.
- Security and reliability fixes.
- Bug fixes.
- Compatibility updates.

### Release Information

Official releases and version-specific changes will be published here:

**[View PharmaAssist Releases](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection/releases)**

**[View Commit History](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection/commits/main/)**

**[View Issues and Bug Reports](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection/issues)**

Only officially published releases should be treated as versioned releases. Development commits do not necessarily represent production-ready versions.

---

# License

Copyright © 2026 Chethan N.

PharmaAssist is intended to be distributed under the **Apache License, Version 2.0**.

Under this license, users may use, reproduce, modify and distribute the project subject to the license conditions, including preservation of applicable copyright and license notices.

The full license text is available in the repository:

[LICENSE](LICENSE)

Official license information:

https://www.apache.org/licenses/LICENSE-2.0

Third-party libraries, datasets, pretrained models and other external assets may have separate licenses and redistribution restrictions. Their respective licenses take precedence for those individual components.

---

## Disclaimer

PharmaAssist is an independent software development and research project.

It is not affiliated with, endorsed by or certified by any pharmaceutical manufacturer, regulatory authority or medical institution.

The application provides preliminary image-based screening assistance only.

It must not be used as the sole basis for medical, pharmaceutical, regulatory or safety decisions.

**Developed and maintained by Chethan N.**

[GitHub Repository](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection) · [Releases](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection/releases) · [Issues](https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection/issues)
