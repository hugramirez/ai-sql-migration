"""SQL migration tools powered by SQLFluff."""

from __future__ import annotations

import os
import re
from typing import Iterable

from langchain_core.tools import tool
from sqlfluff.core import Linter


def _to_bool(value: str, default: bool = True) -> bool:
    if not value:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


_TABLE_MAP: dict[str, str] = {
    r"\[PANTHERx\]\.\[cpr\]\.\[dim_patient\]": "workspace.default.dim_patient",
    r"PANTHERx\.cpr\.dim_patient": "workspace.default.dim_patient",
}


def _rewrite_tsql_to_sparksql(query: str) -> tuple[str, list[str]]:
    warnings: list[str] = []
    rewritten = query.strip().rstrip(";")

    # SELECT TOP N ... -> SELECT ... LIMIT N
    top_match = re.match(
        r"(?is)^\s*select\s+top\s*\(\s*(\d+)\s*\)\s+(.*)$",
        rewritten,
    ) or re.match(r"(?is)^\s*select\s+top\s+(\d+)\s+(.*)$", rewritten)
    if top_match:
        top_n = top_match.group(1)
        select_rest = top_match.group(2).strip()
        rewritten = f"SELECT {select_rest} LIMIT {top_n}"
        warnings.append("Applied TOP -> LIMIT rewrite.")

    # ISNULL(a,b) -> COALESCE(a,b)
    isnull_pattern = re.compile(r"(?i)\bisnull\s*\(")
    if isnull_pattern.search(rewritten):
        rewritten = isnull_pattern.sub("COALESCE(", rewritten)
        warnings.append("Applied ISNULL -> COALESCE rewrite.")

    # GETDATE() -> current_timestamp()
    getdate_pattern = re.compile(r"(?i)\bgetdate\s*\(\s*\)")
    if getdate_pattern.search(rewritten):
        rewritten = getdate_pattern.sub("current_timestamp()", rewritten)
        warnings.append("Applied GETDATE() -> current_timestamp() rewrite.")

    # Remap known SQL Edge table references to Databricks catalog paths
    for pattern, replacement in _TABLE_MAP.items():
        new_sql = re.sub(pattern, replacement, rewritten, flags=re.IGNORECASE)
        if new_sql != rewritten:
            warnings.append(f"Remapped table reference -> {replacement}.")
            rewritten = new_sql

    # Strip remaining T-SQL bracket notation: [column] -> column
    bracket_pattern = re.compile(r"\[(\w+)\]")
    if bracket_pattern.search(rewritten):
        rewritten = bracket_pattern.sub(r"\1", rewritten)
        warnings.append("Stripped T-SQL bracket notation.")

    return rewritten, warnings


def _format_violations(violations: Iterable) -> str:
    rows = []
    for v in violations:
        rows.append(f"- {v.rule_code()} at L{v.line_no}:P{v.line_pos}: {v.description}")
    return "\n".join(rows) if rows else "- none"


@tool
def migrate_sql_query(query: str) -> str:
    """Migrate SQL Edge (T-SQL style) SQL to Databricks-compatible Spark SQL."""
    input_query = query.strip()
    if not input_query:
        raise ValueError("query is required.")

    enabled = _to_bool(os.environ.get("SQLFLUFF_ENABLED", "true"), default=True)
    source_dialect = os.environ.get("SQLFLUFF_SOURCE_DIALECT", "tsql").strip() or "tsql"
    target_dialect = os.environ.get("SQLFLUFF_TARGET_DIALECT", "sparksql").strip() or "sparksql"
    if not enabled:
        return (
            "SQLFluff migration is disabled (SQLFLUFF_ENABLED=false).\n\n"
            "Use this SQL directly and review manually:\n"
            f"{input_query}"
        )

    src_linter = Linter(dialect=source_dialect)
    src_result = src_linter.lint_string(input_query)
    src_violations = src_result.get_violations()

    rewritten_sql, rewrites = _rewrite_tsql_to_sparksql(input_query)

    dst_linter = Linter(dialect=target_dialect)
    dst_result = dst_linter.lint_string(rewritten_sql)
    fixed_sql, _ = dst_result.fix_string()
    if fixed_sql.strip():
        rewritten_sql = fixed_sql.strip().rstrip(";")
    dst_violations = dst_linter.lint_string(rewritten_sql).get_violations()

    warnings = []
    if not rewrites:
        warnings.append("No deterministic rewrite rule was applied.")
    warnings.extend(rewrites)
    if dst_violations:
        warnings.append("Target SQL still has lint violations; review before executing.")

    warning_text = "\n".join(f"- {w}" for w in warnings) if warnings else "- none"
    return (
        "### Migration summary\n"
        f"- source_dialect: `{source_dialect}`\n"
        f"- target_dialect: `{target_dialect}`\n\n"
        "### Migrated SQL\n"
        f"{rewritten_sql}\n\n"
        "### Source lint violations\n"
        f"{_format_violations(src_violations)}\n\n"
        "### Target lint violations\n"
        f"{_format_violations(dst_violations)}\n\n"
        "### Warnings\n"
        f"{warning_text}\n"
    )

