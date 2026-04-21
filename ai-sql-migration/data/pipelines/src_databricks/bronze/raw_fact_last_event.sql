-- Run order: Bronze last event snapshot per prescription (or source grain)
-- Lineage: prescription and patient; assigned date -> raw_dim_date
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_last_event (
    sk_event_id BIGINT COMMENT 'Surrogate key for event row',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_assigned_date_id INT COMMENT 'FK to raw_dim_date (assignment date)',
    last_event_assigned_date TIMESTAMP COMMENT 'When the event was assigned',
    last_event_type STRING COMMENT 'Event type code or label',
    last_event_description STRING COMMENT 'Event description',
    last_event_category STRING COMMENT 'Event category',
    event_priority STRING COMMENT 'Priority level',
    assigned_to_user_id STRING COMMENT 'User or queue assigned',
    resolution_date TIMESTAMP COMMENT 'Resolution timestamp',
    is_resolved BOOLEAN COMMENT 'Resolved flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Workflow or case-management last-event snapshot at bronze; links to prescription and patient.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
