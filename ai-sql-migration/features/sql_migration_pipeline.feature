# features/sql_migration_pipeline.feature
# -*- encoding: utf-8 -*-

# ADR: ADR-001 - Tiered LLM Model Routing via Lightweight Classifier
# ADR: ADR-002 - T-SQL → Spark SQL Migration via SQLFluff + Custom Rewrites
# Specs: SPEC-001 (Classifier), SPEC-002 (Migration), SPEC-003 (Observability)

@sql_migration
Feature: T-SQL to Spark SQL Migration Pipeline

  As a data engineer
  I want to provide a T-SQL query from Azure SQL Edge
  So that the agent migrates it to valid Spark SQL and executes it on Databricks

  Background:
    Given the agent is configured with valid LLM credentials
    And SQLFluff is enabled with source dialect "tsql" and target dialect "sparksql"
    And the Unity Catalog prefix is "localuc.gold"
    And the LLM classifier model is available

  # ==========================================
  # Happy Path — Migration End-to-End
  # ==========================================

  @happy_path
  @critical
  Scenario: Basic T-SQL query migrated and executed successfully
    Given I have the T-SQL query:
      """
      SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name,
                   ISNULL(last_name, 'unknown') AS last_name,
                   GETDATE() AS migrated_at
      FROM localdb.dbo.dim_patient
      """
    When I call migrate_sql_query with the query
    Then the output should contain "MIGRATED_SQL:"
    And the migrated SQL should contain "LIMIT 5"
    And the migrated SQL should contain "COALESCE"
    And the migrated SQL should not contain "ISNULL"
    And the migrated SQL should contain "current_timestamp()"
    And the migrated SQL should not contain "GETDATE"
    And the migrated SQL should contain "localuc.gold.dim_patient"
    And the migrated SQL should not contain "[" or "]"

  @happy_path
  @critical
  Scenario: Migrated SQL is parseable by parse_migrated_sql_line
    Given I have any valid T-SQL query
    When I call migrate_sql_query
    Then parse_migrated_sql_line should return a non-empty string
    And the returned SQL should not start with "MIGRATED_SQL:"

  @happy_path
  Scenario: Query with OFFSET/FETCH NEXT migrated to LIMIT
    Given I have the T-SQL query:
      """
      SELECT first_name, last_name
      FROM dbo.dim_patient
      ORDER BY patient_id
      OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY
      """
    When I call migrate_sql_query with the query
    Then the migrated SQL should contain "LIMIT 10"
    And the migrated SQL should not contain "OFFSET"
    And the migrated SQL should not contain "FETCH NEXT"

  @happy_path
  Scenario: String concatenation rewritten to concat_ws for space-separated columns
    Given I have the T-SQL query:
      """
      SELECT first_name + ' ' + last_name AS full_name FROM dbo.dim_patient
      """
    When I call migrate_sql_query with the query
    Then the migrated SQL should contain "concat_ws"
    And the migrated SQL should not contain "first_name + ' ' + last_name"

  # ==========================================
  # Tier Routing via Classifier
  # ==========================================

  @classifier
  @critical
  Scenario: Simple SELECT query routed to "simple" tier
    Given I have the query "SELECT TOP 5 patient_id FROM localdb.dbo.dim_patient"
    When the classifier evaluates the query
    Then the tier should be "simple"
    And the classifier result should have input_tokens greater than 0

  @classifier
  @critical
  Scenario: Migration query with JOIN routed to "complex" tier
    Given I have the query "Migrate this T-SQL to Databricks: SELECT TOP 5 p.first_name, f.drug_name FROM localdb.dbo.dim_patient p JOIN localdb.dbo.fact_prescription f ON p.patient_id = f.patient_id"
    When the classifier evaluates the query
    Then the tier should be "complex"

  @classifier
  Scenario: Aggregation query routed to "medium" or "complex" tier
    Given I have the query "GROUP BY payer_id with COUNT of prescriptions per month"
    When the classifier evaluates the query
    Then the tier should be one of "medium" or "complex"

  @classifier
  @critical
  Scenario: Classifier error falls back safely to "complex" tier
    Given the LLM classifier is configured to raise a network exception
    When classify_query is called with any query
    Then the returned tier should be "complex"
    And no exception should propagate to the caller
    And input_tokens should be 0
    And output_tokens should be 0

  # ==========================================
  # Performance — Latency SLAs
  # ==========================================

  @performance
  @critical
  Scenario: Classification completes within 2 seconds
    Given the classifier model is reachable
    When I classify the query "SELECT patient_id FROM dbo.dim_patient"
    Then the classification should complete in less than 2000 milliseconds

  @performance
  @critical
  Scenario: Full migration pipeline completes within 30 seconds end-to-end
    Given the agent is fully initialized with tier "complex"
    When I invoke the agent with a complex T-SQL migration query
    Then the total latency captured in RunMetrics should be less than 30000 milliseconds

  # ==========================================
  # Cost Observability
  # ==========================================

  @observability
  @critical
  Scenario: RunMetrics captures token counts and estimated cost after invocation
    Given the agent completes a "simple" tier query
    When I collect run metrics
    Then RunMetrics.input_tokens should be greater than 0
    And RunMetrics.output_tokens should be greater than 0
    And RunMetrics.estimated_cost_usd should be a non-negative float
    And RunMetrics.tier should be "simple"
    And RunMetrics.latency_ms should be greater than 0

  @observability
  Scenario: Classifier token usage is included in total RunMetrics
    Given the classifier consumed 150 input tokens and 2 output tokens
    And the agent consumed 800 input tokens and 200 output tokens
    When I collect run metrics with classifier_input_tokens=150 and classifier_output_tokens=2
    Then RunMetrics.input_tokens should equal 950
    And RunMetrics.output_tokens should equal 202

  @observability
  Scenario: Cost estimation is correct for claude-haiku-4-5-20251001
    Given model "claude-haiku-4-5-20251001" with 1000000 input tokens and 1000000 output tokens
    When I call estimate_cost
    Then the estimated cost should equal 4.80 USD

  @observability
  Scenario: Cost estimation returns None for unknown model without raising
    Given model "unknown/hypothetical-model" with 100 input tokens and 50 output tokens
    When I call estimate_cost
    Then the result should be None
    And no exception should be raised

  # ==========================================
  # Edge Cases & Error Handling
  # ==========================================

  @edge_case
  @critical
  Scenario: Empty query raises ValueError before reaching SQLFluff
    Given I have an empty query string ""
    When I call migrate_sql_query
    Then a ValueError should be raised
    And the error message should indicate the query is required

  @edge_case
  Scenario: Query with only whitespace treated as empty
    Given I have a query containing only spaces and newlines
    When I call migrate_sql_query
    Then a ValueError should be raised

  @edge_case
  Scenario: Query with no recognized T-SQL patterns returned with no rewrites
    Given I have the Spark SQL query "SELECT patient_id FROM localuc.gold.dim_patient LIMIT 5"
    When I call migrate_sql_query
    Then REWRITES in the output should be "none" or empty
    And the migrated SQL should be functionally equivalent to the input

  @edge_case
  Scenario: Table not in known mapping left unchanged by rewrite
    Given I have the T-SQL query "SELECT id FROM dbo.unknown_custom_table"
    When I call migrate_sql_query
    Then the table reference "dbo.unknown_custom_table" should remain unchanged
    And no incorrect remapping to "localuc.gold" should occur

  # ==========================================
  # Security & Privacy
  # ==========================================

  @security
  @critical
  Scenario: Agent never executes INSERT, UPDATE, DELETE, or DDL statements
    Given the system prompt enforces read-only behavior
    When the agent receives a request to "DELETE FROM dbo.dim_patient"
    Then the agent should refuse to execute the statement
    And no destructive SQL should be submitted to any database

  @security
  Scenario: Credentials are not exposed in tool output or logs
    Given the agent connects to Databricks and SQL Edge with credentials from environment
    When any tool is invoked
    Then the tool output should not contain the value of DATABRICKS_TOKEN
    And the tool output should not contain the value of SQLEDGE_PASSWORD

  # ==========================================
  # Regression Prevention
  # ==========================================

  @regression
  Scenario: TOP N with parentheses correctly rewritten (regression: regex edge case)
    Given I have the T-SQL query "SELECT TOP (5) patient_id FROM dbo.dim_patient"
    When I call migrate_sql_query
    Then the migrated SQL should contain "LIMIT 5"
    And the migrated SQL should not contain "TOP"

  @regression
  Scenario: dbo.table shorthand remapped to Unity Catalog (regression: localdb prefix not required)
    Given I have the T-SQL query "SELECT patient_id FROM dbo.dim_patient"
    When I call migrate_sql_query
    Then the migrated SQL should contain "localuc.gold.dim_patient"

  @regression
  Scenario: Multiple ISNULL calls in same query all rewritten
    Given I have the T-SQL query "SELECT ISNULL(a,'x'), ISNULL(b,'y'), ISNULL(c,'z') FROM dbo.dim_patient"
    When I call migrate_sql_query
    Then the migrated SQL should not contain "ISNULL"
    And the migrated SQL should contain "COALESCE" at least 3 times
