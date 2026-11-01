# Counterfeit Pharmaceutical Detection Repository Audit

**Audit date:** 2026-11-01  
**Repository:** `ChethanNGowda/CounterfeitPharmaceuticalDetection`  
**Audited branch:** `main`  
**Scope:** Git state, FastAPI and ML pipeline, Qwen/Ollama integration, Flutter workflows, tests, evaluation and split safeguards, configuration, documentation, and security posture.

## Executive summary

No verified P0 issue was found. The repository has a coherent screening pipeline with image-quality gating, model registry support, confidence-qualified decisions, Grad-CAM/evaluation tooling, Qwen Vision integration, and a Flutter client. The highest-priority work is security hardening and restoring a consistent test/documentation contract after the recent authentic-probability decision-band changes.

This audit makes no claim that the model authenticates medicines. The application remains a preliminary visual screening tool and requires human or laboratory verification.

## Repository state

- Branch: `main`
- Remote: `origin` points to `https://github.com/ChethanNGowda/CounterfeitPharmaceuticalDetection.git`
- Audit began with a clean worktree after commit `1751455` (`Remove obsolete project documentation`).
- No obvious secret-bearing filenames were tracked; `.env` is ignored and `.env.example` contains placeholders only. This is not a substitute for secret scanning.
- No standalone research paper for the current PharmaAssist implementation is tracked at the repository root. The repository contains project reports and imported material under `external_models/TrueMeds/`; those documents must not be presented as current PharmaAssist evidence without provenance review.

## Verification performed

- Flutter tests: passed (the Flutter test command exited successfully).
- Python tests excluding `tests/test_api.py`: **127 passed, 20 failed**.
- Full Python collection: blocked before execution because the active environment does not provide the `httpx2` package required by the installed Starlette TestClient, despite `httpx2` being listed in `requirements.txt`.
- The failing Python tests are concentrated in stale confidence-based/Qwen gating and decision expectations, plus an out-of-range threshold expectation. They are evidence of contract drift, not a basis for changing thresholds or weakening validation.

## Prioritized incomplete-task checklist

### P0 — Critical

- [ ] None verified during this audit.

### P1 — Important

#### Security and operational safety

- [ ] **Restrict API exposure before deployment.** `backend/app/main.py:34-39` enables all origins, methods, headers, and credentials. Add an explicit production allowlist and document the development-only configuration.
- [ ] **Protect expensive unauthenticated inference.** `backend/app/routes/predict.py:65-127` accepts unauthenticated uploads up to 15 MB and can trigger a 180-second Ollama call. Add deployment-level authentication, rate limiting, concurrency/resource limits, and request timeouts; add tests for abuse controls.
- [ ] **Define a safe Ollama transport policy.** `ml/verification/qwen_verifier.py:269-272,408-412` sends image data to an environment-selected URL that defaults to plaintext HTTP. Require or explicitly warn about HTTPS for non-loopback endpoints, and document the privacy boundary.
- [ ] **Redact internal exception details.** `backend/app/routes/predict.py:124-127,207-214` returns raw exception text to clients. Log detailed diagnostics server-side and return stable, non-sensitive error messages.
- [ ] **Validate checkpoint provenance before deserialization.** `ml/models/transfer_learning.py:97,110,123,211,248` uses pickle-capable `torch.load` paths. Add trusted-path and SHA-256 verification (or a safe loading strategy) before loading deployment checkpoints. The model endpoint currently reports hashes but does not enforce them.
- [ ] **Correct iOS permissions.** `frontend/flutter_app/ios/Runner/Info.plist` has no camera or photo-library usage descriptions while `scan_screen.dart:88-156` uses `image_picker`. Add the required iOS permission declarations and a device-level validation test/check.
- [ ] **Protect stored scan history.** `frontend/flutter_app/lib/services/storage_service.dart:108-119` stores full scan records in unencrypted `SharedPreferences`, while `frontend/flutter_app/README.md` describes encrypted local storage. Use a protected storage design or correct the claim and document the risk.
- [ ] **Make production transport explicit.** `frontend/flutter_app/lib/core/constants.dart:8-11` and `storage_service.dart:42-46` default to HTTP and permit arbitrary user-entered URLs. Define HTTPS/authentication expectations and avoid treating LAN HTTP as production-safe.

