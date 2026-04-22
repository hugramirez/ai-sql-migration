-- Run order: Silver prescription fact (dedupe by prescription_external_id; analytics columns for gold)
CREATE OR REPLACE TABLE pharmacy.silver.fact_prescription_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_prescription_id,
    prescription_external_id,
    sk_patient_id,
    sk_medication_id,
    sk_prescriber_id,
    sk_payer_id,
    sk_written_date_id,
    sk_filled_date_id,
    written_date,
    filled_date,
    CASE
        WHEN filled_date IS NULL OR written_date IS NULL THEN NULL
        ELSE DATEDIFF(filled_date, written_date)
    END AS days_to_fill,
    quantity_prescribed,
    days_supply,
    refills_authorized AS refills,
    copay_amount AS copay,
    insurance_paid_amount AS insurance_paid,
    total_cost,
    CASE
        WHEN LOWER(TRIM(prescription_status)) IN ('completed', 'active') THEN TRUE
        ELSE FALSE
    END AS is_filled,
    CASE
        WHEN LOWER(TRIM(prescription_status)) LIKE '%reject%'
            OR LOWER(TRIM(prescription_status)) LIKE '%denied%' THEN TRUE
        ELSE FALSE
    END AS is_rejected,
    CASE
        WHEN LOWER(TRIM(prescription_status)) LIKE '%reject%'
            OR LOWER(TRIM(prescription_status)) LIKE '%denied%' THEN prescription_status
        ELSE NULL
    END AS rejection_reason,
    prescription_status,
    therapy_type,
    is_specialty,
    is_controlled_substance,
    prior_authorization_required,
    prior_authorization_approved,
    created_date,
    updated_date,
    MD5(CONCAT(prescription_external_id, sk_patient_id, sk_medication_id)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY prescription_external_id ORDER BY updated_date DESC NULLS LAST, created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_fact_prescription
) ranked
WHERE ranked._row_num = 1;
