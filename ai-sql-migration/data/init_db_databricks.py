"""Databricks Unity Catalog pipeline: DDL from modular SQL + bronze dimension loads.

Uses ``databricks-sql-connector`` (SQL warehouse). Environment (from ``ai-sql-migration/.env``):

- ``DATABRICKS_HOST`` — workspace URL, e.g. ``https://adb-....azuredatabricks.net``
- ``DATABRICKS_TOKEN`` — personal access token or OAuth token
- ``DATABRICKS_WAREHOUSE_ID`` — SQL warehouse ID (UUID)
- ``DATABRICKS_MAX_ROWS_PER_TABLE`` (optional) — positive integer caps CSV rows loaded **per bronze dimension table** (dev/smoke tests). Omit or empty = load all rows.

The Unity Catalog ``pharmacy`` must exist (and your principal needs ``USE CATALOG`` + DDL on it).
Bronze fact tables are left empty by this loader: SQL Server ``raw_data/*.csv`` does not match
bronze fact schemas (different column model). Load facts separately (Spark / COPY INTO / ETL).

See also: ``data/pipelines/src_databricks/run.sql`` (concatenated reference).
"""

from __future__ import annotations

import argparse
import logging
import math
import os
import re
import sys
import traceback
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urlparse

import pandas as pd
from databricks import sql
from dotenv import load_dotenv

env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
# override=True: variables already set in the shell (sometimes empty) must not block .env
load_dotenv(env_path, override=True)


def _max_rows_from_env() -> int | None:
    """Parse ``DATABRICKS_MAX_ROWS_PER_TABLE``; ``None`` means no cap."""
    raw = os.environ.get("DATABRICKS_MAX_ROWS_PER_TABLE", "").strip()
    if not raw:
        return None
    try:
        n = int(raw)
        if n <= 0:
            return None
        return n
    except ValueError:
        logging.warning("Invalid DATABRICKS_MAX_ROWS_PER_TABLE=%r; ignoring cap", raw)
        return None


def _resolve_bronze_row_cap(max_rows_per_table: int | None) -> int | None:
    """``None`` → use env; ``<= 0`` → no cap (ignores env); ``> 0`` → that cap."""
    if max_rows_per_table is None:
        return _max_rows_from_env()
    if max_rows_per_table <= 0:
        return None
    return max_rows_per_table


# Same CSV order as SQL Server init (dimensions only are loaded here)
DIM_LOAD_ORDER = [
    "dim_patient",
    "dim_medication",
    "dim_prescriber",
    "dim_payer",
    "dim_date",
    "dim_care_team_member",
]

CSV_TO_BRONZE = {name: f"pharmacy.bronze.raw_{name}" for name in DIM_LOAD_ORDER}

# Schemas + bronze DDL only (run before loading CSVs into bronze).
PIPELINE_BRONZE_PHASE = [
    "pipelines/src_databricks/schemas/bronze.sql",
    "pipelines/src_databricks/schemas/silver.sql",
    "pipelines/src_databricks/schemas/gold.sql",
    "pipelines/src_databricks/bronze/raw_dim_date.sql",
    "pipelines/src_databricks/bronze/raw_dim_payer.sql",
    "pipelines/src_databricks/bronze/raw_dim_care_team_member.sql",
    "pipelines/src_databricks/bronze/raw_dim_patient.sql",
    "pipelines/src_databricks/bronze/raw_dim_medication.sql",
    "pipelines/src_databricks/bronze/raw_dim_prescriber.sql",
    "pipelines/src_databricks/bronze/raw_fact_prescription.sql",
    "pipelines/src_databricks/bronze/raw_fact_adherence.sql",
    "pipelines/src_databricks/bronze/raw_fact_clinical_interaction.sql",
    "pipelines/src_databricks/bronze/raw_fact_shipment.sql",
    "pipelines/src_databricks/bronze/raw_fact_last_event.sql",
]

