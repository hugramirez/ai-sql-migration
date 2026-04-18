-- Run order: 96 — High-level row counts and freshness by entity
CREATE OR REPLACE VIEW pharmacy.gold.v_data_statistics AS
SELECT
    'Patients' AS entity,
    COUNT(*) AS total_records,
    COUNT(DISTINCT DATE(created_date)) AS distinct_creation_dates,
    MAX(created_date) AS last_update
FROM pharmacy.gold.dim_patient
UNION ALL
SELECT
    'Medications',
    COUNT(*),
    COUNT(DISTINCT DATE(created_date)),
    MAX(created_date)
FROM pharmacy.gold.dim_medication
UNION ALL
SELECT
    'Prescriptions',
    COUNT(*),
    COUNT(DISTINCT DATE(created_date)),
    MAX(created_date)
FROM pharmacy.gold.fact_prescription
UNION ALL
SELECT
    'Shipments',
    COUNT(*),
    COUNT(DISTINCT DATE(created_date)),
    MAX(created_date)
FROM pharmacy.gold.fact_shipment;
