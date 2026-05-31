# ai-sql-migration

AI-powered SQL migration agent that uses [LangGraph](https://github.com/langchain-ai/langgraph) and an LLM (Anthropic Claude or [OpenRouter](https://openrouter.ai)) to query data from **Azure SQL Edge** (Docker) and **Databricks** using natural language.

A lightweight LLM classifier automatically routes each query to the right-sized model based on complexity (simple / medium / complex), optimizing cost without sacrificing quality on hard tasks. The classifier works with both Anthropic and OpenRouter.

## Requirements

- Python 3.13+
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
- An **Anthropic API key** (`ANTHROPIC_API_KEY`) **or** an **OpenRouter API key** (`OPENROUTER_API_KEY`) — at least one is required
- Docker running `azure-sql-edge` (for SQL Edge tools)
- A Databricks workspace with a SQL warehouse (for Databricks tools)
  - **Required**: A Unity Catalog (`localuc` by default) must exist before using Databricks features

**For step-by-step setup instructions, see [runbook.md](ai-sql-migration/runbook.md)** ← Start here if this is your first time setting up the project.

## Setup

1. Clone the repo and enter the project directory:

```bash
cd ai-sql-migration
```

2. Install dependencies:

```bash
uv sync
```

3. Copy the environment variables template and fill in your credentials:

```bash
cp .env.example .env
```

### LLM Provider (at least one required)

| Variable | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic API key (`sk-ant-...`). Enables the LLM classifier and tiered routing with Claude models. |
| `OPENROUTER_API_KEY` | OpenRouter API key (`sk-or-...`). Enables classifier + tiered routing via OpenRouter. Takes precedence over Anthropic when both are set. |

### Anthropic model tiers (optional — only used when `ANTHROPIC_API_KEY` is set)

| Variable | Default | Description |
| --- | --- | --- |
| `ANTHROPIC_MODEL_CLASSIFIER` | `claude-haiku-4-5-20251001` | Model used to classify query complexity |
| `ANTHROPIC_MODEL_SIMPLE` | `claude-haiku-4-5-20251001` | Model for simple queries (basic SELECTs, schema lookups) |
| `ANTHROPIC_MODEL_MEDIUM` | `claude-sonnet-4-5` | Model for medium queries (JOINs, aggregations) |
| `ANTHROPIC_MODEL_COMPLEX` | `claude-sonnet-4-5` | Model for complex queries (full T-SQL→Spark migrations, subqueries) |

### OpenRouter model tiers (optional — only used when `OPENROUTER_API_KEY` is set)

| Variable | Default | Description |
| --- | --- | --- |
| `OPENROUTER_MODEL_CLASSIFIER` | `meta-llama/llama-3.1-8b-instruct:free` | Model used to classify query complexity |
| `OPENROUTER_MODEL_SIMPLE` | `meta-llama/llama-3.1-8b-instruct:free` | Model for simple queries (basic SELECTs, schema lookups) |
| `OPENROUTER_MODEL_MEDIUM` | `mistralai/mixtral-8x7b-instruct` | Model for medium queries (JOINs, aggregations) |
| `OPENROUTER_MODEL_COMPLEX` | `anthropic/claude-sonnet-4-5` | Model for complex queries (full T-SQL→Spark migrations, subqueries) |

### SQL Edge connection

| Variable | Description |
|---|---|
| `SQLEDGE_HOST` | SQL Edge host (default: `localhost`) |
| `SQLEDGE_PORT` | SQL Edge port (default: `1433`) |
| `SQLEDGE_DATABASE` | Database name (e.g. `ecobicis`) |
| `SQLEDGE_USER` | SQL Edge login (e.g. `sa`) |
| `SQLEDGE_PASSWORD` | SQL Edge password |

### Databricks connection

| Variable | Description |
|---|---|
| `DATABRICKS_HOST` | Databricks workspace URL |
| `DATABRICKS_TOKEN` | Databricks personal access token |
| `DATABRICKS_WAREHOUSE_ID` | SQL warehouse ID |
| `UC_CATALOG` | Unity Catalog name |
| `UC_SCHEMA` | Schema name within the catalog |

### SQLFluff migration

| Variable | Description |
|---|---|
| `SQLFLUFF_ENABLED` | Enable SQL migration lint/fix flow (`true`/`false`) |
| `SQLFLUFF_SOURCE_DIALECT` | Source SQL dialect for migration (default: `tsql`) |
| `SQLFLUFF_TARGET_DIALECT` | Target SQL dialect for migration (default: `sparksql`) |

### Observability (optional)

| Variable | Default | Description |
| --- | --- | --- |
| `LANGSMITH_TRACING` | `false` | Enable LangSmith tracing. Must be set in `.env` — cannot be set at runtime. |
| `LANGSMITH_API_KEY` | — | LangSmith API key (`ls__...`). Required when tracing is enabled. |
| `LANGSMITH_PROJECT` | `ai-sql-migration` | Project name in LangSmith. |
| `LANGSMITH_ENDPOINT` | `https://api.smith.langchain.com` | LangSmith API endpoint. |
| `QUALITY_JUDGE_ENABLED` | `false` | Run a cheap LLM judge after each response to score quality (1–5). Adds ~1 extra LLM call per run. |

### Databricks Unity Catalog Setup (Required)

Before using Databricks features, ensure the Unity Catalog exists and you have access:

```sql
CREATE CATALOG IF NOT EXISTS localuc;
GRANT USE CATALOG ON CATALOG localuc TO `user@enterprise.com`;
```

Run these commands in your **Databricks workspace SQL editor** before initializing the database pipeline or querying Databricks with the agent. Replace `user@enterprise.com` with your actual Databricks principal (user email or service principal name).

## Running

```bash
uv run python main.py
```

Override the default query with the `USER_QUERY` environment variable:

```bash
USER_QUERY="Use migrate_sql_query for: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name FROM pharmacy_db.dbo.dim_patient; then run_sql_query on the migrated SQL in Databricks." uv run python main.py
```

## Project Structure

```
ai-sql-migration/
├── main.py                      # Entry point and rich console UI
├── pyproject.toml               # Project metadata and dependencies
├── .env.example                 # Environment variables template
└── src/
    ├── config/
    │   ├── settings.py          # Settings dataclass loaded from env (Anthropic + OpenRouter fields)
    │   └── llm_config.py        # Model factory, query classifier (ClassifierResult), quality judge
    ├── graph/
    │   ├── builder.py           # LangGraph agent compilation
    │   ├── nodes.py             # LLM call, tool, and routing nodes
    │   └── state.py             # Agent state definition
    ├── models/                  # Data models
    ├── observability/
    │   └── metrics.py           # RunMetrics: latency, tokens, cost estimation, quality score
    └── tools/
        ├── sql_migration.py     # SQL Edge -> Databricks migration tool (SQLFluff)
        ├── sqledge_sql.py       # Azure SQL Edge tools
        └── databricks_sql.py    # Databricks SQL tools (with async polling)
```

## Agent Tools

### Azure SQL Edge

| Tool | Description |
|---|---|
| `run_sqledge_query` | Runs a read-only `SELECT` query against the SQL Edge instance. Automatically injects `TOP N` to cap results. |
| `describe_sqledge_table` | Returns column names, data types, and nullability for a given table via `INFORMATION_SCHEMA.COLUMNS`. |

### Databricks

| Tool | Description |
|---|---|
| `run_sql_query` | Runs a read-only `SELECT`, `SHOW`, or `DESCRIBE` query against Databricks SQL Warehouse. Automatically appends `LIMIT N`. |
| `describe_table` | Describes a Unity Catalog table schema using `DESCRIBE TABLE`. |
| `migrate_sql_query` | Migrates SQL Edge/T-SQL flavored SQL to Spark SQL using SQLFluff lint + rewrite rules. |

## Usage Examples

The agent automatically classifies each query into a tier (`simple` / `medium` / `complex`) and routes it to the appropriate model. Use explicit queries so the agent also chooses the correct tool and data source.

### Tier: simple

Queries clasificadas como `simple` usan el modelo más ligero (e.g. `claude-haiku` o `llama-3.1-8b:free`). Ideales para lookups de schema o SELECTs básicos de una sola tabla.

#### Describir schema de una tabla (SQL Edge)

```bash
USER_QUERY="Use describe_sqledge_table for dim_patient and list all columns." uv run python main.py
```

#### Describir schema de una tabla (Databricks)

```bash
USER_QUERY="Use describe_table for localuc.gold.dim_patient and show me the columns." uv run python main.py
```

#### SELECT básico (SQL Edge)

```bash
USER_QUERY="Use run_sqledge_query to execute: SELECT TOP (5) [sk_patient_id], [first_name], [last_name], [is_active] FROM [localdb].[dbo].[dim_patient] WHERE [is_active] = 1" uv run python main.py
```

#### SELECT básico (Databricks)

```bash
USER_QUERY="Use run_sql_query to list 5 rows from localuc.gold.dim_patient." uv run python main.py
```

#### Migrar y ejecutar query básica (SQL Edge → Databricks)

```bash
USER_QUERY="Use migrate_sql_query for: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, ISNULL(last_name, 'unknown') AS last_name, GETDATE() AS migrated_at FROM localdb.dbo.dim_patient; then run_sql_query on the migrated SQL in Databricks."
uv run python main.py
```

---

### Tier: medium

Queries clasificadas como `medium` usan un modelo intermedio (e.g. `claude-sonnet` o `mixtral-8x7b`). Ideales para agregaciones, JOINs simples y filtros compuestos.

#### Agregación con GROUP BY (SQL Edge)

```bash
USER_QUERY="Use run_sqledge_query to count patients grouped by primary_rare_disease, order by count descending, top 10." uv run python main.py
```

#### JOIN entre dos tablas (SQL Edge)

```bash
USER_QUERY="Use run_sqledge_query to join dim_patient with fact_prescription on sk_patient_id, show first_name, last_name and count of prescriptions per patient, top 5." uv run python main.py
```

#### Agregación en Databricks

```bash
USER_QUERY="Use run_sql_query on localuc.gold.fact_prescription to show total prescriptions per medication, grouped by medication name, top 10 ordered by total descending." uv run python main.py
```

---

### Tier: complex

Queries clasificadas como `complex` usan el modelo más capaz (e.g. `claude-sonnet-4-5` o `claude-opus`). Ideales para migraciones T-SQL → Spark SQL completas y analytics multi-tabla.

#### Migrar query con window functions y CTE

```bash
export USER_QUERY="Use migrate_sql_query for this T-SQL, then run it with run_sql_query:
WITH ranked_patients AS (
    SELECT
        p.sk_patient_id,
        p.first_name,
        p.last_name,
        ISNULL(p.primary_rare_disease, 'Unknown') AS disease,
        COUNT(rx.sk_prescription_id) AS total_prescriptions,
        ROW_NUMBER() OVER (PARTITION BY p.primary_rare_disease ORDER BY COUNT(rx.sk_prescription_id) DESC) AS rn
    FROM localdb.dbo.dim_patient p
    LEFT JOIN localdb.dbo.fact_prescription rx ON p.sk_patient_id = rx.sk_patient_id
    WHERE p.is_active = 1
    GROUP BY p.sk_patient_id, p.first_name, p.last_name, p.primary_rare_disease
)
SELECT TOP 10 first_name, last_name, disease, total_prescriptions, rn
FROM ranked_patients
WHERE rn = 1
ORDER BY total_prescriptions DESC;"
uv run python main.py
```

#### Migrar query con JOIN y agregación

```bash
export USER_QUERY="Migrate this T-SQL to Databricks using migrate_sql_query, then run it with run_sql_query:
SELECT TOP 10
    p.first_name,
    p.last_name,
    COUNT(rx.sk_prescription_id) AS total_prescriptions,
    ISNULL(p.primary_rare_disease, 'Unknown') AS disease
FROM localdb.dbo.dim_patient p
JOIN localdb.dbo.fact_prescription rx ON p.sk_patient_id = rx.sk_patient_id
GROUP BY p.first_name, p.last_name, p.primary_rare_disease
ORDER BY total_prescriptions DESC"
uv run python main.py
```

#### Migrar desde archivo .sql

```bash
uv run python main.py --sql-file reports/patient_spending.sql
```

#### Guardar el SQL migrado a un archivo

```bash
uv run python main.py -q "SELECT TOP 5 GETDATE() AS ts, ISNULL(first_name,'?') AS name FROM localdb.dbo.dim_patient" --write-migrated output/migrated.sql
```

#### Uso programático

```python
from dotenv import load_dotenv
load_dotenv()

from src.config import Settings, classify_query
from src.graph.builder import build_agent
from langchain_core.messages import HumanMessage

settings = Settings.from_env()

query = "Migrate this SQL Edge query to Databricks and run it: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name FROM pharmacy_db.dbo.dim_patient;"

# classify_query returns a ClassifierResult with .tier and token usage
classifier_result = classify_query(settings, query)
agent = build_agent(settings, tier=classifier_result.tier)

result = agent.invoke({"messages": [HumanMessage(content=query)]})
print(result["messages"][-1].content)
```

## Dependencies

| Package | Purpose |
|---|---|
| `anthropic` | Claude API client |
| `langchain-anthropic` | LangChain-compatible Claude chat model (used when `ANTHROPIC_API_KEY` is set) |
| `langchain-openai` | LangChain-compatible OpenAI-format chat model (used for OpenRouter) |
| `langchain-core` | Base abstractions for tools and messages |
| `langgraph` | Agent graph orchestration |
| `pyodbc` | ODBC connector for Azure SQL Edge |
| `databricks-sql-connector` | Databricks SQL warehouse connector |
| `python-dotenv` | Load environment variables from `.env` |
| `sqlfluff` | SQL linting/fixing and dialect-aware migration assistance |
| `rich` | Terminal UI (panels, markdown, colored output) |
