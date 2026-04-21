-- Run order: Silver shipments (delivery lag)
CREATE OR REPLACE TABLE pharmacy.silver.fact_shipment_cleansed
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
    CASE
        WHEN delivery_date IS NULL THEN NULL
        ELSE DATEDIFF(delivery_date, ship_date)
    END AS delivery_days,
    carrier_name,
    tracking_number,
    shipping_cost,
    delivery_status,
    exception_flag,
    exception_reason,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM pharmacy.bronze.raw_fact_shipment;
