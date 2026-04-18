-- Run order: 90 — Analytic view: patient counts by state (BI)
CREATE OR REPLACE VIEW pharmacy.gold.v_patients_by_state AS
SELECT
    p.state,
    COUNT(DISTINCT p.sk_patient_id) AS total_patients,
    COUNT(DISTINCT CASE WHEN p.is_active THEN p.sk_patient_id END) AS active_patients,
    COUNT(DISTINCT p.primary_rare_disease) AS disease_count,
    ROUND(AVG(p.age), 1) AS avg_age
FROM pharmacy.gold.dim_patient p
WHERE p.state IS NOT NULL
GROUP BY p.state;
