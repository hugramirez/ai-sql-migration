# Query Complexity Classifier

## Purpose

The query classifier is a lightweight LLM call that determines the complexity tier (`simple`, `medium`, or `complex`) of each incoming user query before invoking the main agent. Its purpose is to route queries to the least-expensive model that can handle them correctly, reducing per-invocation cost without sacrificing quality on hard tasks.

Implemented in `src/config/llm_config.py::classify_query()`. Driven by ADR-001.

## Requirements

- The classifier SHALL use the cheapest available model (`claude-haiku-4-5-20251001` for Anthropic, `llama-3.1-8b-instruct:free` for OpenRouter).
- The classifier SHALL return exactly one of three tiers: `simple`, `medium`, or `complex`.
- The classifier SHALL complete its call in less than 2000 milliseconds under normal network conditions.
- The classifier SHALL fall back to `complex` on any exception without propagating the error to the caller.
- The classifier SHALL capture input and output token counts and expose them in `ClassifierResult` for cost accounting.
- The classifier model SHALL be configurable via environment variables (`ANTHROPIC_MODEL_CLASSIFIER`, `OPENROUTER_MODEL_CLASSIFIER`) without code changes.
- The agent tier selected by the classifier SHALL be recorded in `RunMetrics.tier` for every invocation.

## Scenarios

### Simple query correctly classified

```gherkin
Given I have the query "SELECT TOP 5 patient_id FROM localdb.dbo.dim_patient"
When the classifier evaluates the query
Then the tier should be "simple"
And input_tokens should be greater than 0
```

### Migration query classified as complex

```gherkin
Given I have the query "Migrate this T-SQL to Databricks: SELECT TOP 5 p.first_name FROM localdb.dbo.dim_patient p JOIN localdb.dbo.fact_prescription f ON p.patient_id = f.patient_id"
When the classifier evaluates the query
Then the tier should be "complex"
```

### Safe fallback on classifier error

```gherkin
Given the LLM classifier raises a network exception
When classify_query is called with any query
Then the returned tier should be "complex"
And no exception should propagate to the caller
And input_tokens should be 0
```

### Token usage reflected in RunMetrics

```gherkin
Given the classifier consumed 150 input tokens and 2 output tokens
And the agent consumed 800 input tokens and 200 output tokens
When collect_run_metrics is called with classifier token counts
Then RunMetrics.input_tokens should equal 950
And RunMetrics.output_tokens should equal 202
```
