-- Run order: Gold shipment fact
CREATE OR REPLACE TABLE pharmacy.gold.fact_shipment
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_shipment_id,
    sk_prescription_id,
    sk_patient_id,
    sk_ship_date_id,
    sk_delivery_date_id,
    ship_date,
    delivery_date,
    delivery_days,
    carrier_name,
    tracking_number,
    shipping_cost,
    delivery_status,
    exception_flag,
    exception_reason,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_shipment_cleansed;
