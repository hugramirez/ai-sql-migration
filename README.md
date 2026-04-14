## Compufest[1]

# ai-sql-migration

AI-powered SQL migration agent that uses [LangGraph](https://github.com/langchain-ai/langgraph) and [Anthropic Claude](https://www.anthropic.com) to query and migrate Databricks data sources.

## Requirements

- Python 3.13+
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- An Anthropic API key
- A Databricks workspace with a SQL warehouse

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
| `DATABRICKS_HOST` | Databricks workspace URL (e.g. `https://<workspace>.azuredatabricks.net`) |
| `DATABRICKS_TOKEN` | Databricks personal access token |
| `DATABRICKS_WAREHOUSE_ID` | SQL warehouse ID |
| `UC_CATALOG` | Unity Catalog name |
| `UC_SCHEMA` | Schema name within the catalog |

## Running

```bash
uv run python main.py
```

Or via the installed CLI script:

```bash
uv run ai-sql-migration
```

## Project Structure

```
ai-sql-migration/
├── main.py               # Entry point
├── pyproject.toml        # Project metadata and dependencies
├── .env.example          # Environment variables template
└── src/
    ├── config/           # Settings loaded from environment variables
    ├── graph/            # LangGraph agent definition
    ├── models/           # Data models
    └── tools/            # Agent tools (Databricks SQL, etc.)
```

## Dependencies

| Package | Purpose |
|---|---|
| `anthropic` | Claude API client |
| `langgraph` | Agent orchestration framework |
| `databricks-sql-connector` | Databricks SQL warehouse connector |
| `python-dotenv` | Load environment variables from `.env` |
