"""Offline administrator utility for provisioning and revoking sync devices.

The generated token is printed once and must be delivered through an approved
secure channel. It is never stored by this utility or logged by the API.
"""

from __future__ import annotations

import argparse

from backend.app.services.sync_store import SyncStore


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage PharmaAssist sync devices")
    parser.add_argument("--db", help="SQLite database path (or PHARMA_SYNC_DB_PATH)")
    commands = parser.add_subparsers(dest="command", required=True)
    provision = commands.add_parser("provision", help="create a device credential")
    provision.add_argument("device_id")
    revoke = commands.add_parser("revoke", help="revoke a device credential")
    revoke.add_argument("device_id")
    args = parser.parse_args()
    store = SyncStore(db_path=args.db) if args.db else SyncStore()
    if args.command == "provision":
        print(store.provision_device(args.device_id))
        return 0
    print("revoked" if store.revoke_device(args.device_id) else "device not found or already revoked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
