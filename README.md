## Compufest[1]

# ai-sql-migration

AI-powered SQL migration agent that uses [LangGraph](https://github.com/langchain-ai/langgraph) and [Anthropic Claude](https://www.anthropic.com) to query data from **Azure SQL Edge** (Docker) and **Databricks** using natural language.

## Requirements

- Python 3.13+
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
- An Anthropic API key
- Docker running `azure-sql-edge` (for SQL Edge tools)
- A Databricks workspace with a SQL warehouse (for Databricks tools)

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

| Variable | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Your Anthropic API key (`sk-ant-...`) |
| `SQLEDGE_HOST` | SQL Edge host (default: `localhost`) |
| `SQLEDGE_PORT` | SQL Edge port (default: `1433`) |
| `SQLEDGE_DATABASE` | Database name (e.g. `ecobicis`) |
| `SQLEDGE_USER` | SQL Edge login (e.g. `sa`) |
| `SQLEDGE_PASSWORD` | SQL Edge password |
| `DATABRICKS_HOST` | Databricks workspace URL |
| `DATABRICKS_TOKEN` | Databricks personal access token |
| `DATABRICKS_WAREHOUSE_ID` | SQL warehouse ID |
| `UC_CATALOG` | Unity Catalog name |
| `UC_SCHEMA` | Schema name within the catalog |
| `SQLFLUFF_ENABLED` | Enable SQL migration lint/fix flow (`true`/`false`) |
| `SQLFLUFF_SOURCE_DIALECT` | Source SQL dialect for migration (default: `tsql`) |
| `SQLFLUFF_TARGET_DIALECT` | Target SQL dialect for migration (default: `sparksql`) |

## Running

```bash
uv run python main.py
```

Override the default query with the `USER_QUERY` environment variable:

```bash
USER_QUERY="Use migrate_sql_query for: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name FROM PANTHERx.cpr.dim_patient; then run_sql_query on the migrated SQL in Databricks." uv run python main.py
```

## Project Structure

```
ai-sql-migration/
├── main.py                      # Entry point and rich console UI
├── pyproject.toml               # Project metadata and dependencies
├── .env.example                 # Environment variables template
└── src/
    ├── config/
    │   ├── settings.py          # Settings dataclass loaded from env
    │   └── llm_config.py        # ChatAnthropic model factory
    ├── graph/
    │   ├── builder.py           # LangGraph agent compilation
    │   ├── nodes.py             # LLM call, tool, and routing nodes
    │   └── state.py             # Agent state definition
    ├── models/                  # Data models
    └── tools/
        ├── sql_migration.py     # SQL Edge -> Databricks migration tool (SQLFluff)
        ├── sqledge_sql.py       # Azure SQL Edge tools
        └── databricks_sql.py    # Databricks SQL tools
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

Use explicit queries so the agent chooses the correct tool and data source.

**Databricks (`run_sql_query`)**
```bash
USER_QUERY="Use run_sql_query to list 5 rows from workspace.default.dim_patient." uv run python main.py
```

**Databricks schema (`describe_table`)**
```bash
USER_QUERY="Use describe_table for workspace.default.dim_patient and show me the columns." uv run python main.py
```

**SQL Edge (`run_sqledge_query`)**
```bash
USER_QUERY="Use run_sqledge_query to execute: SELECT TOP (5) [sk_patient_id], [patient_external_id], [first_name], [last_name], [date_of_birth], [age], [gender], [ethnicity], [state], [zip_code], [enrollment_date], [primary_rare_disease], [secondary_conditions], [is_active], [created_date], [updated_date] FROM [PANTHERx].[cpr].[dim_patient]" uv run python main.py
```

**SQL Edge schema (`describe_sqledge_table`)**
```bash
USER_QUERY="Use describe_sqledge_table for dim_patient and list all columns." uv run python main.py
```

**SQL Edge active patients (`run_sqledge_query`)**
```bash
USER_QUERY="Use run_sqledge_query to execute: SELECT TOP (5) [sk_patient_id], [first_name], [last_name], [is_active], [updated_date] FROM [PANTHERx].[cpr].[dim_patient] WHERE [is_active] = 1" uv run python main.py
```

**Migrate SQL Edge -> Databricks (`migrate_sql_query` + `run_sql_query`)**
```bash
export USER_QUERY="Use migrate_sql_query for: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, ISNULL(last_name, 'unknown') AS last_name, GETDATE() AS migrated_at FROM PANTHERx.cpr.dim_patient; then run_sql_query on the migrated SQL in Databricks."
uv run python main.py
```

**Programmatic usage:**

```python
from dotenv import load_dotenv
load_dotenv()

from src.config import Settings
from src.graph.builder import build_agent
from langchain_core.messages import HumanMessage

settings = Settings.from_env()
agent = build_agent(settings)

result = agent.invoke({
    "messages": [HumanMessage(content="Migrate this SQL Edge query to Databricks and run it: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name FROM PANTHERx.cpr.dim_patient;")]
})
print(result["messages"][-1].content)
```

## Dependencies

| Package | Purpose |
|---|---|
| `anthropic` | Claude API client |
| `langchain-anthropic` | LangChain-compatible Claude chat model |
| `langchain-core` | Base abstractions for tools and messages |
| `langgraph` | Agent graph orchestration |
| `pyodbc` | ODBC connector for Azure SQL Edge |
| `databricks-sql-connector` | Databricks SQL warehouse connector |
| `python-dotenv` | Load environment variables from `.env` |
| `sqlfluff` | SQL linting/fixing and dialect-aware migration assistance |
| `rich` | Terminal UI (panels, markdown, colored output) |
