-- Run order: 21 — Silver patient (latest row per patient_external_id)
CREATE OR REPLACE TABLE pharmacy.silver.dim_patient_cleansed
USING DELTA
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'quality_score' = '0.95'
)
AS
SELECT
    sk_patient_id,
    patient_external_id,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    date_of_birth,
    CASE
        WHEN date_of_birth IS NULL THEN NULL
        ELSE CAST(FLOOR(DATEDIFF(CURRENT_DATE(), date_of_birth) / 365.25) AS INT)
    END AS age,
    CASE
        WHEN gender IN ('M', 'F', 'Other') THEN gender
        ELSE 'Unknown'
    END AS gender,
    COALESCE(ethnicity, 'Not Specified') AS ethnicity,
    state,
    zip_code,
    enrollment_date,
    primary_rare_disease,
    secondary_conditions,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(patient_external_id, first_name, last_name, gender, ethnicity)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY patient_external_id ORDER BY updated_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_patient
) ranked
WHERE ranked._row_num = 1;