# Silver / gold / views read from bronze — must run after bronze dimension loads.
PIPELINE_DOWNSTREAM_PHASE = [
    "pipelines/src_databricks/silver/dim_patient_cleansed.sql",
    "pipelines/src_databricks/silver/dim_medication_cleansed.sql",
    "pipelines/src_databricks/silver/dim_prescriber_cleansed.sql",
    "pipelines/src_databricks/silver/dim_payer_cleansed.sql",
    "pipelines/src_databricks/silver/dim_care_team_member_cleansed.sql",
    "pipelines/src_databricks/silver/dim_date_cleansed.sql",
    "pipelines/src_databricks/silver/fact_prescription_cleansed.sql",
    "pipelines/src_databricks/silver/fact_adherence_cleansed.sql",
    "pipelines/src_databricks/silver/fact_clinical_interaction_cleansed.sql",
    "pipelines/src_databricks/silver/fact_shipment_cleansed.sql",
    "pipelines/src_databricks/silver/fact_last_event_cleansed.sql",
    "pipelines/src_databricks/silver/_metadata_pipeline_runs.sql",
    "pipelines/src_databricks/silver/_metadata_quality_checks.sql",
    "pipelines/src_databricks/gold/dim_patient.sql",
    "pipelines/src_databricks/gold/dim_medication.sql",
    "pipelines/src_databricks/gold/dim_prescriber.sql",
    "pipelines/src_databricks/gold/dim_payer.sql",
    "pipelines/src_databricks/gold/dim_date.sql",
    "pipelines/src_databricks/gold/dim_care_team_member.sql",
    "pipelines/src_databricks/gold/fact_prescription.sql",
    "pipelines/src_databricks/gold/fact_adherence.sql",
    "pipelines/src_databricks/gold/fact_clinical_interaction.sql",
    "pipelines/src_databricks/gold/fact_shipment.sql",
    "pipelines/src_databricks/gold/fact_last_event.sql",
    "pipelines/src_databricks/views/v_patients_by_state.sql",
    "pipelines/src_databricks/views/v_prescription_metrics.sql",
    "pipelines/src_databricks/views/v_patient_adherence.sql",
    "pipelines/src_databricks/views/v_prescriber_performance.sql",
    "pipelines/src_databricks/views/v_shipment_analysis.sql",
    "pipelines/src_databricks/views/v_data_integrity_check.sql",
    "pipelines/src_databricks/views/v_data_statistics.sql",
]

PIPELINE_DDL_FILES = [*PIPELINE_BRONZE_PHASE, *PIPELINE_DOWNSTREAM_PHASE]

LAYER_COUNTS_SQL = "pipelines/src_databricks/schemas/layer_counts.sql"


def _setup_logging() -> str:
    log_dir = os.path.join(os.path.dirname(__file__), "..", "logs")
    os.makedirs(log_dir, exist_ok=True)
    log_filename = os.path.join(
        log_dir,
        f"databricks_pipeline_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log",
    )
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


def _server_hostname() -> str:
    raw = os.environ.get("DATABRICKS_HOST", "").strip().rstrip("/")
    if not raw:
        raise ValueError("DATABRICKS_HOST is not set.")
    if raw.startswith("http://") or raw.startswith("https://"):
        host = urlparse(raw).hostname
        if not host:
            raise ValueError(f"Could not parse hostname from DATABRICKS_HOST={raw!r}")
        return host
    return raw.replace("https://", "").replace("http://", "")


def _warehouse_id_is_uuid_shape(warehouse_id: str) -> bool:
    """True if value looks like a SQL warehouse UUID (32 hex, optional hyphens)."""
    clean = warehouse_id.replace("-", "").strip()
    return bool(re.fullmatch(r"[0-9a-fA-F]{32}", clean))


def _warn_if_suspicious_warehouse_id(warehouse_id: str) -> None:
    if _warehouse_id_is_uuid_shape(warehouse_id):
        return
    logging.warning(
        "DATABRICKS_WAREHOUSE_ID does not look like a full UUID (32 hex). "
        "Copy the warehouse ID from SQL Warehouses in the same workspace as DATABRICKS_HOST; "
        "truncated IDs often cause HTTP 400 on OpenSession. Current length (no hyphens): %s",
        len(warehouse_id.replace("-", "")),
    )


