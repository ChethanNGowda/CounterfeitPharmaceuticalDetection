# Hybrid offline-first synchronization design

**Date:** 2026-11-05  
**Starting commit:** `9011f5c01abf7fa58c404461d8b914d1f6cbf638`

## Audit findings

The Flutter client currently stores scan history and settings in
`SharedPreferences`. `ScanHistoryItem` already has a stable generated ID and
preserves the server response, notes, sample ID, timestamp, and image path.
The existing API client supports only:

- `POST /predict`
- `POST /verify` (screening compatibility alias)
- `GET /`, `/health`, `/models`, and Qwen diagnostics

There is no backend endpoint for synchronizing a saved record, no idempotency
key contract, no authentication contract, and no server-side record
identifier. Reusing `/predict` for synchronization would rescreen an image,
could create duplicate work, and would not synchronize the local record
itself. It is therefore not a safe synchronization implementation.

## Safe phased design

1. Keep `SharedPreferences` history as the local source of truth.
2. Extend each record with operating mode, provider, and synchronization
   status while remaining backward-compatible with existing records.
3. Persist a separate queue metadata list keyed by the stable local record ID.
4. Require explicit synchronization consent before new records are queued.
5. Never enqueue offline-only records and never retroactively enqueue historical
   records when consent is enabled.
6. Expose pending, failed, and blocked states with manual retry controls.
7. Use bounded exponential retry metadata for a future compatible endpoint.
8. Keep actual remote synchronization disabled until the backend provides a
   dedicated authenticated, idempotent endpoint accepting the local record ID
   as an idempotency key.

## Current limitation

This phase must not claim that records synchronize with the backend. Until the
API contract exists, the client can safely preserve local records and queue
intent/status only. The required future API should define authentication,
payload fields, image-upload consent, idempotency behavior, conflict handling,
and response validation before network upload is enabled.

## Phase 2 implementation status

The local-only queue phase is implemented in the Flutter client:

- `ScanHistoryItem` now stores the operating mode, provider, and sync status.
- Missing fields in older history JSON default to `unknown`, `unavailable`, and
  `local`, respectively.
- `SyncQueueItem` stores the stable record ID, queue and attempt timestamps,
  bounded attempt count, retry time, failure reason, and local queue status.
- Queue metadata is persisted under a separate versioned
  `SharedPreferences` key and duplicate record IDs are rejected.
- Explicit queue insertion is refused for offline-only or unavailable-provider
  records, and no existing records are automatically enqueued.
- Retry metadata is recorded locally with exponential delays capped at one hour
  and five attempts.

No HTTP synchronization, image upload, `/predict` reuse, or successful-sync
state transition was added in this phase.
