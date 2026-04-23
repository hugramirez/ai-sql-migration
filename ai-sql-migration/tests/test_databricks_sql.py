"""Tests for Databricks SQL warehouse guardrails."""

from __future__ import annotations

import pytest

from src.tools.databricks_sql import _guard_select_only


def test_guard_accepts_with_cte():
    q = _guard_select_only(
        "WITH x AS (SELECT 1 AS a) SELECT * FROM x"
    )
    assert q.startswith("WITH")


def test_guard_accepts_select():
    assert _guard_select_only("SELECT 1").startswith("SELECT")


def test_guard_rejects_insert():
    with pytest.raises(ValueError, match="Only SELECT"):
        _guard_select_only("INSERT INTO t VALUES (1)")
