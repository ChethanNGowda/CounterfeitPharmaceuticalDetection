# Security and privacy notes

## Data flows

- Screening images are sent to the configured backend only when the user
  starts a backend screening request. Review deployment TLS, access controls,
  request retention, and server storage configuration before real use.
- Medicine photos and profile/OCR data are stored locally in app-private
  storage. They are not included in the current record sync payload.
- Official-alert requests send reviewed medicine metadata to the configured
  backend. The source is fixed in server code; callers cannot select a URL.
- Ollama may receive structured screening evidence or official alert excerpts
  for advisory explanation. It does not decide official status. Configure its
  base URL and model in the server environment; secure the service network.

## Synchronization

The separate `/sync/records` endpoint uses provisioned device bearer
credentials, hashed token storage, revocation, bounded payloads, idempotency,
and SQLite transactions. The Flutter app stores the token using Android secure
storage. Never log or share authorization headers. Configure HTTPS for
non-local sync endpoints. Local queued records remain on device after transient
network failures and may be retried.

## Operational checklist

1. Set secrets and database paths through environment configuration; keep `.env`
   files out of version control.
2. Use HTTPS for deployed APIs; debug cleartext is only for local development.
3. Restrict access to Ollama and the sync provisioning command.
4. Review backend filesystem permissions and backups for the SQLite database.
5. Define retention/deletion schedules for server-side synchronized records.
6. Keep logs free of tokens, images, OCR output, and personal data.
7. Test revocation and restore procedures before production use.

This repository does not provide a hosted product database or manufacturer
authentication credentials. The public CDSCO alert integration is a bounded
source check, not a broad product authentication service. Absence of a notice
does not prove authenticity. Do not use this prototype as the sole basis for
dispensing, treatment, or disposal decisions.
