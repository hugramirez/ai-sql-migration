"""Databricks SQL tools for Unity Catalog tables."""

from __future__ import annotations

from langchain_core.tools import tool


def _require_sql_env() -> tuple[str, str, str]:
    import os

    host = os.environ.get("DATABRICKS_HOST", "").strip()
    token = os.environ.get("DATABRICKS_TOKEN", "").strip()
    warehouse_id = os.environ.get("DATABRICKS_WAREHOUSE_ID", "").strip()
    if not host or not token or not warehouse_id:
        raise RuntimeError(
            "Missing Databricks SQL env vars. Set DATABRICKS_HOST, DATABRICKS_TOKEN, and DATABRICKS_WAREHOUSE_ID."
        )
    return host, token, warehouse_id


def _guard_select_only(query: str) -> str:
    q = query.strip().rstrip(";")
    if not q:
        raise ValueError("Query is empty.")
    first = q.split(maxsplit=1)[0].upper()
    allowed = {"SELECT", "SHOW", "DESCRIBE"}
    if first not in allowed:
        raise ValueError("Only SELECT/SHOW/DESCRIBE queries are allowed.")
    return q


@tool
def run_sql_query(query: str, limit: int = 100) -> str:
    """Run a read-only SQL query against Databricks SQL Warehouse."""
    safe_query = _guard_select_only(query)
    host, token, warehouse_id = _require_sql_env()

    try:
        from databricks import sql
    except Exception:
        return "Missing dependency: install `databricks-sql-connector` to run SQL queries."

    limited_query = safe_query
    if " limit " not in safe_query.lower():
        limited_query = f"{safe_query} LIMIT {max(1, min(limit, 1000))}"

    with sql.connect(
        server_hostname=host.replace("https://", ""),
        http_path=f"/sql/1.0/warehouses/{warehouse_id}",
        access_token=token,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute(limited_query)
            rows = cursor.fetchall()
            cols = [d[0] for d in cursor.description] if cursor.description else []

    preview = [", ".join(cols)] if cols else []
    for row in rows[:limit]:
        preview.append(", ".join(str(value) for value in row))
    return "\n".join(preview) if preview else "Query returned no rows."


@tool
def describe_table(table_name: str) -> str:
    """Describe a Unity Catalog table schema."""
    table = table_name.strip()
    if not table:
        raise ValueError("table_name is required.")
    return run_sql_query.invoke({"query": f"DESCRIBE TABLE {table}", "limit": 200})

