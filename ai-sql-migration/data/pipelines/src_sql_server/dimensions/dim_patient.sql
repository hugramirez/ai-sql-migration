-- Run order: im_patient
-- Grain: One row per unique patient
-- SCD Type: Type 1

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

    CREATE INDEX idx_dim_patient_external_id ON dbo.dim_patient(patient_external_id);
    CREATE INDEX idx_dim_patient_active ON dbo.dim_patient(is_active);

    PRINT 'dim_patient';
END
GO
