-- Run order: Bronze medication dimension
CREATE OR REPLACE TABLE localuc.bronze.raw_dim_medication (
    sk_medication_id BIGINT COMMENT 'Surrogate key for medication (internal unique identifier)',
    ndc_code STRING COMMENT 'National Drug Code identifier from source system',
    medication_name STRING COMMENT 'Branded or trade medication name',
    generic_name STRING COMMENT 'Generic drug name',
    manufacturer STRING COMMENT 'Drug manufacturer name',
    rare_disease_indication STRING COMMENT 'Rare disease indication or therapeutic use',
    orphan_drug_designation BOOLEAN COMMENT 'Indicates FDA orphan drug designation',
    fda_approval_date DATE COMMENT 'FDA approval date for the product',
    dosage_form STRING COMMENT 'Dosage form (e.g. tablet, capsule, injectable)',
    strength STRING COMMENT 'Drug strength or concentration',
    route_of_administration STRING COMMENT 'Route of administration (e.g. oral, IV)',
    storage_requirements STRING COMMENT 'Storage and handling requirements',
    avg_wholesale_price DECIMAL(10, 2) COMMENT 'Average wholesale price',
    is_active BOOLEAN COMMENT 'Indicates if medication record is currently active',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'The table contains medication master and product reference data. It includes identifiers such as surrogate keys and NDC codes, descriptive attributes including medication and generic names, manufacturer, dosage form, strength, and route of administration. Rare disease and orphan drug attributes support specialty pharmacy and program analytics. Pricing and regulatory dates enable formulary, access, and compliance reporting. Audit columns capture ingestion lineage for downstream bronze-to-silver processing.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);
