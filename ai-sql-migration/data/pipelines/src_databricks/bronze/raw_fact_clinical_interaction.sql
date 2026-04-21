-- Run order: Bronze clinical interaction fact
-- Lineage: patient, prescriber, care team member, date dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_clinical_interaction (
    sk_interaction_id BIGINT COMMENT 'Surrogate key for interaction event',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_prescriber_id BIGINT COMMENT 'FK to raw_dim_prescriber',
    sk_care_team_member_id BIGINT COMMENT 'FK to raw_dim_care_team_member',
    sk_interaction_date_id INT COMMENT 'FK to raw_dim_date',
    interaction_date TIMESTAMP COMMENT 'Interaction date and time',
    interaction_type STRING COMMENT 'Call, visit, message, etc.',
    interaction_mode STRING COMMENT 'Inbound, outbound, telehealth, etc.',
    duration_minutes INT COMMENT 'Duration in minutes',
    interaction_notes STRING COMMENT 'Free-text notes',
    outcome STRING COMMENT 'Interaction outcome category',
    patient_satisfaction_score INT COMMENT 'Satisfaction score if captured',
    follow_up_required BOOLEAN COMMENT 'Follow-up required flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Clinical or care management touchpoints at bronze; joins dimensions for Unity Catalog column lineage.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
