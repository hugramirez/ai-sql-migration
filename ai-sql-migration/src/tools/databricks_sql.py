"""Databricks SQL tools using the REST Statements API."""

from __future__ import annotations

import os
import re
import time

import requests
from dotenv import load_dotenv

load_dotenv(override=True)
from langchain_core.tools import tool


def _require_env() -> tuple[str, str, str]:
    host = os.environ.get("DATABRICKS_HOST", "").strip().rstrip("/")
    token = os.environ.get("DATABRICKS_TOKEN", "").strip()
    warehouse_id = os.environ.get("DATABRICKS_WAREHOUSE_ID", "").strip()
    if not host or not token or not warehouse_id:
        raise RuntimeError(
            "Missing Databricks env vars. Set DATABRICKS_HOST, DATABRICKS_TOKEN, and DATABRICKS_WAREHOUSE_ID."
        )
    return host, token, warehouse_id


def _guard_select_only(query: str) -> str:
    q = query.strip().rstrip(";")
    if not q:
        raise ValueError("Query is empty.")
    first = q.split(maxsplit=1)[0].upper()
    # WITH ... AS (...) SELECT ... is read-only and common for reports
    allowed = {"SELECT", "WITH", "SHOW", "DESCRIBE", "EXPLAIN"}
    if first not in allowed:
        raise ValueError("Only SELECT/WITH/SHOW/DESCRIBE/EXPLAIN queries are allowed.")
    return q


_TERMINAL_STATES = frozenset({"SUCCEEDED", "FAILED", "CANCELLED", "CLOSED"})
_MAX_POLL_SECONDS = 300
_POLL_INTERVAL_START = 1.0
_POLL_INTERVAL_MAX = 5.0


def _poll_statement(host: str, token: str, statement_id: str) -> dict:
    """Poll GET /api/2.0/sql/statements/{id} until the query reaches a terminal state."""
    elapsed = 0.0
    interval = _POLL_INTERVAL_START
    while elapsed < _MAX_POLL_SECONDS:
        time.sleep(interval)
        elapsed += interval
        resp = requests.get(
            f"{host}/api/2.0/sql/statements/{statement_id}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("status", {}).get("state") in _TERMINAL_STATES:
            return data
        interval = min(interval * 1.5, _POLL_INTERVAL_MAX)
    raise RuntimeError(
        f"Databricks query timed out after {_MAX_POLL_SECONDS}s (statement_id={statement_id})"
    )


def _execute(query: str, limit: int) -> str:
    host, token, warehouse_id = _require_env()

    payload = {
        "statement": query,
        "warehouse_id": warehouse_id,
        "wait_timeout": "30s",
        "disposition": "INLINE",
        "format": "JSON_ARRAY",
    }

    catalog = os.environ.get("UC_CATALOG", "").strip()
    schema = os.environ.get("UC_SCHEMA", "").strip()
    if catalog:
        payload["catalog"] = catalog
    if schema:
        payload["schema"] = schema

    resp = requests.post(
        f"{host}/api/2.0/sql/statements",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
        timeout=60,
    )
    resp.raise_for_status()
    data = resp.json()

    state = data.get("status", {}).get("state")

    # If Databricks returned before the query finished, poll until terminal state
    if state not in _TERMINAL_STATES:
        statement_id = data.get("statement_id")
        data = _poll_statement(host, token, statement_id)
        state = data.get("status", {}).get("state")

    if state != "SUCCEEDED":
        error = data.get("status", {}).get("error", {})
        raise RuntimeError(f"Query {state}: {error.get('message', str(data.get('status', {})))}")

    columns = [c["name"] for c in data.get("manifest", {}).get("schema", {}).get("columns", [])]
    rows = data.get("result", {}).get("data_array", [])

    lines = [", ".join(columns)] if columns else []
    for row in rows[:limit]:
        lines.append(", ".join("" if v is None else str(v) for v in row))
    return "\n".join(lines) if lines else "Query returned no rows."


@tool
def run_sql_query(query: str, limit: int = 100) -> str:
    """Run a read-only SQL query against Databricks SQL Warehouse."""
    safe_query = _guard_select_only(query)
    capped = max(1, min(limit, 1000))
    if "select" in safe_query.lower() and not re.search(r"\blimit\b", safe_query, re.IGNORECASE):
        safe_query = f"{safe_query} LIMIT {capped}"
    return _execute(safe_query, capped)


@tool
def describe_table(table_name: str) -> str:
    """Describe a Unity Catalog table schema."""
    table = table_name.strip()
    if not table:
        raise ValueError("table_name is required.")
    return _execute(f"DESCRIBE TABLE {table}", 200)
