-- Run order: Silver shipments (delivery lag; carrier / exception fields mapped for gold views)
CREATE OR REPLACE TABLE localuc.silver.fact_shipment_cleansed
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
    COALESCE(actual_delivery_date, estimated_delivery_date) AS delivery_date,
    CASE
        WHEN ship_date IS NULL THEN NULL
        ELSE DATEDIFF(COALESCE(actual_delivery_date, estimated_delivery_date), ship_date)
    END AS delivery_days,
    carrier AS carrier_name,
    tracking_number,
    shipping_cost,
    shipment_status AS delivery_status,
    (
        LENGTH(TRIM(COALESCE(delivery_exception_reason, ''))) > 0
        OR LOWER(COALESCE(shipment_status, '')) LIKE '%exception%'
        OR LOWER(COALESCE(shipment_status, '')) LIKE '%delay%'
    ) AS exception_flag,
    delivery_exception_reason AS exception_reason,
    shipment_external_id,
    estimated_delivery_date,
    actual_delivery_date,
    shipment_method,
    temperature_controlled,
    signature_required,
    created_date,
    updated_date,
    current_timestamp() AS _silver_processed_date
FROM localuc.bronze.raw_fact_shipment;
