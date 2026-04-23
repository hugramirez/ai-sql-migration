-- ============================================================================
-- Pharmacy pipeline — Databricks SQL Editor / SQL Warehouse
--
-- Single batch script. Canonical sources live under:
--   schemas/  bronze/  silver/  gold/  views/
--
-- After editing any modular .sql file, refresh this file by concatenating
-- those scripts in dependency order (same order as ``init_db_databricks.PIPELINE_DDL_FILES``).
--
-- Catalog: pharmacy (Unity Catalog). Needs CREATE on bronze, silver, gold.
-- ============================================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/schemas/bronze.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

CREATE SCHEMA IF NOT EXISTS pharmacy.bronze
COMMENT 'BRONZE LAYER - Raw Data Ingestion Zone
Purpose: Stores unprocessed data extracted directly from source systems (SQL Server, APIs, files)
Characteristics:
  - No transformations applied (source system data as-is)
  - Audit columns added (_ingest_timestamp, _source_system, _ingest_batch_id)
  - Change Data Feed (CDF) enabled for incremental processing
  - Schema evolution allowed (addNewColumns mode)
Data Retention: 90 days (compliance with temporary storage policies)
Owner: data_engineers group
Access Level: Restricted - Only data engineers can create/modify tables
Table Naming Convention: raw_{original_table_name}
Quality Checks: Schema validation, null checks, duplicate detection
Lineage: Direct mapping from source system tables';


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/schemas/silver.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

CREATE SCHEMA IF NOT EXISTS pharmacy.silver
COMMENT 'SILVER LAYER - Cleansed and conformed data
Purpose: Deduplicated, validated, and lightly enriched tables sourced from pharmacy.bronze
Characteristics:
  - Row-level quality rules and hashes for change detection
  - Surrogate keys preserved from bronze for lineage to gold
  - CDF enabled where tables feed downstream gold or analytics
Lineage: CTAS / MERGE from pharmacy.bronze raw_* tables';


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/schemas/gold.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

CREATE SCHEMA IF NOT EXISTS pharmacy.gold
COMMENT 'GOLD LAYER - Analytics-ready dimensional model
Purpose: Curated dimensions and facts for BI and applications
Characteristics:
  - One row per business key (or snapshot policy) per entity
  - Optional ZORDER / OPTIMIZE on large facts
