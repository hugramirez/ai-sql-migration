-- Run order: Gold medication dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_medication
USING DELTA
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true'
)
AS
SELECT
    sk_medication_id,
    ndc_code,
    medication_name,
    generic_name,
    manufacturer,
    rare_disease_indication,
    orphan_drug_designation,
    fda_approval_date,
    dosage_form,
    strength,
    route_of_administration,
    storage_requirements,
    avg_wholesale_price,
    is_active,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_medication_cleansed;
