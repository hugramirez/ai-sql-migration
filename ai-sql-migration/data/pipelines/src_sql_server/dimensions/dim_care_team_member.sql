-- Run order: dim_care_team_member
-- Grain: One row per unique employee
-- SCD Type: Type 1

USE localdb;
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

    PRINT 'dim_care_team_member';
END
GO
