-- ============================================================================
-- Pharmacy platform — SQL Server Implementation
--
-- Single batch script. Canonical sources live under:
--   schemas/  dimensions/  facts/
--
-- After editing any modular .sql file, refresh this file by concatenating
-- those scripts in dependency order (same order as listed in SOURCE SECTION
-- markers below).
--
-- Database: pharmacy_db
-- Schema: dbo
-- ============================================================================


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: schemas/00_schema.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'pharmacy_db')
BEGIN
    CREATE DATABASE pharmacy_db
        COLLATE SQL_Latin1_General_CP1_CI_AS;
END
GO

USE pharmacy_db;
GO

EXEC sp_updateextendedproperty
    @name = N'Description',
    @value = N'Pharmacy Comprehensive Platform - dimensional model for pharmacy management',
    @level0type = N'SCHEMA',
    @level0name = N'dbo';
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: dimensions/01_dim_patient.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 01 — dim_patient (one row per patient; SCD Type 1 - current state only)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_patient' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.dim_patient (
        sk_patient_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        patient_external_id varchar(50) NOT NULL UNIQUE,
        first_name varchar(100) NOT NULL,
        last_name varchar(100) NOT NULL,
        date_of_birth date NOT NULL,
        age int,
        gender varchar(20),
        ethnicity varchar(50),
        state varchar(2),
        zip_code varchar(10),
        enrollment_date date NOT NULL,
        primary_rare_disease varchar(200),
        secondary_conditions varchar(500),
        is_active bit NOT NULL DEFAULT 1,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE()
    );

    DROP INDEX IF EXISTS idx_dim_patient_external_id ON dbo.dim_patient; CREATE INDEX idx_dim_patient_external_id ON dbo.dim_patient(patient_external_id);
    DROP INDEX IF EXISTS idx_dim_patient_active ON dbo.dim_patient; CREATE INDEX idx_dim_patient_active ON dbo.dim_patient(is_active);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: dimensions/02_dim_medication.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 02 — dim_medication (one row per NDC code; SCD Type 1 - prices update in place)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_medication' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.dim_medication (
        sk_medication_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        ndc_code varchar(20) NOT NULL UNIQUE,
        medication_name varchar(200) NOT NULL,
        generic_name varchar(200),
        manufacturer varchar(200),
        rare_disease_indication varchar(200),
        orphan_drug_designation bit NOT NULL DEFAULT 0,
        fda_approval_date date,
        dosage_form varchar(50),
        strength varchar(50),
        route_of_administration varchar(50),
        storage_requirements varchar(200),
        avg_wholesale_price numeric(10,2),
        is_active bit NOT NULL DEFAULT 1,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE()
    );

    DROP INDEX IF EXISTS idx_dim_medication_ndc ON dbo.dim_medication; CREATE INDEX idx_dim_medication_ndc ON dbo.dim_medication(ndc_code);
    DROP INDEX IF EXISTS idx_dim_medication_active ON dbo.dim_medication; CREATE INDEX idx_dim_medication_active ON dbo.dim_medication(is_active);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: dimensions/03_dim_prescriber.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 03 — dim_prescriber (one row per NPI; SCD Type 2 - track specialty/location changes)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_prescriber' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.dim_prescriber (
        sk_prescriber_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        npi_number varchar(20) NOT NULL UNIQUE,
        first_name varchar(100) NOT NULL,
        last_name varchar(100) NOT NULL,
        specialty varchar(100),
        sub_specialty varchar(100),
        practice_name varchar(200),
        address_line1 varchar(200),
        city varchar(100),
        state varchar(2),
        zip_code varchar(10),
        phone varchar(20),
        years_experience int,
        is_active bit NOT NULL DEFAULT 1,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE()
    );

    DROP INDEX IF EXISTS idx_dim_prescriber_npi ON dbo.dim_prescriber; CREATE INDEX idx_dim_prescriber_npi ON dbo.dim_prescriber(npi_number);
    DROP INDEX IF EXISTS idx_dim_prescriber_active ON dbo.dim_prescriber; CREATE INDEX idx_dim_prescriber_active ON dbo.dim_prescriber(is_active);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: dimensions/04_dim_payer.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 04 — dim_payer (one row per payer/plan; SCD Type 1 - attributes update in place)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_payer' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.dim_payer (
        sk_payer_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        payer_external_id varchar(50) NOT NULL UNIQUE,
        payer_name varchar(200) NOT NULL,
        payer_type varchar(50),
        bin_number varchar(10),
        pcn_number varchar(20),
        group_number varchar(50),
        contact_phone varchar(20),
        specialty_pharmacy_network bit NOT NULL DEFAULT 0,
        is_active bit NOT NULL DEFAULT 1,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE()
    );

    DROP INDEX IF EXISTS idx_dim_payer_external_id ON dbo.dim_payer; CREATE INDEX idx_dim_payer_external_id ON dbo.dim_payer(payer_external_id);
    DROP INDEX IF EXISTS idx_dim_payer_active ON dbo.dim_payer; CREATE INDEX idx_dim_payer_active ON dbo.dim_payer(is_active);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: dimensions/05_dim_date.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 05 — dim_date (conformed date dimension; one row per calendar date)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_date' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.dim_date (
        sk_date_id int NOT NULL PRIMARY KEY,
        full_date date NOT NULL UNIQUE,
        day_of_week int,
        day_name varchar(10),
        day_of_month int,
        day_of_year int,
        week_of_year int,
        month_num int,
        month_name varchar(10),
        quarter int,
        year int,
        is_weekend bit,
        is_holiday bit
    );

    DROP INDEX IF EXISTS idx_dim_date_full_date ON dbo.dim_date; CREATE INDEX idx_dim_date_full_date ON dbo.dim_date(full_date);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: dimensions/06_dim_care_team_member.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 06 — dim_care_team_member (one row per employee; SCD Type 1 - attributes update in place)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_care_team_member' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.dim_care_team_member (
        sk_care_team_member_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        employee_id varchar(50) NOT NULL UNIQUE,
        first_name varchar(100) NOT NULL,
        last_name varchar(100) NOT NULL,
        role varchar(100),
        disease_specialty varchar(200),
        hire_date date,
        is_active bit NOT NULL DEFAULT 1,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE()
    );

    DROP INDEX IF EXISTS idx_dim_care_team_member_employee_id ON dbo.dim_care_team_member; CREATE INDEX idx_dim_care_team_member_employee_id ON dbo.dim_care_team_member(employee_id);
    DROP INDEX IF EXISTS idx_dim_care_team_member_active ON dbo.dim_care_team_member; CREATE INDEX idx_dim_care_team_member_active ON dbo.dim_care_team_member(is_active);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: facts/01_fact_prescription.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 07 — fact_prescription (primary hub; one row per prescription; Fact Type: Additive)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_prescription' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.fact_prescription (
        sk_prescription_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        prescription_external_id varchar(50) NOT NULL UNIQUE,
        sk_patient_id bigint NOT NULL,
        sk_medication_id bigint NOT NULL,
        sk_prescriber_id bigint NOT NULL,
        sk_payer_id bigint NOT NULL,
        sk_written_date_id int NOT NULL,
        sk_filled_date_id int NOT NULL,
        written_date date NOT NULL,
        filled_date date NOT NULL,
        quantity_prescribed numeric(10,2) NOT NULL,
        days_supply int,
        refills_authorized int,
        refills_remaining int,
        copay_amount numeric(10,2),
        insurance_paid_amount numeric(12,2),
        total_cost numeric(12,2),
        prescription_status varchar(50),
        therapy_type varchar(50),
        is_specialty bit DEFAULT 0,
        is_controlled_substance bit DEFAULT 0,
        prior_authorization_required bit DEFAULT 0,
        prior_authorization_approved bit DEFAULT 0,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT fk_fact_prescription_patient FOREIGN KEY (sk_patient_id) REFERENCES dbo.dim_patient(sk_patient_id),
        CONSTRAINT fk_fact_prescription_medication FOREIGN KEY (sk_medication_id) REFERENCES dbo.dim_medication(sk_medication_id),
        CONSTRAINT fk_fact_prescription_prescriber FOREIGN KEY (sk_prescriber_id) REFERENCES dbo.dim_prescriber(sk_prescriber_id),
        CONSTRAINT fk_fact_prescription_payer FOREIGN KEY (sk_payer_id) REFERENCES dbo.dim_payer(sk_payer_id),
        CONSTRAINT fk_fact_prescription_written_date FOREIGN KEY (sk_written_date_id) REFERENCES dbo.dim_date(sk_date_id),
        CONSTRAINT fk_fact_prescription_filled_date FOREIGN KEY (sk_filled_date_id) REFERENCES dbo.dim_date(sk_date_id)
    );

    DROP INDEX IF EXISTS idx_fact_prescription_patient ON dbo.fact_prescription; CREATE INDEX idx_fact_prescription_patient ON dbo.fact_prescription(sk_patient_id);
    DROP INDEX IF EXISTS idx_fact_prescription_medication ON dbo.fact_prescription; CREATE INDEX idx_fact_prescription_medication ON dbo.fact_prescription(sk_medication_id);
    DROP INDEX IF EXISTS idx_fact_prescription_prescriber ON dbo.fact_prescription; CREATE INDEX idx_fact_prescription_prescriber ON dbo.fact_prescription(sk_prescriber_id);
    DROP INDEX IF EXISTS idx_fact_prescription_payer ON dbo.fact_prescription; CREATE INDEX idx_fact_prescription_payer ON dbo.fact_prescription(sk_payer_id);
    DROP INDEX IF EXISTS idx_fact_prescription_filled_date ON dbo.fact_prescription; CREATE INDEX idx_fact_prescription_filled_date ON dbo.fact_prescription(sk_filled_date_id);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: facts/02_fact_adherence.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 08 — fact_adherence (one row per patient-prescription-measurement period; Fact Type: Semi-additive)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_adherence' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.fact_adherence (
        sk_adherence_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        sk_patient_id bigint NOT NULL,
        sk_prescription_id bigint NOT NULL,
        sk_measurement_date_id int NOT NULL,
        measurement_date date NOT NULL,
        measurement_period varchar(20),
        pdc_proportion_days_covered numeric(5,2),
        mpf_medication_possession_ratio numeric(5,2),
        gaps_in_therapy_days int,
        missed_refills_count int,
        on_time_refills_count int,
        patient_reported_adherence varchar(50),
        barriers_to_adherence varchar(500),
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT fk_fact_adherence_patient FOREIGN KEY (sk_patient_id) REFERENCES dbo.dim_patient(sk_patient_id),
        CONSTRAINT fk_fact_adherence_prescription FOREIGN KEY (sk_prescription_id) REFERENCES dbo.fact_prescription(sk_prescription_id),
        CONSTRAINT fk_fact_adherence_measurement_date FOREIGN KEY (sk_measurement_date_id) REFERENCES dbo.dim_date(sk_date_id)
    );

    DROP INDEX IF EXISTS idx_fact_adherence_patient ON dbo.fact_adherence; CREATE INDEX idx_fact_adherence_patient ON dbo.fact_adherence(sk_patient_id);
    DROP INDEX IF EXISTS idx_fact_adherence_prescription ON dbo.fact_adherence; CREATE INDEX idx_fact_adherence_prescription ON dbo.fact_adherence(sk_prescription_id);
    DROP INDEX IF EXISTS idx_fact_adherence_measurement_date ON dbo.fact_adherence; CREATE INDEX idx_fact_adherence_measurement_date ON dbo.fact_adherence(sk_measurement_date_id);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: facts/03_fact_clinical_interaction.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 09 — fact_clinical_interaction (one row per interaction event; Fact Type: Additive)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_clinical_interaction' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.fact_clinical_interaction (
        sk_interaction_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        sk_patient_id bigint NOT NULL,
        sk_prescription_id bigint,
        sk_care_team_member_id bigint NOT NULL,
        sk_interaction_date_id int NOT NULL,
        interaction_date datetime2(3) NOT NULL,
        interaction_type varchar(100),
        interaction_purpose varchar(200),
        duration_minutes int,
        patient_satisfaction_score int,
        outcome_description varchar(500),
        follow_up_required bit DEFAULT 0,
        follow_up_date date,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT fk_fact_clinical_interaction_patient FOREIGN KEY (sk_patient_id) REFERENCES dbo.dim_patient(sk_patient_id),
        CONSTRAINT fk_fact_clinical_interaction_prescription FOREIGN KEY (sk_prescription_id) REFERENCES dbo.fact_prescription(sk_prescription_id),
        CONSTRAINT fk_fact_clinical_interaction_care_team FOREIGN KEY (sk_care_team_member_id) REFERENCES dbo.dim_care_team_member(sk_care_team_member_id),
        CONSTRAINT fk_fact_clinical_interaction_date FOREIGN KEY (sk_interaction_date_id) REFERENCES dbo.dim_date(sk_date_id)
    );

    DROP INDEX IF EXISTS idx_fact_clinical_interaction_patient ON dbo.fact_clinical_interaction; CREATE INDEX idx_fact_clinical_interaction_patient ON dbo.fact_clinical_interaction(sk_patient_id);
    DROP INDEX IF EXISTS idx_fact_clinical_interaction_care_team ON dbo.fact_clinical_interaction; CREATE INDEX idx_fact_clinical_interaction_care_team ON dbo.fact_clinical_interaction(sk_care_team_member_id);
    DROP INDEX IF EXISTS idx_fact_clinical_interaction_date ON dbo.fact_clinical_interaction; CREATE INDEX idx_fact_clinical_interaction_date ON dbo.fact_clinical_interaction(sk_interaction_date_id);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: facts/04_fact_shipment.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 10 — fact_shipment (one row per shipment; Fact Type: Additive)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_shipment' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.fact_shipment (
        sk_shipment_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        shipment_external_id varchar(50) NOT NULL UNIQUE,
        sk_prescription_id bigint NOT NULL,
        sk_patient_id bigint NOT NULL,
        sk_ship_date_id int NOT NULL,
        sk_delivery_date_id int,
        ship_date date NOT NULL,
        estimated_delivery_date date,
        actual_delivery_date date,
        carrier varchar(50),
        tracking_number varchar(100),
        shipment_method varchar(50),
        temperature_controlled bit DEFAULT 0,
        signature_required bit DEFAULT 0,
        shipment_status varchar(50),
        delivery_exception_reason varchar(200),
        shipping_cost numeric(10,2),
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT fk_fact_shipment_prescription FOREIGN KEY (sk_prescription_id) REFERENCES dbo.fact_prescription(sk_prescription_id),
        CONSTRAINT fk_fact_shipment_patient FOREIGN KEY (sk_patient_id) REFERENCES dbo.dim_patient(sk_patient_id),
        CONSTRAINT fk_fact_shipment_ship_date FOREIGN KEY (sk_ship_date_id) REFERENCES dbo.dim_date(sk_date_id),
        CONSTRAINT fk_fact_shipment_delivery_date FOREIGN KEY (sk_delivery_date_id) REFERENCES dbo.dim_date(sk_date_id)
    );

    DROP INDEX IF EXISTS idx_fact_shipment_prescription ON dbo.fact_shipment; CREATE INDEX idx_fact_shipment_prescription ON dbo.fact_shipment(sk_prescription_id);
    DROP INDEX IF EXISTS idx_fact_shipment_patient ON dbo.fact_shipment; CREATE INDEX idx_fact_shipment_patient ON dbo.fact_shipment(sk_patient_id);
    DROP INDEX IF EXISTS idx_fact_shipment_ship_date ON dbo.fact_shipment; CREATE INDEX idx_fact_shipment_ship_date ON dbo.fact_shipment(sk_ship_date_id);

