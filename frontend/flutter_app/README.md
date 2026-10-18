# PharmaAssist — Field Pharmaceutical Screening App

**Mobile Field Screening & Inspection Triage Client for Counterfeit Pharmaceutical Detection**

> ⚠️ **Screening Instrument Only:** This application provides visual and convolutional pattern screening. Camera-based optical analysis cannot detect active pharmaceutical ingredients (API), verify chemical potency, or certify pharmacological bioequivalence. All suspicious or inconclusive findings require independent confirmation by a certified analytical laboratory (e.g. HPLC or Raman spectroscopy).

---

## Overview

PharmaAssist is an Android mobile screening instrument inspired by the field usability and disciplined workflow of DetectaChem MobileDetect. Built with Flutter, it interfaces with the project's production FastAPI backend and multi-model machine learning pipeline:

- **Primary Classifier:** Fine-tuned EfficientNet-B0 (99.88% test accuracy, 100% recall).
- **Secondary AI Inspector:** Local Ollama Qwen Vision (4B parameters) vision-language verifier for tablet shape, color consistency, imprint legibility, and packaging inspection.
- **Image Quality Pre-Screen:** OpenCV Laplacian variance blur check, brightness mean, RMS contrast, and 64×64 pixel resolution gate.
- **Conservative Decision Engine:** Deterministic 4-rule synthesis engine enforcing mandatory physical laboratory review for low-confidence, uncertain, or conflicting evidence.
- **Persistent Local Archive:** Encrypted local storage of completed inspections (up to 50 records), sample IDs, medicine names, inspection notes, and generated field reports.

---

## Key Features

1. **DetectaChem-Inspired Field Workflow:**
   - Real-time backend connectivity ping on launch with visual status indicator.
   - Sample ID and lot metadata tracking with auto-generated unique identifier generator (`SMP-YYMMDD-XXXX`).
   - Optional product/medicine name and field inspection notes input.
   - Built-in optical capture guidelines (orthogonal alignment, glare prevention, matte background).
   - High-resolution camera capture with gallery fallback and clear/retake controls.
   - Multi-stage screening progress bar (`Transmitting` → `Quality Gate` → `Neural Inference` → `Decision Synthesis`).

2. **Three Distinct Instrument Outcomes:**
   - **`SCREENING INDICATES AUTHENTIC`** (Forest Green `#22C55E`): Surface pattern matches authentic reference models.
   - **`SCREENING INDICATES COUNTERFEIT`** (Crimson Red `#EF4444`): Pattern anomalies, imprint defects, or classifier flags detected. Sample quarantine advised.
   - **`INCONCLUSIVE / REVIEW REQUIRED`** (Amber `#F59E0B`): Borderline confidence, optical variance, or verifier disagreement. Physical laboratory testing required.

3. **Inspection Report Generation & Export:**
   - Structured plain-text field inspection reports.
   - Formatted for laboratory escalation, chain-of-custody logging, or supply-chain triage.
   - Built-in Report Viewer modal with one-tap copy to system clipboard.

4. **Persistent Local Archive & Search:**
   - Archived records displayed newest-first.
   - Real-time search by Sample ID, product name, or notes.
   - Filter chips: `All`, `Authentic`, `Counterfeit`, `Needs Review`.
   - Swipe-to-delete and individual record deletion with confirmation.
   - Bulk storage wipe with safety prompt.

---

## Architecture & Integration

```
Physical Android Phone (PharmaAssist App)
        │
        │ HTTP Multipart / REST API
        ▼
FastAPI Backend (backend.app.main:app)
  ├── OpenCV Quality Gate (Resolution, Blur ≥ 50, Brightness 15-245)
  ├── EfficientNet-B0 Classifier (outputs/full_data_training/checkpoints/...)
  ├── QwenVisionVerifier (qwen3.5:4b via local Ollama at http://localhost:11434)
  └── DecisionEngine (Conservative 4-rule verdict synthesizer)
```

