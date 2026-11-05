# Backend synchronization API

## Status

The backend now provides a versioned, authenticated metadata synchronization
endpoint. It does not run screening and does not treat client predictions as
verified pharmaceutical-authenticity evidence.

## Authentication

Each installation receives an individual bearer credential. Provision and
revocation are local administrative operations:

```powershell
python -m backend.sync_admin --db data\pharma_sync.sqlite3 provision phone-001
python -m backend.sync_admin --db data\pharma_sync.sqlite3 revoke phone-001
```

The provisioning command prints the token once. The database stores only a
salted PBKDF2-HMAC-SHA256 hash. Tokens must be delivered and stored through a
secure deployment mechanism; they are not embedded in Flutter or Android
assets. The API accepts `Authorization: Bearer pa1.<device-id>.<secret>`.

## Endpoint

`POST /sync/records`

Send a JSON body containing `api_version: "v1"`, `client_record_id`,
`client_created_at`, `operating_mode`, `provider`, `sync_status`,
`screening_metadata`, optional `notes`, and `image_upload_consent`. Images are
optional base64 payloads and require consent plus `image_media_type`. The
server validates and stores images under generated UUID filenames; client
filenames and paths are never used.

The endpoint returns a server record ID, synchronization timestamp, duplicate
flag, and `screening_verified: false`. Repeating an identical record for the
same device returns the original server ID. Reusing the client ID with
different data returns `409 Conflict`. Records from different devices are
isolated.

Authentication failures return `401`; invalid data returns `400`/`422`;
unsupported images return `415`; oversized payloads return `413`; durable
persistence failures return `500`.

## Persistence and limits

SQLite is used for this prototype. Set `PHARMA_SYNC_DB_PATH` to choose the
database location and `PHARMA_SYNC_IMAGE_DIR` to choose the image directory.
The default database is `data/pharma_sync.sqlite3`, which must remain outside
source control. SQLite transactions and a device/record unique constraint
protect concurrent duplicate submissions. Record JSON is limited to 256 KiB
and images to 15 MiB.

Backups, retention, deletion, TLS termination, and credential delivery remain
deployment responsibilities. Use HTTPS and protect the database and image
directory. Notes and images may contain sensitive information and are not
included in application logs.

The Flutter client integration stores the individual bearer token in Android
secure storage, defaults synchronization consent to disabled, sends metadata
only, and requires HTTPS except for loopback/emulator development endpoints.
It does not upload images. Before production use, deploy this API with secure
credential delivery, HTTPS, database/image retention controls, and a tested
device-specific configuration.

The client validation in this phase completed Flutter analysis and 58 Flutter
tests. The Android debug build requires Windows Developer Mode (or equivalent
symlink support) because Flutter plugins are present; APK compilation remains
an environment-dependent manual check when that capability is enabled.
