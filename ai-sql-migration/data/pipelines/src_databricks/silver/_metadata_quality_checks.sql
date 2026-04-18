-- Run order: 33 — Data quality check results
CREATE OR REPLACE TABLE pharmacy.silver._metadata_quality_checks (
    table_name STRING NOT NULL COMMENT 'Table or dataset evaluated',
    check_type STRING COMMENT 'Rule or check category',
    check_description STRING COMMENT 'Human-readable description',
    passed BOOLEAN COMMENT 'Whether the check passed',
    rows_checked BIGINT COMMENT 'Population evaluated',
    rows_failed BIGINT COMMENT 'Rows failing the rule',
    check_timestamp TIMESTAMP COMMENT 'When the check ran' DEFAULT current_timestamp(),
    details STRING COMMENT 'JSON or text details'
) USING DELTA COMMENT 'Stores outcomes of Great Expectations / DQ jobs for governance dashboards.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported'
);
