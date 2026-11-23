from __future__ import annotations

import base64
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from io import BytesIO
import random
import sqlite3

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from backend.app.main import app
from backend.app.services.sync_store import SyncStore
import backend.app.routes.sync as sync_route


@pytest.fixture
def sync_client(tmp_path, monkeypatch):
    sync_route.store = SyncStore(
        db_path=tmp_path / "sync.sqlite3",
        image_dir=tmp_path / "images",
    )
    token = sync_route.store.provision_device("device-a")
    return TestClient(app), token


def payload(record_id="record-1", **overrides):
    value = {
        "client_record_id": record_id,
        "client_created_at": datetime.now(timezone.utc).isoformat(),
        "operating_mode": "backend",
        "provider": "backend",
        "sync_status": "local",
        "screening_metadata": {
            "prediction": "AUTHENTIC",
            "confidence": 0.91,
        },
        "notes": "field note",
        "image_upload_consent": False,
    }
    value.update(overrides)
    return value


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_missing_invalid_and_revoked_authentication(sync_client):
    client, token = sync_client
    request = payload()
    assert client.post("/sync/records", json=request).status_code == 401
    invalid_token = "pa1.device-a.invalid"
    invalid = client.post(
        "/sync/records", json=request, headers=auth(invalid_token)
    )
    assert invalid.status_code == 401
    assert invalid_token not in invalid.text
    with sqlite3.connect(sync_route.store.db_path) as connection:
        stored_hash = connection.execute(
            "SELECT token_hash FROM devices WHERE device_id = ?", ("device-a",)
        ).fetchone()[0]
    assert token not in stored_hash
    assert token.split(".")[-1] not in stored_hash
    assert sync_route.store.revoke_device("device-a")
    assert client.post("/sync/records", json=request, headers=auth(token)).status_code == 401


def test_device_ids_with_token_delimiters_are_rejected(sync_client):
    _, _ = sync_client
    for device_id in ("device.name", "device/name", "device\\name", "device\x00name"):
        with pytest.raises(ValueError):
            sync_route.store.provision_device(device_id)


def test_first_creation_and_identical_duplicate_are_idempotent(sync_client):
    client, token = sync_client
    response = client.post("/sync/records", json=payload(), headers=auth(token))
    assert response.status_code == 201
    body = response.json()
    assert body["duplicate"] is False
    assert body["screening_verified"] is False
    duplicate = client.post("/sync/records", json=payload(**{"client_created_at": body["synchronized_at"]}), headers=auth(token))
    assert duplicate.status_code == 409

    identical = payload(record_id="record-2")
    first = client.post("/sync/records", json=identical, headers=auth(token))
    assert first.status_code == 201
    again = client.post("/sync/records", json=identical, headers=auth(token))
    assert again.status_code == 201
    assert again.json()["duplicate"] is True
    assert again.json()["server_record_id"] == first.json()["server_record_id"]


def test_same_id_different_payload_conflicts(sync_client):
    client, token = sync_client
    assert client.post("/sync/records", json=payload(), headers=auth(token)).status_code == 201
    changed = payload()
    changed["notes"] = "changed"
    response = client.post("/sync/records", json=changed, headers=auth(token))
    assert response.status_code == 409


def test_sync_status_changes_remain_idempotent(sync_client):
    client, token = sync_client
    request = payload()
    created = client.post("/sync/records", json=request, headers=auth(token))
    assert created.status_code == 201
    changed_status = {**request, "sync_status": "synced"}
    response = client.post("/sync/records", json=changed_status, headers=auth(token))
    assert response.status_code == 201
    assert response.json()["duplicate"] is True


def test_image_requires_consent_and_is_stored_safely(sync_client):
    client, token = sync_client
    image = base64.b64encode(b"not an image").decode()
    no_consent = payload(
        image_base64=image,
        image_media_type="image/png",
        client_file_name="../../secret.png",
    )
    assert client.post("/sync/records", json=no_consent, headers=auth(token)).status_code == 400

    image = BytesIO()
    noisy_pixels = random.Random(42).randbytes(512 * 512 * 3)
    Image.frombytes("RGB", (512, 512), noisy_pixels).save(image, format="PNG")
    encoded_image = base64.b64encode(image.getvalue()).decode()
    assert len(encoded_image) > 256 * 1024
    accepted = payload(
        record_id="image-1",
        image_base64=encoded_image,
        image_media_type="image/png",
        client_file_name="../../ignored.png",
        image_upload_consent=True,
    )
    stored = client.post("/sync/records", json=accepted, headers=auth(token))
    assert stored.status_code == 201
    assert stored.json()["image_stored"] is True
    duplicate = client.post("/sync/records", json=accepted, headers=auth(token))
    assert duplicate.status_code == 201
    assert duplicate.json()["duplicate"] is True

    other_image = BytesIO()
    other_pixels = random.Random(43).randbytes(512 * 512 * 3)
    Image.frombytes("RGB", (512, 512), other_pixels).save(other_image, format="PNG")
    changed = {**accepted, "image_base64": base64.b64encode(other_image.getvalue()).decode()}
    conflict = client.post("/sync/records", json=changed, headers=auth(token))
    assert conflict.status_code == 409
    assert len(list(sync_route.store.image_dir.iterdir())) == 1