---

## Quick Start & Setup

### Prerequisites

1. **Python 3.12 Backend Virtual Environment** installed at repository root (`.venv`).
2. **Android SDK Command-Line Tools** (platforms `android-34`/`android-35`, build-tools `34.0.0`/`35.0.0`).
3. **Microsoft OpenJDK 17** installed at `C:\Android\jdk`.
4. **Flutter SDK 3.47.7** or compatible.
5. Android smartphone with **USB Debugging** enabled.

---

### Step 1: Start the FastAPI Backend

Run the following in Windows PowerShell from the repository root:

```powershell
# Activate environment and launch API on all network interfaces
.\.venv\Scripts\uvicorn.exe backend.app.main:app --host 0.0.0.0 --port 8000
```

> **Firewall Note:** When binding to `0.0.0.0`, ensure Windows Defender Firewall allows incoming connections on port `8000` from your private local network.

---

### Step 2: Configure Physical Device Network

1. Connect your Android phone to the **same Wi-Fi network** as your laptop.
2. Note your laptop's local IPv4 address (e.g. `10.152.189.167` or `192.168.1.x`):
   ```powershell
   Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like '*Wi-Fi*' }
   ```
3. In PharmaAssist on the phone:
   - Navigate to **Settings**.
   - Set **Backend URL** to `http://10.152.189.167:8000` (or tap the **Physical Dev** preset chip).
   - Tap **Test Backend Connection**. When green, tap **Save**.

---

### Step 3: Run Tests & Build the APK

From `frontend/flutter_app/`:

```powershell
# Run Flutter automated unit and widget test suite (27 tests)
cmd /c run_flutter.bat test --reporter expanded

# Run static code analysis
cmd /c run_flutter.bat analyze

# Build debug APK
cmd /c run_flutter.bat build apk --debug
```

APK output artifact:
`frontend/flutter_app/build/app/outputs/flutter-apk/app-debug.apk`

---

### Step 4: Install onto Physical Phone

Connect phone via USB and run:

```powershell
adb devices
adb install -r "frontend\flutter_app\build\app\outputs\flutter-apk\app-debug.apk"
```

---

## Secondary AI Verification (Qwen Vision)

The backend integrates an optional secondary vision-language inspection model (`qwen3.5:4b`) hosted via local [Ollama](https://ollama.com):

- **Auto Mode (Default):** Qwen Vision is conditionally invoked only when primary EfficientNet-B0 confidence is in the borderline zone (`0.70 ≤ confidence < 0.90`).
- **Always Mode:** Force Qwen Vision review on every sample for deep physical feature extraction.
- **Never Mode:** Fast-path execution; primary classifier only (~35 ms latency).
- **Graceful Degradation:** If Ollama is offline or times out, the backend gracefully flags `needs_human_verification: true` with an operational warning. Mobile app screening remains operational.

---

## Development HTTP vs Production HTTPS

- **Local Development:** Android `usesCleartextTraffic="true"` is enabled in `AndroidManifest.xml` to allow testing against local development servers over `http://10.x.x.x` or `http://192.168.x.x`.
- **Production Deployment:** For production cloud deployment, all traffic must be routed through HTTPS with valid SSL/TLS certificates and mutual authentication. Cleartext HTTP must be disabled.

---

## Clinical & Scientific Limitations

1. **Camera Optical Screening Only:** Visual inspection can detect surface anomalies, font discrepancies, score inconsistencies, and color variations. It cannot determine chemical composition, Active Pharmaceutical Ingredient (API) potency, or excipient purity.
2. **Not a Laboratory Certificate:** A `LIKELY AUTHENTIC` result is an optical decision-support screen, not a certificate of chemical authenticity or regulatory release.
3. **Environmental Variances:** Glare, camera motion blur, shadows, and packaging plastic can impact convolutional feature extraction. Always use the built-in field guidance for optimal results.
