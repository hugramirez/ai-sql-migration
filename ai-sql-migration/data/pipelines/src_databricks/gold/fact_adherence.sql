-- Run order: 47 — Gold adherence fact
CREATE OR REPLACE TABLE pharmacy.gold.fact_adherence
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_adherence_id,
    sk_prescription_id,
    sk_patient_id,
    sk_medication_id,
    measurement_period_start_date,
    measurement_period_end_date,
    period_days,
    days_supplied,
    days_covered,
    gaps_count,
    pdc_ratio,
    mpf_ratio,
    refills_count,
    adherence_status,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_adherence_cleansed;

OPTIMIZE pharmacy.gold.fact_adherence ZORDER BY (sk_patient_id, measurement_period_start_date);
