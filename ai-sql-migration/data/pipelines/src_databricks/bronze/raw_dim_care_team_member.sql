-- Run order: 12 — Bronze care team member dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_care_team_member (
    sk_care_team_member_id BIGINT COMMENT 'Surrogate key for care team member',
    employee_id STRING COMMENT 'Internal employee identifier',
    first_name STRING COMMENT 'First name',
    last_name STRING COMMENT 'Last name',
    role STRING COMMENT 'Job role or title',
    disease_specialty STRING COMMENT 'Disease or therapeutic specialty',
    hire_date DATE COMMENT 'Hire date',
    is_active BOOLEAN COMMENT 'Active employment or roster flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Internal care team roster at bronze; referenced by raw_fact_clinical_interaction.sk_care_team_member_id.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
