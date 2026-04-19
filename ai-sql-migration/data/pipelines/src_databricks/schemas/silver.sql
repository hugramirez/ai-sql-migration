CREATE SCHEMA IF NOT EXISTS pharmacy.silver
COMMENT 'SILVER LAYER - Cleansed and conformed data
Purpose: Deduplicated, validated, and lightly enriched tables sourced from pharmacy.bronze
Characteristics:
  - Row-level quality rules and hashes for change detection
  - Surrogate keys preserved from bronze for lineage to gold
  - CDF enabled where tables feed downstream gold or analytics
Lineage: CTAS / MERGE from pharmacy.bronze raw_* tables';
