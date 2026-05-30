-- Run order: dim_date
-- Grain: One row per calendar date
-- Conformed dimension (all timestamps use this)

USE localuc_db;
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

    PRINT 'dim_date';
END
GO