#### Correctness and evidence integrity

- [ ] **Bring Python tests and implementation back to one contract.** The current implementation uses authentic-probability bands (`ml/config.py:35-42`, `ml/verification/decision_engine.py:45-56`), while multiple tests still assert the removed confidence-band behavior. Update tests only after confirming the intended behavior; do not restore obsolete thresholds merely to make the suite green.
- [ ] **Resolve the API test/environment blocker.** `tests/test_api.py` cannot be collected because `httpx2` is unavailable in the active environment. Install from the declared dependency set in a controlled environment and update the stale threshold case (`tests/test_api.py:93-104`) to expect the route’s documented `1.0` upper bound.
- [ ] **Reconcile evaluation and leakage claims.** `reports/duplicate_leakage_audit.md:97-119` documents five exact train/test duplicate groups and warns that reported accuracy may be inflated, while `README.md` presents the split as leakage-controlled. Re-run evaluation on a deduplicated/grouped split before presenting headline metrics as generalization evidence.
- [ ] **Correct Qwen architecture documentation.** `README.md:117-119` describes image-based Qwen Vision, while `reports/FINAL_PROJECT_AUDIT_REPORT.md:125-130` describes the legacy text-only `qwen3:8b` evidence reviewer. Mark the legacy reviewer clearly and identify the production path consistently.

### P2 — Polish and maintainability

- [ ] **Remove or isolate duplicate legacy paths.** `ml/verification/qwen_reviewer.py` is explicitly legacy but remains exported and tested; `ml/preprocessing/image_preprocessor.py` is also legacy. Keep compatibility only where required, otherwise deprecate and prevent production use.
- [ ] **Avoid duplicate image validation.** PIL validation occurs in `backend/app/services/classifier.py:56-68`, while quality/readability work is repeated in `ml/inference/predict.py:224-230,256`. Consolidate only after measuring that the quality-gate behavior remains unchanged.
- [ ] **Limit or omit raw Qwen output.** `ml/verification/qwen_verifier.py:131,471` and `backend/app/schemas/predict.py:97` expose `raw_text` in API responses. Add a size limit/redaction policy if this field is retained.
- [ ] **Refresh runtime model availability.** `ml/config.py:55-100` computes checkpoint availability at import time, while startup preloads the default model. Add explicit startup diagnostics and tests for missing/corrupt checkpoints.
- [ ] **Persist historical images deliberately.** `scan_screen.dart:229` stores a picker/cache path, and `history_screen.dart:809-817` opens results without an image file. Copy images to managed app storage or present a clear “image unavailable” state.
- [ ] **Implement real report export/share or rename the feature.** `report_service.dart:350-378` and `results_screen.dart:841-853` copy text to the clipboard; the UI does not provide the claimed file export/share workflow.
- [ ] **Add Flutter workflow coverage.** Add tests for camera/gallery permissions, multipart upload errors, durable history images, report export/share, and backend timeout/error states.
- [ ] **Reconcile model status and metrics across documents.** `reports/FINAL_PROJECT_AUDIT_REPORT.md:100-123`, `README.md:65-101`, and `frontend/flutter_app/README.md:13` make inconsistent claims about available comparison checkpoints and accuracy. Use one generated/evidence-linked source of truth.

## Existing strengths to preserve

- The API validates MIME type, decoded image format, empty uploads, and a 15 MB size limit.
- The decision engine retains a separate manual-review outcome and does not treat an authentic prediction as proof of authenticity.
- Quality failures prevent normal classification and secondary review.
- Qwen is local/optional and has explicit unavailable/degraded states.
- Model registry and evaluation scripts distinguish fine-tuned availability from generic pretrained assets.
- Dataset audit scripts and duplicate reports exist; their warnings need to be reflected in the headline documentation.

## Recommended implementation order

1. Establish the intended authentic-probability contract and update the stale Python tests.
2. Resolve the declared `httpx2` environment dependency and make the API suite runnable.
3. Harden API exposure, error redaction, checkpoint verification, and Ollama transport.
4. Fix iOS permissions and clarify/enforce Flutter storage and transport security.
5. Reconcile evaluation/Qwen/model documentation, then add missing workflow tests.
6. Consolidate legacy/duplicate paths only after compatibility tests cover the production pipeline.
