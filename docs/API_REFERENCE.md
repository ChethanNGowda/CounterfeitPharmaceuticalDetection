# Backend API reference

FastAPI publishes the live OpenAPI schema and Swagger UI from the running
server (`/openapi.json` and `/docs`). The following describes the current
application routes; schemas in `backend/app/schemas/` are the source of truth.

| Route | Purpose | Notes |
|---|---|---|
| `GET /` | Service metadata | Does not perform screening. |
| `GET /health` | Health/model/service diagnostics | Availability is not a prediction. |
| `POST /predict` | Image screening | Multipart image input; bounded upload; optional advisory Qwen review. |
| `POST /verify` | Backward-compatible screening alias | This is not product or batch verification. |
| `POST /sync/records` | Authenticated record synchronization | Dedicated path; device bearer token; metadata and consented sync contract. |
| `POST /verification/official-alerts` | Check a reviewed medicine record against linked official CDSCO spurious-drug alerts | Fixed official source, no caller-provided URL/image; only potential concern or unable to verify is currently evidence-supported. |

## Official alert request

`POST /verification/official-alerts` accepts product fields such as medicine
name, manufacturer, batch, manufacturing/expiry dates, strength, dosage form,
and a product identifier. Fields are bounded and control characters are
rejected. Arbitrary URL fields are rejected. A batch value is required before
the source is queried.

The response carries a status, source records (URL, retrieval timestamp,
excerpt and matched context), optional Ollama explanation, and a limitation
disclaimer. The backend fixes the result status independently from the
explanation. Source/network failures return `unable_to_verify`. An absent alert
match is not evidence that a product is genuine. The service does not currently
connect to manufacturer batch-authentication APIs and cannot positively
authenticate a product.

## Authentication and errors

Device synchronization credentials are administered out of band; see
`BACKEND_SYNC_API_2026-11-05.md`. Do not put credentials in query parameters.
Request-size middleware applies before JSON parsing. Validation errors are
sanitized and responses use structured FastAPI/Pydantic schemas. Do not treat
`/verify` as the official-alert endpoint: it remains an alias for image
screening for compatibility.

For exact field constraints and deployment behavior, inspect `backend/app/`;
the running OpenAPI document is authoritative for that deployed revision.
