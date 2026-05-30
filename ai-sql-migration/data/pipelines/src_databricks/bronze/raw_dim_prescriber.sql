-- Run order: Bronze prescriber dimension
CREATE OR REPLACE TABLE localuc.bronze.raw_dim_prescriber (
    sk_prescriber_id BIGINT COMMENT 'Surrogate key for prescriber (internal unique identifier)',
    npi_number STRING COMMENT 'National Provider Identifier (NPI)',
    first_name STRING COMMENT 'Prescriber first name',
    last_name STRING COMMENT 'Prescriber last name',
    specialty STRING COMMENT 'Primary medical specialty',
    sub_specialty STRING COMMENT 'Sub-specialty or secondary specialty',
    practice_name STRING COMMENT 'Practice or organization name',
    address_line1 STRING COMMENT 'Primary practice address line',
    city STRING COMMENT 'City of practice',
    state STRING COMMENT 'US state or province code of practice',
    zip_code STRING COMMENT 'Practice ZIP or postal code',
    phone STRING COMMENT 'Practice contact phone number',
    years_experience INT COMMENT 'Years of professional experience',
    is_active BOOLEAN COMMENT 'Indicates if prescriber record is currently active',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'The table contains prescriber and provider reference data. It includes the NPI, name, specialty, practice location, and contact attributes sourced from the upstream system. This data supports prescriber network analysis, territory alignment, and program outreach while preserving ingestion lineage for bronze-to-silver processing.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
