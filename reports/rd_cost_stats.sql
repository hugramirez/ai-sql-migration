SELECT
    m.rare_disease_indication,
    COUNT(fp.sk_prescription_id) AS total_prescriptions,
    SUM(fp.total_cost) AS total_spend,
    AVG(fp.total_cost) AS avg_cost_per_rx,
    AVG(fp.copay_amount) AS avg_patient_copay,
    AVG(fp.insurance_paid_amount) AS avg_insurance_paid
FROM dbo.fact_prescription fp
    INNER JOIN dbo.dim_medication m ON m.sk_medication_id = fp.sk_medication_id
WHERE
    fp.prescription_status NOT IN('Discontinued')
GROUP BY
    m.rare_disease_indication
ORDER BY total_spend DESC;