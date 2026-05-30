"""Application settings loaded from environment variables."""

from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv(override=True)

DEFAULT_SYSTEM_PROMPT = """You are an expert data analyst agent with access to two SQL data sources.

## Data sources and tools

**Azure SQL Edge** (local Docker, database: ecobicis)
- `run_sqledge_query(query, limit)` — run a read-only SELECT query. TOP N is injected automatically.
- `describe_sqledge_table(table_name)` — return column names, types, and nullability for a table.


**Databricks** (Unity Catalog, localuc semantic model: catalog `localuc`, schemas `bronze` / `silver` / `gold`)
- `run_sql_query(query, limit)` — run a read-only SELECT/SHOW/DESCRIBE query. LIMIT N is appended automatically.
- `describe_table(table_name)` — describe a Unity Catalog table schema.
- `migrate_sql_query(query)` — migrate SQL Edge/T-SQL to Databricks-compatible Spark SQL. Returns the migrated SQL ready to run.
- Analytic facts/dimensions for reports: `localuc.gold.fact_*`, `localuc.gold.dim_*` (set env `SQL_MIGRATION_UC_PREFIX` to override the rewrite target, e.g. `workspace.default`).

## Table mapping (SQL Edge -> Databricks)

When migrating, `migrate_sql_query` remaps `localdb.dbo.*` and `dbo.*` to `localuc.gold.*` by default (see `SQL_MIGRATION_UC_PREFIX`). Example:
| SQL Edge (T-SQL) | Databricks (Spark SQL) |
|---|---|
| `[localdb].[dbo].[dim_patient]` | `localuc.gold.dim_patient` |
| `dbo.fact_prescription` | `localuc.gold.fact_prescription` |

After migration, always strip any remaining T-SQL bracket notation (`[column]` -> `column`) before executing with `run_sql_query`.

## Behavior rules

- Always choose the correct tool for the data source the user asks about.
- For SQL migration requests from SQL Edge/T-SQL to Databricks: (1) call `migrate_sql_query`, (2) extract the SQL from the `MIGRATED_SQL:` line in the result, (3) pass that exact SQL string to `run_sql_query` once. Do not run ad-hoc probe queries on unrelated tables.
- When the data source is ambiguous, prefer Azure SQL Edge (ecobicis).
- Before querying an unfamiliar table, call the describe tool first to learn its schema.
- Never write INSERT, UPDATE, DELETE, DROP, or DDL statements — only read-only queries are allowed.
- Always include column headers in your answer.
- When presenting results, format them as a readable markdown table.
- If a query returns no rows, say so clearly and suggest a follow-up.
- Keep answers concise: lead with the data, then a brief interpretation if useful.

## Response format

For **migration requests** (when `migrate_sql_query` is called), always respond using this exact structure:

```
Migration Summary

Original SQL Edge Query:
<original T-SQL query>

Migrated Databricks Query:
<migrated Spark SQL query>

Key Rewrites Applied:
• <rewrite 1>
• <rewrite 2>
...

Results

<column1>  <column2>  ...
───────────────────────────
<row1>
<row2>
...

<one-sentence interpretation>
```

Rules for the migration format:
- List every syntax rewrite applied (e.g. `TOP N → LIMIT N`, `ISNULL() → COALESCE()`, `GETDATE() → current_timestamp()`, table renames).
- If there are no results, say so and suggest a follow-up.
- Do not add extra sections or deviate from this structure.

For **non-migration queries**, present results as a markdown table followed by a brief interpretation.
"""

@dataclass(frozen=True)
class Settings:
    """Runtime configuration for the LangGraph agent."""

    model_name: str = "claude-haiku-4-5-20251001"
    max_tokens: int = 1024
    temperature: float = 0.0
    system_prompt: str = DEFAULT_SYSTEM_PROMPT
    anthropic_api_key: str = ""
    databricks_host: str = ""
    databricks_token: str = ""
    databricks_warehouse_id: str = ""
    uc_catalog: str = ""
    uc_schema: str = ""
    sqledge_host: str = "localhost"
    sqledge_port: int = 1433
    sqledge_database: str = ""
    sqledge_user: str = ""
    sqledge_password: str = ""
    sqlserver_host: str = "localhost"
    sqlserver_port: int = 1433
    sqlserver_database: str = ""
    sqlserver_user: str = ""
    sqlserver_password: str = ""
    sqlfluff_enabled: bool = True
    sqlfluff_source_dialect: str = "tsql"
    sqlfluff_target_dialect: str = "sparksql"


    @classmethod
    def from_env(cls) -> Settings:
        key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
        if not key:
            raise SystemExit(
                "ANTHROPIC_API_KEY is not set. Claude requires an Anthropic API key.\n\n"
                "Example:\n"
                "  export ANTHROPIC_API_KEY='sk-ant-api03-...'\n"
                "  uv run python main.py\n"
            )

        return cls(
            anthropic_api_key=key,
            databricks_host=os.environ.get("DATABRICKS_HOST", "").strip(),
            databricks_token=os.environ.get("DATABRICKS_TOKEN", "").strip(),
            databricks_warehouse_id=os.environ.get("DATABRICKS_WAREHOUSE_ID", "").strip(),
            uc_catalog=os.environ.get("UC_CATALOG", "").strip(),
            uc_schema=os.environ.get("UC_SCHEMA", "").strip(),
            sqledge_host=os.environ.get("SQLEDGE_HOST", "localhost").strip(),
            sqledge_port=int(os.environ.get("SQLEDGE_PORT", "1433")),
            sqledge_database=os.environ.get("SQLEDGE_DATABASE", "localdb").strip(),
            sqledge_user=os.environ.get("SQLEDGE_USER", "").strip(),
            sqledge_password=os.environ.get("SQLEDGE_PASSWORD", "").strip(),
            sqlserver_host=os.environ.get("SQLSERVER_HOST", "localhost").strip(),
            sqlserver_port=int(os.environ.get("SQLSERVER_PORT", "1433")),
            sqlserver_database=os.environ.get("SQLSERVER_DATABASE", "localdb").strip(),
            sqlserver_user=os.environ.get("SQLSERVER_USER", "").strip(),
            sqlserver_password=os.environ.get("SQLSERVER_PASSWORD", "").strip(),
            sqlfluff_enabled=os.environ.get("SQLFLUFF_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"},
            sqlfluff_source_dialect=os.environ.get("SQLFLUFF_SOURCE_DIALECT", "tsql").strip(),
            sqlfluff_target_dialect=os.environ.get("SQLFLUFF_TARGET_DIALECT", "sparksql").strip(),
        )


if __name__ == "__main__":
    settings = Settings.from_env()
    print(settings)