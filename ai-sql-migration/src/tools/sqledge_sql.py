"""Azure SQL Edge tools for local Docker instance."""

from __future__ import annotations

import os

from langchain_core.tools import tool


def _get_connection():
    import pyodbc

    host = os.environ.get("SQLEDGE_HOST", "localhost").strip()
    port = os.environ.get("SQLEDGE_PORT", "1433").strip()
    database = os.environ.get("SQLEDGE_DATABASE", "sqledge_dev").strip()
    user = os.environ.get("SQLEDGE_USER", "").strip()
    password = os.environ.get("SQLEDGE_PASSWORD", "").strip()

    if not user or not password:
        raise RuntimeError(
            "Missing SQL Edge credentials. Set SQLEDGE_USER and SQLEDGE_PASSWORD."
        )

    conn_str = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={host},{port};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={password};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


def _guard_select_only(query: str) -> str:
    q = query.strip().rstrip(";")
    if not q:
        raise ValueError("Query is empty.")
    first = q.split(maxsplit=1)[0].upper()
    allowed = {"SELECT", "SHOW", "EXEC", "EXECUTE", "SP_HELP", "SP_COLUMNS"}
    if first not in allowed:
        raise ValueError("Only SELECT/SHOW/EXEC queries are allowed.")
    return q


@tool
def run_sqledge_query(query: str, limit: int = 100) -> str:
    """Run a read-only SQL query against the local Azure SQL Edge Docker instance (sqledge_dev)."""
    safe_query = _guard_select_only(query)

    capped = max(1, min(limit, 1000))
    if "select" in safe_query.lower() and " top " not in safe_query.lower():
        # Inject TOP after SELECT keyword
        idx = safe_query.upper().index("SELECT") + len("SELECT")
        safe_query = safe_query[:idx] + f" TOP {capped}" + safe_query[idx:]

    with _get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(safe_query)
        cols = [d[0] for d in cursor.description] if cursor.description else []
        rows = cursor.fetchall()

    preview = [", ".join(cols)] if cols else []
    for row in rows:
        preview.append(", ".join(str(v) for v in row))
    return "\n".join(preview) if preview else "Query returned no rows."


@tool
def describe_sqledge_table(table_name: str) -> str:
    """Describe a table schema in the Azure SQL Edge Docker instance."""
    table = table_name.strip()
    if not table:
        raise ValueError("table_name is required.")
    query = (
        f"SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE "
        f"FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '{table}'"
    )
    return run_sqledge_query.invoke({"query": query, "limit": 200})
