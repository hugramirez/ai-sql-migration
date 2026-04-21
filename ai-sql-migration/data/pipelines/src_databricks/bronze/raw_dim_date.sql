-- Run order: Bronze conformed date dimension (no CDF required for static calendar)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_date (
    sk_date_id INT COMMENT 'Surrogate key for calendar date',
    full_date DATE COMMENT 'Calendar date',
    day_of_week INT COMMENT 'Day of week (1–7 per source convention)',
    day_name STRING COMMENT 'Day name (e.g. Monday)',
    day_of_month INT COMMENT 'Day of month',
    day_of_year INT COMMENT 'Day of year',
    week_of_year INT COMMENT 'ISO or calendar week of year',
    month_num INT COMMENT 'Month number 1–12',
    month_name STRING COMMENT 'Month name',
    quarter INT COMMENT 'Calendar quarter 1–4',
    year INT COMMENT 'Calendar year',
    is_weekend BOOLEAN COMMENT 'True if Saturday or Sunday',
    is_holiday BOOLEAN COMMENT 'True if holiday flag set in source',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Calendar date dimension at bronze; keys link facts to written, filled, ship, and interaction dates.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);
