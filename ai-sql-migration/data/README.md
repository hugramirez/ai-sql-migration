# Directorio de datos

Inicialización de base de datos (`init_db.py`) y pipelines SQL bajo `pipelines/`.

## Databricks (Unity Catalog)

Desde **`ai-sql-migration`**, configura `DATABRICKS_HOST`, `DATABRICKS_TOKEN` y `DATABRICKS_WAREHOUSE_ID` en `.env`. El catálogo **`localuc`** debe existir y debes tener permiso `USE CATALOG`.

### Prerrequisitos: Crear el catálogo `localuc` (Requerido)

Antes de ejecutar `init_db_databricks.py`, el Unity Catalog **debe existir**. Ejecuta estos comandos SQL en el **editor SQL de tu workspace de Databricks**:

```sql
CREATE CATALOG IF NOT EXISTS localuc;
GRANT USE CATALOG ON CATALOG localuc TO `user@enterprise.com`;
```

Reemplaza `user@enterprise.com` con tu principal de Databricks (correo de usuario o service principal). Sin este paso, `init_db_databricks.py` fallará con errores de permiso o "catalog not found".

`DATABRICKS_WAREHOUSE_ID` debe ser el **UUID completo** del SQL warehouse (32 caracteres hexadecimales, con o sin guiones); un ID truncado generalmente produce HTTP 400 al conectar.

Opcional: `DATABRICKS_MAX_ROWS_PER_TABLE=100` limita la carga de CSVs de **dimensiones** bronze a las primeras *N* filas por tabla (pruebas de humo). Omite para una carga completa. CLI: `uv run python data/init_db_databricks.py init --max-rows 100` (usa `--max-rows 0` para ignorar el límite de entorno en esa ejecución).

- **CLI de Python**: `uv run python data/init_db_databricks.py --help` — `init` ejecuta DDL bronze, carga CSVs de dimensiones en `localuc.bronze.raw_dim_*`, luego silver / gold / vistas. Los archivos SQL que añaden `OPTIMIZE` después de un `CREATE TABLE … AS SELECT` se dividen automáticamente en sentencias separadas del warehouse. Los facts en bronze no se cargan desde `raw_data` (el esquema difiere de las exportaciones de SQL Server); extiende con tu propia ingesta.
- **Prueba de humo (solo SQL warehouse)**: `uv run python scripts/test_databricks_sql_connection.py` — ejecuta `SELECT 1` con los mismos parámetros de `databricks.sql.connect` que el pipeline (lee `.env`).
- **Notebook**: abre `data/init_db_databricks.ipynb` (incluye una celda de conexión mínima después de `load_dotenv`; mismo flujo que la CLI para el pipeline completo).

## Inicialización de base de datos

Crea la base de datos SQL Server, tablas y carga CSVs de muestra antes de consultar localmente.

### Prerrequisitos

