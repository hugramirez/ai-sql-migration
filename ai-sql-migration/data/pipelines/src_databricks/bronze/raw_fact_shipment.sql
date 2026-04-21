-- Run order: Bronze shipment fact
-- Lineage: prescription and patient dimensions; ship/delivery date roles -> raw_dim_date
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_shipment (
    sk_shipment_id BIGINT COMMENT 'Surrogate key for shipment',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_ship_date_id INT COMMENT 'FK to raw_dim_date (ship date)',
    sk_delivery_date_id INT COMMENT 'FK to raw_dim_date (delivery date)',
    ship_date DATE COMMENT 'Shipment date',
    delivery_date DATE COMMENT 'Delivery or expected delivery date',
    carrier_name STRING COMMENT 'Carrier name',
    tracking_number STRING COMMENT 'Tracking identifier',
    shipping_cost DECIMAL(10, 2) COMMENT 'Shipping cost',
    delivery_status STRING COMMENT 'Delivery status',
    exception_flag BOOLEAN COMMENT 'Exception occurred',
    exception_reason STRING COMMENT 'Exception reason',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Fulfillment and logistics at bronze; ties shipments to prescriptions and patients for lineage.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
