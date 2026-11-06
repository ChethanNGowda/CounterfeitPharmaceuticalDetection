"""Durable authenticated storage for client-owned synchronization records."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


TOKEN_PREFIX = "pa1"
PBKDF2_ITERATIONS = 310_000


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _db_path() -> Path:
    configured = os.getenv("PHARMA_SYNC_DB_PATH", "data/pharma_sync.sqlite3")
    return Path(configured).expanduser()


def _image_dir(db_path: Path) -> Path:
    configured = os.getenv("PHARMA_SYNC_IMAGE_DIR")
    return Path(configured).expanduser() if configured else db_path.parent / "sync_images"


def hash_token(token_secret: str, salt: bytes) -> str:
    derived = hashlib.pbkdf2_hmac(
        "sha256", token_secret.encode("utf-8"), salt, PBKDF2_ITERATIONS
    )
    return base64.urlsafe_b64encode(derived).decode("ascii")


def parse_token(authorization: str | None) -> tuple[str, str] | None:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    value = authorization[7:].strip()
    parts = value.split(".", 2)
    if len(parts) != 3 or parts[0] != TOKEN_PREFIX or not all(parts[1:]):
        return None
    return parts[1], parts[2]


class SyncStore:
    def __init__(self, db_path: Path | None = None, image_dir: Path | None = None):
        self.db_path = Path(db_path) if db_path is not None else _db_path()
        self.image_dir = (
            Path(image_dir) if image_dir is not None else _image_dir(self.db_path)
        )
        self._lock = threading.RLock()
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.image_dir.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(
            self.db_path, timeout=10, isolation_level=None, check_same_thread=False
        )
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA journal_mode = WAL")
        return connection

    def _initialize(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS devices (
                    device_id TEXT PRIMARY KEY,
                    salt BLOB NOT NULL,
                    token_hash TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    revoked_at TEXT
                );
                CREATE TABLE IF NOT EXISTS sync_records (
                    server_record_id TEXT PRIMARY KEY,
                    device_id TEXT NOT NULL REFERENCES devices(device_id),
                    client_record_id TEXT NOT NULL,
                    payload_hash TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    image_path TEXT,
                    created_at TEXT NOT NULL,
                    synced_at TEXT NOT NULL,
                    UNIQUE(device_id, client_record_id)
                );
                CREATE INDEX IF NOT EXISTS idx_sync_records_device
                    ON sync_records(device_id);
                """
            )

    def provision_device(self, device_id: str) -> str:
        device_id = device_id.strip()
        if not device_id or len(device_id) > 128:
            raise ValueError("device_id must be 1-128 characters")
        secret = secrets.token_urlsafe(32)
        salt = secrets.token_bytes(16)
        token = f"{TOKEN_PREFIX}.{device_id}.{secret}"
        with self._lock, self._connect() as connection:
            connection.execute(
                """
                INSERT INTO devices(device_id, salt, token_hash, created_at)
                VALUES (?, ?, ?, ?)
                """,
                (device_id, salt, hash_token(secret, salt), utc_now().isoformat()),
            )
        return token

    def revoke_device(self, device_id: str) -> bool:
        with self._lock, self._connect() as connection:
            cursor = connection.execute(
                "UPDATE devices SET revoked_at = ? WHERE device_id = ? AND revoked_at IS NULL",
                (utc_now().isoformat(), device_id),
            )
            return cursor.rowcount == 1

    def authenticate(self, authorization: str | None) -> str | None:
        parsed = parse_token(authorization)
        if parsed is None:
            return None
        device_id, secret = parsed
        with self._connect() as connection:
            row = connection.execute(
                "SELECT salt, token_hash, revoked_at FROM devices WHERE device_id = ?",
                (device_id,),
            ).fetchone()
        if row is None or row["revoked_at"] is not None:
            return None
        candidate = hash_token(secret, row["salt"])
        return device_id if hmac.compare_digest(candidate, row["token_hash"]) else None

    def save_record(
        self,
        device_id: str,
        client_record_id: str,
        payload: dict[str, Any],
        image_bytes: bytes | None,
        image_extension: str | None,
    ) -> tuple[str, bool, datetime]:
        idempotency_payload = {
            key: value for key, value in payload.items() if key != "sync_status"
        }
        payload_json = json.dumps(
            idempotency_payload, sort_keys=True, separators=(",", ":")
        )
        payload_hash = hashlib.sha256(payload_json.encode("utf-8")).hexdigest()
        synced_at = utc_now()
        with self._lock, self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            existing = connection.execute(
                """
                SELECT server_record_id, payload_hash, synced_at
                FROM sync_records
                WHERE device_id = ? AND client_record_id = ?
                """,
                (device_id, client_record_id),
            ).fetchone()
            if existing is not None:
                if not hmac.compare_digest(existing["payload_hash"], payload_hash):
                    raise ValueError("idempotency_conflict")
                return existing["server_record_id"], True, datetime.fromisoformat(
                    existing["synced_at"]
                )

            server_id = str(uuid.uuid4())
            image_path = None
            if image_bytes is not None and image_extension is not None:
                image_path = str(self.image_dir / f"{server_id}.{image_extension}")
                Path(image_path).write_bytes(image_bytes)
            try:
                connection.execute(
                    """
                    INSERT INTO sync_records(
                        server_record_id, device_id, client_record_id, payload_hash,
                        payload_json, image_path, created_at, synced_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        server_id,
                        device_id,
                        client_record_id,
                        payload_hash,
                        payload_json,
                        image_path,
                        payload["client_created_at"],
                        synced_at.isoformat(),
                    ),
                )
            except Exception:
                if image_path:
                    Path(image_path).unlink(missing_ok=True)
                raise
            return server_id, False, synced_at
