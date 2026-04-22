-- Run order: Bronze clinical interaction fact (aligned to dbo.fact_clinical_interaction / raw_data CSV)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_clinical_interaction (
    sk_interaction_id BIGINT COMMENT 'Surrogate key for interaction event',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription (nullable in source)',
    sk_care_team_member_id BIGINT COMMENT 'FK to raw_dim_care_team_member',
    sk_interaction_date_id INT COMMENT 'FK to raw_dim_date',
    interaction_date TIMESTAMP COMMENT 'Interaction date and time',
    interaction_type STRING COMMENT 'Interaction channel or type',
    interaction_purpose STRING COMMENT 'Purpose of the interaction',
    duration_minutes INT COMMENT 'Duration in minutes',
    patient_satisfaction_score INT COMMENT 'Satisfaction score if captured',
    outcome_description STRING COMMENT 'Outcome narrative',
    follow_up_required BOOLEAN COMMENT 'Follow-up required flag',
    follow_up_date DATE COMMENT 'Planned follow-up date',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Clinical interactions at bronze; matches dbo.fact_clinical_interaction for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
