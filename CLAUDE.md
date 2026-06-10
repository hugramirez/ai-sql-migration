# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start

```bash
cd ai-sql-migration
uv sync
cp .env.example .env  # fill in credentials
uv run python main.py
```

## Project Overview

**ai-sql-migration** is an AI-powered SQL migration agent that converts T-SQL (Azure SQL Edge) to Spark SQL (Databricks) using LangGraph and Claude or OpenRouter LLMs.

**Key features:**
- Intelligent query complexity classifier (routes to lightweight, medium, or powerful models)
- LLM-powered SQL migration using SQLFluff
- Supports both Anthropic Claude and OpenRouter
- Observability: token counting, latency tracking, cost estimation, quality scoring
- Rich terminal UI showing metrics after each run

## Single-Package Layout

The entire project lives under `ai-sql-migration/`:

```
ai-sql-migration/
├── main.py                      # Entry point; rich UI + agent orchestration
├── pyproject.toml               # Python 3.13+, uv, dependencies
├── .env.example                 # Environment template (copy to .env)
├── src/
│   ├── config/
│   │   ├── settings.py          # Load .env, defaults, system prompt
│   │   └── llm_config.py        # Provider detection, classifier, quality judge
│   ├── graph/
│   │   ├── builder.py           # LangGraph agent compilation
│   │   ├── nodes.py             # LLM call, tool, and routing logic
│   │   └── state.py             # MessagesState definition
│   ├── models/                  # Data models (ClassifierResult, RunMetrics)
│   ├── observability/
│   │   └── metrics.py           # Token accounting, cost table, RunMetrics
│   └── tools/
│       ├── sql_migration.py     # SQLFluff T-SQL→Spark SQL rewrite
│       ├── sqledge_sql.py       # Azure SQL Edge query tools
│       └── databricks_sql.py    # Databricks SQL tools (async polling)
├── tests/
│   ├── test_sql_migration.py    # SQLFluff rewrites (TOP→LIMIT, ISNULL→COALESCE)
│   └── test_databricks_sql.py   # Read-only guard tests
├── data/
│   ├── init_db.py              # SQL Edge database seed (CSV → tables)
│   └── init_db_databricks.py   # Databricks UC initialization
├── specs/
│   └── ai_sql_migration.spec.yaml  # Quantifiable requirements
├── features/
│   └── sql_migration_pipeline.feature  # Gherkin scenarios
├── openspec/
│   └── specs/
│       ├── query-classifier/spec.md  # Classifier requirements
│       └── sql-migration-pipeline/spec.md  # Migration requirements
├── docs/
│   └── architecture/adr/ADR-001-tiered-llm-model-routing.md
└── CLAUDE.md                    # Dev guidance (this file)
```

## Running

**Default query** (demonstrates classification + routing):
```bash
uv run python main.py
```

**Custom query** via `USER_QUERY` env var:
```bash
USER_QUERY="Use describe_table for localuc.gold.dim_patient and list all columns." uv run python main.py
USER_QUERY="Use run_sql_query to count patients grouped by primary_rare_disease, top 10." uv run python main.py
USER_QUERY="Migrate this T-SQL to Databricks using migrate_sql_query: SELECT TOP 5 ISNULL(first_name, 'unknown') FROM pharmacy_db.dbo.dim_patient; then run_sql_query on the migrated SQL." uv run python main.py
```

**From SQL file**:
```bash
uv run python main.py --sql-file reports/patient_spending.sql
```

**Save migrated SQL to file**:
```bash
uv run python main.py -q "SELECT TOP 5 GETDATE() AS ts FROM pharmacy_db.dbo.dim_patient" --write-migrated output/migrated.sql
```

## Development Commands

```bash
cd ai-sql-migration

# Install dependencies
uv sync

# Run all tests
uv run pytest tests/ -v

# Run a single test file
uv run pytest tests/test_sql_migration.py -v

# Run a single test
uv run pytest tests/test_sql_migration.py::test_top_to_limit -v

# Run Gherkin scenarios (requires behave)
uv run behave features/

# Run linting (if configured)
uv run ruff check .

# Run type checking (if configured)
uv run mypy src/
```

