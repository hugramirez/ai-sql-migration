-- Run order: 43 — Gold payer dimension
CREATE OR REPLACE TABLE pharmacy.gold.dim_payer
USING DELTA
TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
AS
SELECT
    sk_payer_id,
    payer_external_id,
    payer_name,
    payer_type,
    bin_number,
    pcn_number,
    group_number,
    contact_phone,
    specialty_pharmacy_network,
    is_active,
    created_date,
    current_timestamp() AS _gold_created_date
FROM pharmacy.silver.dim_payer_cleansed;