def test_image_payload_errors_are_rejected_before_storage(sync_client):
    client, token = sync_client
    invalid_base64 = payload(
        record_id="invalid-base64",
        image_base64="%%%not-base64%%%",
        image_media_type="image/png",
        image_upload_consent=True,
    )
    assert client.post(
        "/sync/records", json=invalid_base64, headers=auth(token)
    ).status_code == 400

    unsupported_type = payload(
        record_id="unsupported-image",
        image_base64="aGVsbG8=",
        image_media_type="image/tiff",
        image_upload_consent=True,
    )
    assert client.post(
        "/sync/records", json=unsupported_type, headers=auth(token)
    ).status_code == 415

    too_large = payload(
        record_id="oversized-image",
        image_base64="A" * ((((15 * 1024 * 1024 + 2) // 3) * 4 + 4)),
        image_media_type="image/png",
        image_upload_consent=True,
    )
    response = client.post("/sync/records", json=too_large, headers=auth(token))
    assert response.status_code == 413
    assert not list(sync_route.store.image_dir.iterdir())


def test_cross_device_records_are_not_reused(sync_client):
    client, token = sync_client
    token_b = sync_route.store.provision_device("device-b")
    request = payload()
    assert client.post("/sync/records", json=request, headers=auth(token)).status_code == 201
    response = client.post("/sync/records", json=request, headers=auth(token_b))
    assert response.status_code == 201
    assert response.json()["duplicate"] is False


def test_malformed_request_and_oversized_record_are_rejected(sync_client):
    client, token = sync_client
    malformed = client.post(
        "/sync/records",
        json={**payload(), "client_record_id": "../bad", "notes": {"sensitive": "must-not-echo"}},
        headers=auth(token),
    )
    assert malformed.status_code == 422
    assert "must-not-echo" not in malformed.text
    huge = payload(screening_metadata={"large": "x" * (256 * 1024)})
    assert client.post("/sync/records", json=huge, headers=auth(token)).status_code == 413


def test_sync_database_failure_returns_sanitized_error(
    sync_client, monkeypatch, caplog
):
    client, token = sync_client

    def fail_save(*args, **kwargs):
        raise sqlite3.OperationalError("database locked: private-note")

    monkeypatch.setattr(sync_route.store, "save_record", fail_save)
    response = client.post(
        "/sync/records",
        json=payload(notes="private-note"),
        headers=auth(token),
    )
    assert response.status_code == 500
    assert response.json() == {"detail": "Synchronization could not be durably stored."}
    assert "private-note" not in response.text
    assert "private-note" not in caplog.text


def test_database_insert_failure_removes_unreferenced_image(sync_client):
    client, token = sync_client
    with sqlite3.connect(sync_route.store.db_path) as connection:
        connection.execute(
            """
            CREATE TRIGGER fail_sync_insert BEFORE INSERT ON sync_records
            BEGIN SELECT RAISE(ABORT, 'forced database failure'); END;
            """
        )
    image = BytesIO()
    Image.new("RGB", (64, 64), color=(24, 180, 150)).save(image, format="PNG")
    request = payload(
        record_id="db-failure-image",
        image_base64=base64.b64encode(image.getvalue()).decode(),
        image_media_type="image/png",
        image_upload_consent=True,
    )
    response = client.post("/sync/records", json=request, headers=auth(token))
    assert response.status_code == 500
    assert response.json() == {"detail": "Synchronization could not be durably stored."}
    assert list(sync_route.store.image_dir.iterdir()) == []


def test_sync_endpoint_does_not_invoke_screening_service(sync_client, monkeypatch):
    client, token = sync_client

    def screening_must_not_run():
        raise AssertionError("sync invoked prediction service")

    monkeypatch.setattr(
        "backend.app.routes.predict.ClassifierService.get_instance",
        screening_must_not_run,
    )
    response = client.post("/sync/records", json=payload(), headers=auth(token))
    assert response.status_code == 201


def test_persistence_survives_store_reload(sync_client, tmp_path):
    client, token = sync_client
    request = payload()
    created = client.post("/sync/records", json=request, headers=auth(token))
    assert created.status_code == 201
    database = sync_route.store.db_path
    images = sync_route.store.image_dir
    sync_route.store = SyncStore(db_path=database, image_dir=images)
    assert client.post("/sync/records", json=request, headers=auth(token)).json()["duplicate"] is True


def test_concurrent_duplicate_requests_create_one_record(sync_client):
    client, token = sync_client
    request = payload(record_id="concurrent-1")

    def submit():
        return client.post("/sync/records", json=request, headers=auth(token))

    with ThreadPoolExecutor(max_workers=4) as executor:
        responses = list(executor.map(lambda _: submit(), range(4)))
    assert all(response.status_code == 201 for response in responses)
    assert sum(response.json()["duplicate"] is False for response in responses) == 1
