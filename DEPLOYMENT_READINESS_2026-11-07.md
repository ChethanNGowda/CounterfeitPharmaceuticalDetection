# PharmaAssist deployment readiness and device test plan

## Readiness status

The local backend synchronization flow, Flutter tests, and Android debug APK
build are validated. This is not a production deployment approval. Physical
Android-device testing and deployed HTTPS testing remain pending.

The application performs preliminary visual screening only. It must not be
presented as proof of pharmaceutical authenticity, chemical composition,
safety, dosage, or regulatory approval.

## Backend deployment checklist

Before any non-local deployment:

- Terminate TLS at a trusted HTTPS endpoint and reject production cleartext
  traffic. Validate certificates normally; do not disable certificate
  validation.
- Set `PHARMA_SYNC_DB_PATH` and `PHARMA_SYNC_IMAGE_DIR` to protected,
  environment-specific locations outside the source checkout.
- Provision one credential per device with the offline administrator utility.
  Deliver each token through an approved secure channel; never commit, print
  to application logs, or embed tokens in Flutter/Android assets.
- Revoke lost, retired, or compromised device credentials and verify that
  revoked tokens receive `401`.
- Back up SQLite and separately protect synchronized image files. Test restore
  into an isolated environment before relying on backups.
- Define retention and deletion ownership for metadata, notes, and images.
  Do not retain records indefinitely by default.
- Preserve the API limits: 256 KiB synchronization records and 15 MiB images.
  Keep reverse-proxy limits at least as strict as the application limits.
- Monitor authentication failures, validation failures, persistence failures,
  and restart health without recording bearer tokens, notes, image content, or
  sensitive payloads.
- Confirm accepted records survive a server restart and that database
  permissions prevent unauthorized access.
- Confirm synchronization stores client screening metadata as unverified and
  never runs `/predict` or `/verify`.

## Android physical-device procedure

Use only a disposable device credential and a backend reachable from the
phone. Record each result in the table; do not mark a test passed before
executing it.

| Test | Expected result | Actual result |
|---|---|---|
| Install debug APK | APK installs without an unsafe production claim | Pending |
| Camera permission and capture | Permission is requested; captured image can be previewed | Pending |
| Gallery selection | Supported image can be selected and previewed | Pending |
| Backend configuration | Device can reach the configured development backend | Pending |
| Credential entry | Credential is stored in Android secure storage, not preferences | Pending |
| Consent disabled | No new synchronization upload occurs | Pending |
| Metadata synchronization | Consent enabled and valid credential produce a synced record | Pending |
| Duplicate submission | Same stable record is handled idempotently; no duplicate server record | Pending |
| Network unavailable | Local history remains; queue entry and retry metadata remain | Pending |
| Network restored | Eligible queued record retries and becomes synced | Pending |
| Offline-only mode | No upload or queue submission occurs | Pending |
| History and report | Local record, status, notes, and report remain available | Pending |
| App restart | Local history, queue state, consent, and credential behavior persist safely | Pending |
| Revoked credential | Upload is blocked and the queue does not retry forever | Pending |

During testing, verify the server database independently and confirm that
metadata-only tests create no image file. Do not use a production endpoint or
production credential.

## APK integrity record

The debug APK is produced by:

```powershell
cd frontend\flutter_app
flutter build apk --debug
```

Validated toolchain: Flutter 3.47.7 and Dart 3.13.5. Record the checksum and
size from the exact APK delivered to the tester:

```powershell
Get-FileHash .\build\app\outputs\flutter-apk\app-debug.apk -Algorithm SHA256
Get-Item .\build\app\outputs\flutter-apk\app-debug.apk | Select-Object FullName,Length
```

This procedure covers a debug APK only; it does not create or validate a
release APK.

## Remaining risks and external validation

- The prototype uses SQLite and filesystem image storage; production backup,
  retention, deletion, access control, and monitoring must be operated
  deliberately.
- Device-specific network reachability, Android permissions, secure-storage
  behavior, and app restart behavior require a physical-device test.
- TLS termination, deployed authentication, and server-side persistence must
  be tested in the intended HTTPS deployment.
- Offline-only mode does not provide local AI screening because a validated
  Android inference runtime and model conversion are not present.
