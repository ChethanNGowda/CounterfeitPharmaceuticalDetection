# PharmaAssist 2.0 — Technical Project Report

**Repository:** `ChethanNGowda/CounterfeitPharmaceuticalDetection`
**Project type:** Research and educational prototype for preliminary packaging-image screening
**Report status:** Implementation report; not a clinical or regulatory evaluation

## 1. Abstract

PharmaAssist is a Flutter Android client and Python/FastAPI service for
preliminary image-based pharmaceutical package screening. It combines a
server-side EfficientNet-B0 classifier with input-quality checks and optional
Ollama advisory text generation. The client also supports local records,
multiple package views, on-device OCR suggestions, expiry tracking, user
packaging observations, scan history, reports, QR/barcode value capture, and
consented authenticated metadata synchronization. An optional official alert
check compares reviewed fields with a bounded CDSCO notice source. None of
these mechanisms establishes medicine composition, dosage, safety, or
definitive authenticity. There is no Android inference runtime, positive
manufacturer verification integration, or physical-device validation of all
new Phase 5 workflows.

## 2. Introduction

Packaging inspection and traceability are relevant to identifying suspicious
medical products, but visual appearance and a decoded identifier are
insufficient to confirm what a product contains or who manufactured it. This
project explores software-assisted triage while keeping the output
preliminary and requiring human/regulatory follow-up.

## 3. Problem statement

Users lack a structured way to capture package views, retain OCR suggestions,
record observations, and consult a bounded official alert source from a single
workflow. Image-based classifiers also have distribution and quality limits.
The system must expose those limits, preserve uncertain cases, and avoid
turning a model score or missing alert into a guarantee.

## 4. Objectives

- Provide an Android interface to submit an image for backend screening.
- Preserve offline access to locally stored records and reports.
- Assist entry of package information with editable, sourced OCR suggestions.
- Compare values extracted from multiple package sides without silently
  replacing conflicts.
- Provide a narrowly scoped official alert lookup and retain its sources.
- Synchronize consented records through a separate authenticated API.
- Communicate limitations and request human review for uncertain evidence.

## 5. Literature and technical background

EfficientNet studies compound scaling of CNN width, depth, and input
resolution. MobileNetV3 studies hardware-aware architecture search for
resource-constrained devices. Grad-CAM produces coarse class-activation
localization from gradients; it explains model sensitivity, not chemical
composition. ML Kit Text Recognition returns text structure from images, but
recognition quality depends on image focus, resolution, and legibility. These
papers/docs inform implementation choices; they do not validate PharmaAssist
as a medical device. Primary references appear in Section 25.

## 6. Existing system and scope

The repository already contained image screening, history, reporting, sync,
OCR, and packaging tools. Phase 5 extends these existing flows rather than
creating a replacement application. The current backend classifier path uses
the verified EfficientNet-B0 checkpoint. Other model architectures in the
registry do not imply that usable pharmaceutical checkpoints are present.

## 7. Proposed system

The proposed system is a client/server screening and record-management
prototype. The client handles capture, editable records, local storage,
reports, and user observations. The backend performs image checks and
classifier inference. A separate route checks reviewed medicine metadata
against CDSCO spurious-drug alert documents. Ollama can explain returned
evidence, but cannot change its deterministic status.

## 8. Requirements

### Functional

- Capture/select screening and medicine photos.
- Keep multiple labelled package images and associated OCR text.
- Edit and save medicine details and expiry date.
- Capture manual or decoded product identifiers.
- Search and review local records and screening history.
- Export available PDF/CSV/TXT reports.
- Synchronize records only through authenticated `/sync/records`.
- Query the fixed official alert integration when a batch is available.

### Non-functional

- Retain local records during backend outages.
- Validate file, field, payload-size, and source-host boundaries.
- Keep credentials out of application source and user-visible errors.
- Preserve old local medicine profile fields.
- Avoid unsupported certainty, calibration, or offline-inference claims.

## 9. System architecture

The Flutter app communicates with FastAPI for requested screening and
verification. Local profile, OCR, and inspection data remain on-device. The
sync API is a separate authenticated path to SQLite. See
[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) for the Mermaid data-flow
diagrams and route details.

## 10. Methodology

