-- Run order: Bronze payer (plan) dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_payer (
    sk_payer_id BIGINT COMMENT 'Surrogate key for payer',
    payer_external_id STRING COMMENT 'External payer or plan identifier',
    payer_name STRING COMMENT 'Payer or plan display name',
    payer_type STRING COMMENT 'Commercial, Medicare, Medicaid, etc.',
    bin_number STRING COMMENT 'Bank Identification Number (BIN)',
    pcn_number STRING COMMENT 'Processor Control Number (PCN)',
    group_number STRING COMMENT 'Group or plan group number',
    contact_phone STRING COMMENT 'Payer contact phone',
    specialty_pharmacy_network BOOLEAN COMMENT 'Participates in specialty pharmacy network',
    is_active BOOLEAN COMMENT 'Payer record active flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Insurance payer and benefit configuration at bronze; referenced by raw_fact_prescription.sk_payer_id.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);
