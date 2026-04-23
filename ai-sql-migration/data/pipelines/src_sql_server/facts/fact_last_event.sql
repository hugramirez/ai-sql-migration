-- Run order: fact_last_event
-- Grain: One row per prescription (latest event snapshot)
-- Fact Type: Snapshot

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

    PRINT 'fact_last_event';
END
GO
