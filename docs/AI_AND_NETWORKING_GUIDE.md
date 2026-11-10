# PharmaAssist — AI Verification, Ollama Lifecycle & Networking Reference

## 1. Ollama Service Lifecycle (Windows)

### Why the Background Script is Needed
On Windows, launching `ollama app.exe` via desktop shortcut or Windows startup can fail with `Unable to init instance: Unspecified error` when a previous instance left an unreleased process handle or stale PID entry. The CLI server `ollama.exe serve` starts reliably and binds to `127.0.0.1:11434`.

### Startup & Shutdown Scripts
The repository provides idempotent PowerShell scripts in `scripts/`:

- **Start Ollama**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\start_ollama.ps1
  ```
  - Verifies whether an Ollama instance is already responding at `http://127.0.0.1:11434/api/tags`.
  - If responding, does not launch a redundant server.
  - If not responding, launches `ollama.exe serve` in the background and polls up to 15 seconds until the service is ready.
  - Reports all installed models.

- **Stop Ollama**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts\stop_ollama.ps1
  ```
  - Gracefully stops background `ollama` processes without deleting locks blindly.

---

## 2. AI Health & State Machine (`GET /ai/health`)

PharmaAssist introduces a dedicated non-destructive AI operational readiness endpoint:

`GET /ai/health`

### State Machine Lifecycle
The AI secondary verification service tracks the following discrete operational states:

| State | Meaning |
|---|---|
| `NOT_CONFIGURED` | Ollama base URL or configuration is missing. |
| `OLLAMA_UNREACHABLE` | Ollama process is not running or unreachable on configured port. |
| `MODEL_NOT_INSTALLED` | Ollama server is responding, but the configured vision model (`qwen3.5:4b`) is not pulled. |
| `MODEL_LOADING` | Model is currently being loaded into RAM/VRAM (`/api/ps`). |
| `READY` | Model is loaded, reachable, and ready for inference. |
| `INFERENCE_IN_PROGRESS`| Active visual verification request is executing. |
| `INFERENCE_TIMED_OUT`  | Inference exceeded the configured timeout threshold. |
| `INFERENCE_FAILED`     | Model returned invalid payload or unhandled runtime failure. |

### Sample Response (`GET /ai/health`)
```json
{
  "status": "READY",
  "available": true,
  "ollama_reachable": true,
  "ollama_url": "http://127.0.0.1:11434",
  "configured_model": "qwen3.5:4b",
  "installed_models": [
    "qwen3.5:4b",
    "qwen3-vl:4b",
    "nomic-embed-text:latest"
  ],
  "model_installed": true,
  "vision_supported": true,
  "last_inference_time": "2026-11-10T14:40:00Z",
  "last_error": null,
  "message": "Qwen Vision secondary review is ready with model 'qwen3.5:4b'."
}
```

> **Design Rule**: Calling `/ai/health` never downloads models, triggers GPU/CPU token generation, or alters database state.

---

## 3. Model Compatibility & Latency

### Installed Models
- **`qwen3.5:4b`** (Recommended): Full support for structured schema-constrained JSON output (`_QWEN_RESPONSE_SCHEMA`) and vision inputs.
- **`qwen3-vl:4b`**: Vision capable, but raw format may spend token budget on `<think>` without user-facing content in older Ollama runtimes.

### Latency Profiles
- **CPU Cold Inference**: ~65–75 seconds per image on laptop-class CPUs (e.g. AMD Ryzen without dedicated ROCm GPU acceleration).
- **Default Timeouts**:
  - Connection timeout: 5.0s
  - Text inference timeout: 30.0s
  - Image vision timeout: 120.0s (`DEFAULT_OLLAMA_TIMEOUT`)

---

## 4. Mobile Networking & Synchronization Policy

### Physical Android LAN Sync
Physical Android devices connect to the local development backend over Wi-Fi (e.g. `192.168.x.x` or `10.x.x.x`). 

`SyncService.isSecureEndpoint` enforces:
1. **Production / Release**: Strictly requires `https://`.
2. **Development / Debug (`kDebugMode`)**:
   - Permits loopback: `127.0.0.1`, `localhost`, `10.0.2.2` (Android Emulator alias).
   - Permits RFC1918 private IPv4 subnets:
     - `10.0.0.0/8`
     - `172.16.0.0/12` (`172.16.x.x` – `172.31.x.x`)
     - `192.168.0.0/16`
3. **Public Non-HTTPS**: Explicitly rejected at all times (e.g. `http://8.8.8.8` or arbitrary public IPs).

---

## 5. Visual Preflight & Packaging Tolerance

In `ml/inference/predict.py`:
- Clear tablet images pass directly through preflight and the classifier.
- Blister-packs, strip packaging, and multi-pill packaging (`packaging.status == 'VISIBLE / DETECTED'`) are recognized and permitted through the pipeline without premature rejection.
- Images with ambiguous contours (`Uncertain / Background dominant`) without detectable packaging continue through classification, attaching an advisory warning and flagging `needs_human_verification = True`, rather than failing early.
