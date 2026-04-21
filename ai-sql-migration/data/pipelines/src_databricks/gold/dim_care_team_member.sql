-- Run order: Gold care team member dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_care_team_member
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_care_team_member_id,
    employee_id,
    first_name,
    last_name,
    role,
    disease_specialty,
    hire_date,
    is_active,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_care_team_member_cleansed;
