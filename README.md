# PharmaAssist

PharmaAssist is an image-based **preliminary pharmaceutical screening** system.
It accepts a medicine photograph, validates the upload and image quality, runs
the available visual classifier, and returns a confidence-qualified screening
outcome for human follow-up. It is not a laboratory authentication instrument.

> **Safety limitation:** Image-based predictions cannot establish a medicine's
> chemical composition, active pharmaceutical ingredient, dosage, safety,
> regulatory approval, or definitive authenticity. Do not take, discard,
> quarantine, release, or prescribe a medicine based only on this application.
> Suspicious, inconclusive, and poor-quality cases require a pharmacist,
> health-authority, or certified laboratory review.

## Repository layout

| Path | Purpose |
|---|---|
| `backend/app/` | FastAPI application, routes, schemas, and service integration |
| `ml/` | preprocessing, model registry, inference, decision engine, training, evaluation, and explainability |
| `data/splits/` | Binary authentic/counterfeit CSV manifests |
| `data/processed/` | Images referenced by the binary manifests |
| `external_models/PharmaAssist/` | Pretrained and fine-tuned model artifacts |
| `scripts/` | Dataset, duplicate, CLI, and audit utilities |
| `frontend/flutter_app/` | Android Flutter client |
| `tests/` | Python backend and ML regression tests |
| `reports/` | Evidence-based audits and historical reports |

## Architecture

```text
Flutter Android client
    │ multipart HTTP
    ▼
FastAPI /predict or /verify
    ├─ MIME, size, decode, and dimension validation
    ├─ OpenCV image-quality checks
    ├─ registered primary classifier
    ├─ optional local Ollama/Qwen advisory review
    └─ confidence-qualified decision engine
```

The default registered primary model is `efficientnet_b0`. The API model
registry also knows about `mobilenet_v3_large`, `baseline_cnn`, and `goldformer`,
but a registered architecture is not necessarily a usable fine-tuned
pharmaceutical checkpoint.

## Current verified state

### Model artifacts

The current checkout contains:

- Fine-tuned EfficientNet-B0:
  `external_models/PharmaAssist/weights/checkpoints/efficientnet_b0/best.pt`
- Generic/pretrained EfficientNet-B0 and MobileNetV3-Large weights under
  `external_models/PharmaAssist/weights/pretrained/`
- GoldNet/GoldFormer weights under
  `external_models/GoldNet/weights/`

Fine-tuned MobileNetV3-Large, baseline CNN, and GoldFormer pharmaceutical
checkpoints are **not present** in the current checkout. Their historical
metrics must not be presented as current or reproduced results. Missing
checkpoints cause the API to return an unavailable-service error rather than a
fallback prediction.

### Dataset manifests

The binary manifests currently resolve against `data/processed/` and all
referenced files exist:

| Manifest | Authentic | Counterfeit | Total |
|---|---:|---:|---:|
| `data/splits/train.csv` | 2,500 | 1,350 | 3,850 |
| `data/splits/validation.csv` | 558 | 292 | 850 |
| `data/splits/test.csv` | 558 | 286 | 844 |
| `data/splits/test_clean.csv` | 555 | 284 | 839 |

`data/pharmassist_splits/` is a separate 53-class medicine-identity dataset,
not the binary classifier dataset.

The leakage audit found 12 exact duplicate groups crossing the original
binary splits: 7 train/validation and 5 train/test. `test_clean.csv` removes
the five exact duplicate test files and has no SHA-256 overlap with train or
validation. It still retains 184 cross-split perceptual-hash candidates;
these are similarity candidates, not confirmed duplicates. Therefore no
leakage-free generalization claim should be made from the current artifacts.
See [`reports/ML_PIPELINE_AUDIT_2026-11-02.md`](reports/ML_PIPELINE_AUDIT_2026-11-02.md)
and [`reports/duplicate_leakage_audit.md`](reports/duplicate_leakage_audit.md).

### Reproduction status

This audit did not retrain models or claim to reproduce historical accuracy,
ROC-AUC, PR-AUC, or benchmark-comparison figures. The verified results above
are manifest counts, file existence, split-overlap checks, artifact
availability, and automated test results.

## Windows setup

### Python backend

Use Python 3.12 (the validated local environment) and PowerShell from the
repository root:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

PyTorch may select CUDA automatically when a compatible installation and
driver are available. Otherwise the application uses CPU inference. Do not
install a CUDA wheel blindly; choose the PyTorch build appropriate for the
machine from the official PyTorch installation instructions. Direct Python
dependencies are pinned in `requirements.txt`; recreate the virtual
environment rather than mixing packages into a system interpreter.

### Flutter and Android

Install Flutter 3.47.7 or a compatible stable release, Android SDK tools,
Android platform/build tools, and Java 17. Verify:

```powershell
flutter --version
flutter doctor
cd frontend\flutter_app
flutter pub get
```

