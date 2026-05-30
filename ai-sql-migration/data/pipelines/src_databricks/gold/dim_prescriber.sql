-- Run order: Gold prescriber dimension
CREATE OR REPLACE TABLE localuc.gold.dim_prescriber
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_prescriber_id,
    npi_number,
    first_name,
    last_name,
    specialty,
    sub_specialty,
    practice_name,
    address_line1,
    city,
    state,
    zip_code,
    phone,
    years_experience,
    is_active,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM localuc.silver.dim_prescriber_cleansed;
