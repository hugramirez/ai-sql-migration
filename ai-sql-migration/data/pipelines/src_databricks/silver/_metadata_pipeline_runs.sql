-- Run order: 32 — Operational metadata for pipeline runs (optional lineage sidecar)
CREATE OR REPLACE TABLE pharmacy.silver._metadata_pipeline_runs (
    run_id STRING NOT NULL COMMENT 'Unique run identifier',
    pipeline_name STRING NOT NULL COMMENT 'Pipeline or job name',
    step_name STRING COMMENT 'Step or task name',
    source_layer STRING COMMENT 'Source layer (bronze, silver, gold)',
    target_layer STRING COMMENT 'Target layer',
    start_time TIMESTAMP COMMENT 'Run start time',
    end_time TIMESTAMP COMMENT 'Run end time',
    rows_processed BIGINT COMMENT 'Rows successfully processed',
    rows_failed BIGINT COMMENT 'Rows failed validation',
    status STRING COMMENT 'SUCCESS, FAILED, PARTIAL',
    error_message STRING COMMENT 'Error detail if failed',
    created_at TIMESTAMP COMMENT 'Row insert time' DEFAULT current_timestamp()
) USING DELTA COMMENT 'Pipeline execution audit; populate from orchestration for observability.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);
