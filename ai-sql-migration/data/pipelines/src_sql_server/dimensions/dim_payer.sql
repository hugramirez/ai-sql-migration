-- Run order: dim_payer
-- Grain: One row per payer/plan
-- SCD Type: Type 1

USE localdb;
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

    PRINT 'dim_payer';
END
GO
