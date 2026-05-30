-- Run order: 08 — fact_adherence
-- Grain: One row per patient-prescription-measurement period
-- Fact Type: Semi-additive

USE localdb;
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

    PRINT 'fact_adherence';
END
GO
