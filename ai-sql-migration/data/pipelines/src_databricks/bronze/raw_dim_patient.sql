-- Run order: Bronze patient dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_patient (
    sk_patient_id BIGINT COMMENT 'Surrogate key for patient (internal unique identifier)',
    patient_external_id STRING COMMENT 'External patient identifier from source system',
    first_name STRING COMMENT 'Patient first name',
    last_name STRING COMMENT 'Patient last name',
    date_of_birth DATE COMMENT 'Patient date of birth',
    age INT COMMENT 'Patient age at time of ingestion',
    gender STRING COMMENT 'Patient gender',
    ethnicity STRING COMMENT 'Patient ethnicity',
    state STRING COMMENT 'Patient state of residence',
    zip_code STRING COMMENT 'Patient ZIP code',
    enrollment_date DATE COMMENT 'Date patient enrolled in program',
    primary_rare_disease STRING COMMENT 'Primary rare disease diagnosis',
    secondary_conditions STRING COMMENT 'Comma-separated list of secondary conditions',
    is_active BOOLEAN COMMENT 'Indicates if patient is currently active',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'The table contains comprehensive patient demographic and condition data. It includes essential information such as patient identifiers, names, date of birth, age, gender, and ethnicity. This data can be utilized to analyze patient population trends, support disease management initiatives, and evaluate service outreach effectiveness. Additionally, it tracks the patient''s enrollment status and associated health conditions.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
