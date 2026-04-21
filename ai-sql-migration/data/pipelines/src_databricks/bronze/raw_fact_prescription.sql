-- Run order: 16 — Bronze prescription fact (grain: prescription line or Rx header per source)
-- Lineage: joins raw_dim_patient, raw_dim_medication, raw_dim_prescriber, raw_dim_payer, raw_dim_date (written/filled)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_prescription (
    sk_prescription_id BIGINT COMMENT 'Surrogate key for prescription fact',
    prescription_external_id STRING COMMENT 'Natural or business prescription identifier',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_medication_id BIGINT COMMENT 'FK to raw_dim_medication',
    sk_prescriber_id BIGINT COMMENT 'FK to raw_dim_prescriber',
    sk_payer_id BIGINT COMMENT 'FK to raw_dim_payer',
    sk_written_date_id INT COMMENT 'FK to raw_dim_date (written date)',
    sk_filled_date_id INT COMMENT 'FK to raw_dim_date (fill date)',
    written_date DATE COMMENT 'Date prescription was written',
    filled_date DATE COMMENT 'Date prescription was filled',
    quantity_prescribed DECIMAL(10, 2) COMMENT 'Quantity prescribed',
    days_supply INT COMMENT 'Days supply',
    refills INT COMMENT 'Refills authorized or remaining',
    copay DECIMAL(10, 2) COMMENT 'Patient copay amount',
    insurance_paid DECIMAL(10, 2) COMMENT 'Insurance paid amount',
    total_cost DECIMAL(10, 2) COMMENT 'Total cost of fill or claim',
    is_filled BOOLEAN COMMENT 'Filled flag',
    is_rejected BOOLEAN COMMENT 'Rejection flag',
    rejection_reason STRING COMMENT 'Rejection reason text',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Prescription bridge fact at bronze linking patient, drug, prescriber, payer, and date role keys for UC lineage.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
