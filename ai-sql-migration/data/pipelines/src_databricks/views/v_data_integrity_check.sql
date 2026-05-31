-- Run order: Referential integrity checks (orphan keys in gold fact_prescription)
CREATE OR REPLACE VIEW localuc.gold.v_data_integrity_check AS
SELECT
    'fact_prescription' AS table_name,
    'Missing Patients' AS check_type,
    COUNT(*) AS invalid_records
FROM localuc.gold.fact_prescription f
WHERE NOT EXISTS (
    SELECT 1 FROM localuc.gold.dim_patient d WHERE d.sk_patient_id = f.sk_patient_id
)
UNION ALL
SELECT
    'fact_prescription',
    'Missing Medications',
    COUNT(*)
FROM localuc.gold.fact_prescription f
WHERE NOT EXISTS (
    SELECT 1 FROM localuc.gold.dim_medication d WHERE d.sk_medication_id = f.sk_medication_id
)
UNION ALL
SELECT
    'fact_prescription',
    'Missing Prescribers',
    COUNT(*)
FROM localuc.gold.fact_prescription f
WHERE NOT EXISTS (
    SELECT 1 FROM localuc.gold.dim_prescriber d WHERE d.sk_prescriber_id = f.sk_prescriber_id
)
UNION ALL
SELECT
    'fact_prescription',
    'Invalid Dates',
    COUNT(*)
FROM localuc.gold.fact_prescription f
WHERE f.filled_date IS NOT NULL AND f.written_date IS NOT NULL AND f.filled_date < f.written_date;
