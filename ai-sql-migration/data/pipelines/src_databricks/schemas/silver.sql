CREATE SCHEMA IF NOT EXISTS localuc.silver
COMMENT 'SILVER LAYER - Cleansed and conformed data
Purpose: Deduplicated, validated, and lightly enriched tables sourced from localuc.bronze
Characteristics:
  - Row-level quality rules and hashes for change detection
  - Surrogate keys preserved from bronze for lineage to gold
  - CDF enabled where tables feed downstream gold or analytics
Lineage: CTAS / MERGE from localuc.bronze raw_* tables';
