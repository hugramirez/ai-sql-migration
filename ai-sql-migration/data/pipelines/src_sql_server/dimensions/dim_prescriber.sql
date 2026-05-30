-- Run order: 03 — dim_prescriber
-- Grain: One row per unique NPI
-- SCD Type: Type 2

USE localuc_db;
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

    PRINT 'dim_prescriber';
END
GO
