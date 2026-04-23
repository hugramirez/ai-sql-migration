-- Run order: Silver adherence (join prescription for sk_medication_id; window derived from measurement_period label)
CREATE OR REPLACE TABLE pharmacy.silver.fact_adherence_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
WITH src AS (
    SELECT
        a.sk_adherence_id,
        a.sk_patient_id,
        a.sk_prescription_id,
        a.sk_measurement_date_id,
        a.measurement_date,
        a.measurement_period,
        a.pdc_proportion_days_covered,
        a.mpf_medication_possession_ratio,
        a.gaps_in_therapy_days,
        a.missed_refills_count,
        a.on_time_refills_count,
        a.patient_reported_adherence,
        a.barriers_to_adherence,
        a.created_date,
        p.sk_medication_id,
        CAST(
            LEAST(
                366,
                GREATEST(
                    1,
                    COALESCE(
                        TRY_CAST(regexp_extract(a.measurement_period, '([0-9]+)', 1) AS INT),
                        30
                    )
                )
            ) AS INT
        ) AS period_days,
        LEAST(GREATEST(COALESCE(a.pdc_proportion_days_covered, 0), 0), 1) AS pdc_clamped
    FROM pharmacy.bronze.raw_fact_adherence a
    LEFT JOIN pharmacy.bronze.raw_fact_prescription p
        ON p.sk_prescription_id = a.sk_prescription_id
)
SELECT
    sk_adherence_id,
    sk_prescription_id,
    sk_patient_id,
    sk_medication_id,
    date_sub(measurement_date, period_days - 1) AS measurement_period_start_date,
    measurement_date AS measurement_period_end_date,
    period_days,
    CAST(
        LEAST(
            period_days,
            GREATEST(0, CAST(ROUND(pdc_clamped * period_days) AS INT))
        ) AS INT
    ) AS days_covered,
    CAST(
        LEAST(
            period_days,
            GREATEST(
                0,
                CAST(ROUND(pdc_clamped * period_days) AS INT) + COALESCE(gaps_in_therapy_days, 0)
            )
        ) AS INT
    ) AS days_supplied,
    COALESCE(gaps_in_therapy_days, 0) AS gaps_count,
    ROUND(pdc_clamped, 4) AS pdc_ratio,
    ROUND(LEAST(GREATEST(COALESCE(mpf_medication_possession_ratio, 0), 0), 1), 4) AS mpf_ratio,
    COALESCE(on_time_refills_count, 0) + COALESCE(missed_refills_count, 0) AS refills_count,
    CASE
        WHEN pdc_clamped >= 0.8 THEN 'Adherent'
        WHEN pdc_clamped >= 0.5 THEN 'Partial'
        ELSE 'Non-Adherent'
    END AS adherence_status,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM src;
