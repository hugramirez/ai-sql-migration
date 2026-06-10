# Notas del Agente para ai-sql-migration

## Inicio Rápido

Instalar y ejecutar:
```bash
cd ai-sql-migration
uv sync
cp .env.example .env  # completar credenciales
uv run python main.py
```

Sobrescribir la consulta con `USER_QUERY`:
```bash
USER_QUERY="Use run_sql_query to..." uv run python main.py
```

## Estructura del Proyecto

Proyecto Python de un solo paquete bajo `ai-sql-migration/`.

- **`main.py`** — Punto de entrada; ejecuta el agente LangGraph y formatea la salida con paneles de consola rich.
- **`pyproject.toml`** — Dependencias, Python 3.13+, uv como gestor de paquetes.
- **`src/config/`** — Configuración desde `.env` (usa `python-dotenv`); system prompt; fábrica de cliente LLM; `classify_query()` retorna `ClassifierResult` (tier + uso de tokens); `judge_response()` para puntuación de calidad.
- **`src/graph/`** — Agente LangGraph: `builder.py` compila el grafo, `nodes.py` tiene llamada LLM / nodo de herramientas / enrutamiento, `state.py` define MessagesState.
- **`src/observability/`** — `metrics.py`: dataclass `RunMetrics`, `collect_run_metrics()`, tabla de estimación de costos por modelo. Se imprime como panel después de cada ejecución.
- **`src/tools/`** — Cinco herramientas: `migrate_sql_query` (SQLFluff T-SQL→Spark SQL), `run_sqledge_query`, `describe_sqledge_table`, `run_sql_query`, `describe_table`.
- **`tests/`** — Dos archivos de prueba; usan pytest. `test_sql_migration.py` prueba reescrituras de SQLFluff (TOP→LIMIT, ISNULL→COALESCE, etc.).
- **`data/`** — Scripts de inicialización de BD (`init_db.py` para SQL Edge, `init_db_databricks.py` para Databricks) y archivos CSV de datos.

## Particularidades Clave

### Variables de Entorno
El archivo `.env` **debe** estar presente (`.env.example` es la plantilla). `python-dotenv` lo carga en `settings.py` al importar el módulo con `override=True`, por lo que el `.env` local tiene prioridad.

Críticas para la operación del agente:

- `ANTHROPIC_API_KEY` — Requerida **a menos** que `OPENROUTER_API_KEY` esté configurada. Al menos una debe estar presente.
- `ANTHROPIC_MODEL_CLASSIFIER` / `ANTHROPIC_MODEL_SIMPLE` / `ANTHROPIC_MODEL_MEDIUM` / `ANTHROPIC_MODEL_COMPLEX` — Modelos Claude por nivel (por defecto: haiku / haiku / sonnet / sonnet).
- `OPENROUTER_API_KEY` — Opcional. Cuando está configurada, tiene prioridad sobre Anthropic.
- `OPENROUTER_MODEL_CLASSIFIER` / `OPENROUTER_MODEL_SIMPLE` / `OPENROUTER_MODEL_MEDIUM` / `OPENROUTER_MODEL_COMPLEX` — Modelos OpenRouter por nivel (por defecto: llama-3.1-8b:free / llama-3.1-8b:free / mixtral-8x7b / claude-sonnet-4-5).
- `LANGSMITH_TRACING` / `LANGSMITH_API_KEY` / `LANGSMITH_PROJECT` — Trazado LangSmith. **Deben estar en `.env`** — configurarlos en tiempo de ejecución es demasiado tarde (LangChain los lee al importar).
- `QUALITY_JUDGE_ENABLED` — Configurar `true` para puntuar cada respuesta del 1–5 con un modelo clasificador económico.
- `SQLEDGE_*` — Conexión a SQL Edge (Docker ejecutando `azure-sql-edge`).
- `DATABRICKS_*` — Databricks SQL Warehouse.
- `UC_*` — Unity Catalog (tablas reasignadas mediante la variable de entorno `SQL_MIGRATION_UC_PREFIX`, por defecto: `pharmacy.gold.*`).
- `SQLFLUFF_*` — Controla la migración SQL: `ENABLED`, `SOURCE_DIALECT=tsql`, `TARGET_DIALECT=sparksql`.

### Migración SQL (SQLFluff)
`migrate_sql_query` en `src/tools/sql_migration.py`:
- Usa reglas de lint + reescritura de SQLFluff para convertir T-SQL a Spark SQL.
- Reescribe: `TOP N` → `LIMIT`, `ISNULL()` → `COALESCE()`, `GETDATE()` → `current_timestamp()`.
- **Reasignación de tablas**: `pharmacy_db.dbo.dim_*` → `pharmacy.gold.dim_*` (o según `SQL_MIGRATION_UC_PREFIX`).
- Salida: string con línea marcadora `MIGRATED_SQL:` (parseada por `parse_migrated_sql_line`).
- Las pruebas usan `monkeypatch` para sobrescribir la variable de entorno `SQL_MIGRATION_UC_PREFIX`.

### Visualización y Manejo de Mensajes
`main.py` tiene ayudantes de visualización:
- `_last_migrated_spark_sql()` — Extrae el SQL final de la salida de la herramienta de migración.
- `_ai_migration_summary_block()` — Detecta "Migration Summary" + formato de resultados.
- `_human_display_body()` — Trunca consultas SQL largas (>500 caracteres) para la consola; la consulta completa aún se envía al LLM.

Útil para entender el flujo de mensajes: el agente LangGraph retorna `state["messages"]` (lista de HumanMessage, AIMessage, ToolMessage).

