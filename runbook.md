# Runbook

Este documento proporciona un guía paso a paso para configurar **Azure SQL Edge** y **Databricks** para el proyecto `ai-sql-migration`.

---

## Requisitos Previos

- **Python 3.13+**
- **Docker Desktop** instalado y en ejecución
  - Windows: [Docker Desktop para Windows](https://docs.docker.com/desktop/install/windows-install/)
  - macOS: [Docker Desktop para Mac](https://docs.docker.com/desktop/install/mac-install/)
  - Linux: [Docker Engine](https://docs.docker.com/engine/install/)
- Mínimo **2 GB de RAM** disponible para el contenedor
- Acceso a la red local (para conectar desde la máquina host)

---

## 0. Instalar uv

**Opción A: Con pip (recomendado)**
```bash
pip install uv
```


---

## 1. Verificar instalación de Docker

```bash
docker --version
docker run hello-world
```

Si falla, instala Docker Desktop desde los enlaces anteriores.

---

## 2. Instalar ODBC Driver 18 para SQL Server

### Windows

```powershell
winget install Microsoft.ODBCDriver18ForSQLServer
```

### macOS

```bash
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql18 mssql-tools18
```

### Linux (Ubuntu/Debian)

```bash
sudo apt-get install unixodbc-dev
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo apt-get install msodbcsql18
```

---

## 3. Configurar `.env`

Copia el archivo `.env.example` y complétalo con tus credenciales:

```bash
cp .env.example .env
```

Luego edita `.env` y agrega los valores requeridos:

```ini
# Azure SQL Edge
SQLEDGE_HOST=localhost
SQLEDGE_PORT=1433
SQLEDGE_DATABASE=master
SQLEDGE_USER=sa
SQLEDGE_PASSWORD=value

# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Databricks (opcional)
DATABRICKS_HOST=https://adb-XXXXXXXX.XX.databricks.com
DATABRICKS_TOKEN=dapi...
DATABRICKS_WAREHOUSE_ID=...
UC_CATALOG=localuc
UC_SCHEMA=bronze
```

Consulta el [README → Setup](README.md#setup) para obtener los valores de cada variable.

---

## 4. Descargar la Imagen de Azure SQL Edge

```bash
docker pull mcr.microsoft.com/azure-sql-edge
```

Verifica que se descargó correctamente:

```bash
docker images | grep azure-sql-edge
```

---

## 5. Crear y Ejecutar el Contenedor

Lee `SQLEDGE_PASSWORD` desde `.env` y ejecuta el contenedor:

```bash
# Carga variables del .env y ejecuta el contenedor
set -a
source .env
set +a

docker run \
  --name azure-sql-edge-dev \
  --cap-add SYS_PTRACE \
  -e 'ACCEPT_EULA=1' \
  -e "MSSQL_SA_PASSWORD=$SQLEDGE_PASSWORD" \
  -e 'MSSQL_PID=Developer' \
  -p 1433:1433 \
  -v sql_edge_data:/var/opt/mssql \
  -v sql_edge_backup:/var/opt/mssql/backup \
  -d \
  mcr.microsoft.com/azure-sql-edge
```

---

## 6. Verificar que el Contenedor Está Corriendo

```bash
docker ps
docker logs azure-sql-edge-dev
```

Cuando veas `SQL Engine initialized successfully`, está listo.

---

# Databricks Setup

⚠️ **Prerequisitos**: Antes de continuar, completa la configuración en el [README → Requirements](README.md#requirements):
- Databricks workspace con SQL warehouse (en estado `RUNNING`)
- Unity Catalog `localuc` creado
- Schema `default` dentro del catalog

---

## 1. Generar Token de Acceso Personal (PAT)

1. En Databricks workspace, haz clic en tu **avatar** (esquina superior derecha)
2. Selecciona **Settings** → **Developer**
3. Ve a **Access tokens**
4. Haz clic en **Generate new token**
5. Configura:
   - **Token name**: `ai-migration-token`
   - **Lifetime**: `90 days` (o según tu política)
6. Haz clic en **Generate**
7. **Copia el token** (solo se muestra una vez)

---

## 2. Configurar `.env` para Databricks

Edita el archivo `.env` y agrega:

```ini
DATABRICKS_HOST=https://adb-XXXXXXXX.XX.databricks.com
DATABRICKS_TOKEN=dapi1234567890abcdef1234567890abcd
DATABRICKS_WAREHOUSE_ID=warehouse-id-full-uuid
UC_CATALOG=localuc
UC_SCHEMA=bronze
```

Consulta el [README → Setup](README.md#setup) para obtener los valores exactos de cada variable.

---

## 3. Probar Conexión a Databricks

Ejecuta el test desde el proyecto:

```bash
cd ai-sql-migration
uv run python scripts/test_databricks_sql_connection.py
```

Si muestra `Connection OK.`, la conexión es exitosa.

---

## 7. Sincronizar Dependencias

Desde el directorio `ai-sql-migration`:

```bash
uv sync
```

---

# Crear Esquemas y Poblar Bases de Datos

Una vez completada la instalación básica, crea los esquemas (estructura de tablas) y puebla las bases de datos.

## SQL Server / Azure SQL Edge

### Prerrequisitos

- Docker container `azure-sql-edge-dev` ejecutándose (paso 5 del setup anterior)
- Archivo `.env` con `SQLEDGE_HOST`, `SQLEDGE_PORT`, `SQLEDGE_USER`, `SQLEDGE_PASSWORD`, `SQLEDGE_DATABASE`

### Ejecución

Desde el directorio `ai-sql-migration`:

```bash
uv run python data/init_db.py
```

Esto:
1. Elimina y recrea la base de datos especificada en `SQLEDGE_DATABASE` (por defecto: `localuc_db`)
2. Ejecuta el DDL desde `data/pipelines/src_sql_server/run.sql` para crear tablas e índices
3. Carga los datos de `data/raw_data/` en las tablas correspondientes
4. Registra el proceso en `logs/data_load_YYYYMMDD_HHMMSS.log`

Para más opciones, consulta [data/README.md](ai-sql-migration/data/README.md).

---

## Databricks (Unity Catalog)

### Prerrequisitos

- Databricks workspace con SQL warehouse activo (`RUNNING`)
- **Unity Catalog `localuc` previamente creado** en Databricks
- Tokens PAT (`DATABRICKS_TOKEN`) generado (paso 1 del setup de Databricks)
- Variables de entorno en `.env`: `DATABRICKS_HOST`, `DATABRICKS_TOKEN`, `DATABRICKS_WAREHOUSE_ID`, `UC_CATALOG`, `UC_SCHEMA`

### Crear el Catálogo (si no existe)

Si aún no has creado `localuc`, ejecuta estos comandos en el editor SQL de tu workspace de Databricks:

```sql
CREATE CATALOG IF NOT EXISTS localuc;
GRANT USE CATALOG ON CATALOG localuc TO `tu_email@dominio.com`;
```

Reemplaza `tu_email@dominio.com` con tu principal de Databricks.

### Ejecución

Desde el directorio `ai-sql-migration`:

```bash
uv run python data/init_db_databricks.py init
```

Esto:
1. Crea el esquema `bronze` en el catálogo `localuc` (DDL desde `data/pipelines/src_databricks/run.sql`)
2. Carga las tablas de dimensión desde CSVs en `data/raw_data/dim_*.csv`
3. Crea esquemas `silver` y `gold`
4. Registra el progreso en la consola

Para más opciones, consulta [data/README.md](ai-sql-migration/data/README.md).

---

## Checklist de Verificación

### Azure SQL Edge
- [ ] Docker Desktop instalado
- [ ] ODBC Driver 18 instalado
- [ ] Archivo `.env` creado con `SQLEDGE_PASSWORD`
- [ ] Contenedor `azure-sql-edge-dev` ejecutándose (`docker ps`)
- [ ] Test SQL Edge ejecutado con éxito

### Databricks
- [ ] Token PAT generado
- [ ] Variables `DATABRICKS_*` y `UC_*` en `.env`
- [ ] Test Databricks ejecutado con éxito

### Proyecto
- [ ] Dependencias sincronizadas: `uv sync`
- [ ] Archivo `.env` completo
- [ ] Proyecto listo para usar: `uv run python main.py`
