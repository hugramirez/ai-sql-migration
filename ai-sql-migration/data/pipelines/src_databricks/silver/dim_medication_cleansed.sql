-- Run order: Silver medication (latest row per ndc_code)
CREATE OR REPLACE TABLE pharmacy.silver.dim_medication_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_medication_id,
    ndc_code,
    TRIM(medication_name) AS medication_name,
    TRIM(COALESCE(generic_name, medication_name)) AS generic_name,
    TRIM(manufacturer) AS manufacturer,
    rare_disease_indication,
    orphan_drug_designation,
    fda_approval_date,
    dosage_form,
    strength,
    route_of_administration,
    storage_requirements,
    CASE
        WHEN avg_wholesale_price <= 0 THEN NULL
        ELSE avg_wholesale_price
    END AS avg_wholesale_price,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(ndc_code, medication_name, manufacturer)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY ndc_code ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_medication
) ranked
WHERE ranked._row_num = 1;