## Pruebas

Ejecutar todas las pruebas:
```bash
pytest
```

`test_sql_migration.py` cubre reescrituras SQL y reasignación de tablas. Usa el fixture `monkeypatch` de pytest para sobrescribir variables de entorno en las pruebas.

## System Prompt del Agente

Definido en `settings.py`. Reglas clave que el agente ve:
- Dos fuentes de datos: SQL Edge (T-SQL, `pharmacy_db.dbo.*`) y Databricks (Spark SQL, `pharmacy.gold.*`).
- Para migración: llamar a `migrate_sql_query`, extraer SQL de la línea `MIGRATED_SQL:`, luego llamar a `run_sql_query`.
- Usar siempre la herramienta correcta para la fuente de datos correcta (ambiguo → preferir SQL Edge).
- Solo consultas de solo lectura (no INSERT/UPDATE/DELETE/DDL).
- Formatear siempre los resultados como tablas markdown.

## LLM y Herramientas

- **Selección de proveedor**: Si `OPENROUTER_API_KEY` está configurada → `ChatOpenAI` vía `langchain-openai` apuntando a `https://openrouter.ai/api/v1`. De lo contrario → `ChatAnthropic` vía `langchain-anthropic`.
- **Clasificador de consultas**: `classify_query()` en `llm_config.py` corre en **ambos** proveedores. Retorna un `ClassifierResult` con `.tier` (`simple`/`medium`/`complex`) y `.input_tokens`/`.output_tokens` para incluir en métricas. Cae a `tier="complex"` con tokens=0 en cualquier error.
- **Niveles de modelo**: `build_agent(settings, tier)` selecciona el modelo del nivel correspondiente (`settings.openrouter_model_{tier}` o `settings.anthropic_model_{tier}`). Nivel por defecto: `complex`.
- **Observabilidad**: después de cada `agent.invoke()`, `collect_run_metrics()` agrega tokens del agente + tokens del clasificador para coincidir con LangSmith. Se imprime un panel `Run Metrics` en consola con latencia, llamadas LLM, herramientas usadas, tokens, costo estimado y puntuación de calidad (si `QUALITY_JUDGE_ENABLED=true`).
- **Databricks asíncrono**: `run_sql_query` usa polling (`_poll_statement()`) cuando Databricks devuelve estado `PENDING`/`RUNNING`. Máximo 300s de espera con backoff de 1s→5s.
- **Herramientas**: Cinco herramientas vinculadas al modelo; el router de LangGraph decide tool-call vs. END.
- **Grafo**: START → llm_call → [tool_node o END] → llm_call (bucle hasta que no haya más llamadas a herramientas).

## Configuración del Unity Catalog de Databricks

Antes de inicializar el pipeline de Databricks, asegúrate de que el catálogo `localuc` exista y tu usuario tenga acceso:

```sql
CREATE CATALOG IF NOT EXISTS localuc;
GRANT USE CATALOG ON CATALOG localuc TO `user@enterprise.com`;
```

Ejecuta estos comandos en el editor SQL de tu workspace de Databricks **antes** de ejecutar `data/init_db_databricks.py`. El pipeline espera que `localuc` exista y creará esquemas (`bronze`, `silver`, `gold`) y tablas dentro de él.

## Errores Comunes

1. **Falta `.env`** — Fallará al importar (sin respaldo).
2. **Ninguna clave API configurada** — `Settings.from_env()` lanza `SystemExit` si tanto `ANTHROPIC_API_KEY` como `OPENROUTER_API_KEY` están vacías. Configura al menos una.
3. **Fuente de datos incorrecta** — El agente usa SQL Edge por defecto si es ambiguo; debe ser explícito si se usa Databricks.
4. **Olvidar la reasignación de tablas** — `pharmacy_db.dbo.dim_patient` debe reescribirse a `pharmacy.gold.dim_patient` antes de ejecutar en Databricks.
5. **SQLFluff deshabilitado** — Configurar `SQLFLUFF_ENABLED=true` en `.env`.
6. **Sobrescrituras de entorno obsoletas** — Si pruebas con `SQL_MIGRATION_UC_PREFIX`, recuerda que afecta todas las migraciones en esa sesión.
7. **Catálogo de Databricks faltante** — `localuc` debe existir antes de ejecutar `init_db_databricks.py`; créalo con los comandos SQL anteriores.
8. **Modelo OpenRouter sin soporte de tool-calling** — El modelo clasificador gratuito (`llama-3.1-8b-instruct:free`) solo emite una respuesta de una palabra y no usa herramientas. Los modelos de agente (`SIMPLE`/`MEDIUM`/`COMPLEX`) deben soportar function calling; los valores por defecto (`llama-3.1-8b`, `mixtral-8x7b`, `claude-sonnet-4-5`) sí lo hacen.
9. **Variables LangSmith configuradas en tiempo de ejecución** — `LANGSMITH_TRACING`, `LANGSMITH_API_KEY` y `LANGSMITH_PROJECT` deben estar presentes en `.env` antes de que el proceso inicie. Configurarlos mediante `os.environ` dentro de `main()` es demasiado tarde — LangChain lee la configuración de trazado al importar.
10. **Consulta Databricks en PENDING** — `run_sql_query` ahora hace polling automáticamente cuando Databricks devuelve `PENDING` o `RUNNING`. Si aún ves comportamiento de reintento en LangSmith, verifica que `DATABRICKS_WAREHOUSE_ID` sea correcto y que el warehouse esté ejecutándose.
