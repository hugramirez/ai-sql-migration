-- Run order: 93 — Analytic view: prescriber performance metrics
CREATE OR REPLACE VIEW pharmacy.gold.v_prescriber_performance AS
SELECT
    pr.sk_prescriber_id,
    pr.npi_number,
    pr.first_name,
    pr.last_name,
    pr.specialty,
    COUNT(DISTINCT f.sk_prescription_id) AS total_prescriptions,
    ROUND(
        SUM(CASE WHEN f.is_filled THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS fill_rate_pct,
    ROUND(AVG(f.days_to_fill), 1) AS avg_days_to_fill,
    ROUND(SUM(f.total_cost), 2) AS total_revenue,
    COUNT(DISTINCT f.sk_patient_id) AS unique_patients
FROM pharmacy.gold.fact_prescription f
INNER JOIN pharmacy.gold.dim_prescriber pr
    ON f.sk_prescriber_id = pr.sk_prescriber_id
WHERE f.written_date >= date_sub(current_date(), 365)
GROUP BY pr.sk_prescriber_id, pr.npi_number, pr.first_name, pr.last_name, pr.specialty;
