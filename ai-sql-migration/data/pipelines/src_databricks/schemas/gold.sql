CREATE SCHEMA IF NOT EXISTS localuc.gold
COMMENT 'GOLD LAYER - Analytics-ready dimensional model
Purpose: Curated dimensions and facts for BI and applications
Characteristics:
  - One row per business key (or snapshot policy) per entity
  - Optional ZORDER / OPTIMIZE on large facts
Lineage: CTAS from localuc.silver *_cleansed tables and views for consumption metrics';
