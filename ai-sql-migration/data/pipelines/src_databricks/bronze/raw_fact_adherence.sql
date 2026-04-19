-- Run order: 17 — Bronze adherence measurement fact
-- Lineage: sk_prescription_id -> raw_fact_prescription; patient/medication dimensions
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_adherence (
    sk_adherence_id BIGINT COMMENT 'Surrogate key for adherence row',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_medication_id BIGINT COMMENT 'FK to raw_dim_medication',
    measurement_period_start_date DATE COMMENT 'Start of measurement window',
    measurement_period_end_date DATE COMMENT 'End of measurement window',
    days_supplied INT COMMENT 'Days supplied in window',
    days_covered INT COMMENT 'Days covered by medication',
    gaps_count INT COMMENT 'Number of gaps in therapy',
    pdc_ratio DECIMAL(5, 2) COMMENT 'Proportion of days covered (PDC)',
    mpf_ratio DECIMAL(5, 2) COMMENT 'Medication possession ratio or related metric',
    refills_count INT COMMENT 'Refills in measurement period',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Therapy adherence metrics at bronze; references prescription and dimension keys for lineage.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
