# Data Directory

This directory contains database initialization tools and SQL pipelines.

## Database Initialization

Before querying data, you must create the database schema and load sample data.

### Quick start

Set SQL Server credentials in `ai-sql-migration/.env` (read by `data/init_db.py`):

```env
SQLEDGE_HOST=localhost
SQLEDGE_PORT=1433
SQLEDGE_DATABASE=pharmacy_db
SQLEDGE_USER=sa
SQLEDGE_PASSWORD=<your_password>
```

Omit `SQLEDGE_HOST` / `SQLEDGE_PORT` / `SQLEDGE_DATABASE` to use the defaults above. `create_tables`, `load_data`, and `init` also pick up these values when you pass empty host/port/database (for example only `user` and `password` in a one-liner).

Then run the initialization script from the project root:

```bash
cd ..  
uv run python data/init_db.py
```

This will:
1. Execute `pipelines/src_sql_server/run.sql` to create all tables
2. Load CSV data from `data/raw_data/` into the created tables
3. Generate a log file `logs/data_load_YYYYMMDD_HHMMSS.log` (under `ai-sql-migration/logs/`)

### Manual steps

If you prefer to run steps separately:

```bash
# Step 1: Create tables only
uv run python -c "from data.init_db import create_tables; create_tables(user='sa', password='...')"

# Step 2: Load data only
uv run python -c "from data.init_db import load_data; load_data(user='sa', password='...')"
```

## Directory structure

```
data/
├── init_db.py                 # Database initialization script
├── README.md                  # This file
└── pipelines/
    ├── src_sql_server/
    │   ├── run.sql            # Complete schema + tables DDL
    │   ├── seed_data.sql      # Optional seed data
    │   ├── dimensions/        # Individual dimension table DDL
    │   └── facts/             # Individual fact table DDL
    ├── src_databricks/
    │   ├── run.sql            # Databricks schema + tables
    │   ├── schemas/           # Schema definitions
    │   ├── bronze/            # Bronze layer tables
    │   ├── silver/            # Silver layer tables
    │   ├── gold/              # Gold layer tables
    │   └── views/             # Analytical views
    └── ...
```

## Troubleshooting

### "ODBC Driver 18 for SQL Server" not found
Install the driver:
- **macOS**: `brew install msodbcsql18 mssql-tools18`
- **Linux**: Follow [MS docs](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server)
- **Windows**: Download from [Microsoft](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

### Connection refused
Ensure SQL Server is running:
```bash
docker-compose up -d  # if using Docker
```

### CSV files not found
Ensure `data/raw_data/` contains the table CSV files (same names as `dbo` tables):
```bash
ls -la data/raw_data/
```

## Data schema

See `pipelines/src_sql_server/run.sql` for the complete data model.

Key tables:
- **Dimensions**: `dim_patient`, `dim_medication`, `dim_prescriber`, `dim_payer`, `dim_date`, `dim_care_team_member`
- **Facts**: `fact_prescription`, `fact_adherence`, `fact_clinical_interaction`, `fact_shipment`, `fact_last_event`
