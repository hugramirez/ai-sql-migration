-- Run order: 91 — Analytic view: prescription metrics by medication
CREATE OR REPLACE VIEW pharmacy.gold.v_prescription_metrics AS
SELECT
    m.ndc_code,
    m.medication_name,
    m.manufacturer,
    COUNT(DISTINCT f.sk_prescription_id) AS total_prescriptions,
    SUM(CASE WHEN f.is_filled THEN 1 ELSE 0 END) AS filled_count,
    SUM(CASE WHEN f.is_rejected THEN 1 ELSE 0 END) AS rejected_count,
    ROUND(
        SUM(CASE WHEN f.is_filled THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS fill_rate_pct,
    ROUND(SUM(f.total_cost), 2) AS total_revenue,
    ROUND(AVG(f.days_to_fill), 1) AS avg_days_to_fill
FROM pharmacy.gold.fact_prescription f
INNER JOIN pharmacy.gold.dim_medication m
    ON f.sk_medication_id = m.sk_medication_id
WHERE f.written_date >= date_sub(current_date(), 365)
GROUP BY m.ndc_code, m.medication_name, m.manufacturer;
