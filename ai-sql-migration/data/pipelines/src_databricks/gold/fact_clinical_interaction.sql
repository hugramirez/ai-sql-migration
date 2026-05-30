-- Run order: Gold clinical interaction fact
CREATE OR REPLACE TABLE localuc.gold.fact_clinical_interaction
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
    interaction_mode,
    duration_minutes,
    interaction_notes,
    outcome,
    patient_satisfaction_score,
    follow_up_required,
    created_date,
    current_timestamp() AS _gold_created_date
FROM localuc.silver.fact_clinical_interaction_cleansed;

OPTIMIZE localuc.gold.fact_clinical_interaction ZORDER BY (sk_patient_id, interaction_date);
