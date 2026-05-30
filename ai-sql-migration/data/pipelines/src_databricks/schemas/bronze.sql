CREATE SCHEMA IF NOT EXISTS localuc.bronze
COMMENT 'BRONZE LAYER - Raw Data Ingestion Zone
Purpose: Stores unprocessed data extracted directly from source systems (SQL Server, APIs, files)
Characteristics:
  - No transformations applied (source system data as-is)
  - Audit columns added (_ingest_timestamp, _source_system, _ingest_batch_id)
  - Change Data Feed (CDF) enabled for incremental processing
  - Schema evolution allowed (addNewColumns mode)
Data Retention: 90 days (compliance with temporary storage policies)
Owner: data_engineers group
Access Level: Restricted - Only data engineers can create/modify tables
Table Naming Convention: raw_{original_table_name}
Quality Checks: Schema validation, null checks, duplicate detection
Lineage: Direct mapping from source system tables';
