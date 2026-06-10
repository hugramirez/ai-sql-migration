# ai-sql-migration

Agente de migración SQL impulsado por IA que utiliza [LangGraph](https://github.com/langchain-ai/langgraph) y un LLM (Anthropic Claude o [OpenRouter](https://openrouter.ai)) para migrar y consultar datos desde **Azure SQL Edge** (Docker) a **Databricks** usando lenguaje natural.

Un clasificador LLM ligero enruta automáticamente cada consulta al modelo de tamaño adecuado según su complejidad (simple / medium / complex), optimizando el costo sin sacrificar calidad en tareas difíciles. El clasificador funciona tanto con Anthropic como con OpenRouter.

## Requisitos

- Python 3.13+
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
- Una **clave de API de Anthropic** (`ANTHROPIC_API_KEY`) **o** una **clave de API de OpenRouter** (`OPENROUTER_API_KEY`) — al menos una es requerida
- Docker ejecutando `azure-sql-edge` (para herramientas de SQL Edge)
- Un workspace de Databricks con un SQL warehouse (para herramientas de Databricks) — [regístrate en la edición gratuita](https://www.databricks.com/signup/free-edition?provider=DB_FREE_TIER&dbx_source=www&itm_data=dbx-web&l=en-EN&itm_source=www&itm_category=learn&itm_page=free-edition&itm_location=body&itm_component=hero&itm_offer=free-edition) si aún no tienes una cuenta
  - **Requerido**: Debe existir un Unity Catalog (`localuc` por defecto) antes de usar funcionalidades de Databricks

**Para instrucciones de configuración paso a paso, consulta [runbook.md](runbook.md)** ← Empieza aquí si es tu primera vez configurando el proyecto.

## Configuración

1. Clona el repositorio y entra al directorio del proyecto:

```bash
cd ai-sql-migration
```

2. Instala las dependencias:

```bash
uv sync
```

3. Copia la plantilla de variables de entorno y completa tus credenciales:

```bash
cp .env.example .env
```

### Proveedor LLM (al menos uno requerido)

| Variable | Descripción |
|---|---|
| `ANTHROPIC_API_KEY` | Clave de API de Anthropic (`sk-ant-...`). Habilita el clasificador LLM y enrutamiento por niveles con modelos Claude. |
| `OPENROUTER_API_KEY` | Clave de API de OpenRouter (`sk-or-...`). Habilita clasificador + enrutamiento por niveles vía OpenRouter. Tiene prioridad sobre Anthropic cuando ambas están configuradas. |

### Niveles de modelo Anthropic (opcional — solo se usa cuando `ANTHROPIC_API_KEY` está configurada)

| Variable | Por defecto | Descripción |
|---|---|---|
| `ANTHROPIC_MODEL_CLASSIFIER` | `claude-haiku-4-5-20251001` | Modelo usado para clasificar la complejidad de la consulta |
| `ANTHROPIC_MODEL_SIMPLE` | `claude-haiku-4-5-20251001` | Modelo para consultas simples (SELECTs básicos, consultas de esquema) |
| `ANTHROPIC_MODEL_MEDIUM` | `claude-sonnet-4-5` | Modelo para consultas medianas (JOINs, agregaciones) |
| `ANTHROPIC_MODEL_COMPLEX` | `claude-sonnet-4-5` | Modelo para consultas complejas (migraciones completas T-SQL→Spark, subconsultas) |

### Niveles de modelo OpenRouter (opcional — solo se usa cuando `OPENROUTER_API_KEY` está configurada)

| Variable | Por defecto | Descripción |
|---|---|---|
| `OPENROUTER_MODEL_CLASSIFIER` | `meta-llama/llama-3.1-8b-instruct:free` | Modelo usado para clasificar la complejidad de la consulta |
| `OPENROUTER_MODEL_SIMPLE` | `meta-llama/llama-3.1-8b-instruct:free` | Modelo para consultas simples (SELECTs básicos, consultas de esquema) |
| `OPENROUTER_MODEL_MEDIUM` | `mistralai/mixtral-8x7b-instruct` | Modelo para consultas medianas (JOINs, agregaciones) |
| `OPENROUTER_MODEL_COMPLEX` | `anthropic/claude-sonnet-4-5` | Modelo para consultas complejas (migraciones completas T-SQL→Spark, subconsultas) |

### Conexión a SQL Edge

| Variable | Descripción |
|---|---|
| `SQLEDGE_HOST` | Host de SQL Edge (por defecto: `localhost`) |
| `SQLEDGE_PORT` | Puerto de SQL Edge (por defecto: `1433`) |
| `SQLEDGE_DATABASE` | Nombre de la base de datos (ej. `ecobicis`) |
| `SQLEDGE_USER` | Usuario de SQL Edge (ej. `sa`) |
| `SQLEDGE_PASSWORD` | Contraseña de SQL Edge |

### Conexión a Databricks

| Variable | Descripción |
|---|---|
| `DATABRICKS_HOST` | URL del workspace de Databricks |
| `DATABRICKS_TOKEN` | Token de acceso personal de Databricks |
| `DATABRICKS_WAREHOUSE_ID` | ID del SQL warehouse |
| `UC_CATALOG` | Nombre del Unity Catalog |
| `UC_SCHEMA` | Nombre del esquema dentro del catálogo |

### Migración SQLFluff

| Variable | Descripción |
|---|---|
| `SQLFLUFF_ENABLED` | Habilitar flujo de lint/corrección de migración SQL (`true`/`false`) |
| `SQLFLUFF_SOURCE_DIALECT` | Dialecto SQL de origen para migración (por defecto: `tsql`) |
| `SQLFLUFF_TARGET_DIALECT` | Dialecto SQL de destino para migración (por defecto: `sparksql`) |

### Observabilidad (opcional)

| Variable | Por defecto | Descripción |
|---|---|---|
| `LANGSMITH_TRACING` | `false` | Habilitar trazado LangSmith. Debe configurarse en `.env` — no se puede configurar en tiempo de ejecución. |
| `LANGSMITH_API_KEY` | — | Clave de API de LangSmith (`ls__...`). Requerida cuando el trazado está habilitado. |
| `LANGSMITH_PROJECT` | `ai-sql-migration` | Nombre del proyecto en LangSmith. |
| `LANGSMITH_ENDPOINT` | `https://api.smith.langchain.com` | Endpoint de API de LangSmith. |
| `QUALITY_JUDGE_ENABLED` | `false` | Ejecutar un juez LLM económico después de cada respuesta para calificar calidad (1–5). Agrega ~1 llamada LLM adicional por ejecución. |

### Configuración del Unity Catalog de Databricks (Requerido)

Antes de usar funcionalidades de Databricks, asegúrate de que el Unity Catalog exista y tengas acceso:

```sql
CREATE CATALOG IF NOT EXISTS localuc;
GRANT USE CATALOG ON CATALOG localuc TO `user@enterprise.com`;
```

Ejecuta estos comandos en el **editor SQL de tu workspace de Databricks** antes de inicializar el pipeline de base de datos o consultar Databricks con el agente. Reemplaza `user@enterprise.com` con tu principal de Databricks real (correo de usuario o nombre de service principal).

## Ejecución

```bash
uv run python main.py
```

Sobrescribe la consulta por defecto con la variable de entorno `USER_QUERY`:

```bash
USER_QUERY="Use migrate_sql_query for: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name FROM pharmacy_db.dbo.dim_patient; then run_sql_query on the migrated SQL in Databricks." uv run python main.py
```

## Estructura del Proyecto

```
ai-sql-migration/
├── main.py                      # Punto de entrada e interfaz de consola rich
├── pyproject.toml               # Metadatos del proyecto y dependencias
├── .env.example                 # Plantilla de variables de entorno
└── src/
    ├── config/
    │   ├── settings.py          # Dataclass Settings cargada desde env (campos Anthropic + OpenRouter)
    │   └── llm_config.py        # Fábrica de modelos, clasificador de consultas (ClassifierResult), juez de calidad
    ├── graph/
    │   ├── builder.py           # Compilación del agente LangGraph
    │   ├── nodes.py             # Nodos de llamada LLM, herramientas y enrutamiento
    │   └── state.py             # Definición del estado del agente
    ├── models/                  # Modelos de datos
    ├── observability/
    │   └── metrics.py           # RunMetrics: latencia, tokens, estimación de costos, puntuación de calidad
    └── tools/
        ├── sql_migration.py     # Herramienta de migración SQL Edge -> Databricks (SQLFluff)
        ├── sqledge_sql.py       # Herramientas de Azure SQL Edge
        └── databricks_sql.py    # Herramientas de Databricks SQL (con polling asíncrono)
```

## Herramientas del Agente

### Azure SQL Edge

| Herramienta | Descripción |
|---|---|
| `run_sqledge_query` | Ejecuta una consulta `SELECT` de solo lectura contra la instancia de SQL Edge. Inyecta automáticamente `TOP N` para limitar resultados. |
| `describe_sqledge_table` | Devuelve nombres de columnas, tipos de datos y nulabilidad para una tabla dada mediante `INFORMATION_SCHEMA.COLUMNS`. |

### Databricks

| Herramienta | Descripción |
|---|---|
| `run_sql_query` | Ejecuta una consulta `SELECT`, `SHOW` o `DESCRIBE` de solo lectura contra Databricks SQL Warehouse. Agrega automáticamente `LIMIT N`. |
| `describe_table` | Describe el esquema de una tabla del Unity Catalog usando `DESCRIBE TABLE`. |
| `migrate_sql_query` | Migra SQL con sintaxis SQL Edge/T-SQL a Spark SQL usando reglas de lint + reescritura de SQLFluff. |

## Ejemplos de Uso

El agente clasifica automáticamente cada consulta en un nivel (`simple` / `medium` / `complex`) y la enruta al modelo apropiado. Usa consultas explícitas para que el agente también elija la herramienta y fuente de datos correcta.

### Nivel: simple

Consultas clasificadas como `simple` usan el modelo más ligero (ej. `claude-haiku` o `llama-3.1-8b:free`). Ideales para consultas de esquema o SELECTs básicos de una sola tabla.

#### Describir esquema de una tabla (SQL Edge)

```bash
USER_QUERY="Use describe_sqledge_table for dim_patient and list all columns." uv run python main.py
```

#### Describir esquema de una tabla (Databricks)

```bash
USER_QUERY="Use describe_table for localuc.gold.dim_patient and show me the columns." uv run python main.py
```

#### SELECT básico (SQL Edge)

```bash
USER_QUERY="Use run_sqledge_query to execute: SELECT TOP (5) [sk_patient_id], [first_name], [last_name], [is_active] FROM [localdb].[dbo].[dim_patient] WHERE [is_active] = 1" uv run python main.py
```

#### SELECT básico (Databricks)

```bash
USER_QUERY="Use run_sql_query to list 5 rows from localuc.gold.dim_patient." uv run python main.py
```

#### Migrar y ejecutar consulta básica (SQL Edge → Databricks)

```bash
USER_QUERY="Use migrate_sql_query for: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, ISNULL(last_name, 'unknown') AS last_name, GETDATE() AS migrated_at FROM localdb.dbo.dim_patient; then run_sql_query on the migrated SQL in Databricks."
uv run python main.py
```

---

### Nivel: medium

Consultas clasificadas como `medium` usan un modelo intermedio (ej. `claude-sonnet` o `mixtral-8x7b`). Ideales para agregaciones, JOINs simples y filtros compuestos.

#### Agregación con GROUP BY (SQL Edge)

```bash
USER_QUERY="Use run_sqledge_query to count patients grouped by primary_rare_disease, order by count descending, top 10." uv run python main.py
```

#### JOIN entre dos tablas (SQL Edge)

```bash
USER_QUERY="Use run_sqledge_query to join dim_patient with fact_prescription on sk_patient_id, show first_name, last_name and count of prescriptions per patient, top 5." uv run python main.py
```

#### Agregación en Databricks

```bash
USER_QUERY="Use run_sql_query on localuc.gold.fact_prescription to show total prescriptions per medication, grouped by medication name, top 10 ordered by total descending." uv run python main.py
```

---

### Nivel: complex

Consultas clasificadas como `complex` usan el modelo más capaz (ej. `claude-sonnet-4-5` o `claude-opus`). Ideales para migraciones completas T-SQL → Spark SQL y analytics multi-tabla.

#### Migrar consulta con window functions y CTE

```bash
export USER_QUERY="Use migrate_sql_query for this T-SQL, then run it with run_sql_query:
WITH ranked_patients AS (
    SELECT
        p.sk_patient_id,
        p.first_name,
        p.last_name,
        ISNULL(p.primary_rare_disease, 'Unknown') AS disease,
        COUNT(rx.sk_prescription_id) AS total_prescriptions,
        ROW_NUMBER() OVER (PARTITION BY p.primary_rare_disease ORDER BY COUNT(rx.sk_prescription_id) DESC) AS rn
    FROM localdb.dbo.dim_patient p
    LEFT JOIN localdb.dbo.fact_prescription rx ON p.sk_patient_id = rx.sk_patient_id
    WHERE p.is_active = 1
    GROUP BY p.sk_patient_id, p.first_name, p.last_name, p.primary_rare_disease
)
SELECT TOP 10 first_name, last_name, disease, total_prescriptions, rn
FROM ranked_patients
WHERE rn = 1
ORDER BY total_prescriptions DESC;"
uv run python main.py
```

#### Migrar consulta con JOIN y agregación

```bash
export USER_QUERY="Migrate this T-SQL to Databricks using migrate_sql_query, then run it with run_sql_query:
SELECT TOP 10
    p.first_name,
    p.last_name,
    COUNT(rx.sk_prescription_id) AS total_prescriptions,
    ISNULL(p.primary_rare_disease, 'Unknown') AS disease
FROM localdb.dbo.dim_patient p
JOIN localdb.dbo.fact_prescription rx ON p.sk_patient_id = rx.sk_patient_id
GROUP BY p.first_name, p.last_name, p.primary_rare_disease
ORDER BY total_prescriptions DESC"
uv run python main.py
```

#### Migrar desde archivo .sql

```bash
uv run python main.py --sql-file reports/patient_spending.sql
```

#### Guardar el SQL migrado a un archivo

```bash
uv run python main.py -q "SELECT TOP 5 GETDATE() AS ts, ISNULL(first_name,'?') AS name FROM localdb.dbo.dim_patient" --write-migrated output/migrated.sql
```

#### Uso programático

```python
from dotenv import load_dotenv
load_dotenv()

from src.config import Settings, classify_query
from src.graph.builder import build_agent
from langchain_core.messages import HumanMessage

settings = Settings.from_env()

query = "Migrate this SQL Edge query to Databricks and run it: SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name FROM pharmacy_db.dbo.dim_patient;"

# classify_query devuelve un ClassifierResult con .tier y uso de tokens
classifier_result = classify_query(settings, query)
agent = build_agent(settings, tier=classifier_result.tier)

result = agent.invoke({"messages": [HumanMessage(content=query)]})
print(result["messages"][-1].content)
```

## Dependencias

| Paquete | Propósito |
|---|---|
| `anthropic` | Cliente de API de Claude |
| `langchain-anthropic` | Modelo de chat Claude compatible con LangChain (usado cuando `ANTHROPIC_API_KEY` está configurada) |
| `langchain-openai` | Modelo de chat en formato OpenAI compatible con LangChain (usado para OpenRouter) |
| `langchain-core` | Abstracciones base para herramientas y mensajes |
| `langgraph` | Orquestación de grafos del agente |
| `pyodbc` | Conector ODBC para Azure SQL Edge |
| `databricks-sql-connector` | Conector de Databricks SQL warehouse |
| `python-dotenv` | Carga variables de entorno desde `.env` |
| `sqlfluff` | Linting/corrección SQL y asistencia de migración con conocimiento de dialectos |
| `rich` | Interfaz de terminal (paneles, markdown, salida con colores) |
