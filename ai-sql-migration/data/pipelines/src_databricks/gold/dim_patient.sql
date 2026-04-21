-- Run order: Gold patient dimension (consumption layer)
CREATE OR REPLACE TABLE pharmacy.gold.dim_patient
USING DELTA
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'delta.minFileSize' = '1073741824',
    'delta.tuneFileSizesForRewrites' = 'true'
)
AS
SELECT
    sk_patient_id,
    patient_external_id,
    first_name,
    last_name,
    date_of_birth,
    age,
    gender,
    ethnicity,
    state,
    zip_code,
    enrollment_date,
    primary_rare_disease,
    secondary_conditions,
    is_active,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_patient_cleansed;
