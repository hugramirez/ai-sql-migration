#!/usr/bin/env python3
"""Minimal Databricks SQL warehouse check: same pattern as databricks.sql.connect docs.

Reads ``DATABRICKS_HOST``, ``DATABRICKS_TOKEN``, ``DATABRICKS_WAREHOUSE_ID`` from
``ai-sql-migration/.env`` (repo root = parent of ``scripts/``).

Usage (from ``ai-sql-migration``)::

    uv run python scripts/test_databricks_sql_connection.py
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

from dotenv import load_dotenv


def _warehouse_id_is_uuid_shape(warehouse_id: str) -> bool:
    clean = warehouse_id.replace("-", "").strip()
    return bool(re.fullmatch(r"[0-9a-fA-F]{32}", clean))


def _server_hostname(host_raw: str) -> str:
    host_raw = host_raw.strip().rstrip("/")
    if host_raw.startswith("http://") or host_raw.startswith("https://"):
        h = urlparse(host_raw).hostname
        if not h:
            raise ValueError(f"No hostname in DATABRICKS_HOST={host_raw!r}")
        return h
    return host_raw.replace("https://", "").replace("http://", "")


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    env_file = root / ".env"
    # override=True: a DATABRICKS_* vacío o heredado del shell no debe impedir leer el .env del repo
    loaded = load_dotenv(env_file, override=True)
    if not loaded:
        print(f"Warning: could not load {env_file} (missing or unreadable).", file=sys.stderr)

    host_raw = os.environ.get("DATABRICKS_HOST", "").strip()
    token = os.environ.get("DATABRICKS_TOKEN", "").strip()
    warehouse_id = os.environ.get("DATABRICKS_WAREHOUSE_ID", "").strip()

    if not host_raw or not token or not warehouse_id:
        print(
            "Missing env: set DATABRICKS_HOST, DATABRICKS_TOKEN, DATABRICKS_WAREHOUSE_ID in .env",
            file=sys.stderr,
        )
        return 1

    server_hostname = _server_hostname(host_raw)
    http_path = f"/sql/1.0/warehouses/{warehouse_id}"

    if not _warehouse_id_is_uuid_shape(warehouse_id):
        print(
            "WARNING: DATABRICKS_WAREHOUSE_ID should be the full SQL warehouse UUID (32 hex, "
            "optionally with hyphens) from the same workspace as DATABRICKS_HOST. "
            "Wrong or truncated IDs often cause HTTP 400 on OpenSession.",
            file=sys.stderr,
        )
        print(
            "  Hex length (ignoring hyphens):",
            len(warehouse_id.replace("-", "")),
            file=sys.stderr,
        )

    print("server_hostname:", server_hostname, flush=True)
    print("http_path:", http_path, flush=True)
    print("token length:", len(token), "chars (value not printed)", flush=True)

    from databricks import sql

    try:
        with sql.connect(
            server_hostname=server_hostname,
            http_path=http_path,
            access_token=token,
        ) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 AS ok")
                row = cur.fetchone()
        print("Query result:", row)
        print("Connection OK.")
        return 0
    except Exception as e:
        print(f"{type(e).__name__}: {e}", file=sys.stderr)
        en = type(e).__name__
        if "Request" in en or "Error" in en:
            print(
                "Hints: confirm SQL warehouse ID (full UUID), PAT belongs to this workspace, "
                "warehouse is running and your user can use it; try the same query in SQL Editor.",
                file=sys.stderr,
            )
        return 1


if __name__ == "__main__":
    sys.exit(main())
