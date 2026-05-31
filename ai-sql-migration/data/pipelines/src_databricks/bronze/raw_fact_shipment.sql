-- Run order: Bronze shipment fact (aligned to dbo.fact_shipment / raw_data CSV)
CREATE OR REPLACE TABLE localuc.bronze.raw_fact_shipment (
    sk_shipment_id BIGINT COMMENT 'Surrogate key for shipment',
    shipment_external_id STRING COMMENT 'Business shipment identifier',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_ship_date_id INT COMMENT 'FK to raw_dim_date (ship date)',
    sk_delivery_date_id INT COMMENT 'FK to raw_dim_date (delivery date)',
    ship_date DATE COMMENT 'Shipment date',
    estimated_delivery_date DATE COMMENT 'Estimated delivery date',
    actual_delivery_date DATE COMMENT 'Actual delivery date',
    carrier STRING COMMENT 'Carrier name',
    tracking_number STRING COMMENT 'Tracking identifier',
    shipment_method STRING COMMENT 'Shipping method',
    temperature_controlled BOOLEAN COMMENT 'Cold chain flag',
    signature_required BOOLEAN COMMENT 'Signature required flag',
    shipment_status STRING COMMENT 'Shipment status',
    delivery_exception_reason STRING COMMENT 'Exception reason text',
    shipping_cost DECIMAL(10, 2) COMMENT 'Shipping cost',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Shipments at bronze; matches dbo.fact_shipment for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);
