# ADR-001: Tiered LLM Model Routing via Lightweight Classifier

## Status
- [x] Aceptado

## Context

### Business Context
- **Objetivo**: Reducir el costo de inferencia LLM manteniendo calidad de respuesta en consultas complejas de migración T-SQL → Spark SQL.
- **Restricciones**: El agente debe responder en < 30 segundos de extremo a extremo; el proveedor LLM puede ser Anthropic o OpenRouter.
- **Timeline**: Implementado en el release inicial del agente.
- **Budget**: Sin presupuesto fijo mensual; el objetivo es minimizar costo por invocación.

### Technical Context
- **Escala**: Consultas interactivas on-demand; no hay SLA de throughput masivo.
- **Performance requerido**: Latencia total (clasificación + agente) < 30 s; clasificación sola < 2 s.
- **Integración**: LangGraph como orquestador; `classify_query()` se invoca antes de `build_agent()`.
- **Stack actual**: Python 3.13, LangGraph, LangChain, ChatAnthropic / ChatOpenAI (OpenRouter).

### Stakeholders
- **Promotor**: Equipo de desarrollo del agente.
- **Afectados**: Todos los consumidores del agente (CLI, futuras integraciones API).
- **Decisor**: Tech Lead del proyecto.

## Problem Statement

Sin clasificación previa, cada consulta —sin importar si es un simple `SELECT TOP 5` o una migración compleja con 10 tablas— invocaría siempre el modelo más capaz (Claude Sonnet / Mixtral-8x7b). Esto genera:

1. **Costo innecesario**: Consultas triviales (describe tabla, lookup simple) cuestan lo mismo que migraciones complejas.
2. **Latencia subóptima**: Modelos grandes tienen mayor latencia incluso para tareas simples.
3. **Sin visibilidad de complejidad**: No hay registro de qué tier se usó ni por qué.

El clasificador resuelve los puntos 1 y 2 con un overhead mínimo (< 2 s, modelos baratos/gratuitos).

## Alternatives Considered

### Opción A: Un solo modelo para todo (status quo)
**Descripción**: Siempre usar el modelo más capaz, sin clasificación.

**Ventajas**:
- [+] Sin complejidad adicional (sin clasificador).
- [+] Latencia directa: un solo LLM call.

**Desventajas**:
- [-] Costo máximo en todas las consultas, incluyendo triviales.
- [-] Sin trazabilidad de complejidad en métricas.

**Estimaciones**:
- Costo operacional: ~$0.003–$0.015 USD por consulta (sonnet o mixtral siempre).
- Esfuerzo: 0 horas adicionales.

**Riesgos**:
- Costo acumulado elevado en uso intensivo.

---

### Opción B: Clasificación basada en reglas (regex / keywords)
**Descripción**: Detectar palabras clave en la consulta (`JOIN`, `MIGRATE`, `GROUP BY`) para asignar tier.

**Ventajas**:
- [+] Sin latencia adicional de LLM.
- [+] Determinista y auditable.

**Desventajas**:
- [-] Frágil ante lenguaje natural ("migra esto a Databricks" sin keywords explícitas).
- [-] Requiere mantenimiento manual de reglas.
- [-] Bajo recall en queries expresadas en forma conversacional.

**Estimaciones**:
- Esfuerzo: 4–8 horas (diseño de reglas + tests).
- Costo operacional: $0.

**Riesgos**:
- Misclassification frecuente → queries complejas enrutadas a modelos simple.

---

### Opción C: Clasificador LLM ligero (decisión elegida)
**Descripción**: Invocar un modelo pequeño/barato (`claude-haiku` o `llama-3.1-8b:free`) con un prompt de una sola línea de respuesta para clasificar en `simple` / `medium` / `complex`.

**Ventajas**:
- [+] Entiende lenguaje natural sin reglas manuales.
- [+] Costo marginal muy bajo (~$0.000016 USD con haiku; $0 con llama:free).
- [+] Fácil de actualizar el prompt sin cambiar lógica de routing.
- [+] Genera métricas de tier y tokens como parte del `RunMetrics`.

**Desventajas**:
- [-] Añade ~500–1500 ms de latencia por el clasificador.
- [-] El clasificador puede equivocarse (~10–15% de casos edge).
- [-] Dependencia de un LLM adicional en el critical path.

**Estimaciones**:
- Esfuerzo: 1 día de implementación + tests.
- Costo operacional: < $0.001 USD por invocación total.
- Timeline: 1 semana.

**Riesgos**:
- Error del clasificador → Rollback: el fallback es siempre `"complex"` (conservador).

## Decision

