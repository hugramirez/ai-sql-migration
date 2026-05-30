-- Run order: 10 — fact_shipment
-- Grain: One row per shipment
-- Fact Type: Additive

USE localdb;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_shipment' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.fact_shipment (
        sk_shipment_id bigint NOT NULL PRIMARY KEY IDENTITY(1,1),
        shipment_external_id varchar(50) NOT NULL UNIQUE,
        sk_prescription_id bigint NOT NULL,
        sk_patient_id bigint NOT NULL,
        sk_ship_date_id int NOT NULL,
        sk_delivery_date_id int,
        ship_date date NOT NULL,
        estimated_delivery_date date,
        actual_delivery_date date,
        carrier varchar(50),
        tracking_number varchar(100),
        shipment_method varchar(50),
        temperature_controlled bit DEFAULT 0,
        signature_required bit DEFAULT 0,
        shipment_status varchar(50),
        delivery_exception_reason varchar(200),
        shipping_cost numeric(10,2),
        created_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        updated_date datetime2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT fk_fact_shipment_prescription FOREIGN KEY (sk_prescription_id) REFERENCES dbo.fact_prescription(sk_prescription_id),
        CONSTRAINT fk_fact_shipment_patient FOREIGN KEY (sk_patient_id) REFERENCES dbo.dim_patient(sk_patient_id),
        CONSTRAINT fk_fact_shipment_ship_date FOREIGN KEY (sk_ship_date_id) REFERENCES dbo.dim_date(sk_date_id),
        CONSTRAINT fk_fact_shipment_delivery_date FOREIGN KEY (sk_delivery_date_id) REFERENCES dbo.dim_date(sk_date_id)
    );

    DROP INDEX IF EXISTS idx_fact_shipment_prescription ON dbo.fact_shipment; CREATE INDEX idx_fact_shipment_prescription ON dbo.fact_shipment(sk_prescription_id);
    DROP INDEX IF EXISTS idx_fact_shipment_patient ON dbo.fact_shipment; CREATE INDEX idx_fact_shipment_patient ON dbo.fact_shipment(sk_patient_id);
    DROP INDEX IF EXISTS idx_fact_shipment_ship_date ON dbo.fact_shipment; CREATE INDEX idx_fact_shipment_ship_date ON dbo.fact_shipment(sk_ship_date_id);

    PRINT '✅ fact_shipment';
END
GO