The implementation was audited before additions. Work was grouped around
multi-image medicine capture, OCR provenance and conflicts, raw QR/barcode
identifier handling, fixed-source official alert lookup, local verification
history, regression tests, and documentation. Source tests use mocked network
transport; tests do not contact CDSCO or Ollama. Changes remain uncommitted in
the existing working tree.

## 11. Dataset and preprocessing

The project contains dataset manifests and historical evaluation artifacts.
Their counts and results are tied to those manifest revisions and split
definitions. This report does not claim newly reproduced dataset counts or
metrics. Backend preprocessing is implemented in `ml/` and includes image
decode/quality checks followed by the model's 224×224 RGB normalization
contract. Refer to the dated audits and model report before attempting exact
reproduction. Dataset representativeness for medicines, packaging, sites,
manufacturers, and cameras remains an open evaluation question.

## 12. Model architecture

EfficientNet-B0 is the available pharmaceutical classifier checkpoint in the
current project state. Its checkpoint registry, class order, and preprocessing
implementation are the source of truth. Other architectures are registered
for research/availability reporting but their trained pharmaceutical
checkpoints are currently unavailable. Grad-CAM is available in the Python
research/evaluation path where compatible. No model ensemble was added.

## 13. Training and evaluation

This implementation phase did not retrain a model or produce new evaluation
metrics. Historical reports include results from specific saved splits, but
these are not independently revalidated here and are not field, clinical,
prospective, or regulatory evidence. Confidence is not asserted to be a
calibrated probability. No improvement in classifier accuracy is claimed.

## 14. OCR implementation

The Flutter client uses its shared ML Kit OCR engine on selected medicine
views. Extracted values are suggestions with image-view provenance and raw
recognized text. The editor allows correction, retains ambiguous/missing
values as blank, and exposes differences across views instead of silently
choosing one. This feature was validated with parser and persistence tests;
new package OCR was not physically tested in this Phase 5 work.

## 15. Medicine information management

Local profiles hold name, manufacturer, strength, dosage form, batch,
manufacturing/expiry data, MRP, product identifier, notes, images and OCR
records. New image bytes are copied to app-private documents storage with a
size cap; the pre-existing image-path field remains supported for old records.
User edits are explicit. The system does not infer missing dates or batches.

## 16. Expiry management

Expiry status uses saved profile dates and the existing date parser. Month/year
interpretation and invalid or ambiguous values are covered by regression
tests. Unknown dates remain unknown. The reminder/status feature is a local
record utility, not a medicine safety or stability determination.

## 17. Packaging inspection

The seven-point checklist and user-authored observations remain separate from
AI outputs. Existing photo comparison and zoom are preserved. Visual
observations are not converted into a machine conclusion about authenticity;
the repository does not claim a validated packaging anomaly detector.

## 18. Online verification

The implemented route reads the official CDSCO alerts page and linked,
same-host HTTPS PDF notices within fixed size/page/time limits. A potential
concern requires a matching batch together with product context in the
retrieved notice. Source mismatch, absent notice, missing batch, or retrieval
failure is reported as unable to verify. The current integration does not
query manufacturer authentication portals or other government traceability
systems and does not issue `officially_verified`. Optional Ollama explanation
is generated from bounded excerpts as untrusted evidence and cannot change
the status. The Flutter consent step sends reviewed fields only, not photos.

## 19. Backend and synchronization

FastAPI retains screening routes and aliases. Device record synchronization
continues on a separate authenticated `/sync/records` endpoint with a SQLite
store, token hashing/revocation, size limits, idempotency, and local retry
behavior. `/verify` remains a backward-compatible screening alias; it is not
medicine verification. See `docs/API_REFERENCE.md` and
`BACKEND_SYNC_API_2026-11-05.md` for route-specific contracts.

## 20. Testing and results

At the Phase 5 validation checkpoint, `flutter analyze` passed with no issues,
all 129 Flutter tests passed, and the complete Python `pytest -q` suite passed
(232 tests). A focused mocked verification/request-size run initially exposed
one test assertion mismatch, which was corrected before the full passing
suite. The release APK built in 204.9 seconds at 108,820,902 bytes (103.8
MiB); `apksigner verify` confirmed a valid APK v2 signature. The build reports
a future Kotlin Gradle Plugin compatibility warning for two plugins. Final
Flutter rerun passed analysis and all 129 tests; final backend run passed all
232 tests; `git diff --check` passed with Git line-ending conversion notices.

