-- Run order: 24 — Silver payer (latest row per payer_external_id)
CREATE OR REPLACE TABLE pharmacy.silver.dim_payer_cleansed
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_payer_id,
    payer_external_id,
    TRIM(payer_name) AS payer_name,
    payer_type,
    bin_number,
    pcn_number,
    group_number,
    contact_phone,
    specialty_pharmacy_network,
    COALESCE(is_active, TRUE) AS is_active,
    created_date,
    MD5(CONCAT(payer_external_id, payer_name)) AS _record_hash,
    current_timestamp() AS _silver_processed_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY payer_external_id ORDER BY created_date DESC NULLS LAST) AS _row_num
    FROM pharmacy.bronze.raw_dim_payer
) ranked
WHERE ranked._row_num = 1;