def get_connection():
    """Return a new Databricks SQL warehouse connection (context manager recommended)."""
    token = os.environ.get("DATABRICKS_TOKEN", "").strip()
    warehouse_id = os.environ.get("DATABRICKS_WAREHOUSE_ID", "").strip()
    if not token or not warehouse_id:
        raise ValueError(
            "DATABRICKS_TOKEN and DATABRICKS_WAREHOUSE_ID must be set in the environment or .env"
        )
    _warn_if_suspicious_warehouse_id(warehouse_id)
    http_path = f"/sql/1.0/warehouses/{warehouse_id}"
    return sql.connect(
        server_hostname=_server_hostname(),
        http_path=http_path,
        access_token=token,
    )


def _script_dir() -> Path:
    return Path(__file__).resolve().parent


def _read_sql_file(relative_to_data: str) -> str:
    path = _script_dir() / relative_to_data
    if not path.is_file():
        raise FileNotFoundError(f"SQL file not found: {path}")
    return path.read_text(encoding="utf-8").strip()


def _sql_batches(text: str) -> list[str]:
    """Split a .sql file into statements the SQL warehouse accepts one ``execute`` at a time.

    Databricks rejects ``CREATE ... AS SELECT ...; OPTIMIZE ...`` in a single batch; we split
    before any line that starts with ``OPTIMIZE``.
    """
    text = text.strip()
    if not text:
        return []
    parts = re.split(r"(?m)^(?=OPTIMIZE\s)", text)
    batches = [p.strip() for p in parts if p.strip()]
    return batches if batches else [text]


def execute_sql_file(conn, relative_to_data: str) -> None:
    """Execute a .sql file (one or more statements, e.g. CTAS then ``OPTIMIZE``)."""
    text = _read_sql_file(relative_to_data)
    if not text:
        return
    batches = _sql_batches(text)
    for i, stmt in enumerate(batches, 1):
        label = relative_to_data if len(batches) == 1 else f"{relative_to_data} [{i}/{len(batches)}]"
        logging.info("Executing %s", label)
        with conn.cursor() as cur:
            cur.execute(stmt)


def ensure_pharmacy_catalog(conn) -> None:
    """Create catalog ``pharmacy`` if missing (may require admin / managed location in your workspace)."""
    logging.info("Ensuring catalog pharmacy exists")
    try:
        with conn.cursor() as cur:
            cur.execute("CREATE CATALOG IF NOT EXISTS pharmacy")
    except Exception as e:
        logging.warning(
            "Could not auto-create catalog pharmacy (create it in UC UI if needed): %s",
            e,
        )


def run_ddl_pipeline(conn, files: list[str] | None = None) -> None:
    """Run bronze → silver → gold → views DDL in dependency order."""
    files = files if files is not None else PIPELINE_DDL_FILES
    for rel in files:
        execute_sql_file(conn, rel)
    logging.info("DDL pipeline finished (%s files)", len(files))


def run_layer_counts(conn) -> list[tuple]:
    """Return rows from ``layer_counts.sql`` (layer, table_count)."""
    text = _read_sql_file(LAYER_COUNTS_SQL)
    with conn.cursor() as cur:
        cur.execute(text)
        return cur.fetchall()


def _scalar_py(val):
    """Normalize numpy / pandas scalars for Python type checks."""
    if val is None:
        return None
    if hasattr(val, "item") and callable(val.item):
        try:
            return val.item()
        except Exception:
            return val
    return val


def _sql_literal(val, *, as_boolean: bool = False) -> str:
    val = _scalar_py(val)
    if val is None or (isinstance(val, float) and math.isnan(val)):
        return "NULL"
    if isinstance(val, pd.Timestamp):
        val = val.to_pydatetime()
    if as_boolean or isinstance(val, bool):
        if val in (True, 1) or val is True:
            return "TRUE"
        if val in (False, 0) or val is False:
            return "FALSE"
        return "TRUE" if bool(val) else "FALSE"
    if isinstance(val, (int,)) and not isinstance(val, bool):
        return str(int(val))
    if isinstance(val, float):
        return repr(val)
    if isinstance(val, datetime):
        return f"TIMESTAMP'{val.isoformat(sep=' ', timespec='seconds')}'"
    if isinstance(val, date):
        return f"DATE'{val.isoformat()}'"
    s = str(val).replace("'", "''")
    return f"'{s}'"


