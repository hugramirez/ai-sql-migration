-- Run order: 29 — Silver clinical interactions (validated scores)
CREATE OR REPLACE TABLE pharmacy.silver.fact_clinical_interaction_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_interaction_id,
    sk_patient_id,
    sk_prescriber_id,
    sk_care_team_member_id,
    sk_interaction_date_id,
    interaction_date,
    interaction_type,
    interaction_mode,
    duration_minutes,
    interaction_notes,
    outcome,
    CASE
        WHEN patient_satisfaction_score <= 0 OR patient_satisfaction_score > 5 THEN NULL
        ELSE patient_satisfaction_score
    END AS patient_satisfaction_score,
    follow_up_required,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM pharmacy.bronze.raw_fact_clinical_interaction;
