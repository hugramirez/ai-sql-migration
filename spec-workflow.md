# OpenSpec Workflow — Guía Práctica

**OpenSpec** es una herramienta IA que genera propuestas de cambio arquitectónicos automáticamente. Lee especificaciones existentes y genera documentación de diseño, tareas de implementación y cambios en requirements.

En este proyecto (`ai-sql-migration`), OpenSpec es el **primer paso** en una metodología híbrida de 6 pasos:

```
OpenSpec → ADR → SDD → Gherkin → Código → Validación
```

---

## Instalación

```bash
# Instalar globalmente desde npm
npm install -g @fission-ai/openspec@latest

# Verificar versión
openspec --version
# Esperado: >= 1.3.1
```

---

## Cuándo usar OpenSpec

Usa OpenSpec **antes de cualquier cambio no trivial**:

- ✅ Nueva feature o capacidad
- ✅ Cambio de arquitectura o flujo
- ✅ Nuevo proveedor de datos (ej: Snowflake)
- ✅ Nuevo proveedor de LLM o cambio de routing
- ✅ Cambio en el pipeline de migración SQL
- ❌ Fixes de bugs simples (ir directo a ADR si es necesario)
- ❌ Cambios de documentación o refactor menor

---

## Cómo usar OpenSpec

### 1. Escribir la propuesta

En **Claude Code** (o cualquier terminal con OpenSpec instalado), ejecuta:

```bash
cd ai-sql-migration
openspec:proposal "descripción clara del cambio deseado"
```

**Ejemplo**:
```bash
/openspec:proposal "agregar Snowflake como fuente de datos junto a SQL Edge y Databricks"
```

OpenSpec leerá las specs existentes en `openspec/specs/` y generará artefactos en `openspec/changes/[id]/`.

### 2. Qué genera OpenSpec

OpenSpec crea cuatro archivos:

| Archivo | Contenido | Cómo usarlo |
|---|---|---|
| **proposal.md** | Intención, contexto, alcance, impacto | Léelo primero para validar que entendió tu idea |
| **design.md** | Decisiones técnicas, alternativas evaluadas, ventajas/desventajas | **Base para el ADR** — copia decisiones aquí |
| **tasks.md** | Desglose granular de tareas de implementación | Planificación del trabajo y estimación |
| **specs/[feature]/spec.md** | Delta de nuevos/cambios requirements | Futuro material para `openspec/specs/` |

**Ubicación**: Los archivos se generan en `openspec/changes/[id]/` donde `[id]` es un ID único generado por OpenSpec.

### 3. Revisar la propuesta

1. **Lee `proposal.md`** — ¿Entendió bien tu idea?
   - Si sí → continúa al paso 4
   - Si no → ajusta la descripción y vuelve a correr openspec:proposal

2. **Lee `design.md`** — ¿Las decisiones técnicas tienen sentido?
   - Si sí → copia los puntos clave al ADR (Paso 2 de la guía)
   - Si hay alternativas mejores → documenta en el ADR por qué

3. **Lee `tasks.md`** — ¿Las tareas coinciden con tu entendimiento del trabajo?
   - Si sí → úsalas como referencia para el planning
   - Si hay cambios → actualiza las tareas en el ADR o en issues de GitHub

### 4. Actualizar specs de OpenSpec (si aplica)

Si el cambio introduce un nuevo componente, copia el `specs/[feature]/spec.md` generado a:

```
openspec/specs/[nombre]/spec.md
```

**Ejemplo**: Si agregas Snowflake, copia a:
```
openspec/specs/snowflake-connector/spec.md
```

Esto asegura que futuras propuestas hereden este conocimiento.

### 5. Nunca editar los archivos generados

⚠️ **Regla importante**: Los archivos en `openspec/changes/[id]/` son artefactos generados. No los edites a mano.

Si necesitas ajustar algo:
1. Borra la carpeta `openspec/changes/[id]/`
2. Corre openspec:proposal de nuevo con una descripción mejorada

---

## Estructura de OpenSpec en el proyecto

```
openspec/
├── specs/                          ← Specifications vivas por componente
│   ├── query-classifier/spec.md    ← Requisitos del clasificador de tier
│   ├── sql-migration-pipeline/spec.md  ← Requisitos del pipeline de migración
│   └── [nuevos componentes]/spec.md
│
└── changes/                        ← Proposals generadas (no editar)
    └── [change-id]/
        ├── proposal.md
        ├── design.md
        ├── tasks.md
        └── specs/[feature]/spec.md
```

---

## Flujo completo: ejemplo paso a paso

### Escenario: Agregar Snowflake como fuente de datos

#### Paso 1: Generar propuesta
```bash
cd ai-sql-migration
/openspec:proposal "agregar Snowflake como fuente de datos junto a SQL Edge y Databricks para soportar queries distribuidas"
```

**Output esperado**:
```
✓ Propuesta generada en: openspec/changes/sf-connector-001/
  - proposal.md (descripción general)
  - design.md (decisiones técnicas)
  - tasks.md (desglose de trabajo)
  - specs/snowflake-connector/spec.md (delta de requirements)
```

#### Paso 2: Revisar y aceptar
```bash
cat openspec/changes/sf-connector-001/design.md
# ✓ Las decisiones técnicas son sólidas
# ✓ Coincide con la arquitectura existente
```

#### Paso 3: Actualizar specs de OpenSpec
```bash
cp openspec/changes/sf-connector-001/specs/snowflake-connector/spec.md \
   openspec/specs/snowflake-connector/spec.md
```