The Android application ID is
`com.chethan.pharmaassist.pharma_assist`. Camera and internet permissions are
declared in the main Android manifest. Debug builds may use cleartext HTTP for
local development; production deployments should use HTTPS.

## Model installation

The default deployment checkpoint must exist at:

```text
external_models\PharmaAssist\weights\checkpoints\efficientnet_b0\best.pt
```

The generic pretrained file used by model construction is:

```text
external_models\PharmaAssist\weights\pretrained\efficientnet_b0.pth
```

Do not commit private or redistributable weights. If a checkpoint is absent or
cannot be loaded, the backend logs the detailed server-side failure and
returns a sanitized `503` response. It never fabricates a prediction.

## Run the backend

From the repository root:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

For a phone on the same private LAN, bind to all interfaces and configure the
phone with the host's LAN address:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

Health and documentation endpoints:

```powershell
curl.exe http://127.0.0.1:8000/
curl.exe http://127.0.0.1:8000/health
curl.exe http://127.0.0.1:8000/models
curl.exe http://127.0.0.1:8000/health/qwen
```

Swagger UI is available at `http://127.0.0.1:8000/docs`.

### Screening request

`/verify` is a compatibility alias for `/predict`. The upload field is
`file`; optional form fields include `threshold`, `model`, `enable_qwen`,
`enable_vision`, and `vision_mode`.

```powershell
curl.exe -X POST "http://127.0.0.1:8000/predict" `
  -F "file=@test_images\sample_authentic_c3pi.jpg" `
  -F "vision_mode=never"
```

Accepted upload types are JPEG, PNG, WEBP, and BMP. Uploads are limited to
15 MB, decoded and verified server-side, and limited to a maximum image
dimension of 10,000 pixels. Image-quality checks use the configured minimum
64×64 dimensions, Laplacian sharpness threshold 50.0, and brightness range
15–245. Invalid requests return explicit 4xx responses; model or dependency
failures return sanitized 5xx responses.

## Decision semantics

The decision engine uses authentic probability, not a generic confidence
label:

| Authentic probability | Result | Human review |
|---:|---|---|
| `< 0.50` | `LIKELY COUNTERFEIT` / counterfeit indication | Required |
| `0.50` through configured cutoff | `SUSPICIOUS / NEEDS VERIFICATION` | Required |
| `> configured cutoff` (default `0.70`) | `LIKELY AUTHENTIC` / authentic indication | Review safeguards still apply |

Exact boundaries are review conditions. Poor image quality remains visible in
the response even when a documented diagnostic path provides a provisional
classifier suggestion. Model disagreement, malformed secondary responses,
secondary-service outage, and ambiguous results remain review-required. Qwen
is advisory evidence only and cannot override the primary decision policy.

An authentic indication means only that the image resembles reference
examples. It is never proof of genuine composition, correct dosage, safety, or
regulatory approval.

## Ollama and Qwen Vision

Qwen is optional and runs through a local Ollama service. Install Ollama
separately, start its service, and pull the model name configured by the
backend (`qwen3.5:4b` by default):

```powershell
ollama pull qwen3.5:4b
curl.exe http://127.0.0.1:11434/api/tags
```

Use `vision_mode=auto` for conditional review, `always` to request review for
every scan, or `never` to disable the secondary reviewer. If Ollama is offline
or times out, the API reports degraded secondary review and preserves the
human-review requirement where policy calls for it. The primary API remains
usable when the optional service is unavailable.

Troubleshooting:

- `connection refused`: start Ollama and confirm port `11434`.
- model not found: run `ollama pull qwen3.5:4b` and verify the configured name.
- slow CPU review: use `vision_mode=never` or allow the longer request timeout.
- phone cannot reach the backend: use the computer's private LAN IPv4 address,
  allow port 8000 through the private Windows Firewall profile, and keep both
  devices on the same network.

## Flutter app

From `frontend\flutter_app`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to
`frontend\flutter_app\build\app\outputs\flutter-apk\app-debug.apk`.

The backend URL is configurable in **Settings** and is persisted locally. The
source default is loopback (`http://127.0.0.1:8000`), not a developer's LAN
address. For a build-time override:

```powershell
flutter run --dart-define=PHARMA_API_BASE_URL=http://10.0.2.2:8000
```

Use `10.0.2.2` from an Android emulator for the host computer, or enter a
private LAN URL for a physical phone. Failed requests do not create history
records or show a false success screen. The app supports camera capture,
gallery selection, image preview, sample IDs, notes, a 50-record local history,
CSV metadata export, and text report copy.

## Training, evaluation, and leakage checks

No training is required to run the existing deployment checkpoint. Do not
launch expensive retraining without confirming available compute and dataset
authorization.

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

The training module uses seed 42 by default, grouped `GroupShuffleSplit`,
separate augmentation/evaluation transforms, and validation loss for checkpoint
selection. The test split is used only for final evaluation.

