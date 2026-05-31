# Guía de Implementación — Metodología Híbrida

Paso a paso para contribuir a **ai-sql-migration** siguiendo el stack:
**OpenSpec → ADR → SDD → Gherkin → Código → Validación**

---

## Índice

1. [Prerequisitos](#1-prerequisitos)
2. [Estructura del proyecto](#2-estructura-del-proyecto)
3. [Paso 1 — Propuesta con OpenSpec](#3-paso-1--propuesta-con-openspec)
4. [Paso 2 — Crear o actualizar un ADR](#4-paso-2--crear-o-actualizar-un-adr)
5. [Paso 3 — Actualizar el SDD (YAML)](#5-paso-3--actualizar-el-sdd-yaml)
6. [Paso 4 — Escribir escenarios Gherkin](#6-paso-4--escribir-escenarios-gherkin)
7. [Paso 5 — Implementar el código](#7-paso-5--implementar-el-código)
8. [Paso 6 — Validar todo](#8-paso-6--validar-todo)
9. [Referencia rápida](#9-referencia-rápida)
10. [Reglas generales](#10-reglas-generales)

---

## 1. Prerequisitos

Herramientas necesarias antes de empezar:

```bash
# Python + uv (gestor de paquetes del proyecto)
python --version   # >= 3.13
uv --version

# OpenSpec (propuestas de cambio con IA)
npm install -g @fission-ai/openspec@latest
openspec --version   # debe mostrar >= 1.3.1

# behave (para correr los escenarios Gherkin)
uv run pip install behave
```

Credenciales mínimas en `.env`:
```
ANTHROPIC_API_KEY=sk-ant-...   # o OPENROUTER_API_KEY
DATABRICKS_HOST=...
DATABRICKS_TOKEN=...
SQLEDGE_HOST=localhost
```

---

## 2. Estructura del proyecto

```
ai-sql-migration/
├── CLAUDE.md                              ← workflow resumido para Claude Code
├── openspec/
│   ├── specs/                             ← specs vivas por componente
│   │   ├── query-classifier/spec.md
│   │   └── sql-migration-pipeline/spec.md
│   └── changes/                           ← proposals generados (no editar a mano)
│       └── [change-id]/
│           ├── proposal.md
│           ├── design.md
│           ├── tasks.md
│           └── specs/[feature]/spec.md
├── docs/
│   ├── guide.md                           ← este archivo
│   └── architecture/
│       └── adr/
│           └── ADR-001-tiered-llm-model-routing.md
├── specs/
│   └── ai_sql_migration.spec.yaml         ← SDD con umbrales cuantificables
├── features/
│   └── sql_migration_pipeline.feature     ← escenarios Gherkin
├── src/                                   ← código fuente
└── tests/                                 ← pytest
```

---

## 3. Paso 1 — Propuesta con OpenSpec

**Cuándo usarlo**: Antes de cualquier cambio no trivial — nueva feature, cambio de arquitectura, nuevo proveedor de LLM, nueva fuente de datos.

**Cómo**: En Claude Code, escribe el slash command con una descripción del cambio.

```
/openspec:proposal "agregar Snowflake como fuente de datos junto a SQL Edge y Databricks"
```

OpenSpec leerá las specs existentes en `openspec/specs/` y generará en `openspec/changes/[id]/`:

| Archivo | Qué contiene | Para qué sirve |
|---|---|---|
| `proposal.md` | Intención, contexto, alcance | Alinear con el equipo antes de actuar |
| `design.md` | Decisiones técnicas, alternativas | **Base para el ADR** |
| `tasks.md` | Desglose de tareas de implementación | Planificación del trabajo |
| `specs/[feature]/spec.md` | Delta de requirements afectados | Actualizar `openspec/specs/` si se acepta |

**Qué hacer con el output**:
1. Leer `design.md` — si las decisiones tienen sentido, continuar al Paso 2.
2. Si algo no cuadra, ajustar la descripción del proposal y volver a correrlo.
3. Nunca editar los archivos en `openspec/changes/` — son artefactos generados.

---

## 4. Paso 2 — Crear o actualizar un ADR

**Cuándo**: Una vez que el `design.md` del proposal está revisado y las decisiones son claras.

**Dónde**: `docs/architecture/adr/ADR-NNN-titulo-kebab-case.md`

### Crear un nuevo ADR

Copia la estructura de [ADR-001](architecture/adr/ADR-001-tiered-llm-model-routing.md) y reemplaza el contenido. Las secciones obligatorias son:

```markdown
## Status          ← [x] Propuesto / Aceptado / Deprecado
## Context         ← Business context + Technical context + Stakeholders
## Problem Statement   ← qué falla hoy, cuantificable
## Alternatives Considered   ← mínimo 2 opciones con ventajas, desventajas y costo estimado
## Decision        ← opción elegida + justificación + plan de mitigación
## Success Metrics ← tabla con umbral, unidad y método de medición — sin "TBD"
## Consequences    ← positivas y negativas (trade-offs honestos)
```

**Regla**: La tabla de Success Metrics debe tener valores reales. Ejemplo:

| Métrica | Umbral | Unidad | Medición |
|---|---|---|---|
| Latencia de clasificación | < 2000 | ms | `time.monotonic()` en `main.py` |
| Accuracy del classifier | ≥ 85 | % | `tests/fixtures/classifier_test_set.json` |

### Actualizar un ADR existente

Si una decisión previa cambia:
1. Cambiar su status a `Deprecado` o `Reemplazado por [ADR-NNN]`.
2. Crear el nuevo ADR que lo reemplaza con referencia al anterior en `## Related ADRs`.

### Actualizar las specs de OpenSpec

Si el ADR afecta un componente existente, actualizar el `spec.md` correspondiente:
- Classifier → `openspec/specs/query-classifier/spec.md`
- Pipeline → `openspec/specs/sql-migration-pipeline/spec.md`

Si es un componente nuevo, crear `openspec/specs/[nombre]/spec.md`.

---

## 5. Paso 3 — Actualizar el SDD (YAML)

**Archivo**: `specs/ai_sql_migration.spec.yaml`

**Cuándo**: Cada vez que el ADR define nuevos umbrales o cambia los existentes.

### Agregar un nuevo requisito

```yaml
- req_id: "REQ-013"          # siguiente número disponible
  description: "Snowflake query debe completarse en < 5s"
  type: "performance"
  metric_name: "snowflake_query_latency_ms"
  metric_type: "latency"
  threshold: 5000
  operator: "<"
  unit: "milliseconds"
  adr_source: "ADR-003"      # ADR que motivó este requisito
  validation_method: "automated"
  acceptance_criteria: "P95 en 100 runs del test de integración"
```

### Agregar un test case

```yaml
- tc_id: "TC-010"
  description: "Conexión a Snowflake se establece en < 3s"
  category: "performance"
  priority: "critical"
  preconditions:
    - "SNOWFLAKE_ACCOUNT y SNOWFLAKE_TOKEN están seteados"
  inputs:
    query: "SELECT 1"
  expected_outputs:
    latency_ms_lt: 3000
  assertions:
    - name: "Conexión bajo 3s"
      condition: "latency_ms < 3000"
      required: true
  adr_validation: "REQ-013"
  implementation_ref: "tests/test_snowflake.py::test_connection_latency"
```

**Regla**: Cada `req_id` debe tener al menos un `tc_id` que lo valide. Sin test case, el requisito no es ejecutable.

---

## 6. Paso 4 — Escribir escenarios Gherkin

**Archivo**: `features/sql_migration_pipeline.feature`

**Cuándo**: Después de actualizar el SDD, traducir los test cases más importantes a lenguaje de negocio.

### Estructura de un escenario

```gherkin
@categoria
@critical   # solo si es bloqueante para producción
Scenario: Descripción en lenguaje de negocio
  Given [precondición]
  When [acción]
  Then [resultado esperado]
  And [validación adicional]
```

### Categorías disponibles (tags)

| Tag | Cuándo usarlo |
|---|---|
| `@happy_path` | Flujo normal sin errores |
| `@classifier` | Comportamiento del clasificador de tier |
| `@performance` | Validación de latencia o throughput |
| `@observability` | Métricas, tokens, costo |
| `@edge_case` | Inputs vacíos, malformados, límites |
| `@security` | PII, credenciales, queries destructivos |
| `@regression` | Bugs previos que no deben reaparecer |

### Ejemplo — nueva feature Snowflake

```gherkin
@happy_path
@critical
Scenario: Query a Snowflake retorna resultados en menos de 5 segundos
  Given las credenciales de Snowflake están configuradas
  And la tabla "SALES.PUBLIC.DIM_CUSTOMER" existe
  When ejecuto "SELECT TOP 5 customer_id FROM SALES.PUBLIC.DIM_CUSTOMER"
  Then el resultado debe contener al menos 1 fila
  And la latencia debe ser menor a 5000 milisegundos

@regression
Scenario: Query de Snowflake no interfiere con el pipeline de SQL Edge
  Given ambas conexiones están activas
  When ejecuto queries en paralelo a Snowflake y SQL Edge
  Then los resultados de cada fuente deben ser independientes
  And ninguna conexión debe afectar a la otra
```

---

## 7. Paso 5 — Implementar el código

Con el ADR aprobado, el SDD actualizado y los escenarios escritos, recién se empieza a implementar.

**Checklist antes de abrir un PR**:

- [ ] El código referencia el ADR en el commit message (ej: `feat: add Snowflake tool (ADR-003)`)
- [ ] Los nuevos `req_id` del SDD tienen tests en `tests/`
- [ ] Los nuevos escenarios Gherkin tienen step definitions implementados
- [ ] Las variables de entorno nuevas están documentadas en `.env.example`
- [ ] Si se modificó `classify_query()` o el prompt del classifier, correr el test set de accuracy

### Convención de commit

```
<tipo>: <descripción corta> (ADR-NNN)

Ejemplos:
feat: add Snowflake SQL tool and connection settings (ADR-003)
fix: handle OFFSET/FETCH edge case in migration rewrite (ADR-002)
refactor: extract cost table to separate config file (ADR-001)
```

---

## 8. Paso 6 — Validar todo

```bash
# Desde ai-sql-migration/
cd ai-sql-migration

# 1. Tests unitarios y de especificación (SDD)
uv run pytest tests/ -v

# 2. Escenarios Gherkin (requiere behave)
uv run behave features/

# 3. Test rápido del agente completo (requiere .env configurado)
uv run python main.py --query "SELECT TOP 3 patient_id FROM localdb.dbo.dim_patient"

# 4. Test de migración end-to-end con un archivo SQL
uv run python main.py --sql-file ../reports/patient_spending.sql --write-migrated out/result.sql
```

**Criterio de aceptación**: Los tres primeros comandos deben pasar sin errores antes de hacer merge.

---

## 9. Referencia rápida

```
¿Qué quiero hacer?                         ¿Por dónde empiezo?
──────────────────────────────────────────────────────────────────
Nueva feature o cambio arquitectónico      /openspec:proposal "..."
Documentar una decisión ya tomada          Crear ADR-NNN directamente
Agregar un umbral de performance           Editar specs/ai_sql_migration.spec.yaml
Prevenir regresión de un bug              Agregar @regression scenario en features/
Cambiar el prompt del classifier           Editar llm_config.py + actualizar ADR-001
Agregar nuevo modelo a la tabla de costos  Editar src/observability/metrics.py + REQ en SDD
```

### Numeración de artefactos

| Artefacto | Formato | Ejemplo |
|---|---|---|
| ADR | `ADR-NNN` (001, 002, 003…) | `ADR-002` |
| Spec ID | `SPEC-NNN` | `SPEC-004` |
| Requisito | `REQ-NNN` | `REQ-013` |
| Test case | `TC-NNN` | `TC-010` |

---

## 10. Reglas generales

1. **No hay código sin ADR para cambios arquitectónicos.** Si la decisión impacta cómo el sistema enruta queries, se conecta a una fuente de datos, o modifica el pipeline de migración, necesita ADR.

2. **No hay ADR sin Success Metrics con umbrales reales.** Un ADR sin métricas concretas no es auditable.

3. **No hay requisito en el SDD sin test case.** Un requisito sin validación ejecutable es una aspiración, no una especificación.

4. **El fallback siempre es conservador.** Si el classifier falla → `complex`. Si la migración falla → error explícito. Nunca silenciar errores.

5. **Las specs de OpenSpec son la fuente de verdad para los proposals futuros.** Mantenerlas actualizadas después de cada ADR aceptado.

---

**Última actualización**: 2026-05-31
**Versión**: 1.0
**Owner**: Hugo Alejandro Ramirez Moreno
