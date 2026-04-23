-- Run order: fact_clinical_interaction
-- Grain: One row per interaction event
-- Fact Type: Additive

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

    PRINT 'fact_clinical_interaction';
END
GO
