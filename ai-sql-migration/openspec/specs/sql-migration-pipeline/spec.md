# SQL Migration Pipeline

## Purpose

The SQL migration pipeline translates T-SQL queries (Azure SQL Edge / SQL Server dialect) into valid Spark SQL compatible with Databricks Unity Catalog. It is composed of two steps executed by the LangGraph agent:

1. `migrate_sql_query(query)` — rewrites syntax and remaps table identifiers.
2. `run_sql_query(query)` — executes the migrated SQL on the Databricks warehouse.

Implemented in `src/tools/sql_migration.py` and `src/tools/databricks_sql.py`. Driven by ADR-002.

## Requirements

- `migrate_sql_query` SHALL rewrite `SELECT TOP N` to `SELECT ... LIMIT N`.
- `migrate_sql_query` SHALL rewrite `ISNULL(a, b)` to `COALESCE(a, b)`.
- `migrate_sql_query` SHALL rewrite `GETDATE()` to `current_timestamp()`.
- `migrate_sql_query` SHALL rewrite `OFFSET n ROWS FETCH NEXT m ROWS ONLY` to `LIMIT m`.
- `migrate_sql_query` SHALL remap `localdb.dbo.<table>` and `dbo.<table>` references to the configured Unity Catalog prefix (`localuc.gold.<table>` by default, overridable via `SQL_MIGRATION_UC_PREFIX`).
- `migrate_sql_query` SHALL strip T-SQL bracket notation (`[column]` → `column`) from the output.
- `migrate_sql_query` SHALL rewrite T-SQL string concatenation (`a + ' ' + b`) to `concat_ws(' ', a, b)`.
- `migrate_sql_query` SHALL always produce output containing a `MIGRATED_SQL:` prefix line parseable by `parse_migrated_sql_line()`.
- `migrate_sql_query` SHALL raise `ValueError` when called with an empty or whitespace-only query.
- The agent SHALL invoke `migrate_sql_query` before `run_sql_query` for every migration request — never running the original T-SQL on Databricks.
- The agent SHALL never generate or execute INSERT, UPDATE, DELETE, DROP, or any DDL statement.
- `run_sql_query` SHALL append `LIMIT N` automatically to prevent runaway result sets.

## Scenarios

### Full T-SQL query migrated correctly

```gherkin
Given I have the T-SQL query:
  "SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, GETDATE() AS ts FROM localdb.dbo.dim_patient"
When I call migrate_sql_query
Then the migrated SQL should contain "LIMIT 5"
And the migrated SQL should contain "COALESCE"
And the migrated SQL should not contain "ISNULL"
And the migrated SQL should contain "current_timestamp()"
And the migrated SQL should contain "localuc.gold.dim_patient"
And the migrated SQL should not contain "[" or "]"
```

### OFFSET/FETCH rewritten to LIMIT

```gherkin
Given I have the T-SQL query:
  "SELECT first_name FROM dbo.dim_patient ORDER BY patient_id OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY"
When I call migrate_sql_query
Then the migrated SQL should contain "LIMIT 10"
And the migrated SQL should not contain "OFFSET" or "FETCH"
```

### Output always parseable

```gherkin
Given I have any valid T-SQL query
When I call migrate_sql_query
Then parse_migrated_sql_line(output) should return a non-empty string
```

### Empty query raises ValueError

```gherkin
Given I have an empty query string
When I call migrate_sql_query
Then a ValueError should be raised
```

### dbo shorthand remapped without localdb prefix

```gherkin
Given I have the T-SQL query "SELECT patient_id FROM dbo.dim_patient"
When I call migrate_sql_query
Then the migrated SQL should contain "localuc.gold.dim_patient"
```

### TOP with parentheses correctly handled

```gherkin
Given I have the T-SQL query "SELECT TOP (5) patient_id FROM dbo.dim_patient"
When I call migrate_sql_query
Then the migrated SQL should contain "LIMIT 5"
And the migrated SQL should not contain "TOP"
```
