-- Run order: fact_prescription (PRIMARY HUB)
-- Grain: One row per prescription filled
-- Fact Type: Additive

USE localuc_db;
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

    PRINT 'fact_prescription (HUB)';
END
GO