Before trusting a split, audit manifests without changing data:

```powershell
.\.venv\Scripts\python.exe scripts\audit_datasets.py
.\.venv\Scripts\python.exe scripts/check_duplicates.py `
  --root data\processed `
  --manifest-dir data\splits
```

`scripts/check_duplicates.py` defaults to `outputs/clean_dataset`; therefore
the explicit `--manifest-dir data\splits` arguments above are required for the
current manifests. The duplicate script checks SHA-256 and group overlap; it
does not prove that perceptual-hash candidates are duplicates.

Evaluate an existing compatible checkpoint without retraining:

```powershell
.\.venv\Scripts\python.exe -m ml.evaluation.evaluate `
  --checkpoint external_models\PharmaAssist\weights\checkpoints\efficientnet_b0\best.pt `
  --pretrained-checkpoint external_models\PharmaAssist\weights\pretrained\efficientnet_b0.pth `
  --raw-dir data\processed `
  --test-manifest data\splits\test_clean.csv `
  --cpu
```

The evaluator emits classification metrics and emits ROC-AUC/PR-AUC only
when binary targets and valid probability scores support them. The current
deployment checkpoint does not contain full training metadata, so a complete
historical metric reproduction still requires matching model configuration
and preprocessing evidence. Do not label old reports as newly reproduced.

## Tests

Python tests from the repository root:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Focused ML checks:

```powershell
.\.venv\Scripts\python.exe -m pytest tests\test_ml_audit.py tests\test_evaluate.py
```

Flutter checks:

```powershell
cd frontend\flutter_app
flutter analyze
flutter test
```

The most recent verified Flutter validation reported clean analysis, 45
passing tests, and a successful debug APK build. Python suites also contain
legacy tests whose expectations may reflect the retired confidence-band
policy; report any failures rather than weakening tests. On 2026-11-03, the
full Python run reported **179 passed and 19 failed**; the failures are in
legacy conditional-gating, decision-engine, and Qwen verifier expectations,
not silently ignored.

## Continuous integration

`.github/workflows/ci.yml` runs on pushes to `main` and pull requests. It
installs the pinned Python dependencies, runs the current backend/ML contract
tests, installs the locked Flutter dependencies, and runs Flutter analysis and
tests. CI does not require private datasets, model downloads, a GPU, secrets,
or an Ollama daemon. A failed command fails its job; no check is converted to
a success-shaped fallback.

## Manual real-device release checklist

Automated checks cannot validate camera hardware, Android permissions, local
network routing, or the complete field workflow. Before distributing an APK,
perform these checks on a real, non-production test device:

1. Grant camera permission and capture a clear medicine image.
2. Select an image from the gallery, preview it, retake/replace it, and verify
   that unsupported, empty, tiny, or oversized files are rejected.
3. Configure an HTTPS backend, test the connection, and confirm the health
   status and model registry display.
4. Configure a private-LAN HTTP backend only for a debug build; verify that the
   phone and host share the same network and that Windows Firewall permits the
   private profile.
5. Complete a successful scan and confirm the result, sample ID, medicine
   name, notes, image preview, disclaimer, report copy, and history record.
6. Stop the backend or disable the network and confirm a timeout/connection
   error does not create a false success or history record; retry afterward.
7. Exercise authentic-indicated, counterfeit-indicated, inconclusive,
   poor-quality, and manual-review responses using controlled test fixtures.
8. Verify history deletion, the 50-record limit, CSV export, app restart
   persistence, and navigation back to Home/Scan/History/Settings.
9. Confirm no sensitive patient or prescription information is entered into
   sample IDs, notes, logs, or exported metadata.

## Privacy, security, and responsible use

- Images are sent only to the backend URL configured by the user. Qwen review
  is intended to run through local Ollama; verify network configuration before
  using sensitive images.
- Local history contains sample metadata and result JSON. Do not place patient,
  prescription, or personally identifying information in sample IDs or notes.
- Keep secrets, private datasets, private model weights, local configuration,
  and credentials out of Git.
- Production deployments should use HTTPS, restricted CORS origins, network
  access controls, authentication, and appropriate retention policies.
- The backend logs detailed operational failures server-side but sanitizes
  client-facing errors; do not expose logs publicly.
- This system is decision support for triage, not a substitute for a
  pharmacist, regulator, or certified analytical laboratory.

## Known limitations

- The current binary dataset has exact cross-split duplicates in the original
  manifests and retained perceptual-hash candidates in the clean evaluation.
- Fine-tuned comparison checkpoints are unavailable.
- No current audit result certifies historical accuracy or generalization.
- Grad-CAM supports registered architectures with a supported convolutional
  target layer; unavailable checkpoints and unsupported target layers fail
  explicitly.
- Android cleartext access is intended for debug/local development only.
- Camera image quality depends on lighting, focus, glare, framing, and device
  hardware.