**La opción elegida es: Opción C — Clasificador LLM Ligero.**

### Justificación
La opción C balancea correctamente costo vs. precisión: usa un modelo gratuito o de bajo costo para tomar una decisión de enrutamiento, mientras que el fallback conservador (`complex`) garantiza que una clasificación errónea nunca degradará la calidad — solo incrementará el costo en ese caso específico. La opción A no cumple el objetivo de reducción de costos. La opción B es frágil ante el lenguaje natural que el agente recibe.

### Implementación
- **Responsable(s)**: Hugo Alejandro Ramirez Moreno
- **Duración estimada**: Implementado
- **Dependencias**: `src/config/llm_config.py::classify_query()`, `src/config/settings.py` (variables de modelo por tier)
- **Go/No-Go Date**: 2026-05-01

### Mitigación de Riesgos
- Error del clasificador → fallback a `"complex"` en `except Exception` (ver `llm_config.py:91`)
- Latencia del clasificador eleva total → se monitorea en `RunMetrics.latency_ms`

## Success Metrics

| Métrica | Tipo | Umbral | Unidad | Medición |
|---------|------|--------|--------|----------|
| Latencia de clasificación | Performance | < 2000 | ms | `time.monotonic()` antes/después de `classify_query()` |
| Accuracy del clasificador | Functional | ≥ 85 | % | Test set de 20 queries etiquetadas manualmente |
| Costo por invocación (simple) | Financial | < 0.0005 | USD | `estimate_cost()` en `RunMetrics` |
| Costo por invocación (complex) | Financial | < 0.020 | USD | `estimate_cost()` en `RunMetrics` |
| Tasa de fallback a "complex" | Reliability | < 5 | % | Logs + LangSmith traces |
| Latencia total agente (P95) | Performance | < 30000 | ms | `RunMetrics.latency_ms` |

### Validación
- **Cómo se valida**: `pytest tests/` + revisión manual de LangSmith traces
- **Frecuencia**: En cada PR que modifique `classify_query()` o el prompt del clasificador
- **Owner**: Desarrollador principal

## Consequences

### Positive Consequences
- [+] Reducción de costo ~60–80% en queries simples vs. siempre usar sonnet.
- [+] Trazabilidad de tier en métricas (`RunMetrics.tier`) para análisis de uso.
- [+] El prompt del clasificador es configurable sin tocar código.

### Negative Consequences / Trade-offs
- [-] +500–1500 ms de latencia adicional por el clasificador (necesario para el ahorro de costo).
- [-] Dos LLM calls en lugar de uno por invocación del agente.

### Technical Debt Introduced
Ninguna. El clasificador tiene cobertura de tests y fallback explícito.

### Learning Required
Equipo debe entender que `RunMetrics.tier` refleja la decisión del clasificador, no la complejidad real percibida por el usuario.

## Implementation Considerations

### Phase 1: Clasificador y routing
- [x] Implementar `classify_query()` con fallback conservador
- [x] Configurar modelos por tier vía variables de entorno
- [x] Integrar resultado en `RunMetrics`

### Phase 2: Observabilidad y validación
- [x] Token counting del clasificador sumado al total
- [x] Estimación de costo separada (agente + clasificador)
- [ ] Test set de 20 queries etiquetadas para medir accuracy del clasificador

### Rollback Plan
Eliminar la llamada a `classify_query()` en `main.py` y fijar tier `"complex"` hardcodeado. Sin cambios de API ni de herramientas.

### Monitoring & Alerts
- Alert 1: `latency_ms` > 30000 ms en cualquier run.
- Alert 2: Tasa de fallback > 5% en LangSmith (indicaría fallo del clasificador).

## Related ADRs

- [ADR-002]: T-SQL → Spark SQL Migration via SQLFluff + Custom Rewrites (Blocks: usa el tier elegido por este ADR)

## References

### Documentation
- `src/config/llm_config.py` — implementación de `classify_query()` y `ClassifierResult`
- `src/observability/metrics.py` — `estimate_cost()` y `collect_run_metrics()`
- `src/config/settings.py` — variables de configuración de modelos por tier

### Tools / Frameworks
- [LangChain ChatAnthropic](https://python.langchain.com/docs/integrations/chat/anthropic/)
- [OpenRouter API](https://openrouter.ai/docs)

## Approval & Sign-off

| Rol | Nombre | Fecha | Status |
|-----|--------|-------|--------|
| Tech Lead | Hugo Alejandro Ramirez Moreno | 2026-05-01 | ✓ Approved |

---

**Created**: 2026-05-01  
**Last Updated**: 2026-05-31  
**Next Review Date**: 2026-08-31
