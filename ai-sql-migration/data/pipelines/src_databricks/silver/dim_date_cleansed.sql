-- Run order: Silver date conformed dimension (pass-through from bronze calendar)
CREATE OR REPLACE TABLE pharmacy.silver.dim_date_cleansed
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
    current_timestamp() AS _silver_processed_date
FROM pharmacy.bronze.raw_dim_date;
