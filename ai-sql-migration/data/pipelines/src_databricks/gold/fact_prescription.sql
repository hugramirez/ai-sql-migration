-- Run order: Gold prescription fact + physical optimization
CREATE OR REPLACE TABLE pharmacy.gold.fact_prescription
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
    days_to_fill,
    quantity_prescribed,
    days_supply,
    refills,
    copay,
    insurance_paid,
    total_cost,
    is_filled,
    is_rejected,
    rejection_reason,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_prescription_cleansed;

OPTIMIZE pharmacy.gold.fact_prescription ZORDER BY (sk_patient_id, written_date);