Lineage: CTAS from pharmacy.silver *_cleansed tables and views for consumption metrics';


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_dim_date.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze conformed date dimension (no CDF required for static calendar)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_date (
    sk_date_id INT COMMENT 'Surrogate key for calendar date',
    full_date DATE COMMENT 'Calendar date',
    day_of_week INT COMMENT 'Day of week (1–7 per source convention)',
    day_name STRING COMMENT 'Day name (e.g. Monday)',
    day_of_month INT COMMENT 'Day of month',
    day_of_year INT COMMENT 'Day of year',
    week_of_year INT COMMENT 'ISO or calendar week of year',
    month_num INT COMMENT 'Month number 1–12',
    month_name STRING COMMENT 'Month name',
    quarter INT COMMENT 'Calendar quarter 1–4',
    year INT COMMENT 'Calendar year',
    is_weekend BOOLEAN COMMENT 'True if Saturday or Sunday',
    is_holiday BOOLEAN COMMENT 'True if holiday flag set in source',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Calendar date dimension at bronze; keys link facts to written, filled, ship, and interaction dates.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_dim_payer.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze payer (plan) dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_payer (
    sk_payer_id BIGINT COMMENT 'Surrogate key for payer',
    payer_external_id STRING COMMENT 'External payer or plan identifier',
    payer_name STRING COMMENT 'Payer or plan display name',
    payer_type STRING COMMENT 'Commercial, Medicare, Medicaid, etc.',
    bin_number STRING COMMENT 'Bank Identification Number (BIN)',
    pcn_number STRING COMMENT 'Processor Control Number (PCN)',
    group_number STRING COMMENT 'Group or plan group number',
    contact_phone STRING COMMENT 'Payer contact phone',
    specialty_pharmacy_network BOOLEAN COMMENT 'Participates in specialty pharmacy network',
    is_active BOOLEAN COMMENT 'Payer record active flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Insurance payer and benefit configuration at bronze; referenced by raw_fact_prescription.sk_payer_id.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_dim_care_team_member.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze care team member dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_care_team_member (
    sk_care_team_member_id BIGINT COMMENT 'Surrogate key for care team member',
    employee_id STRING COMMENT 'Internal employee identifier',
    first_name STRING COMMENT 'First name',
    last_name STRING COMMENT 'Last name',
    role STRING COMMENT 'Job role or title',
    disease_specialty STRING COMMENT 'Disease or therapeutic specialty',
    hire_date DATE COMMENT 'Hire date',
    is_active BOOLEAN COMMENT 'Active employment or roster flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Internal care team roster at bronze; referenced by raw_fact_clinical_interaction.sk_care_team_member_id.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_dim_patient.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze patient dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_patient (
    sk_patient_id BIGINT COMMENT 'Surrogate key for patient (internal unique identifier)',
    patient_external_id STRING COMMENT 'External patient identifier from source system',
    first_name STRING COMMENT 'Patient first name',
    last_name STRING COMMENT 'Patient last name',
    date_of_birth DATE COMMENT 'Patient date of birth',
    age INT COMMENT 'Patient age at time of ingestion',
    gender STRING COMMENT 'Patient gender',
    ethnicity STRING COMMENT 'Patient ethnicity',
    state STRING COMMENT 'Patient state of residence',
    zip_code STRING COMMENT 'Patient ZIP code',
    enrollment_date DATE COMMENT 'Date patient enrolled in program',
    primary_rare_disease STRING COMMENT 'Primary rare disease diagnosis',
    secondary_conditions STRING COMMENT 'Comma-separated list of secondary conditions',
    is_active BOOLEAN COMMENT 'Indicates if patient is currently active',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'The table contains comprehensive patient demographic and condition data. It includes essential information such as patient identifiers, names, date of birth, age, gender, and ethnicity. This data can be utilized to analyze patient population trends, support disease management initiatives, and evaluate service outreach effectiveness. Additionally, it tracks the patient''s enrollment status and associated health conditions.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_dim_medication.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze medication dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_medication (
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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_dim_prescriber.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze prescriber dimension
CREATE OR REPLACE TABLE pharmacy.bronze.raw_dim_prescriber (
    sk_prescriber_id BIGINT COMMENT 'Surrogate key for prescriber (internal unique identifier)',
    npi_number STRING COMMENT 'National Provider Identifier (NPI)',
    first_name STRING COMMENT 'Prescriber first name',
    last_name STRING COMMENT 'Prescriber last name',
    specialty STRING COMMENT 'Primary medical specialty',
    sub_specialty STRING COMMENT 'Sub-specialty or secondary specialty',
    practice_name STRING COMMENT 'Practice or organization name',
    address_line1 STRING COMMENT 'Primary practice address line',
    city STRING COMMENT 'City of practice',
    state STRING COMMENT 'US state or province code of practice',
    zip_code STRING COMMENT 'Practice ZIP or postal code',
    phone STRING COMMENT 'Practice contact phone number',
    years_experience INT COMMENT 'Years of professional experience',
    is_active BOOLEAN COMMENT 'Indicates if prescriber record is currently active',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'The table contains prescriber and provider reference data. It includes the NPI, name, specialty, practice location, and contact attributes sourced from the upstream system. This data supports prescriber network analysis, territory alignment, and program outreach while preserving ingestion lineage for bronze-to-silver processing.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_fact_prescription.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze prescription fact (aligned to dbo.fact_prescription / raw_data CSV)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_prescription (
    sk_prescription_id BIGINT COMMENT 'Surrogate key for prescription fact',
    prescription_external_id STRING COMMENT 'Natural or business prescription identifier',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_medication_id BIGINT COMMENT 'FK to raw_dim_medication',
    sk_prescriber_id BIGINT COMMENT 'FK to raw_dim_prescriber',
    sk_payer_id BIGINT COMMENT 'FK to raw_dim_payer',
    sk_written_date_id INT COMMENT 'FK to raw_dim_date (written date)',
    sk_filled_date_id INT COMMENT 'FK to raw_dim_date (fill date)',
    written_date DATE COMMENT 'Date prescription was written',
    filled_date DATE COMMENT 'Date prescription was filled',
    quantity_prescribed DECIMAL(10, 2) COMMENT 'Quantity prescribed',
    days_supply INT COMMENT 'Days supply',
    refills_authorized INT COMMENT 'Refills authorized',
    refills_remaining INT COMMENT 'Refills remaining',
    copay_amount DECIMAL(10, 2) COMMENT 'Patient copay amount',
    insurance_paid_amount DECIMAL(12, 2) COMMENT 'Insurance paid amount',
    total_cost DECIMAL(12, 2) COMMENT 'Total cost',
    prescription_status STRING COMMENT 'Workflow status in source',
    therapy_type STRING COMMENT 'Therapy classification',
    is_specialty BOOLEAN COMMENT 'Specialty medication flag',
    is_controlled_substance BOOLEAN COMMENT 'Controlled substance flag',
    prior_authorization_required BOOLEAN COMMENT 'PA required',
    prior_authorization_approved BOOLEAN COMMENT 'PA approved',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    updated_date TIMESTAMP COMMENT 'Record last update in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Prescription fact at bronze; column names match SQL Server dbo.fact_prescription for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_fact_adherence.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze adherence fact (aligned to dbo.fact_adherence / raw_data CSV)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_adherence (
    sk_adherence_id BIGINT COMMENT 'Surrogate key for adherence row',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_measurement_date_id INT COMMENT 'FK to raw_dim_date (measurement date)',
    measurement_date DATE COMMENT 'As-of measurement date',
    measurement_period STRING COMMENT 'Label for evaluation window (e.g. 180-day)',
    pdc_proportion_days_covered DECIMAL(5, 2) COMMENT 'Proportion of days covered (PDC)',
    mpf_medication_possession_ratio DECIMAL(5, 2) COMMENT 'Medication possession ratio',
    gaps_in_therapy_days INT COMMENT 'Gap days in therapy',
    missed_refills_count INT COMMENT 'Missed refills count',
    on_time_refills_count INT COMMENT 'On-time refills count',
    patient_reported_adherence STRING COMMENT 'Patient-reported adherence category',
    barriers_to_adherence STRING COMMENT 'Barriers text',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Adherence metrics at bronze; matches dbo.fact_adherence for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_fact_clinical_interaction.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze clinical interaction fact (aligned to dbo.fact_clinical_interaction / raw_data CSV)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_clinical_interaction (
    sk_interaction_id BIGINT COMMENT 'Surrogate key for interaction event',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription (nullable in source)',
    sk_care_team_member_id BIGINT COMMENT 'FK to raw_dim_care_team_member',
    sk_interaction_date_id INT COMMENT 'FK to raw_dim_date',
    interaction_date TIMESTAMP COMMENT 'Interaction date and time',
    interaction_type STRING COMMENT 'Interaction channel or type',
    interaction_purpose STRING COMMENT 'Purpose of the interaction',
    duration_minutes INT COMMENT 'Duration in minutes',
    patient_satisfaction_score INT COMMENT 'Satisfaction score if captured',
    outcome_description STRING COMMENT 'Outcome narrative',
    follow_up_required BOOLEAN COMMENT 'Follow-up required flag',
    follow_up_date DATE COMMENT 'Planned follow-up date',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Clinical interactions at bronze; matches dbo.fact_clinical_interaction for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_fact_shipment.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze shipment fact (aligned to dbo.fact_shipment / raw_data CSV)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_shipment (
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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/bronze/raw_fact_last_event.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Bronze last-event snapshot (aligned to dbo.fact_last_event / raw_data CSV)
CREATE OR REPLACE TABLE pharmacy.bronze.raw_fact_last_event (
    sk_event_id BIGINT COMMENT 'Surrogate key for event row',
    sk_prescription_id BIGINT COMMENT 'FK to raw_fact_prescription',
    sk_patient_id BIGINT COMMENT 'FK to raw_dim_patient',
    sk_assigned_date_id INT COMMENT 'FK to raw_dim_date (assignment date)',
    last_event_assigned_date TIMESTAMP COMMENT 'When the event was assigned',
    last_event_type STRING COMMENT 'Event type code or label',
    last_event_description STRING COMMENT 'Event description',
    last_event_category STRING COMMENT 'Event category',
    event_priority STRING COMMENT 'Priority level',
    assigned_to_user_id STRING COMMENT 'User or queue assigned',
    resolution_date TIMESTAMP COMMENT 'Resolution timestamp',
    is_resolved BOOLEAN COMMENT 'Resolved flag',
    created_date TIMESTAMP COMMENT 'Record creation timestamp in source system',
    _ingest_timestamp TIMESTAMP COMMENT 'Timestamp when record was ingested' DEFAULT current_timestamp(),
    _source_system STRING COMMENT 'Source system name' DEFAULT 'sqlserver',
    _ingest_batch_id STRING COMMENT 'Batch identifier for ingestion'
) USING DELTA COMMENT 'Last-event snapshot at bronze; matches dbo.fact_last_event for CSV ingest.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true',
    'classification' = 'pii'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/dim_patient_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver patient (latest row per patient_external_id)
CREATE OR REPLACE TABLE pharmacy.silver.dim_patient_cleansed
USING DELTA
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'quality_score' = '0.95'
)
AS
SELECT
    sk_patient_id,
    patient_external_id,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    date_of_birth,
    CASE
        WHEN date_of_birth IS NULL THEN NULL
        ELSE CAST(FLOOR(DATEDIFF(CURRENT_DATE(), date_of_birth) / 365.25) AS INT)
    END AS age,
    CASE
        WHEN gender IN ('M', 'F', 'Other') THEN gender
        ELSE 'Unknown'
    END AS gender,
    COALESCE(ethnicity, 'Not Specified') AS ethnicity,
    state,
    zip_code,
    enrollment_date,
    primary_rare_disease,
    secondary_conditions,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(patient_external_id, first_name, last_name, gender, ethnicity)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY patient_external_id ORDER BY updated_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_patient
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/dim_medication_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver medication (latest row per ndc_code)
CREATE OR REPLACE TABLE pharmacy.silver.dim_medication_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_medication_id,
    ndc_code,
    TRIM(medication_name) AS medication_name,
    TRIM(COALESCE(generic_name, medication_name)) AS generic_name,
    TRIM(manufacturer) AS manufacturer,
    rare_disease_indication,
    orphan_drug_designation,
    fda_approval_date,
    dosage_form,
    strength,
    route_of_administration,
    storage_requirements,
    CASE
        WHEN avg_wholesale_price <= 0 THEN NULL
        ELSE avg_wholesale_price
    END AS avg_wholesale_price,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(ndc_code, medication_name, manufacturer)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY ndc_code ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_medication
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/dim_prescriber_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver prescriber (current row per npi_number; SCD2 fields reserved for future)
CREATE OR REPLACE TABLE pharmacy.silver.dim_prescriber_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_prescriber_id,
    npi_number,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    specialty,
    sub_specialty,
    TRIM(practice_name) AS practice_name,
    address_line1,
    city,
    state,
    zip_code,
    phone,
    years_experience,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(npi_number, specialty, practice_name)) AS _record_hash,
    current_timestamp() AS _valid_from,
    CAST(NULL AS TIMESTAMP) AS _valid_to,
    TRUE AS _is_current,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY npi_number ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_prescriber
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/dim_payer_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver payer (latest row per payer_external_id)
CREATE OR REPLACE TABLE pharmacy.silver.dim_payer_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_payer_id,
    payer_external_id,
    TRIM(payer_name) AS payer_name,
    payer_type,
    bin_number,
    pcn_number,
    group_number,
    contact_phone,
    specialty_pharmacy_network,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(payer_external_id, payer_name)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY payer_external_id ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_payer
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/dim_care_team_member_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver care team member (latest row per employee_id)
CREATE OR REPLACE TABLE pharmacy.silver.dim_care_team_member_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_care_team_member_id,
    employee_id,
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    role,
    disease_specialty,
    hire_date,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    updated_date,
    MD5(CONCAT(employee_id, role)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_care_team_member
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/dim_date_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/fact_prescription_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver prescription fact (dedupe by prescription_external_id; analytics columns for gold)
CREATE OR REPLACE TABLE pharmacy.silver.fact_prescription_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_prescription_id,
    prescription_external_id,
    sk_patient_id,
    sk_medication_id,
    sk_prescriber_id,
    sk_payer_id,
    sk_written_date_id,
    sk_filled_date_id,
    written_date,
    filled_date,
    CASE
        WHEN filled_date IS NULL OR written_date IS NULL THEN NULL
        ELSE DATEDIFF(filled_date, written_date)
    END AS days_to_fill,
    quantity_prescribed,
    days_supply,
    refills_authorized AS refills,
    copay_amount AS copay,
    insurance_paid_amount AS insurance_paid,
    total_cost,
    CASE
        WHEN LOWER(TRIM(prescription_status)) IN ('completed', 'active') THEN TRUE
        ELSE FALSE
    END AS is_filled,
    CASE
        WHEN LOWER(TRIM(prescription_status)) LIKE '%reject%'
            OR LOWER(TRIM(prescription_status)) LIKE '%denied%' THEN TRUE
        ELSE FALSE
    END AS is_rejected,
    CASE
        WHEN LOWER(TRIM(prescription_status)) LIKE '%reject%'
            OR LOWER(TRIM(prescription_status)) LIKE '%denied%' THEN prescription_status
        ELSE NULL
    END AS rejection_reason,
    prescription_status,
    therapy_type,
    is_specialty,
    is_controlled_substance,
    prior_authorization_required,
    prior_authorization_approved,
    created_date,
    updated_date,
    MD5(CONCAT(prescription_external_id, sk_patient_id, sk_medication_id)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY prescription_external_id ORDER BY updated_date DESC NULLS LAST, created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_fact_prescription
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/fact_adherence_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver adherence (join prescription for sk_medication_id; window derived from measurement_period label)
CREATE OR REPLACE TABLE pharmacy.silver.fact_adherence_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
WITH src AS (
    SELECT
        a.sk_adherence_id,
        a.sk_patient_id,
        a.sk_prescription_id,
        a.sk_measurement_date_id,
        a.measurement_date,
        a.measurement_period,
        a.pdc_proportion_days_covered,
        a.mpf_medication_possession_ratio,
        a.gaps_in_therapy_days,
        a.missed_refills_count,
        a.on_time_refills_count,
        a.patient_reported_adherence,
        a.barriers_to_adherence,
        a.created_date,
        p.sk_medication_id,
        CAST(
            LEAST(
                366,
                GREATEST(
                    1,
                    COALESCE(
                        TRY_CAST(regexp_extract(a.measurement_period, '([0-9]+)', 1) AS INT),
                        30
                    )
                )
            ) AS INT
        ) AS period_days,
        LEAST(GREATEST(COALESCE(a.pdc_proportion_days_covered, 0), 0), 1) AS pdc_clamped
    FROM pharmacy.bronze.raw_fact_adherence a
    LEFT JOIN pharmacy.bronze.raw_fact_prescription p
        ON p.sk_prescription_id = a.sk_prescription_id
)
SELECT
    sk_adherence_id,
    sk_prescription_id,
    sk_patient_id,
    sk_medication_id,
    date_sub(measurement_date, period_days - 1) AS measurement_period_start_date,
    measurement_date AS measurement_period_end_date,
    period_days,
    CAST(
        LEAST(
            period_days,
            GREATEST(0, CAST(ROUND(pdc_clamped * period_days) AS INT))
        ) AS INT
    ) AS days_covered,
    CAST(
        LEAST(
            period_days,
            GREATEST(
                0,
                CAST(ROUND(pdc_clamped * period_days) AS INT) + COALESCE(gaps_in_therapy_days, 0)
            )
        ) AS INT
    ) AS days_supplied,
    COALESCE(gaps_in_therapy_days, 0) AS gaps_count,
    ROUND(pdc_clamped, 4) AS pdc_ratio,
    ROUND(LEAST(GREATEST(COALESCE(mpf_medication_possession_ratio, 0), 0), 1), 4) AS mpf_ratio,
    COALESCE(on_time_refills_count, 0) + COALESCE(missed_refills_count, 0) AS refills_count,
    CASE
        WHEN pdc_clamped >= 0.8 THEN 'Adherent'
        WHEN pdc_clamped >= 0.5 THEN 'Partial'
        ELSE 'Non-Adherent'
    END AS adherence_status,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM src;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/fact_clinical_interaction_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver clinical interactions (aligned to dbo; gold uses legacy interaction_mode / outcome column names)
CREATE OR REPLACE TABLE pharmacy.silver.fact_clinical_interaction_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_interaction_id,
    sk_patient_id,
    sk_prescription_id,
    sk_care_team_member_id,
    sk_interaction_date_id,
    interaction_date,
    interaction_type,
    CAST(NULL AS STRING) AS interaction_mode,
    duration_minutes,
    interaction_purpose AS interaction_notes,
    outcome_description AS outcome,
    CASE
        WHEN patient_satisfaction_score <= 0 OR patient_satisfaction_score > 5 THEN NULL
        ELSE patient_satisfaction_score
    END AS patient_satisfaction_score,
    follow_up_required,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM pharmacy.bronze.raw_fact_clinical_interaction;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/fact_shipment_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver shipments (delivery lag; carrier / exception fields mapped for gold views)
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
FROM pharmacy.bronze.raw_fact_shipment;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/fact_last_event_cleansed.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Silver last event (latest row per sk_prescription_id by assigned time)
CREATE OR REPLACE TABLE pharmacy.silver.fact_last_event_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_event_id,
    sk_prescription_id,
    sk_patient_id,
    sk_assigned_date_id,
    last_event_assigned_date,
    last_event_type,
    last_event_description,
    last_event_category,
    event_priority,
    assigned_to_user_id,
    resolution_date,
    CASE
        WHEN resolution_date IS NULL THEN NULL
        ELSE DATEDIFF(TO_DATE(resolution_date), TO_DATE(last_event_assigned_date))
    END AS days_to_resolution,
    COALESCE(is_resolved, FALSE) AS is_resolved,
    created_date,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY sk_prescription_id ORDER BY last_event_assigned_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_fact_last_event
) ranked
WHERE ranked._row_num = 1;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/_metadata_pipeline_runs.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Operational metadata for pipeline runs (optional lineage sidecar)
CREATE OR REPLACE TABLE pharmacy.silver._metadata_pipeline_runs (
    run_id STRING NOT NULL COMMENT 'Unique run identifier',
    pipeline_name STRING NOT NULL COMMENT 'Pipeline or job name',
    step_name STRING COMMENT 'Step or task name',
    source_layer STRING COMMENT 'Source layer (bronze, silver, gold)',
    target_layer STRING COMMENT 'Target layer',
    start_time TIMESTAMP COMMENT 'Run start time',
    end_time TIMESTAMP COMMENT 'Run end time',
    rows_processed BIGINT COMMENT 'Rows successfully processed',
    rows_failed BIGINT COMMENT 'Rows failed validation',
    status STRING COMMENT 'SUCCESS, FAILED, PARTIAL',
    error_message STRING COMMENT 'Error detail if failed',
    created_at TIMESTAMP COMMENT 'Row insert time' DEFAULT current_timestamp()
) USING DELTA COMMENT 'Pipeline execution audit; populate from orchestration for observability.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported',
    'delta.enableChangeDataFeed' = 'true'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/silver/_metadata_quality_checks.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Data quality check results
CREATE OR REPLACE TABLE pharmacy.silver._metadata_quality_checks (
    table_name STRING NOT NULL COMMENT 'Table or dataset evaluated',
    check_type STRING COMMENT 'Rule or check category',
    check_description STRING COMMENT 'Human-readable description',
    passed BOOLEAN COMMENT 'Whether the check passed',
    rows_checked BIGINT COMMENT 'Population evaluated',
    rows_failed BIGINT COMMENT 'Rows failing the rule',
    check_timestamp TIMESTAMP COMMENT 'When the check ran' DEFAULT current_timestamp(),
    details STRING COMMENT 'JSON or text details'
) USING DELTA COMMENT 'Stores outcomes of Great Expectations / DQ jobs for governance dashboards.' TBLPROPERTIES (
    'delta.feature.allowColumnDefaults' = 'supported'
);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/dim_patient.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold patient dimension (consumption layer)
CREATE OR REPLACE TABLE pharmacy.gold.dim_patient
USING DELTA
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true'
)
AS
SELECT
    sk_patient_id,
    patient_external_id,
    first_name,
    last_name,
    date_of_birth,
    age,
    gender,
    ethnicity,
    state,
    zip_code,
    enrollment_date,
    primary_rare_disease,
    secondary_conditions,
    is_active,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_patient_cleansed;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/dim_medication.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold medication dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_medication
USING DELTA
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true'
)
AS
SELECT
    sk_medication_id,
    ndc_code,
    medication_name,
    generic_name,
    manufacturer,
    rare_disease_indication,
    orphan_drug_designation,
    fda_approval_date,
    dosage_form,
    strength,
    route_of_administration,
    storage_requirements,
    avg_wholesale_price,
    is_active,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_medication_cleansed;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/dim_prescriber.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold prescriber dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_prescriber
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
FROM pharmacy.silver.dim_prescriber_cleansed;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/dim_payer.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold payer dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_payer
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_payer_id,
    payer_external_id,
    payer_name,
    payer_type,
    bin_number,
    pcn_number,
    group_number,
    contact_phone,
    specialty_pharmacy_network,
    is_active,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_payer_cleansed;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/dim_date.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold date dimension
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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/dim_care_team_member.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_care_team_member_cleansed;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/fact_prescription.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold prescription fact + physical optimization
CREATE OR REPLACE TABLE pharmacy.gold.fact_prescription
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_prescription_id,
    prescription_external_id,
    sk_patient_id,
    sk_medication_id,
    sk_prescriber_id,
    sk_payer_id,
    sk_written_date_id,
    sk_filled_date_id,
    written_date,
    filled_date,
    days_to_fill,
    quantity_prescribed,
    days_supply,
    refills,
    copay,
    insurance_paid,
    total_cost,
    is_filled,
    is_rejected,
    rejection_reason,
    created_date,
    updated_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_prescription_cleansed;

OPTIMIZE pharmacy.gold.fact_prescription ZORDER BY (sk_patient_id, written_date);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/fact_adherence.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold adherence fact
CREATE OR REPLACE TABLE pharmacy.gold.fact_adherence
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_adherence_id,
    sk_prescription_id,
    sk_patient_id,
    sk_medication_id,
    measurement_period_start_date,
    measurement_period_end_date,
    period_days,
    days_supplied,
    days_covered,
    gaps_count,
    pdc_ratio,
    mpf_ratio,
    refills_count,
    adherence_status,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_adherence_cleansed;

OPTIMIZE pharmacy.gold.fact_adherence ZORDER BY (sk_patient_id, measurement_period_start_date);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/fact_clinical_interaction.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold clinical interaction fact
CREATE OR REPLACE TABLE pharmacy.gold.fact_clinical_interaction
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_interaction_id,
    sk_patient_id,
    sk_prescription_id,
    sk_care_team_member_id,
    sk_interaction_date_id,
    interaction_date,
    interaction_type,
    interaction_mode,
    duration_minutes,
    interaction_notes,
    outcome,
    patient_satisfaction_score,
    follow_up_required,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_clinical_interaction_cleansed;

OPTIMIZE pharmacy.gold.fact_clinical_interaction ZORDER BY (sk_patient_id, interaction_date);


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/fact_shipment.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/gold/fact_last_event.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Gold last-event snapshot fact
CREATE OR REPLACE TABLE pharmacy.gold.fact_last_event
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_event_id,
    sk_prescription_id,
    sk_patient_id,
    sk_assigned_date_id,
    last_event_assigned_date,
    last_event_type,
    last_event_description,
    last_event_category,
    event_priority,
    assigned_to_user_id,
    resolution_date,
    days_to_resolution,
    is_resolved,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.fact_last_event_cleansed;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_patients_by_state.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Analytic view: patient counts by state (BI)
CREATE OR REPLACE VIEW pharmacy.gold.v_patients_by_state AS
SELECT
    p.state,
    COUNT(DISTINCT p.sk_patient_id) AS total_patients,
    COUNT(DISTINCT CASE WHEN p.is_active THEN p.sk_patient_id END) AS active_patients,
    COUNT(DISTINCT p.primary_rare_disease) AS disease_count,
    ROUND(AVG(p.age), 1) AS avg_age
FROM pharmacy.gold.dim_patient p
WHERE p.state IS NOT NULL
GROUP BY p.state;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_prescription_metrics.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Analytic view: prescription metrics by medication
CREATE OR REPLACE VIEW pharmacy.gold.v_prescription_metrics AS
SELECT
    m.ndc_code,
    m.medication_name,
    m.manufacturer,
    COUNT(DISTINCT f.sk_prescription_id) AS total_prescriptions,
    SUM(CASE WHEN f.is_filled THEN 1 ELSE 0 END) AS filled_count,
    SUM(CASE WHEN f.is_rejected THEN 1 ELSE 0 END) AS rejected_count,
    ROUND(
        SUM(CASE WHEN f.is_filled THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS fill_rate_pct,
    ROUND(SUM(f.total_cost), 2) AS total_revenue,
    ROUND(AVG(f.days_to_fill), 1) AS avg_days_to_fill
FROM pharmacy.gold.fact_prescription f
INNER JOIN pharmacy.gold.dim_medication m
    ON f.sk_medication_id = m.sk_medication_id
WHERE f.written_date >= date_sub(current_date(), 365)
GROUP BY m.ndc_code, m.medication_name, m.manufacturer;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_patient_adherence.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Analytic view: adherence summary by patient
CREATE OR REPLACE VIEW pharmacy.gold.v_patient_adherence AS
SELECT
    p.sk_patient_id,
    p.patient_external_id,
    p.first_name,
    p.last_name,
    COUNT(DISTINCT a.sk_medication_id) AS medication_count,
    ROUND(AVG(a.pdc_ratio), 4) AS avg_pdc,
    COUNT(DISTINCT CASE WHEN a.adherence_status = 'Adherent' THEN a.sk_medication_id END) AS adherent_medications,
    COUNT(DISTINCT CASE WHEN a.adherence_status = 'Non-Adherent' THEN a.sk_medication_id END) AS non_adherent_medications,
    ROUND(AVG(a.gaps_count), 1) AS avg_gaps
FROM pharmacy.gold.fact_adherence a
INNER JOIN pharmacy.gold.dim_patient p
    ON a.sk_patient_id = p.sk_patient_id
WHERE a.measurement_period_end_date >= date_sub(current_date(), 90)
GROUP BY p.sk_patient_id, p.patient_external_id, p.first_name, p.last_name;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_prescriber_performance.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Analytic view: prescriber performance metrics
CREATE OR REPLACE VIEW pharmacy.gold.v_prescriber_performance AS
SELECT
    pr.sk_prescriber_id,
    pr.npi_number,
    pr.first_name,
    pr.last_name,
    pr.specialty,
    COUNT(DISTINCT f.sk_prescription_id) AS total_prescriptions,
    ROUND(
        SUM(CASE WHEN f.is_filled THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS fill_rate_pct,
    ROUND(AVG(f.days_to_fill), 1) AS avg_days_to_fill,
    ROUND(SUM(f.total_cost), 2) AS total_revenue,
    COUNT(DISTINCT f.sk_patient_id) AS unique_patients
FROM pharmacy.gold.fact_prescription f
INNER JOIN pharmacy.gold.dim_prescriber pr
    ON f.sk_prescriber_id = pr.sk_prescriber_id
WHERE f.written_date >= date_sub(current_date(), 365)
GROUP BY pr.sk_prescriber_id, pr.npi_number, pr.first_name, pr.last_name, pr.specialty;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_shipment_analysis.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Analytic view: shipment volume and performance by period
CREATE OR REPLACE VIEW pharmacy.gold.v_shipment_analysis AS
SELECT
    YEAR(s.ship_date) AS ship_year,
    MONTH(s.ship_date) AS ship_month,
    s.carrier_name,
    COUNT(DISTINCT s.sk_shipment_id) AS total_shipments,
    ROUND(AVG(s.delivery_days), 1) AS avg_delivery_days,
    COUNT(DISTINCT CASE WHEN s.exception_flag THEN s.sk_shipment_id END) AS exception_count,
    ROUND(SUM(s.shipping_cost), 2) AS total_shipping_cost
FROM pharmacy.gold.fact_shipment s
WHERE s.ship_date >= date_sub(current_date(), 365)
GROUP BY YEAR(s.ship_date), MONTH(s.ship_date), s.carrier_name;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_data_integrity_check.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: Referential integrity checks (orphan keys in gold fact_prescription)
CREATE OR REPLACE VIEW pharmacy.gold.v_data_integrity_check AS
SELECT
    'fact_prescription' AS table_name,
    'Missing Patients' AS check_type,
    COUNT(*) AS invalid_records
FROM pharmacy.gold.fact_prescription f
WHERE NOT EXISTS (
    SELECT 1 FROM pharmacy.gold.dim_patient d WHERE d.sk_patient_id = f.sk_patient_id
)
UNION ALL
SELECT
    'fact_prescription',
    'Missing Medications',
    COUNT(*)
FROM pharmacy.gold.fact_prescription f
WHERE NOT EXISTS (
    SELECT 1 FROM pharmacy.gold.dim_medication d WHERE d.sk_medication_id = f.sk_medication_id
)
UNION ALL
SELECT
    'fact_prescription',
    'Missing Prescribers',
    COUNT(*)
FROM pharmacy.gold.fact_prescription f
WHERE NOT EXISTS (
    SELECT 1 FROM pharmacy.gold.dim_prescriber d WHERE d.sk_prescriber_id = f.sk_prescriber_id
)
UNION ALL
SELECT
    'fact_prescription',
    'Invalid Dates',
    COUNT(*)
FROM pharmacy.gold.fact_prescription f
WHERE f.filled_date IS NOT NULL AND f.written_date IS NOT NULL AND f.filled_date < f.written_date;


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: pipelines/src_databricks/views/v_data_statistics.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: High-level row counts and freshness by entity
CREATE OR REPLACE VIEW pharmacy.gold.v_data_statistics AS
SELECT
    'Patients' AS entity,
    COUNT(*) AS total_records,
    COUNT(DISTINCT DATE(created_date)) AS distinct_creation_dates,
    MAX(created_date) AS last_update
FROM pharmacy.gold.dim_patient
UNION ALL
SELECT
    'Medications',
    COUNT(*),
    COUNT(DISTINCT DATE(created_date)),
    MAX(created_date)
FROM pharmacy.gold.dim_medication
UNION ALL
SELECT
    'Prescriptions',
    COUNT(*),
    COUNT(DISTINCT DATE(created_date)),
    MAX(created_date)
FROM pharmacy.gold.fact_prescription
UNION ALL
SELECT
    'Shipments',
    COUNT(*),
    COUNT(DISTINCT DATE(created_date)),
    MAX(created_date)
FROM pharmacy.gold.fact_shipment;
