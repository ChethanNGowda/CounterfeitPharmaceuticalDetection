# PharmaAssist Flutter client

This directory contains the Android Flutter client for the PharmaAssist
preliminary medicine-image screening system. It captures or selects an image,
sends it to the configured FastAPI backend, displays the confidence-qualified
screening result, and stores a local archive of inspection metadata.

The client does **not** authenticate medicines. It cannot establish chemical
composition, dosage, safety, regulatory approval, or definitive authenticity.
Use pharmacist, authority, and certified laboratory review for decisions that
affect treatment or product disposition.

## Requirements

- Flutter 3.47.7 or a compatible stable release
- Dart 3.13.5 or compatible SDK
- Android SDK and Java 17 for Android builds

Install dependencies:

```powershell
flutter pub get
```

## Run and configure

The backend URL is configured from the app's **Settings** screen and persisted
locally. The source default is `http://127.0.0.1:8000`; it is intentionally
not a developer-specific LAN address.

For an Android emulator, the host computer is normally reachable at
`http://10.0.2.2:8000`:

```powershell
flutter run --dart-define=PHARMA_API_BASE_URL=http://10.0.2.2:8000
```

For a physical phone, run FastAPI on the host's private LAN interface and
enter the configured development URL in Settings. Keep the phone and computer
on the same network. Record synchronization itself requires an HTTPS endpoint;
plain HTTP LAN URLs remain unsuitable for bearer-token synchronization.

The app supports camera capture, gallery selection, preview and retake,
client-side file checks, upload progress states, retry after request failure,
sample IDs, notes, a 50-record local history, CSV metadata export, and
copyable inspection reports. Settings provides three coordinated operating
modes:

- **Automatic** uses the configured FastAPI backend when screening is requested.
- **Offline only** keeps the app, history, notes, and reports local. AI screening
  is explicitly unavailable because this checkout does not contain a validated
  Android inference runtime or converted pharmaceutical model.
- **Backend preferred** uses the configured backend and never substitutes an
  unvalidated local model.

The current offline phase does not upload images or fabricate local predictions.
Local model conversion, parity testing, latency measurement, and memory
measurement remain prerequisites before offline AI screening can be enabled.
The current checkout has no Android inference runtime or converted model; see
the [on-device inference audit](../../reports/ON_DEVICE_INFERENCE_AUDIT_2026-11-05.md).

### Hybrid synchronization

Synchronization consent is disabled by default. When enabled, newly created
backend-screened records may be queued for metadata synchronization; older
records are not automatically enqueued. The device bearer credential is stored
with Android secure storage, never `SharedPreferences`. Images are not uploaded
by the current client integration, and offline-only records never enter the
queue. Non-localhost synchronization endpoints must use HTTPS. Conflicts,
revoked credentials, and insecure endpoints are shown as blocked/conflict
states rather than retried indefinitely.

Provision a device credential with the backend administrator command described
in the root `BACKEND_SYNC_API_2026-11-05.md`, then enter that token in Settings.
This only stores client history metadata; it does not verify medicine
authenticity or rerun screening.

## Validation and build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to
`build\app\outputs\flutter-apk\app-debug.apk`.

Debug builds permit cleartext HTTP for local development. Use HTTPS and
appropriate authentication/network controls for production deployments.
Camera and internet permissions are declared in
`android/app/src/main/AndroidManifest.xml`.

See the repository [README](../../README.md) for backend setup, API examples,
model requirements, dataset evidence, decision semantics, Ollama
troubleshooting, and responsible-use limitations.