## 21. Security and privacy

The online alert endpoint accepts structured fields, not caller URLs or image
uploads. Its source host and allowed paths are fixed; redirects and proxy
inheritance are disabled, response sizes are bounded, and transport failures
degrade to unable-to-verify. Ollama receives excerpts only for explanation
and is instructed to treat them as untrusted; it has no verification
authority. Sync remains authenticated and separate. Local medicine photos and
OCR data are not added to sync payloads. Deployment operators must still
configure TLS, restrict Ollama/network/database access, define retention, and
manage server-side backups.

## 22. Limitations

- No Android inference runtime; offline AI screening is unavailable.
- Only EfficientNet-B0 has a verified usable checkpoint in the supported
  screening path.
- No calibrated output or clinical/field validation claim.
- Image screening cannot establish composition, dosage, safety, or definitive
  authenticity.
- The alert integration only checks CDSCO public alert documents; no matching
  alert is not evidence of authenticity.
- No manufacturer API credentials/integration are configured.
- OCR is imperfect and requires user review.
- This Phase 5 scanner/verification/multi-image workflow is not physically
  validated on an Android device.
- The application does not provide stock management, prescription handling,
  user roles, or authoritative storage guidance.

## 23. Future enhancements

Potential work includes a formally authorized manufacturer verification
integration, multilingual field testing, prospective representative datasets,
calibration and external evaluation, accessibility/device studies, and
audited product-specific reporting. Any new source must have documented
authorization, availability, terms, and failure semantics before integration.

## 24. Conclusion

PharmaAssist combines preliminary server-side visual screening with local
medicine records and user review tools. Phase 5 extends package-photo/OCR
handling and adds a bounded official-alert check without treating the classifier,
barcode, absent alert, or language model as proof. The project remains a
research prototype requiring expert review and broader validation.

## 25. References

1. World Health Organization. “Substandard and falsified medical products.”
   [Fact sheet](https://www.who.int/news-room/fact-sheets/substandard-and-falsified-medical-products).
2. Central Drugs Standard Control Organization. “Guidance for Identification
   and Verification of Spurious Drugs.”
   [Official guidance PDF](https://www.cdsco.gov.in/opencms/export/sites/CDSCO_WEB/Pdf-documents/Guidance-for-Identification-and-Verification-of-Spurious-Drugs_.pdf).
3. Central Drugs Standard Control Organization. [Official Alerts page](https://www.cdsco.gov.in/opencms/opencms/en/Alerts/).
4. Tan, M. and Le, Q. V. “EfficientNet: Rethinking Model Scaling for
   Convolutional Neural Networks.” ICML 2019.
   [PMLR](https://proceedings.mlr.press/v97/tan19a.html).
5. Howard, A. et al. “Searching for MobileNetV3.” ICCV 2019.
   [CVF](https://openaccess.thecvf.com/content_ICCV_2019/html/Howard_Searching_for_MobileNetV3_ICCV_2019_paper.html).
6. Selvaraju, R. R. et al. “Grad-CAM: Visual Explanations from Deep Networks
   via Gradient-Based Localization.” ICCV 2017.
   [CVF PDF](https://openaccess.thecvf.com/content_ICCV_2017/papers/Selvaraju_Grad-CAM_Visual_Explanations_from_Deep_Networks_via_Gradient-Based_Localization_ICCV_2017_paper.pdf).
7. Google. [ML Kit Text Recognition v2 documentation](https://developers.google.com/ml-kit/vision/text-recognition/v2).

## Reproduction materials

- [Architecture](../docs/ARCHITECTURE.md)
- [API reference](../docs/API_REFERENCE.md)
- [OCR and medicine records](../docs/OCR_AND_MEDICINE_RECORDS.md)
- [Model and dataset notes](../docs/MODEL_AND_DATASET.md)
- [Security and privacy](../docs/SECURITY_AND_PRIVACY.md)
- [Progress and validation log](../docs/PHARMAASSIST_2_PROGRESS.md)
- [Physical Android checklist](../docs/PHARMAASSIST_PHASE4_ANDROID_CHECKLIST.md)
- [Protected baseline recovery guide](../docs/RECOVERY_GUIDE.md)
