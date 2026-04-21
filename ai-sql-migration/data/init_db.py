"""Database initialization: create tables and load CSV data."""

from __future__ import annotations

import logging
import os
import sys
import traceback
from datetime import datetime
from pathlib import Path

import pandas as pd
import pyodbc
from dotenv import load_dotenv

# Load .env from parent directory
env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(env_path)

# Table loading order (dimensions first, then facts)
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
    "fact_last_event",
]


def _get_connection(
    host: str = "",
    port: int = 0,
    database: str = "",
    user: str = "",
    password: str = "",
) -> pyodbc.Connection:
    """Create a connection to SQL Server.
    
    If parameters are not provided, reads from .env:
    - SQLEDGE_HOST (default: localhost)
    - SQLEDGE_PORT (default: 1433)
    - SQLEDGE_DATABASE (default: pharmacy_db)
    - SQLEDGE_USER
    - SQLEDGE_PASSWORD
    """
    # Read from .env if parameters not provided
    host = host or os.environ.get("SQLEDGE_HOST", "localhost")
    port = port or int(os.environ.get("SQLEDGE_PORT", "1433"))
    database = database or os.environ.get("SQLEDGE_DATABASE", "pharmacy_db")
    user = user or os.environ.get("SQLEDGE_USER", "")
    password = password or os.environ.get("SQLEDGE_PASSWORD", "")
    
    if not user or not password:
        raise ValueError(
            "SQLEDGE_USER and SQLEDGE_PASSWORD must be set in .env or provided as arguments"
        )
    
    driver = "ODBC Driver 18 for SQL Server"
    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={host},{port};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={password};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


def _setup_logging() -> str:
    """Configure logging and return absolute path to the log file."""
    log_dir = os.path.join(os.path.dirname(__file__), "..", "logs")
    os.makedirs(log_dir, exist_ok=True)
    log_filename = os.path.join(
        log_dir, f"data_load_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    )

    # Clear existing handlers
    for handler in logging.getLogger().handlers[:]:
        logging.getLogger().removeHandler(handler)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(log_filename),
            logging.StreamHandler(),
        ],
    )
    return log_filename


def _validate_file_exists(file_path: str) -> None:
    """Check if CSV file exists."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Data file not found: {file_path}")


def _validate_not_empty(df: pd.DataFrame, table_name: str) -> None:
    """Check if dataframe is empty."""
    if df.empty:
        raise ValueError(f"Data for {table_name} is empty")


def _validate_fact_last_event_grain(df: pd.DataFrame) -> None:
    """Enforce one row per prescription (matches dbo.fact_last_event UNIQUE grain)."""
    if "sk_prescription_id" not in df.columns:
        return
    dup_mask = df.duplicated(subset=["sk_prescription_id"], keep=False)
    if dup_mask.any():
        n = int(dup_mask.sum())
        raise ValueError(
            f"fact_last_event.csv must have exactly one row per sk_prescription_id; "
            f"found {n} rows in duplicate groups"
        )


def _validate_columns(
    conn: pyodbc.Connection, table_name: str, df: pd.DataFrame
) -> None:
    """Validate that CSV columns exist in database table.
    
    Note: Allows CSV to have fewer columns than table (e.g., columns with defaults).
    """
    cursor = conn.cursor()

    cursor.execute(
        f"""
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '{table_name.split('.')[-1]}'
        """
    )

    db_columns = {row[0].lower() for row in cursor.fetchall()}
    csv_columns = {col.lower() for col in df.columns}

    # Only validate that CSV columns exist in table, not vice versa
    invalid = csv_columns - db_columns

    if invalid:
        raise ValueError(
            f"Table {table_name} CSV has unknown columns: {invalid}"
        )


def _clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Clean dataframe: handle nulls and strip whitespace."""
    df = df.where(pd.notnull(df), None)

    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].str.strip()

    return df


def _has_identity_column(conn: pyodbc.Connection, table_name: str) -> bool:
    """Check if table has an identity column."""
    cursor = conn.cursor()
    table_short = table_name.split('.')[-1]
    cursor.execute(f"""
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '{table_short}'
        AND COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1
    """)
    return cursor.fetchone()[0] > 0


