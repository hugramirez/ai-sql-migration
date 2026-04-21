import pandas as pd
import pyodbc
import logging
import traceback
import os
from datetime import datetime

# =========================
# CONFIG
# =========================

DB_CONFIG = {
    "driver": "ODBC Driver 17 for SQL Server",
    "server": "localhost,1433",
    "database": "pharmacy_db",
    "user": "sa",
    "password": "TuPassword123!"
}

DATA_PATH = "../.data"

LOAD_ORDER = [
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
    "fact_last_event"
]

FILE_MAP = {
    table: os.path.join(DATA_PATH, f"{table}.csv")
    for table in LOAD_ORDER
}

# =========================
# LOGGING
# =========================

def setup_logging():
    log_filename = f"etl_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(log_filename),
            logging.StreamHandler()
        ]
    )

# =========================
# DB CONNECTION
# =========================

def get_connection():
    conn_str = (
        f"DRIVER={{{DB_CONFIG['driver']}}};"
        f"SERVER={DB_CONFIG['server']};"
        f"DATABASE={DB_CONFIG['database']};"
        f"UID={DB_CONFIG['user']};"
        f"PWD={DB_CONFIG['password']}"
    )
    return pyodbc.connect(conn_str)

# =========================
# VALIDATIONS
# =========================

def validate_file_exists(file_path):
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

def validate_not_empty(df, table_name):
    if df.empty:
        raise ValueError(f"{table_name} is empty")

def validate_columns(conn, table_name, df):
    cursor = conn.cursor()

    cursor.execute(f"""
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '{table_name.split('.')[-1]}'
    """)

    db_columns = {row[0].lower() for row in cursor.fetchall()}
    csv_columns = {col.lower() for col in df.columns}

    missing = db_columns - csv_columns
    extra = csv_columns - db_columns

    if missing:
        raise ValueError(f"{table_name} missing columns: {missing}")

    if extra:
        logging.warning(f"{table_name} has extra columns (ignored): {extra}")

# =========================
# CLEANING
# =========================

def clean_dataframe(df):
    # Replace NaN with None for SQL compatibility
    df = df.where(pd.notnull(df), None)

    # Strip strings
    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].str.strip()

    return df

# =========================
# LOAD FUNCTION
# =========================

def load_table(conn, table_name, file_path):
    logging.info(f"📥 Loading {table_name} from {file_path}")

    validate_file_exists(file_path)

    df = pd.read_csv(file_path)

    validate_not_empty(df, table_name)
    validate_columns(conn, table_name, df)

    df = clean_dataframe(df)

    columns = ", ".join(df.columns)
    placeholders = ", ".join(["?"] * len(df.columns))

    query = f"""
        INSERT INTO {table_name} ({columns})
        VALUES ({placeholders})
    """

    cursor = conn.cursor()
    cursor.fast_executemany = True

    try:
        cursor.executemany(query, df.values.tolist())
        conn.commit()
        logging.info(f"✅ {table_name} loaded successfully ({len(df)} rows)")

    except Exception as e:
        conn.rollback()
        logging.error(f"❌ Error loading {table_name}: {str(e)}")
        raise

# =========================
# MAIN PIPELINE
# =========================

def run_pipeline():
    setup_logging()
    logging.info("🚀 Starting ETL pipeline")

    conn = get_connection()

    success_tables = []
    failed_tables = []

    for table in LOAD_ORDER:
        try:
            load_table(conn, f"dbo.{table}", FILE_MAP[table])
            success_tables.append(table)
        except Exception as e:
            failed_tables.append(table)
            logging.error(f"💥 Failed table: {table}")
            logging.error(traceback.format_exc())

    conn.close()

    # =========================
    # FINAL REPORT
    # =========================
    logging.info("====================================")
    logging.info("📊 ETL SUMMARY")
    logging.info(f"✅ Success: {len(success_tables)} tables")
    logging.info(f"❌ Failed: {len(failed_tables)} tables")

    if failed_tables:
        logging.info(f"Failed tables: {failed_tables}")

    logging.info("====================================")

# =========================
# RUN
# =========================

if __name__ == "__main__":
    run_pipeline()