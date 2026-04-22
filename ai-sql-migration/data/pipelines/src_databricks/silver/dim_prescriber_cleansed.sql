-- Run order: Silver prescriber (current row per npi_number; SCD2 fields reserved for future)
CREATE OR REPLACE TABLE pharmacy.silver.dim_prescriber_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_prescriber_id,
    npi_number,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    specialty,
    sub_specialty,
    TRIM(practice_name) AS practice_name,
    address_line1,
    city,
    state,
    zip_code,
    phone,
    years_experience,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(npi_number, specialty, practice_name)) AS _record_hash,
    current_timestamp() AS _valid_from,
    CAST(NULL AS TIMESTAMP) AS _valid_to,
    TRUE AS _is_current,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY npi_number ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_prescriber
) ranked
WHERE ranked._row_num = 1;