def _load_table(
    conn: pyodbc.Connection,
    table_name: str,
    file_path: str,
) -> int:
    """Load a single table from CSV file.

    Returns:
        Number of rows loaded
    """
    logging.info(f"Loading {table_name} from {file_path}")

    _validate_file_exists(file_path)
    df = pd.read_csv(file_path)

    _validate_not_empty(df, table_name)
    if table_name.lower().endswith("fact_last_event"):
        _validate_fact_last_event_grain(df)
    _validate_columns(conn, table_name, df)

    df = _clean_dataframe(df)

    columns = ", ".join(df.columns)
    placeholders = ", ".join(["?"] * len(df.columns))

    query = f"""
        INSERT INTO {table_name} ({columns})
        VALUES ({placeholders})
    """

    cursor = conn.cursor()
    cursor.fast_executemany = True
    has_identity = _has_identity_column(conn, table_name)

    try:
        # Enable IDENTITY_INSERT only if table has identity column
        if has_identity:
            cursor.execute(f"SET IDENTITY_INSERT {table_name} ON")

        cursor.executemany(query, df.values.tolist())
        conn.commit()

        rows_loaded = len(df)
        logging.info(f"✓ {table_name} loaded successfully ({rows_loaded} rows)")
        return rows_loaded

    except Exception as e:
        conn.rollback()
        logging.error(f"✗ Error loading {table_name}: {str(e)}")
        raise
    finally:
        # Always disable IDENTITY_INSERT if it was enabled
        if has_identity:
            try:
                cursor.execute(f"SET IDENTITY_INSERT {table_name} OFF")
                conn.commit()
            except Exception:
                pass


def create_tables(
    host: str = "",
    port: int = 0,
    database: str = "",
    user: str = "",
    password: str = "",
    sql_file: str = "pipelines/src_sql_server/run.sql",
) -> None:
    """Execute SQL DDL script to create database schema and tables.

    Args:
        host: SQL Server host
        port: SQL Server port
        database: Database name
        user: SQL Server user
        password: SQL Server password
        sql_file: Path to SQL script file (relative to data/ directory)
    """
    # Resolve path relative to this script's directory
    script_dir = os.path.dirname(__file__)
    full_sql_path = os.path.join(script_dir, sql_file)

    logging.info(f"Creating database schema from {sql_file}")

    if not os.path.exists(full_sql_path):
        raise FileNotFoundError(f"SQL script not found: {full_sql_path}")

    database = database or os.environ.get("SQLEDGE_DATABASE", "pharmacy_db")

    with open(full_sql_path, "r") as f:
        sql_script = f.read()

    try:
        # Phase 0: Drop existing database if it exists (skip if can't acquire lock)
        logging.info("Phase 0: Attempting to drop existing database if it exists...")
        try:
            conn = _get_connection(host, port, "master", user, password)
            conn.autocommit = True
            cursor = conn.cursor()

            drop_db_script = f"""
            IF EXISTS (SELECT * FROM sys.databases WHERE name = '{database}')
            BEGIN
                ALTER DATABASE {database} SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                DROP DATABASE {database};
            END
            """
            cursor.execute(drop_db_script)
            cursor.close()
            conn.close()
            logging.info(f"✓ Database '{database}' dropped if it existed")
        except Exception as e:
            logging.warning(f"Could not drop database (will continue anyway): {str(e)}")

        # Phase 1: Execute CREATE DATABASE in master context
        logging.info("Phase 1: Ensuring database exists...")
        conn = _get_connection(host, port, "master", user, password)
        conn.autocommit = True
        cursor = conn.cursor()

        # Only execute up to and including CREATE DATABASE
        create_db_script = f"""
        IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '{database}')
        BEGIN
            CREATE DATABASE {database}
                COLLATE SQL_Latin1_General_CP1_CI_AS;
        END
        """
        cursor.execute(create_db_script)
        cursor.close()
        conn.close()
        logging.info(f"✓ Database '{database}' ensured")

        # Phase 2: Connect to target database and create schema/tables
        logging.info("Phase 2: Creating tables in target database...")
        conn = _get_connection(host, port, database, user, password)
        conn.autocommit = False  # Use transactions for DDL
        cursor = conn.cursor()

        # Execute script split by GO batches (SQL Server batch separator)
        # Skip any "USE master;" or "CREATE DATABASE" statements
        batches = sql_script.split("GO")
        batch_count = 0

        for i, batch in enumerate(batches, 1):
            batch = batch.strip()
            # Skip empty batches, USE statements, and CREATE DATABASE
            if not batch or batch.startswith("USE master") or "CREATE DATABASE" in batch:
                continue

            batch_count += 1
            logging.info(f"Executing batch {batch_count}")
            try:
                cursor.execute(batch)
                conn.commit()
            except Exception as e:
                logging.warning(f"Error in batch {batch_count}: {str(e)}")
                conn.rollback()

        conn.close()
        logging.info("✓ Schema creation completed successfully")

    except Exception as e:
        logging.error(f"✗ Failed to create schema: {str(e)}")
        raise


