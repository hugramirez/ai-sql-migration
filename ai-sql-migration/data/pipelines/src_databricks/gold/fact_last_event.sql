-- Run order: 50 — Gold last-event snapshot fact
CREATE OR REPLACE TABLE pharmacy.gold.fact_last_event
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_event_id,
    sk_prescription_id,
    sk_patient_id,
    sk_assigned_date_id,
    last_event_assigned_date,
    last_event_type,
    last_event_description,
    last_event_category,
    event_priority,
    assigned_to_user_id,
    resolution_date,
    days_to_resolution,
    is_resolved,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_last_event_cleansed;