def _fetch_insert_columns(cursor, catalog: str, schema: str, table: str, df_cols: list[str]) -> list[str]:
    cursor.execute(
        f"""
        SELECT column_name
        FROM {catalog}.information_schema.columns
        WHERE table_catalog = '{catalog}'
          AND table_schema = '{schema}'
          AND table_name = '{table}'
        ORDER BY ordinal_position
        """
    )
    table_cols = [r[0] for r in cursor.fetchall() if not str(r[0]).startswith("_")]
    lower_map = {c.lower(): c for c in table_cols}
    ordered: list[str] = []
    for c in df_cols:
        key = c.lower()
        if key in lower_map:
            ordered.append(lower_map[key])
    return ordered


def _boolean_columns(cursor, catalog: str, schema: str, table: str) -> set[str]:
    cursor.execute(
        f"""
        SELECT column_name
        FROM {catalog}.information_schema.columns
        WHERE table_catalog = '{catalog}'
          AND table_schema = '{schema}'
          AND table_name = '{table}'
          AND data_type = 'BOOLEAN'
        """
    )
    return {r[0] for r in cursor.fetchall()}


def load_bronze_dimensions(
    conn,
    data_path: str = "raw_data",
    batch_size: int = 80,
    max_rows_per_table: int | None = None,
) -> dict[str, int]:
    """Truncate and load dimension CSVs into ``pharmacy.bronze.raw_*`` (ingest columns use defaults).

    Args:
        max_rows_per_table: If set, only the first N rows of each CSV are inserted (after read).
            ``None`` loads every row.
    """
    base = _script_dir() / data_path
    counts: dict[str, int] = {}

    with conn.cursor() as cursor:
        for dim in DIM_LOAD_ORDER:
            bronze_fqn = CSV_TO_BRONZE[dim]
            parts = bronze_fqn.replace("`", "").split(".")
            if len(parts) != 3:
                raise ValueError(f"Expected catalog.schema.table, got {bronze_fqn!r}")
            catalog, schema, table = parts
            csv_path = base / f"{dim}.csv"
            if not csv_path.is_file():
                raise FileNotFoundError(f"Missing CSV: {csv_path}")

            df = pd.read_csv(csv_path)
            if df.empty:
                raise ValueError(f"Empty CSV for {dim}")

            n_csv = len(df)
            if max_rows_per_table is not None:
                df = df.head(max_rows_per_table).copy()
                logging.info(
                    "Row cap %s applied to %s (%s rows in CSV → %s to load)",
                    max_rows_per_table,
                    dim,
                    n_csv,
                    len(df),
                )

            insert_cols = _fetch_insert_columns(
                cursor, catalog, schema, table, list(df.columns)
            )
            if not insert_cols:
                raise RuntimeError(f"No overlapping columns between {csv_path} and {bronze_fqn}")

            bool_cols = _boolean_columns(cursor, catalog, schema, table)

            logging.info("Truncating %s", bronze_fqn)
            cursor.execute(f"TRUNCATE TABLE {bronze_fqn}")

            col_sql = ", ".join(insert_cols)
            total = 0
            for start in range(0, len(df), batch_size):
                chunk = df.iloc[start : start + batch_size]
                value_rows = []
                for _, row in chunk.iterrows():
                    cells = []
                    for c in insert_cols:
                        if c in row.index:
                            raw = row[c]
                        elif c.lower() in (x.lower() for x in row.index):
                            idx = [x for x in row.index if x.lower() == c.lower()][0]
                            raw = row[idx]
                        else:
                            raw = None
                        if c in bool_cols:
                            cells.append(_sql_literal(raw, as_boolean=True))
                        else:
                            cells.append(_sql_literal(raw, as_boolean=False))
                    value_rows.append("(" + ", ".join(cells) + ")")
                stmt = f"INSERT INTO {bronze_fqn} ({col_sql}) VALUES {', '.join(value_rows)}"
                cursor.execute(stmt)
                total += len(chunk)

            counts[dim] = total
            logging.info("Loaded %s rows into %s", total, bronze_fqn)

    return counts


