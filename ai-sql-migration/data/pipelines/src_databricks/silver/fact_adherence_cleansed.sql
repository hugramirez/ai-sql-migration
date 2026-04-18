-- Run order: 28 — Silver adherence (enriched; no dedupe key in bronze — pass-through with derived columns)
CREATE OR REPLACE TABLE pharmacy.silver.fact_adherence_cleansed
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
    DATEDIFF(measurement_period_end_date, measurement_period_start_date) AS period_days,
    days_supplied,
    days_covered,
    gaps_count,
    ROUND(COALESCE(pdc_ratio, 0), 4) AS pdc_ratio,
    ROUND(COALESCE(mpf_ratio, 0), 4) AS mpf_ratio,
    refills_count,
    CASE
        WHEN COALESCE(pdc_ratio, 0) >= 0.8 THEN 'Adherent'
        WHEN COALESCE(pdc_ratio, 0) >= 0.5 THEN 'Partial'
        ELSE 'Non-Adherent'
    END AS adherence_status,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM pharmacy.bronze.raw_fact_adherence;
