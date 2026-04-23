"""Unit tests for migrate_sql_query tool."""

from __future__ import annotations

import pytest

from src.tools.sql_migration import (
    _rewrite_tsql_to_sparksql,
    migrate_sql_query,
    parse_migrated_sql_line,
)


def test_top_to_limit():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT TOP 5 name FROM my_table")
    assert "LIMIT 5" in sql
    assert "TOP" not in sql.upper()


def test_isnull_to_coalesce():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT ISNULL(name, 'unknown') FROM my_table")
    assert "COALESCE(" in sql
    assert "ISNULL" not in sql.upper()


def test_getdate_to_current_timestamp():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT GETDATE() AS now FROM my_table")
    assert "current_timestamp()" in sql
    assert "GETDATE" not in sql.upper()


def test_table_remap_dotted():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT id FROM pharmacy_db.dbo.dim_patient")
    assert "pharmacy.gold.dim_patient" in sql
    assert "pharmacy_db" not in sql


def test_table_remap_bracketed():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT id FROM [pharmacy_db].[dbo].[dim_patient]")
    assert "pharmacy.gold.dim_patient" in sql
    assert "pharmacy_db" not in sql


def test_table_remap_dbo_fact():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT 1 FROM dbo.fact_prescription rx")
    assert "pharmacy.gold.fact_prescription" in sql
    assert "dbo.fact_prescription" not in sql


def test_uc_prefix_env_override(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("SQL_MIGRATION_UC_PREFIX", "workspace.default")
    sql, _ = _rewrite_tsql_to_sparksql("SELECT 1 FROM pharmacy_db.dbo.dim_medication")
    assert "workspace.default.dim_medication" in sql


def test_tsql_plus_concat_to_concat_ws():
    sql, warnings = _rewrite_tsql_to_sparksql(
        "SELECT p.first_name + ' ' + p.last_name AS n FROM t p"
    )
    assert "concat_ws" in sql.lower()
    assert "p.first_name" in sql and "p.last_name" in sql


def test_parse_migrated_sql_line():
    body = "MIGRATED_SQL: SELECT 1 AS x\nREWRITES: none"
    assert parse_migrated_sql_line(body) == "SELECT 1 AS x"


def test_offset_fetch_to_limit():
    sql, warnings = _rewrite_tsql_to_sparksql(
        "SELECT a FROM t ORDER BY a OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY"
    )
    assert "LIMIT 20" in sql
    assert "OFFSET" not in sql.upper()
    assert "FETCH" not in sql.upper()


def test_bracket_notation_stripped():
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT [first_name] FROM my_table")
    assert "[" not in sql
    assert "first_name" in sql


def test_full_query_combined():
    query = (
        "SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, "
        "ISNULL(last_name, 'unknown') AS last_name, "
        "GETDATE() AS migrated_at FROM pharmacy_db.dbo.dim_patient;"
    )
    sql, warnings = _rewrite_tsql_to_sparksql(query)
    assert "LIMIT 5" in sql
    assert "COALESCE(" in sql
    assert "current_timestamp()" in sql
    assert "pharmacy.gold.dim_patient" in sql
    assert "TOP" not in sql.upper()
    assert "ISNULL" not in sql.upper()
    assert "GETDATE" not in sql.upper()


def test_migrate_sql_query_tool_output_format():
    query = "SELECT TOP 3 ISNULL(name, 'x') AS name FROM pharmacy_db.dbo.dim_patient;"
    result = migrate_sql_query.invoke({"query": query})
    assert result.startswith("MIGRATED_SQL:")
    assert "REWRITES:" in result


def test_migrate_sql_query_tool_migrated_sql_line():
    query = "SELECT TOP 3 GETDATE() AS ts FROM pharmacy_db.dbo.dim_patient;"
    result = migrate_sql_query.invoke({"query": query})
    migrated_line = next(l for l in result.splitlines() if l.startswith("MIGRATED_SQL:"))
    extracted = migrated_line[len("MIGRATED_SQL:"):].strip()
    assert "current_timestamp()" in extracted
    assert "LIMIT 3" in extracted
    assert "pharmacy.gold.dim_patient" in extracted