#### Paso 4: Crear ADR
Basándote en `design.md`, crea `docs/architecture/adr/ADR-003-snowflake-connector.md` con:
- Status: `Propuesto`
- Context: business + technical
- Problem Statement: por qué agregar Snowflake
- Alternatives: Snowflake vs. BigQuery vs. Redshift vs. Postgres
- Decision: elegir Snowflake + justificación
- Success Metrics: tabla con latencia, accuracy, costo (con umbrales reales)
- Consequences: positivos y negativos

#### Paso 5: Actualizar SDD
Edita `specs/ai_sql_migration.spec.yaml`:
- Agregar REQ-NNN para conexión, query latency, error handling
- Agregar TC-NNN que valida cada requisito

#### Paso 6: Escribir Gherkin
Edita `features/sql_migration_pipeline.feature`:
```gherkin
@happy_path
@performance
Scenario: Query a Snowflake retorna en menos de 5 segundos
  Given credenciales de Snowflake configuradas
  When ejecuto "SELECT * FROM SALES.PUBLIC.CUSTOMERS LIMIT 10"
  Then obtengo resultados en < 5000ms
```

#### Paso 7: Implementar código
- Crear `src/tools/snowflake_connector.py`
- Agregar tool al agent
- Escribir tests en `tests/test_snowflake.py`

#### Paso 8: Validar
```bash
cd ai-sql-migration
uv run pytest tests/ -v              # Unit + spec tests
uv run behave features/              # Gherkin scenarios
uv run python main.py --query "SELECT * FROM Snowflake"  # End-to-end
```

---

## Referencia rápida: decisiones clave

### ¿Cuándo usar qué artefacto?

| Necesidad | Solución |
|---|---|
| Proponer nuevo feature/cambio | `openspec:proposal` |
| Documentar decisión técnica | ADR (`docs/architecture/adr/`) |
| Agregar umbral de performance | `specs/ai_sql_migration.spec.yaml` |
| Escribir test de negocio | Gherkin en `features/` |
| Prevenir regresión de bug | `@regression` scenario en Gherkin |

### ¿Cómo sé que OpenSpec entiende bien mi idea?

✅ **Buen proposal**:
- `proposal.md` menciona el contexto completo
- `design.md` tiene 2+ alternativas evaluadas
- `tasks.md` es granular (tareas atómicas de 2-4 horas)
- Las métricas de éxito son cuantificables

❌ **Mal proposal** (volver a intentar):
- Decide una única solución sin alternativas
- Tasks son demasiado grandes ("implementar Snowflake" en 1 tarea)
- Métricas vagas ("rápido", "confiable", "seguro")

---

## Troubleshooting

### OpenSpec falla con "specs not found"
```
Causa: OpenSpec no está en la carpeta con openspec/specs/
Solución: Corre openspec:proposal desde ai-sql-migration/
```

### Generó una propuesta pero no entiendo design.md
```
Causa: Descripción muy vaga del cambio
Solución: Sé más específico:
  ❌ "mejorar performance"
  ✅ "agregar cache de 5 minutos en queries clasificadas como 'simple'"
```

### Las tasks generadas no coinciden con mi plan
```
Causa: OpenSpec interpretó diferente el scope
Solución: Edita tasks.md manualmente o regenera con una descripción más clara
Nota: tasks.md está en openspec/changes/ — es seguro editarlo después de generado
       (a diferencia de los otros archivos)
```

### Cambié design.md pero quiero regenerarlo
```
Solución: Borra openspec/changes/[id]/ y vuelve a ejecutar:
  openspec:proposal "descripción refinada..."
Nota: Nunca intentes actualizar un proposal existente. Siempre genera uno nuevo.
```

---

## Integración con flujo Git

Cuando hagas commit del ADR y cambios de specs:

```bash
# Después de crear ADR y actualizar specs
git add docs/architecture/adr/ADR-003-*.md
git add openspec/specs/snowflake-connector/spec.md
git add specs/ai_sql_migration.spec.yaml
git commit -m "docs: ADR-003 Snowflake connector + updated specs"

# Cuando hagas merge de código:
git commit -m "feat: implement Snowflake tool and connection (ADR-003)"
```

**Convención**: Referencia el ADR en commit messages de implementación para trazabilidad.

---

## Checklist OpenSpec

- [ ] ¿Ejecuté `openspec:proposal` con descripción clara?
- [ ] ¿Leí y validé proposal.md?
- [ ] ¿Leí design.md y las decisiones son sólidas?
- [ ] ¿Revisé tasks.md contra mi entendimiento del trabajo?
- [ ] ¿Copié specs/[feature]/spec.md a openspec/specs/ si es nuevo componente?
- [ ] ¿Guardé un link o referencia al change-id para futuro debugging?
- [ ] ¿Nunca edité proposal.md/design.md a mano (borré y regeneré en su lugar)?

---

## Recursos

- **OpenSpec GitHub**: https://github.com/fission-ai/openspec
- **Guía de metodología completa**: [guide.md](ai-sql-migration/docs/guide.md)
- **ADRs en este proyecto**: [docs/architecture/adr/](ai-sql-migration/docs/architecture/adr/)
- **Specs vivas**: [openspec/specs/](ai-sql-migration/openspec/specs/)

---

**Última actualización**: 2026-06-08
**Owner**: Hugo Alejandro Ramirez Moreno
