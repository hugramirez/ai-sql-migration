-- Run order: 44 — Gold date dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_date
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_date_id,
    full_date,
    day_of_week,
    day_name,
    day_of_month,
    day_of_year,
    week_of_year,
    month_num,
    month_name,
    quarter,
    year,
    is_weekend,
    is_holiday,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_date_cleansed;