## Environment Variables (`.env`)

**At least one LLM provider required:**

| Variable | Example | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | `sk-ant-...` | Claude API key |
| `OPENROUTER_API_KEY` | `sk-or-...` | When set, takes precedence over Anthropic |

**Anthropic model tiers** (only if `ANTHROPIC_API_KEY` set):

| Variable | Default | Used for |
|---|---|---|
| `ANTHROPIC_MODEL_CLASSIFIER` | `claude-haiku-4-5-20251001` | Query complexity routing |
| `ANTHROPIC_MODEL_SIMPLE` | `claude-haiku-4-5-20251001` | Simple SELECTs, schema lookups |
| `ANTHROPIC_MODEL_MEDIUM` | `claude-sonnet-4-5` | JOINs, aggregations |
| `ANTHROPIC_MODEL_COMPLEX` | `claude-sonnet-4-5` | Full T-SQL→Spark migrations, CTEs |

**OpenRouter model tiers** (only if `OPENROUTER_API_KEY` set):

| Variable | Default | Used for |
|---|---|---|
| `OPENROUTER_MODEL_CLASSIFIER` | `meta-llama/llama-3.1-8b-instruct:free` | Query classification |
| `OPENROUTER_MODEL_SIMPLE` | `meta-llama/llama-3.1-8b-instruct:free` | Simple queries |
| `OPENROUTER_MODEL_MEDIUM` | `mistralai/mixtral-8x7b-instruct` | Medium queries |
| `OPENROUTER_MODEL_COMPLEX` | `anthropic/claude-sonnet-4-5` | Complex queries |

**SQL Edge** (Azure SQL Edge in Docker):

| Variable | Default | Notes |
|---|---|---|
| `SQLEDGE_HOST` | `localhost` | Docker host |
| `SQLEDGE_PORT` | `1433` | SQL Server port |
| `SQLEDGE_DATABASE` | — | Database name (e.g., `pharmacy_db`) |
| `SQLEDGE_USER` | — | Login (usually `sa`) |
| `SQLEDGE_PASSWORD` | — | Password |

**Databricks** (SQL Warehouse + Unity Catalog):

| Variable | Notes |
|---|---|
| `DATABRICKS_HOST` | Workspace URL (e.g., `https://adb-XXXXXXXX.XX.databricks.com`) |
| `DATABRICKS_TOKEN` | Personal access token (`dapi...`) |
| `DATABRICKS_WAREHOUSE_ID` | SQL warehouse ID |
| `UC_CATALOG` | Unity Catalog name (e.g., `localuc`) |
| `UC_SCHEMA` | Schema within catalog (e.g., `gold`) |

**SQL Migration** (SQLFluff):

| Variable | Default | Notes |
|---|---|---|
| `SQLFLUFF_ENABLED` | `true` | Enable T-SQL→Spark SQL rewrite |
| `SQLFLUFF_SOURCE_DIALECT` | `tsql` | Source dialect |
| `SQLFLUFF_TARGET_DIALECT` | `sparksql` | Target dialect |
| `SQL_MIGRATION_UC_PREFIX` | `pharmacy.gold` | Table mapping prefix |

**Observability** (optional):

| Variable | Default | Notes |
|---|---|---|
| `LANGSMITH_TRACING` | `false` | **Must be in `.env` before startup** |
| `LANGSMITH_API_KEY` | — | LangSmith API key (if tracing enabled) |
| `LANGSMITH_PROJECT` | `ai-sql-migration` | LangSmith project name |
| `QUALITY_JUDGE_ENABLED` | `false` | Score responses 1–5 with lightweight LLM |

