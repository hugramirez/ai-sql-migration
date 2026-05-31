-- Run order: dim_medication
-- Grain: One row per unique NDC code
-- SCD Type: Type 1

USE localdb;
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

    CREATE INDEX idx_dim_medication_ndc ON dbo.dim_medication(ndc_code);
    CREATE INDEX idx_dim_medication_active ON dbo.dim_medication(is_active);

    PRINT 'dim_medication';
END
GO
