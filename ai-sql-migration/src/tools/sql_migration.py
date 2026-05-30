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


def _migration_uc_prefix() -> str:
    """Unity Catalog prefix for localuc warehouse objects (no trailing dot)."""
    raw = os.environ.get("SQL_MIGRATION_UC_PREFIX", "localuc.gold").strip()
    return raw.rstrip(".").strip() or "localuc.gold"


# Tables aligned with data/pipelines (SQL Server dbo.* → same logical name under UC prefix)
_LOCALDB_DBO_TABLES: tuple[str, ...] = (
    "dim_patient",
    "dim_medication",
    "dim_prescriber",
    "dim_payer",
    "dim_date",
    "dim_care_team_member",
    "fact_prescription",
    "fact_adherence",
    "fact_clinical_interaction",
    "fact_shipment",
    "fact_last_event",
)


def _table_rewrite_pairs() -> list[tuple[str, str]]:
    """Longest-match-friendly (localdb.dbo.* before bare dbo.*)."""
    prefix = _migration_uc_prefix()
    pairs: list[tuple[str, str]] = []
    for t in _LOCALDB_DBO_TABLES:
        target = f"{prefix}.{t}"
        pairs.append((rf"\[localdb\]\.\[dbo\]\.\[{t}\]", target))
        pairs.append((rf"localdb\.dbo\.{t}\b", target))
        pairs.append((rf"(?<![\w])dbo\.{t}\b", target))
    pairs.sort(key=lambda x: len(x[0]), reverse=True)
    return pairs


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

    # OFFSET n ROWS FETCH NEXT m ROWS ONLY (T-SQL) -> LIMIT m (Spark SQL)
    off_fetch = re.compile(
        r"(?is)\bOFFSET\s+\d+\s+ROWS\s+FETCH\s+NEXT\s+(\d+)\s+ROWS\s+ONLY\s*$"
    )
    if off_fetch.search(rewritten):
        rewritten = off_fetch.sub(r"LIMIT \1", rewritten).strip()
        warnings.append("Applied OFFSET/FETCH -> LIMIT rewrite.")

    # Remap localdb dbo.* → Unity Catalog gold (or SQL_MIGRATION_UC_PREFIX)
    for pattern, replacement in _table_rewrite_pairs():
        new_sql = re.sub(pattern, replacement, rewritten, flags=re.IGNORECASE)
        if new_sql != rewritten:
            warnings.append(f"Remapped table reference -> {replacement}.")
            rewritten = new_sql

    # Strip remaining T-SQL bracket notation: [column] -> column
    bracket_pattern = re.compile(r"\[(\w+)\]")
    if bracket_pattern.search(rewritten):
        rewritten = bracket_pattern.sub(r"\1", rewritten)
        warnings.append("Stripped T-SQL bracket notation.")

    # T-SQL string concat: expr + 'literal' + expr -> Spark concat / concat_ws
    _three_term_plus = re.compile(r"([\w.]+)\s*\+\s*('(?:[^']|'')*')\s*\+\s*([\w.]+)")
    did_plus_concat = False
    while True:
        m = _three_term_plus.search(rewritten)
        if not m:
            break
        if m.group(2) == "' '":
            rewritten = _three_term_plus.sub(r"concat_ws(' ', \1, \3)", rewritten, count=1)
        else:
            rewritten = _three_term_plus.sub(r"concat(\1, \2, \3)", rewritten, count=1)
        did_plus_concat = True
    if did_plus_concat:
        warnings.append("Applied T-SQL + string concat between expressions -> concat/concat_ws.")

    return rewritten, warnings


def parse_migrated_sql_line(tool_output: str) -> str | None:
    """Extract SQL from a ``migrate_sql_query`` tool result line ``MIGRATED_SQL: ...``."""
    for line in tool_output.strip().splitlines():
        if line.startswith("MIGRATED_SQL:"):
            return line[len("MIGRATED_SQL:") :].strip()
    return None


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

    lines = [
        f"MIGRATED_SQL: {rewritten_sql}",
        f"REWRITES: {', '.join(rewrites) if rewrites else 'none'}",
    ]
    if dst_violations:
        lines.append(f"LINT_WARNINGS: {_format_violations(dst_violations)}")
    return "\n".join(lines)