END
GO


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- SOURCE SECTION: facts/05_fact_last_event.sql
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-- Run order: 11 — fact_last_event (one row per prescription; Fact Type: Snapshot - current state only)

USE pharmacy_db;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_last_event' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.fact_last_event (
        sk_event_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        sk_prescription_id bigint NOT NULL UNIQUE,
        sk_patient_id bigint NOT NULL,
        sk_assigned_date_id int NOT NULL,
        last_event_assigned_date datetime2(3) NOT NULL,
        last_event_type varchar(100),
        last_event_description varchar(500),
        last_event_category varchar(50),
        event_priority varchar(20),
        assigned_to_user_id varchar(50),
        resolution_date datetime2(3),
        is_resolved bit DEFAULT 0,
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT fk_fact_last_event_prescription FOREIGN KEY (sk_prescription_id) REFERENCES dbo.fact_prescription(sk_prescription_id),
        CONSTRAINT fk_fact_last_event_patient FOREIGN KEY (sk_patient_id) REFERENCES dbo.dim_patient(sk_patient_id),
        CONSTRAINT fk_fact_last_event_assigned_date FOREIGN KEY (sk_assigned_date_id) REFERENCES dbo.dim_date(sk_date_id)
    );

    DROP INDEX IF EXISTS idx_fact_last_event_prescription ON dbo.fact_last_event; CREATE INDEX idx_fact_last_event_prescription ON dbo.fact_last_event(sk_prescription_id);
    DROP INDEX IF EXISTS idx_fact_last_event_patient ON dbo.fact_last_event; CREATE INDEX idx_fact_last_event_patient ON dbo.fact_last_event(sk_patient_id);
    DROP INDEX IF EXISTS idx_fact_last_event_resolved ON dbo.fact_last_event; CREATE INDEX idx_fact_last_event_resolved ON dbo.fact_last_event(is_resolved);

END
GO