- **Python**: ejecuta comandos con [`uv`](https://docs.astral.sh/uv/) desde el directorio **`ai-sql-migration`** (la carpeta que contiene `pyproject.toml`, `.env` y `data/`).
- **ODBC**: Microsoft **ODBC Driver 18 for SQL Server** (requerido por `init_db.py`).
- **SQL Server**: accesible en `SQLEDGE_HOST`:`SQLEDGE_PORT` con permiso para crear/eliminar bases de datos (ver abajo).

### Variables de entorno

Crea o edita `ai-sql-migration/.env`. `data/init_db.py` y `data/init_db_databricks.py` lo cargan con **`override=True`**, por lo que los valores en este archivo reemplazan variables del mismo nombre ya presentes en el entorno (incluyendo placeholders vacíos del shell o IDE).

```env
SQLEDGE_HOST=localhost
SQLEDGE_PORT=1433
SQLEDGE_DATABASE=localuc_db
SQLEDGE_USER=sa
SQLEDGE_PASSWORD=<tu_contraseña>
```

Omite `SQLEDGE_HOST`, `SQLEDGE_PORT` o `SQLEDGE_DATABASE` para usar los valores por defecto mostrados arriba. `SQLEDGE_USER` y `SQLEDGE_PASSWORD` son requeridos (valores vacíos hacen que el script termine).

### Inicio rápido

Desde **`ai-sql-migration`** (no la raíz del monorepo a menos que hagas `cd` a esta carpeta):

```bash
cd /ruta/a/ai-sql-migration
uv sync
uv run python data/init_db.py
```

Si la raíz del repositorio es `compufest-1-` y este proyecto vive en una subcarpeta:

```bash
cd compufest-1-/ai-sql-migration
uv run python data/init_db.py
```

Esto ejecuta `init()`, que:

1. **Elimina `localuc_db` si ya existe** (mejor esfuerzo), la recrea, luego ejecuta `pipelines/src_sql_server/run.sql` para crear tablas e índices.
2. Carga CSVs desde `data/raw_data/` en tablas `dbo.*` (ver orden de carga en `init_db.py`).
3. Escribe registros bajo `ai-sql-migration/logs/` como `data_load_YYYYMMDD_HHMMSS.log` (se crea un nuevo archivo de log cuando comienza la fase de carga de CSV).

**Advertencia:** El paso 1 es destructivo para el nombre de base de datos configurado. No apuntes `SQLEDGE_DATABASE` a una base de datos compartida o de producción.

### Pasos manuales

Desde **`ai-sql-migration`**, usa subcomandos (mismo `.env` que init completo):

```bash
# Solo tablas: eliminar/recrear base de datos + ejecutar DDL (sin carga CSV)
uv run python data/init_db.py create-tables

# Solo cargar CSVs: espera que las tablas ya existan
uv run python data/init_db.py load-data
```

Sobrescrituras opcionales (de lo contrario los valores vienen de `.env`):

```bash
uv run python data/init_db.py init --host 127.0.0.1 --user sa --password '...'
uv run python data/init_db.py load-data --data-path raw_data
```

Consulta `uv run python data/init_db.py --help` para todas las opciones (`--sql-file`, `--port`, `--database`, etc.).

## Estructura de directorios

```
data/
├── init_db.py                 # SQL Server / SQL Edge: crear BD + tablas + cargar CSVs (pyodbc)
├── init_db_databricks.py      # Databricks warehouse: DDL UC + cargas de dimensiones bronze
├── init_db_databricks.ipynb   # Notebook envoltorio para el pipeline de Databricks
├── README.md
├── raw_data/               # dim_*.csv, fact_*.csv (nombres de tabla coinciden con tablas dbo)
└── pipelines/
    ├── src_sql_server/
    │   ├── run.sql         # DDL concatenado (script único para init_db)
    │   ├── schemas/
    │   │   └── schema.sql
    │   ├── dimensions/     # Módulos DDL por tabla
    │   └── facts/
    └── src_databricks/
        ├── run.sql
        ├── schemas/
        ├── bronze/
        ├── silver/
        ├── gold/
        └── views/
```

Los archivos modulares bajo `dimensions/`, `facts/` y `schemas/` son las piezas fuente; actualiza `run.sql` cuando los modifiques si dependes de `init_db.py` (ver los comentarios `SOURCE SECTION` dentro de `run.sql`).

## Solución de problemas

### "ODBC Driver 18 for SQL Server" no encontrado

Instala el driver:

- **macOS**: `brew install msodbcsql18` (opcional: `mssql-tools18`)
- **Linux**: [Instalar el controlador ODBC de Microsoft para SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server)
- **Windows**: [Descargar ODBC Driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

### Conexión rechazada o inicio de sesión fallido

Confirma que SQL Server esté ejecutándose y escuchando en `SQLEDGE_HOST`:`SQLEDGE_PORT`, que TCP esté habilitado y que las reglas de firewall permitan al cliente. Este repositorio no incluye un archivo `docker-compose` raíz; usa tu propio contenedor o instancia local y alinea `.env` con él.

### Archivos CSV no encontrados

Las rutas CSV son `data/raw_data/<tabla>.csv` relativas a `data/init_db.py`. Desde `ai-sql-migration`:

```bash
ls -la data/raw_data/
```

## Modelo de datos

Consulta `pipelines/src_sql_server/run.sql` para el DDL completo.

**Dimensiones:** `dim_patient`, `dim_medication`, `dim_prescriber`, `dim_payer`, `dim_date`, `dim_care_team_member`

**Hechos:** `fact_prescription`, `fact_adherence`, `fact_clinical_interaction`, `fact_shipment`, `fact_last_event`
