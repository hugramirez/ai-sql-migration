# Data directory

Database initialization (`init_db.py`) and SQL pipelines under `pipelines/`.

## Databricks (Unity Catalog)

From **`ai-sql-migration`**, set `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, and `DATABRICKS_WAREHOUSE_ID` in `.env`. The catalog **`localuc`** must exist (or be creatable by your user). `DATABRICKS_WAREHOUSE_ID` must be the **full** SQL warehouse UUID (32 hex characters, with or without hyphens); a truncated ID usually yields HTTP 400 on connect.

Optional: `DATABRICKS_MAX_ROWS_PER_TABLE=100` limits bronze **dimension** CSV loads to the first *N* rows per table (smoke tests). Omit for a full load. CLI: `uv run python data/init_db_databricks.py init --max-rows 100` (use `--max-rows 0` to ignore the env cap for that run).

- **Python CLI**: `uv run python data/init_db_databricks.py --help` — `init` runs bronze DDL, loads dimension CSVs into `localuc.bronze.raw_dim_*`, then silver / gold / views. SQL files that append `OPTIMIZE` after a `CREATE TABLE … AS SELECT` are split into separate warehouse statements automatically. Facts in bronze are not loaded from `raw_data` (schema differs from SQL Server exports); extend with your own ingest.
- **Smoke test (SQL warehouse only)**: `uv run python scripts/test_databricks_sql_connection.py` — runs `SELECT 1` with the same `databricks.sql.connect` parameters as the pipeline (reads `.env`).
- **Notebook**: open `data/init_db_databricks.ipynb` (includes a minimal connection cell after `load_dotenv`; same flow as CLI for the full pipeline).

## Database initialization

Create the SQL Server database, tables, and load sample CSVs before querying locally.

### Prerequisites

- **Python**: run commands with [`uv`](https://docs.astral.sh/uv/) from the **`ai-sql-migration`** directory (the folder that contains `pyproject.toml`, `.env`, and `data/`).
- **ODBC**: Microsoft **ODBC Driver 18 for SQL Server** (required by `init_db.py`).
- **SQL Server**: reachable at `SQLEDGE_HOST`:`SQLEDGE_PORT` with permission to create/drop databases (see below).

### Environment variables

Create or edit `ai-sql-migration/.env`. `data/init_db.py` and `data/init_db_databricks.py` load it with **`override=True`**, so values in this file replace same-named variables already present in the environment (including empty placeholders from the shell or IDE).

```env
SQLEDGE_HOST=localhost
SQLEDGE_PORT=1433
SQLEDGE_DATABASE=localuc_db
SQLEDGE_USER=sa
SQLEDGE_PASSWORD=<your_password>
```

Omit `SQLEDGE_HOST`, `SQLEDGE_PORT`, or `SQLEDGE_DATABASE` to use the defaults shown above. `SQLEDGE_USER` and `SQLEDGE_PASSWORD` are required (empty values cause the script to exit).

### Quick start

From **`ai-sql-migration`** (not the monorepo root unless you `cd` into this folder):

```bash
cd /path/to/ai-sql-migration
uv sync
uv run python data/init_db.py
```

If the repository root is `compufest-1-` and this project lives in a subfolder:

```bash
cd compufest-1-/ai-sql-migration
uv run python data/init_db.py
```

This runs `init()`, which:

1. **Drops `localuc_db` if it already exists** (best-effort), recreates it, then runs `pipelines/src_sql_server/run.sql` to create tables and indexes.
2. Loads CSVs from `data/raw_data/` into `dbo.*` tables (see load order in `init_db.py`).
3. Writes logs under `ai-sql-migration/logs/` as `data_load_YYYYMMDD_HHMMSS.log` (a new log file is created when the CSV load phase starts).

**Warning:** Step 1 is destructive for the configured database name. Do not point `SQLEDGE_DATABASE` at a shared or production database.

### Manual steps

From **`ai-sql-migration`**, use subcommands (same `.env` as full init):

```bash
# Tables only: drop/recreate database + run DDL (no CSV load)
uv run python data/init_db.py create-tables

# Load CSVs only: expects tables already exist
uv run python data/init_db.py load-data
```

Optional overrides (otherwise values come from `.env`):

```bash
uv run python data/init_db.py init --host 127.0.0.1 --user sa --password '...'
uv run python data/init_db.py load-data --data-path raw_data
```

See `uv run python data/init_db.py --help` for all flags (`--sql-file`, `--port`, `--database`, etc.).

## Directory layout

```
data/
├── init_db.py                 # SQL Server / SQL Edge: create DB + tables + load CSVs (pyodbc)
├── init_db_databricks.py      # Databricks warehouse: UC DDL + bronze dim loads
├── init_db_databricks.ipynb   # Notebook wrapper for the Databricks pipeline
├── README.md
├── raw_data/               # dim_*.csv, fact_*.csv (table names match dbo tables)
└── pipelines/
    ├── src_sql_server/
    │   ├── run.sql         # Concatenated DDL (single script for init_db)
    │   ├── schemas/
    │   │   └── schema.sql
    │   ├── dimensions/     # Per-table DDL modules
    │   └── facts/
    └── src_databricks/
        ├── run.sql
        ├── schemas/
        ├── bronze/
        ├── silver/
        ├── gold/
        └── views/
```

Modular files under `dimensions/`, `facts/`, and `schemas/` are the source pieces; refresh `run.sql` when you change them if you rely on `init_db.py` (see the `SOURCE SECTION` comments inside `run.sql`).

## Troubleshooting

### "ODBC Driver 18 for SQL Server" not found

Install the driver:

- **macOS**: `brew install msodbcsql18` (optional: `mssql-tools18`)
- **Linux**: [Install the Microsoft ODBC driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server)
- **Windows**: [Download ODBC Driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

### Connection refused or login failed

Confirm SQL Server is running and listening on `SQLEDGE_HOST`:`SQLEDGE_PORT`, that TCP is enabled, and that firewall rules allow the client. This repository does not ship a root-level `docker-compose` file; use your own container or local instance and align `.env` with it.

### CSV files not found

CSV paths are `data/raw_data/<table>.csv` relative to `data/init_db.py`. From `ai-sql-migration`:

```bash
ls -la data/raw_data/
```

## Data model

See `pipelines/src_sql_server/run.sql` for the full DDL.

**Dimensions:** `dim_patient`, `dim_medication`, `dim_prescriber`, `dim_payer`, `dim_date`, `dim_care_team_member`

**Facts:** `fact_prescription`, `fact_adherence`, `fact_clinical_interaction`, `fact_shipment`, `fact_last_event`
