# CLAUDE.md — ai-sql-migration

## Development Workflow

This project uses a **hybrid methodology**: OpenSpec → ADR → SDD → Gherkin → CI.
Each layer feeds the next. Do not skip layers for non-trivial changes.

```
/openspec:proposal "description"     ← start here for any new feature or change
        ↓
openspec/changes/[id]/design.md      ← review decisions, then formalize as ADR
        ↓
docs/architecture/adr/ADR-NNN.md     ← record the "why" with metrics and trade-offs
        ↓
specs/ai_sql_migration.spec.yaml     ← add/update quantifiable requirements + test cases
        ↓
features/sql_migration_pipeline.feature  ← add Gherkin scenarios for new behavior
        ↓
implement + pytest + behave           ← validate everything passes
```

### When to use /openspec:proposal

Run it before writing any ADR or code when the change is non-trivial:

```bash
# Examples:
/openspec:proposal "add Snowflake as a data source alongside SQL Edge and Databricks"
/openspec:proposal "replace the LLM classifier with an embedding-based router"
/openspec:proposal "expose the agent as a FastAPI REST endpoint"
```

OpenSpec reads `openspec/specs/` to understand existing requirements, then generates:
- `openspec/changes/[id]/proposal.md` — intent + context
- `openspec/changes/[id]/design.md` — technical decisions (raw material for the ADR)
- `openspec/changes/[id]/tasks.md` — implementation task breakdown
- `openspec/changes/[id]/specs/` — deltas showing which existing specs are affected

Review `design.md` before creating the ADR — it captures the reasoning before implementation bias sets in.

### Existing specs (OpenSpec)

| Spec | File | Covers |
|---|---|---|
| Query Complexity Classifier | `openspec/specs/query-classifier/spec.md` | Tier routing, fallback, token accounting |
| SQL Migration Pipeline | `openspec/specs/sql-migration-pipeline/spec.md` | T-SQL rewrites, output format, error handling |

### Existing ADRs

| ADR | File | Covers |
|---|---|---|
| ADR-001 | `docs/architecture/adr/ADR-001-tiered-llm-model-routing.md` | LLM classifier + tier routing decision |

When adding an ADR: copy the template from `docs/architecture/adr/ADR-001-*.md`, increment the number, fill all sections. The Success Metrics table must have real thresholds — no "TBD".

### Updating specs after a change

When an ADR is accepted:
1. Update the relevant `openspec/specs/*/spec.md` to reflect new requirements.
2. Update `specs/ai_sql_migration.spec.yaml` with new `req_id` entries and thresholds.
3. Add or update Gherkin scenarios in `features/sql_migration_pipeline.feature`.
4. Run `pytest` + `behave` to confirm all specs pass.

## Running tests

```bash
cd ai-sql-migration
uv run pytest tests/ -v
uv run behave features/          # requires: pip install behave
```

## Project structure reference

See `AGENTS.md` for the full project structure, environment variables, and SQL migration quirks.
