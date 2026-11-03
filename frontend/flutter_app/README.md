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
enter `http://<host-lan-ip>:8000` in Settings. Keep the phone and computer on
the same network.

The app supports camera capture, gallery selection, preview and retake,
client-side file checks, upload progress states, retry after request failure,
sample IDs, notes, a 50-record local history, CSV metadata export, and
copyable inspection reports.

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
