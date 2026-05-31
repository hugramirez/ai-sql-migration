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

- `ANTHROPIC_API_KEY` — Required **unless** `OPENROUTER_API_KEY` is set. At least one must be present.
- `OPENROUTER_API_KEY` — Optional. When set, enables the LLM query classifier and tiered model routing. Takes precedence over Anthropic.
- `OPENROUTER_MODEL_CLASSIFIER` / `OPENROUTER_MODEL_SIMPLE` / `OPENROUTER_MODEL_MEDIUM` / `OPENROUTER_MODEL_COMPLEX` — Model names per tier (all have defaults; only active when `OPENROUTER_API_KEY` is set).
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

- **Provider selection**: If `OPENROUTER_API_KEY` is set → `ChatOpenAI` via `langchain-openai` pointed at `https://openrouter.ai/api/v1`. Otherwise → `ChatAnthropic` via `langchain-anthropic`.
- **Query classifier**: `classify_query()` en `llm_config.py` corre en **ambos** proveedores. Con OpenRouter usa `OPENROUTER_MODEL_CLASSIFIER` (default: `meta-llama/llama-3.1-8b-instruct:free`); con Anthropic usa `ANTHROPIC_MODEL_CLASSIFIER` (default: `claude-haiku-4-5-20251001`). Retorna `simple`, `medium`, o `complex`; cae a `complex` en cualquier error.
- **Model tiers**: `build_agent(settings, tier)` selecciona el modelo del tier correspondiente (`settings.openrouter_model_{tier}` o `settings.anthropic_model_{tier}`). Default tier: `complex`.
- **Tools**: Five tools bound to model; LangGraph router decides tool-call vs. END.
- **Graph**: START → llm_call → [tool_node or END] → llm_call (loop until no more tool calls).

## Databricks Unity Catalog Setup

Before initializing the Databricks pipeline, ensure the `localuc` catalog exists and your user has access:

```sql
CREATE CATALOG IF NOT EXISTS localuc;
GRANT USE CATALOG ON CATALOG localuc TO `user@enterprise.com`;
```

Run these commands in your Databricks workspace SQL editor **before** running `data/init_db_databricks.py`. The pipeline expects `localuc` to exist and will create schemas (`bronze`, `silver`, `gold`) and tables within it.

## Common Mistakes

1. **Missing `.env`** — Will fail at import time (no fallback).
2. **Neither API key set** — `Settings.from_env()` raises `SystemExit` if both `ANTHROPIC_API_KEY` and `OPENROUTER_API_KEY` are empty. Set at least one.
3. **Wrong data source** — Agent defaults to SQL Edge if ambiguous; must be explicit if using Databricks.
4. **Forgetting table mapping** — `pharmacy_db.dbo.dim_patient` must be rewritten to `pharmacy.gold.dim_patient` before running in Databricks.
5. **SQLFluff disabled** — Set `SQLFLUFF_ENABLED=true` in `.env`.
6. **Stale env overrides** — If testing with `SQL_MIGRATION_UC_PREFIX`, remember it affects all migrations in that session.
7. **Missing Databricks catalog** — `localuc` must exist before running `init_db_databricks.py`; create it with the SQL commands above.
8. **OpenRouter model without tool-calling support** — The free-tier classifier model (`llama-3.1-8b-instruct:free`) only emits a one-word response and does not use tools. The agent models (`SIMPLE`/`MEDIUM`/`COMPLEX`) must support function calling; the defaults (`llama-3.1-8b`, `mixtral-8x7b`, `claude-sonnet-4-5`) all do.