**Critical gotchas:**
- `.env` file is **required** (`.env.example` is the template)
- At least one API key (`ANTHROPIC_API_KEY` or `OPENROUTER_API_KEY`) must be set
- `LANGSMITH_TRACING` must be in `.env` **before** the process starts (not set at runtime)
- Databricks Unity Catalog (`localuc`) must exist before seeding; create with:
  ```sql
  CREATE CATALOG IF NOT EXISTS localuc;
  GRANT USE CATALOG ON CATALOG localuc TO `user@enterprise.com`;
  ```

## Agent Architecture

**Flow:**
1. User query → LLM classifier determines tier (simple / medium / complex)
2. Agent built with tier-matched model
3. LLM parses query and calls appropriate tool(s):
   - `describe_sqledge_table(table)` — Schema from SQL Edge
   - `describe_table(table)` — Schema from Databricks
   - `run_sqledge_query(sql)` — Execute SELECT on SQL Edge
   - `run_sql_query(sql)` — Execute SELECT on Databricks (with async polling)
   - `migrate_sql_query(sql)` — Rewrite T-SQL to Spark SQL via SQLFluff
4. Tool results feed back to LLM for synthesis
5. Rich panel UI displays: query → agent reasoning → results → metrics

**Message flow:**
- `HumanMessage` (user query) → `AIMessage` (reasoning + tool calls) → `ToolMessage` (results) → `AIMessage` (synthesis) → stop

**Databricks async polling:**
- `run_sql_query` automatically polls when Databricks returns `PENDING` or `RUNNING`
- Max 300s wait, backoff 1s→5s; timeout raises exception

**Observability metrics:**
- Input + output tokens from classifier and agent
- LLM calls, tool calls, latency (wall-clock time)
- Cost estimation per model's pricing table
- Quality score (1–5) if `QUALITY_JUDGE_ENABLED=true`

## SQL Migration Details

**SQLFluff rewrites** (`src/tools/sql_migration.py`):
- `TOP N` → `LIMIT N`
- `ISNULL(x, y)` → `COALESCE(x, y)`
- `GETDATE()` → `current_timestamp()`
- `CONVERT(datetime, ...)` → `CAST(... AS TIMESTAMP)`
- Table mapping: `pharmacy_db.dbo.dim_*` → `pharmacy.gold.dim_*` (or `SQL_MIGRATION_UC_PREFIX` override)

**Parse migrated SQL from tool output:**
- Tool returns string with `MIGRATED_SQL:` marker line
- `parse_migrated_sql_line()` extracts the SQL after the marker
- LLM then runs the migrated SQL with `run_sql_query`

**Tests use `monkeypatch`** to override `SQL_MIGRATION_UC_PREFIX`:
```python
def test_table_mapping(monkeypatch):
    monkeypatch.setenv("SQL_MIGRATION_UC_PREFIX", "custom.schema")
    sql, warnings = _rewrite_tsql_to_sparksql("SELECT * FROM pharmacy_db.dbo.dim_patient")
    assert "custom.schema.dim_patient" in sql
```

## Testing Strategy

**Run all tests:**
```bash
uv run pytest tests/ -v
```

**Unit tests** (`tests/test_sql_migration.py`):
- SQLFluff rewrite logic
- Parse migrated SQL extraction
- Table remapping with env overrides

**Guard tests** (`tests/test_databricks_sql.py`):
- Read-only enforcement (no INSERT/UPDATE/DELETE/DDL)

**Gherkin scenarios** (BDD):
```bash
uv run behave features/
```

Covers end-to-end workflows (schema lookup, migration, execution).

## Development Workflow

This project uses a **formal specification-driven process**:

```
1. /openspec:proposal "description"      ← start here for non-trivial changes
          ↓
2. openspec/changes/[id]/design.md       ← review decisions
          ↓
3. docs/architecture/adr/ADR-NNN.md      ← record why with metrics
          ↓
4. specs/ai_sql_migration.spec.yaml      ← add requirements + test cases
          ↓
5. features/sql_migration_pipeline.feature ← add Gherkin scenarios
          ↓
6. implement + pytest + behave            ← validate
```

