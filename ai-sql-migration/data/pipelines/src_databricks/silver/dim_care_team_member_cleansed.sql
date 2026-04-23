-- Run order: Silver care team member (latest row per employee_id)
CREATE OR REPLACE TABLE pharmacy.silver.dim_care_team_member_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_care_team_member_id,
    employee_id,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    role,
    disease_specialty,
    hire_date,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(employee_id, role)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_care_team_member
) ranked
WHERE ranked._row_num = 1;
