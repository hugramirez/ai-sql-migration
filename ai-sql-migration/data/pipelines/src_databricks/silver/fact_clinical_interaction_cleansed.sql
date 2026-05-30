-- Run order: Silver clinical interactions (aligned to dbo; gold uses legacy interaction_mode / outcome column names)
CREATE OR REPLACE TABLE localuc.silver.fact_clinical_interaction_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_interaction_id,
    sk_patient_id,
    sk_prescription_id,
    sk_care_team_member_id,
    sk_interaction_date_id,
    interaction_date,
    interaction_type,
    CAST(NULL AS STRING) AS interaction_mode,
    duration_minutes,
    interaction_purpose AS interaction_notes,
    outcome_description AS outcome,
    CASE
        WHEN patient_satisfaction_score <= 0 OR patient_satisfaction_score > 5 THEN NULL
        ELSE patient_satisfaction_score
    END AS patient_satisfaction_score,
    follow_up_required,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM localuc.bronze.raw_fact_clinical_interaction;
