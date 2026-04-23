WITH
    patient_spending AS (
        SELECT
            rx.sk_patient_id,
            rx.sk_medication_id,
            SUM(rx.total_cost) AS total_spent,
            COUNT(*) AS num_rx,
            ROW_NUMBER() OVER (
                PARTITION BY
                    rx.sk_patient_id
                ORDER BY SUM(rx.total_cost) DESC
            ) AS rn
        FROM dbo.fact_prescription rx
        GROUP BY
            rx.sk_patient_id,
            rx.sk_medication_id
    )
SELECT
    p.first_name + ' ' + p.last_name AS patient_name,
    p.primary_rare_disease,
    p.state,
    m.medication_name,
    ps.num_rx AS prescriptions_count,
    ps.total_spent
FROM
    patient_spending ps
    JOIN dbo.dim_patient p ON ps.sk_patient_id = p.sk_patient_id
    JOIN dbo.dim_medication m ON ps.sk_medication_id = m.sk_medication_id
WHERE
    ps.rn = 1
ORDER BY ps.total_spent DESC
OFFSET
    0 ROWS FETCH NEXT 20 ROWS ONLY;