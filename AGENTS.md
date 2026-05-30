# Agent Notes for ai-sql-migration

## Quick Start

Install and run:
```bash
cd ai-sql-migration
uv sync
cp .env.example .env  # fill in credentials
uv run python main.py
```

Override the query with `USER_QUERY`:
```bash
USER_QUERY="Use run_sql_query to..." uv run python main.py
```

## Project Structure

Single-package Python project under `ai-sql-migration/`.

- **`main.py`** — Entry point; runs LangGraph agent and formats output with rich console panels.
- **`pyproject.toml`** — Dependencies, Python 3.13+, uv as package manager.
- **`src/config/`** — Settings from `.env` (uses `python-dotenv`); system prompt; LLM client factory.
- **`src/graph/`** — LangGraph agent: `builder.py` compiles the graph, `nodes.py` has LLM call / tool node / routing, `state.py` defines MessagesState.
- **`src/tools/`** — Five tools: `migrate_sql_query` (SQLFluff T-SQL→Spark SQL), `run_sqledge_query`, `describe_sqledge_table`, `run_sql_query`, `describe_table`.
- **`tests/`** — Two test files; use pytest. `test_sql_migration.py` tests SQLFluff rewrites (TOP→LIMIT, ISNULL→COALESCE, etc.).
- **`data/`** — DB initialization scripts (`init_db.py` for SQL Edge, `init_db_databricks.py` for Databricks) and raw CSV fixtures.

## Key Quirks

### Environment Variables
The `.env` file **must** be present (`.env.example` is the template). `python-dotenv` loads it in `settings.py` at module import time with `override=True`, so local `.env` wins.

Critical for agent operation:
- `ANTHROPIC_API_KEY` — Required.
- `SQLEDGE_*` — SQL Edge connection (Docker running `azure-sql-edge`).
- `DATABRICKS_*` — Databricks SQL Warehouse.
- `UC_*` — Unity Catalog (tables remapped via `SQL_MIGRATION_UC_PREFIX` env var, default: `pharmacy.gold.*`).
- `SQLFLUFF_*` — Controls SQL migration: `ENABLED`, `SOURCE_DIALECT=tsql`, `TARGET_DIALECT=sparksql`.

### SQL Migration (SQLFluff)
`migrate_sql_query` in `src/tools/sql_migration.py`:
- Uses SQLFluff lint + rewrite rules to convert T-SQL to Spark SQL.
- Rewrites: `TOP N` → `LIMIT`, `ISNULL()` → `COALESCE()`, `GETDATE()` → `current_timestamp()`.
- **Table remapping**: `pharmacy_db.dbo.dim_*` → `pharmacy.gold.dim_*` (or `SQL_MIGRATION_UC_PREFIX` override).
- Output: string with `MIGRATED_SQL:` marker line (parsed by `parse_migrated_sql_line`).
- Tests use `monkeypatch` to override `SQL_MIGRATION_UC_PREFIX` env var.

### Display & Message Handling
`main.py` has display helpers:
- `_last_migrated_spark_sql()` — Extracts final SQL from migration tool output.
- `_ai_migration_summary_block()` — Detects "Migration Summary" + results format.
- `_human_display_body()` — Truncates long SQL queries (>500 chars) for console; full query still sent to LLM.

Useful for understanding message flow: LangGraph agent returns `state["messages"]` (list of HumanMessage, AIMessage, ToolMessage).

## Testing

Run all tests:
```bash
pytest
```

`test_sql_migration.py` covers SQL rewrites and table remapping. Uses pytest's `monkeypatch` fixture to override env vars in tests.

## Agent System Prompt

Defined in `settings.py`. Key rules agent sees:
- Two data sources: SQL Edge (T-SQL, `pharmacy_db.dbo.*`) and Databricks (Spark SQL, `pharmacy.gold.*`).
- For migration: call `migrate_sql_query`, extract SQL from `MIGRATED_SQL:` line, then call `run_sql_query`.
- Always use correct tool for correct data source (ambiguous → prefer SQL Edge).
- Read-only queries only (no INSERT/UPDATE/DELETE/DDL).
- Always format results as markdown tables.

## LLM & Tooling

- **Model**: `ChatAnthropic` (Anthropic Claude) via `langchain-anthropic`.
- **Tools**: Five tools bound to model; LangGraph router decides tool-call vs. END.
- **Graph**: START → llm_call → [tool_node or END] → llm_call (loop until no more tool calls).

## Common Mistakes

1. **Missing `.env`** — Will fail at import time (no fallback).
2. **Wrong data source** — Agent defaults to SQL Edge if ambiguous; must be explicit if using Databricks.
3. **Forgetting table mapping** — `pharmacy_db.dbo.dim_patient` must be rewritten to `pharmacy.gold.dim_patient` before running in Databricks.
4. **SQLFluff disabled** — Set `SQLFLUFF_ENABLED=true` in `.env`.
5. **Stale env overrides** — If testing with `SQL_MIGRATION_UC_PREFIX`, remember it affects all migrations in that session.