**When to use `/openspec:proposal`:**
- Adding a new data source (e.g., Snowflake)
- Replacing the classifier with a different approach
- Exposing a REST API
- Major architectural changes

Not required for: bug fixes, refactoring, dependency updates, docs-only changes.

**Existing specs:**
- `openspec/specs/query-classifier/spec.md` — Tier routing, fallback, token accounting
- `openspec/specs/sql-migration-pipeline/spec.md` — T-SQL rewrites, output format, error handling

**After implementing:**
1. Update `specs/ai_sql_migration.spec.yaml` with new `req_id` entries
2. Update `features/` with Gherkin scenarios
3. Run `pytest` and `behave` to ensure all specs pass

## Common Mistakes

1. **Missing or malformed `.env`** — Will fail at import. Use `.env.example` as template.
2. **Neither API key set** — At least one of `ANTHROPIC_API_KEY` or `OPENROUTER_API_KEY` must be present.
3. **Ambiguous data source** — Agent defaults to SQL Edge; be explicit if using Databricks.
4. **Forgetting table mapping** — `pharmacy_db.dbo.dim_patient` must rewrite to `pharmacy.gold.dim_patient` before running in Databricks.
5. **SQLFluff disabled** — Set `SQLFLUFF_ENABLED=true` in `.env`.
6. **Stale env overrides** — If testing with `SQL_MIGRATION_UC_PREFIX`, remember it affects all migrations in that session.
7. **Databricks catalog missing** — `localuc` must exist before `init_db_databricks.py`; create with SQL above.
8. **OpenRouter free-tier classifier** — `llama-3.1-8b-instruct:free` doesn't call tools; agent models must support function calling (defaults do).
9. **LangSmith config set at runtime** — `LANGSMITH_TRACING`, `LANGSMITH_API_KEY`, `LANGSMITH_PROJECT` must be in `.env` before startup (LangChain reads them at import time).
10. **Databricks query pending** — `run_sql_query` auto-polls; if you see hangs, check `DATABRICKS_WAREHOUSE_ID` and warehouse status.

## Key Files to Know

| File | Purpose |
|---|---|
| `main.py` | Entry point; CLI parsing, UI rendering, agent invocation |
| `src/config/settings.py` | `.env` loading, defaults, system prompt |
| `src/config/llm_config.py` | Provider detection, classifier, quality judge |
| `src/graph/builder.py` | LangGraph agent compilation and state setup |
| `src/graph/nodes.py` | LLM call node, tool node, routing logic |
| `src/tools/sql_migration.py` | SQLFluff rewrite engine + table mapping |
| `src/tools/sqledge_sql.py` | pyodbc SQL Edge query tools |
| `src/tools/databricks_sql.py` | Databricks connector + async polling |
| `src/observability/metrics.py` | Token accounting, cost estimation, RunMetrics |
| `data/init_db.py` | SQL Edge seed script |
| `data/init_db_databricks.py` | Databricks Unity Catalog initialization |

## Performance Notes

- **Classifier runs separately** before agent, uses cheapest model (haiku/llama-free)
- **Tier routing optimizes cost** without sacrificing quality (sonnet for hard tasks)
- **Databricks async polling** prevents timeouts on slow queries
- **Token counting** includes both classifier and agent for LangSmith tracking
- **Cost estimation** updated per model's pricing; verify in `metrics.py` if models change

## References

- [README.md](./README.md) — Full setup, usage examples, dependencies
- [AGENTS.md](./AGENTS.md) — Quick start, quirks, env vars, testing tips
- [ai-sql-migration/runbook.md](./ai-sql-migration/runbook.md) — Step-by-step Docker + Databricks setup
- [ADR-001](./ai-sql-migration/docs/architecture/adr/ADR-001-tiered-llm-model-routing.md) — Tiered routing rationale
- [Query Classifier Spec](./ai-sql-migration/openspec/specs/query-classifier/spec.md)
- [SQL Migration Spec](./ai-sql-migration/openspec/specs/sql-migration-pipeline/spec.md)
