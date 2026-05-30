-- Run order: Analytic view: adherence summary by patient
CREATE OR REPLACE VIEW localuc.gold.v_patient_adherence AS
SELECT
    p.sk_patient_id,
    p.patient_external_id,
    p.first_name,
    p.last_name,
    COUNT(DISTINCT a.sk_medication_id) AS medication_count,
    ROUND(AVG(a.pdc_ratio), 4) AS avg_pdc,
    COUNT(DISTINCT CASE WHEN a.adherence_status = 'Adherent' THEN a.sk_medication_id END) AS adherent_medications,
    COUNT(DISTINCT CASE WHEN a.adherence_status = 'Non-Adherent' THEN a.sk_medication_id END) AS non_adherent_medications,
    ROUND(AVG(a.gaps_count), 1) AS avg_gaps
FROM localuc.gold.fact_adherence a
INNER JOIN localuc.gold.dim_patient p
    ON a.sk_patient_id = p.sk_patient_id
WHERE a.measurement_period_end_date >= date_sub(current_date(), 90)
GROUP BY p.sk_patient_id, p.patient_external_id, p.first_name, p.last_name;
