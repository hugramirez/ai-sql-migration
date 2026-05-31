-- Run order: Bronze adherence fact (aligned to dbo.fact_adherence / raw_data CSV)
CREATE OR REPLACE TABLE localuc.bronze.raw_fact_adherence (
    sk_adherence_id BIGINT COMMENT 'Surrogate key for adherence row',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_measurement_date_id INT COMMENT 'FK to raw_dim_date (measurement date)',
    measurement_date DATE COMMENT 'As-of measurement date',
    measurement_period STRING COMMENT 'Label for evaluation window (e.g. 180-day)',
    pdc_proportion_days_covered DECIMAL(5, 2) COMMENT 'Proportion of days covered (PDC)',
    mpf_medication_possession_ratio DECIMAL(5, 2) COMMENT 'Medication possession ratio',
    gaps_in_therapy_days INT COMMENT 'Gap days in therapy',
    missed_refills_count INT COMMENT 'Missed refills count',
    on_time_refills_count INT COMMENT 'On-time refills count',
    patient_reported_adherence STRING COMMENT 'Patient-reported adherence category',
    barriers_to_adherence STRING COMMENT 'Barriers text',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Adherence metrics at bronze; matches dbo.fact_adherence for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