def load_data(
    host: str = "",
    port: int = 0,
    database: str = "",
    user: str = "",
    password: str = "",
    data_path: str = "raw_data",
) -> dict[str, int]:
    """Load all CSV data files into database tables.

    Args:
        host: SQL Server host
        port: SQL Server port
        database: Database name
        user: SQL Server user
        password: SQL Server password
        data_path: Base path to CSV files (default: raw_data - relative to data/ directory)

    Returns:
        Dictionary mapping table names to rows loaded
    """
    log_filename = _setup_logging()
    logging.info(f"Starting CSV data load (log: {log_filename})")

    try:
        conn = _get_connection(host, port, database, user, password)
    except Exception as e:
        logging.error(f"✗ Failed to connect to SQL Server: {str(e)}")
        raise

    results = {}
    failed_tables = []

    # Resolve data_path relative to this script's directory
    script_dir = os.path.dirname(__file__)
    full_data_path = os.path.join(script_dir, data_path)

    # Disable all foreign key constraints for data loading
    cursor = conn.cursor()
    try:
        cursor.execute("EXEC sp_MSForEachTable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'")
        conn.commit()
        logging.info("Foreign key constraints disabled for data loading")
    except Exception as e:
        logging.warning(f"Failed to disable foreign key constraints: {str(e)}")

    # Clear existing data (delete in reverse order to respect foreign keys)
    for table in reversed(LOAD_ORDER):
        try:
            cursor.execute(f"DELETE FROM dbo.{table}")
            conn.commit()
        except Exception as e:
            logging.warning(f"Failed to clear dbo.{table}: {str(e)}")

    for table in LOAD_ORDER:
        file_path = os.path.join(full_data_path, f"{table}.csv")

        try:
            rows_loaded = _load_table(conn, f"dbo.{table}", file_path)
            results[table] = rows_loaded

        except Exception as e:
            failed_tables.append(table)
            logging.error(f"Failed table: {table}")
            logging.error(traceback.format_exc())

    # Re-enable all foreign key constraints after data loading
    try:
        cursor.execute("EXEC sp_MSForEachTable 'ALTER TABLE ? CHECK CONSTRAINT ALL'")
        conn.commit()
        logging.info("Foreign key constraints re-enabled")
    except Exception as e:
        logging.warning(f"Failed to re-enable foreign key constraints: {str(e)}")

    conn.close()

    # Summary
    logging.info(f"\n{'='*60}")
    logging.info(
        f"Data load summary: {len(results)} succeeded, {len(failed_tables)} failed"
    )
    if failed_tables:
        logging.error(f"Failed tables: {', '.join(failed_tables)}")
    logging.info(f"{'='*60}\n")

    if failed_tables:
        raise RuntimeError(
            f"Failed to load {len(failed_tables)} tables: {failed_tables}"
        )

    return results


def init(
    host: str = "",
    port: int = 0,
    database: str = "",
    user: str = "",
    password: str = "",
    sql_file: str = "pipelines/src_sql_server/run.sql",
    data_path: str = "raw_data",
) -> None:
    """Initialize database: create tables and load data.
    
    Args:
        host: SQL Server host
        port: SQL Server port
        database: Database name
        user: SQL Server user
        password: SQL Server password
        sql_file: Path to SQL DDL script
        data_path: Path to CSV data directory (default: raw_data - relative to data/ directory)
    """
    log_filename = _setup_logging()
    logging.info(f"Starting database initialization (log: {log_filename})")

    try:
        # Step 1: Create schema and tables
        logging.info("\n[Step 1/2] Creating database schema...")
        create_tables(host, port, database, user, password, sql_file)

        # Step 2: Load CSV data
        logging.info("[Step 2/2] Loading CSV data...")
        results = load_data(host, port, database, user, password, data_path)

    except Exception as e:
        logging.error(f"\n✗ Initialization failed: {str(e)}")
        raise


if __name__ == "__main__":
    host = os.environ.get("SQLEDGE_HOST", "localhost")
    port = int(os.environ.get("SQLEDGE_PORT", "1433"))
    database = os.environ.get("SQLEDGE_DATABASE", "pharmacy_db")
    user = os.environ.get("SQLEDGE_USER", "")
    password = os.environ.get("SQLEDGE_PASSWORD", "")

    if not user or not password:
        print("SQLEDGE_USER and SQLEDGE_PASSWORD must be set in .env")
        sys.exit(1)

    try:
        init(host, port, database, user, password)
        print("\nDatabase initialization successful!")
    except Exception as e:
        sys.exit(1)
