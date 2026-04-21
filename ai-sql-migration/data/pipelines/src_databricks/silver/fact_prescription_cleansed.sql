-- Run order: Silver prescription fact (dedupe by prescription_external_id)
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
        WHEN filled_date IS NULL THEN NULL
        ELSE DATEDIFF(filled_date, written_date)
    END AS days_to_fill,
    quantity_prescribed,
    days_supply,
    refills,
    COALESCE(copay, 0) AS copay,
    COALESCE(insurance_paid, 0) AS insurance_paid,
    COALESCE(total_cost, 0) AS total_cost,
    COALESCE(is_filled, FALSE) AS is_filled,
    COALESCE(is_rejected, FALSE) AS is_rejected,
    rejection_reason,
    created_date,
    MD5(CONCAT(prescription_external_id, sk_patient_id, sk_medication_id)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY prescription_external_id ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_fact_prescription
) ranked
WHERE ranked._row_num = 1;
