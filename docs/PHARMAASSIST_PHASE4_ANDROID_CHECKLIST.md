# PharmaAssist Phase 4 Android validation

**Date:** 2026-11-23 (Asia/Kolkata)
**Device:** realme RMX5171, Android 16 / API 36
**App under test:** temporary side-by-side QA build (`com.chethan.pharmaassist.pharma_assist.phase4qa`)

The already-installed `com.chethan.pharmaassist.pharma_assist` app was not
uninstalled or overwritten. Android rejected an in-place update because the
available local signing key differs from the installed build's key. A debug
application ID suffix was used only for device QA and removed from the source
afterward. No physical-device checks below are inferred from automated tests.

## Observed on the physical phone

| Workflow | Result | Notes |
|---|---|---|
| Install and launch | PASS | Side-by-side QA package installed and launched. |
| Camera permission | PASS | Android permission granted; camera opened from the scanner. |
| Camera preview and capture | PASS, limited | Preview and capture completed. The indoor test photo was dark/blurred and was not submitted for AI screening. |
| Retake | PASS | Retake returned to the live capture flow. |
| Gallery selection | PASS | Android photo picker opened; selected an image and returned to scanner. |
| Light, dark, system appearance | PASS | Light palette inspected; system mode restored and followed the phone's dark appearance. |
| Basic app launch/navigation | PASS | Main application and scanner navigation rendered on the device. |

## Not run on physical hardware

| Workflow | Result | Reason |
|---|---|---|
| ML Kit OCR on real medicine packaging | NOT RUN | No real medicine package was available. |
| Edit and save OCR-derived medicine details | NOT RUN | Requires a real package/OCR workflow. |
| Expiry statuses and reminders | NOT RUN | No real medicine profile was entered on device. |
| Packaging checklist and saved observations | NOT RUN | Not exercised on the device. |
| Backend screening, result detail and recovery | NOT RUN | No reachable configured screening server was available. |
| History image comparison/zoom | NOT RUN | No physical screening record was created. |
| PDF, CSV and TXT exports | NOT RUN | No physical records were available to export. |
| Authenticated synchronization | NOT RUN | The device had no configured credentials or reachable sync service. |
| Enlarged system text and keyboard flows | NOT RUN | Covered by widget/layout tests only. |
| Other screen sizes / large Android device | NOT RUN | Only the RMX5171 was available. |

## Automated coverage (separate from device checks)

Flutter widget tests cover scanner and medicine-related screens, themes,
navigation, small/wide layouts, and enlarged text. Backend tests cover sync
authentication, malformed and oversized payloads, duplicate/conflicting
records, persistence failures, and isolation from prediction. These do not
replace the physical workflows marked NOT RUN above.

## Phase 5 physical-device validation

No Phase 5 workflow below was physically exercised during the Phase 5 code and documentation work. These remain **NOT RUN**, even though automated tests cover data models and service behavior.

| Workflow | Result | Required follow-up |
|---|---|---|
| Capture and label multiple package sides | NOT RUN | Test camera capture, retake, per-image replace/remove, and persistence on Android. |
| Real-package multi-image OCR and conflict review | NOT RUN | Test legibility, raw OCR display, correction, and two-view conflicting batch/date values. |
| QR/barcode scan and manual entry | NOT RUN | Test supported symbologies, permissions, malformed/long values, and ensure decoded URLs are not opened. |
| Official CDSCO alert lookup | NOT RUN | Configure reachable backend and exercise consent, matched notice, no match, timeout, and displayed source data. |
| Ollama explanation | NOT RUN | Verify configured local/service endpoint and ensure explanation cannot change fixed status. |
| Verification history | NOT RUN | Save a lookup on device, restart app, search record, inspect source and timestamp. |
| Existing dual-photo comparison/zoom | NOT RUN for Phase 5 regression | Confirm multi-image additions have not changed original comparison behavior. |

Automated validation must be reported separately and is not physical-device evidence.

## Follow-up release install and scanner check (2026-11-23)

The release APK built for the medicine-data enhancement was verified with
`apksigner`. Its signing-certificate SHA-256 matched the already-installed
`com.chethan.pharmaassist.pharma_assist` app. `adb install -r` succeeded, so
the app was updated in place without uninstalling or clearing its local data.
The app launched and the live camera scanner preview was observed; camera
permission was granted.

This does not supersede the earlier QA table and is not evidence for barcode
decoding, OCR on real packaging, saving edited profiles, PDF export, screening,
or synchronization. Those workflows remain **NOT RUN** on physical hardware.
