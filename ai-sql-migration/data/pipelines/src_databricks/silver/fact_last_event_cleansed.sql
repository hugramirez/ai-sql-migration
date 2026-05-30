-- Run order: Silver last event (latest row per sk_prescription_id by assigned time)
CREATE OR REPLACE TABLE localuc.silver.fact_last_event_cleansed
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
    CASE
        WHEN resolution_date IS NULL THEN NULL
        ELSE DATEDIFF(TO_DATE(resolution_date), TO_DATE(last_event_assigned_date))
    END AS days_to_resolution,
    COALESCE(is_resolved, FALSE) AS is_resolved,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY sk_prescription_id ORDER BY last_event_assigned_date DESC NULLS LAST) AS _row_num
    FROM localuc.bronze.raw_fact_last_event
) ranked
WHERE ranked._row_num = 1;
