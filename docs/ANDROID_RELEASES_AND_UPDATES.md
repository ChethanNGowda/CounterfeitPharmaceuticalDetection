# PharmaAssist Android releases and in-app updates

PharmaAssist checks a static manifest attached to the latest GitHub Release,
avoiding unauthenticated GitHub API rate limits. The Android app can display
release information, download the universal APK over HTTPS, verify its SHA-256 digest,
and open Android's package installer. Android always asks the user to confirm
installation. The app never silently installs an update.

## One-time release signing setup

Every update must be signed with the same Android signing key as the installed
application. Losing or changing this key prevents normal in-place updates.

Create a dedicated release keystore on a secure machine. Do not commit it or
send it in chat:

```powershell
keytool -genkeypair -v -keystore pharmaassist-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias pharmaassist
```

Keep at least two secure offline backups of the keystore and its passwords.
Anyone who obtains the keystore and passwords can publish an update that
Android treats as the same application.

Encode the keystore for a GitHub Actions secret in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\pharmaassist-release.jks"))
```

In GitHub, open **Settings → Secrets and variables → Actions** for this
repository and add these four repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 output from the command above |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | `pharmaassist` (or the alias selected above) |
| `ANDROID_KEY_PASSWORD` | Key password |

Never put these values in source code, README files, issues, commits, or
screenshots.

## Publish a release

The workflow `.github/workflows/android-release.yml` runs when a version tag
such as `v1.2.1` is pushed. It:

1. Checks that all four signing secrets exist.
2. Builds with Flutter 3.47.7 and Java 17.
3. Runs Flutter analysis and tests.
4. Builds a signed universal Android APK.
5. Publishes `pharmaassist-android-universal.apk` and its SHA-256 file as a
   GitHub Release asset.
6. Generates GitHub release notes.

After merging the release-ready code to `main`, create and push a new tag:

```powershell
git checkout main
git pull origin main
git tag v1.2.1
git push origin v1.2.1
```

Use a new, higher semantic version for each release. Do not reuse an existing
tag. The app reads the latest published stable GitHub release, so do not
publish a release until the APK has passed its checks.

## User update experience

- A release build checks for a newer stable version at startup.
- Users can also open **More → Settings → App Updates** and check manually.
- Release notes and version are shown before downloading.
- The APK is downloaded to app-private temporary storage over HTTPS.
- If GitHub provides the asset digest, the downloaded APK is SHA-256 checked.
- Android may ask the user to allow PharmaAssist to install updates.
- Android's system package installer displays the final confirmation.

This is a sideload update channel, not silent background installation. Users
must approve Android's installation prompt. Device policy, Play Protect, OEM
settings, or an incompatible signing key can block installation.

## First migration from previously distributed APKs

Older project release builds used the Android debug signing key. A dedicated
production key will not match that signature. If an older debug-signed APK is
already installed, the first production-key build may require uninstalling the
old app before installing the new one. Uninstalling removes local app data.
Export or back up records before that migration.

Once users have installed the first build signed with the dedicated release
key, all later updates must use that exact same key. Never rotate it casually.

## OCR engine

The Medicine screen uses Google ML Kit on-device Text Recognition rather than
filename-derived sample text. Latin recognition is included; Android also
bundles the optional Devanagari model for common Indian-language packaging.
OCR fields are suggestions only. Users must compare extracted details with the
physical packaging and confirm them manually. The OCR confidence label reports
field-extraction completeness; it is not a probability of medicine authenticity.

ML Kit can still misread tiny, curved, reflective, blurred, damaged, or poorly
lit text. Retake the image, use even lighting, avoid glare, fill the frame with
the label, and review the recognized raw text.

## Important scope

The updater distributes the Android APK only. It does not update the FastAPI
backend, model checkpoints, datasets, or server-side dependencies. Those
components require their own deployment and versioning process.
