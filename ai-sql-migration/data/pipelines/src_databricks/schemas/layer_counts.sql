-- schemas/layer_counts.sql — Validate table counts per layer (Unity Catalog information_schema)
-- Requires catalog pharmacy and schemas bronze, silver, gold.
SELECT
    table_schema AS layer,
    COUNT(*) AS table_count
FROM pharmacy.information_schema.tables
WHERE table_catalog = 'pharmacy'
  AND table_schema IN ('bronze', 'silver', 'gold')
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY CASE table_schema WHEN 'bronze' THEN 1 WHEN 'silver' THEN 2 WHEN 'gold' THEN 3 ELSE 9 END;