def init(
    data_path: str = "raw_data",
    *,
    skip_ensure_catalog: bool = False,
    max_rows_per_table: int | None = None,
) -> None:
    """Bronze DDL → load dimension CSVs into bronze → silver/gold/views DDL + layer counts.

    Args:
        max_rows_per_table: ``None`` → read cap from ``DATABRICKS_MAX_ROWS_PER_TABLE`` if set;
            ``<= 0`` → no cap; ``> 0`` → insert at most that many rows per dimension CSV.
    """
    log_path = _setup_logging()
    logging.info("Databricks pipeline log: %s", log_path)

    row_cap = _resolve_bronze_row_cap(max_rows_per_table)
    if row_cap is not None:
        logging.info("Bronze dimension load capped at %s rows per table", row_cap)

    with get_connection() as conn:
        if not skip_ensure_catalog:
            ensure_pharmacy_catalog(conn)
        run_ddl_pipeline(conn, PIPELINE_BRONZE_PHASE)
        logging.info("Loading bronze dimensions from %s", data_path)
        load_bronze_dimensions(conn, data_path=data_path, max_rows_per_table=row_cap)
        run_ddl_pipeline(conn, PIPELINE_DOWNSTREAM_PHASE)
        try:
            rows = run_layer_counts(conn)
            logging.info("Layer table counts: %s", rows)
        except Exception as e:
            logging.warning("layer_counts query failed: %s", e)


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Databricks UC pharmacy pipeline (DDL + bronze dimensions)."
    )
    p.add_argument(
        "command",
        nargs="?",
        default="init",
        choices=("init", "ddl-only", "load-dims", "layer-counts"),
        help="init: DDL + load dimensions; ddl-only; load-dims; layer-counts",
    )
    p.add_argument(
        "--data-path",
        default="raw_data",
        help="CSV folder relative to data/ (init and load-dims)",
    )
    p.add_argument(
        "--skip-ensure-catalog",
        action="store_true",
        help="Do not run CREATE CATALOG IF NOT EXISTS pharmacy",
    )
    p.add_argument(
        "--max-rows",
        type=int,
        default=None,
        metavar="N",
        help=(
            "Max CSV rows to load per bronze dimension table. "
            "Omit to use DATABRICKS_MAX_ROWS_PER_TABLE from .env; "
            "use 0 to disable cap even if env is set."
        ),
    )
    return p.parse_args()


if __name__ == "__main__":
    args = _parse_args()
    try:
        if args.command == "init":
            init(
                data_path=args.data_path,
                skip_ensure_catalog=args.skip_ensure_catalog,
                max_rows_per_table=args.max_rows,
            )
            print("\nDatabricks pipeline completed.")
        elif args.command == "ddl-only":
            _setup_logging()
            with get_connection() as conn:
                if not args.skip_ensure_catalog:
                    ensure_pharmacy_catalog(conn)
                run_ddl_pipeline(conn)
            print("\nDDL completed.")
        elif args.command == "load-dims":
            _setup_logging()
            row_cap = _resolve_bronze_row_cap(args.max_rows)
            if row_cap is not None:
                logging.info("Bronze dimension load capped at %s rows per table", row_cap)
            with get_connection() as conn:
                load_bronze_dimensions(
                    conn, data_path=args.data_path, max_rows_per_table=row_cap
                )
            print("\nBronze dimensions loaded.")
        else:
            _setup_logging()
            with get_connection() as conn:
                rows = run_layer_counts(conn)
                for r in rows:
                    print(r)
    except Exception:
        logging.error(traceback.format_exc())
        sys.exit(1)
