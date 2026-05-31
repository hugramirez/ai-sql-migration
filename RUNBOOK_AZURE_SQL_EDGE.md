# Runbook: Docker Azure SQL Edge Setup

Este documento proporciona un guía paso a paso para configurar un contenedor Docker con **Azure SQL Edge** para el proyecto `ai-sql-migration`.

---

## Requisitos Previos

- **Docker Desktop** instalado y en ejecución
  - Windows: [Docker Desktop para Windows](https://docs.docker.com/desktop/install/windows-install/)
  - macOS: [Docker Desktop para Mac](https://docs.docker.com/desktop/install/mac-install/)
  - Linux: [Docker Engine](https://docs.docker.com/engine/install/)
- **ODBC Driver 18 for SQL Server** instalado (ver sección de instalación)
- Mínimo **2 GB de RAM** disponible para el contenedor
- Acceso a la red local (para conectar desde la máquina host)

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
# Opción A: Mediante winget
winget install Microsoft.ODBCDriver17ForSQLServer

# Opción B: Descarga manual
# https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server
```

### macOS

```bash
# Con Homebrew
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql18 mssql-tools18
```

### Linux (Ubuntu/Debian)

```bash
sudo apt-get install odbc-mysql
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo apt-get install msodbcsql18
```

---

## 3. Configurar Variables de Entorno

Antes de ejecutar el contenedor, define la contraseña de SQL Edge y otros parámetros:

```bash
# Variables recomendadas
export SQLEDGE_PASSWORD="Sql.Secure99**"
export SQLEDGE_PORT=1433
export SQLEDGE_HOST=localhost
```

⚠️ **Nota**: La contraseña usada es `Sql.Secure99**` (ya incluye mayúsculas, minúsculas, números y caracteres especiales).

---

## 4. Descargar la Imagen de Azure SQL Edge

```bash
docker pull mcr.microsoft.com/azure-sql-edge:latest
```

Para verificar que se descargó correctamente:

```bash
docker images | grep azure-sql-edge
```

---

## 5. Crear y Ejecutar el Contenedor

```bash
docker run \
  --name azure-sql-edge-dev \
  --cap-add SYS_PTRACE \
  -e 'ACCEPT_EULA=1' \
  -e 'MSSQL_SA_PASSWORD=Sql.Secure99**' \
  -e 'MSSQL_PID=Developer' \
  -p 1433:1433 \
  -v sql_edge_data:/var/opt/mssql \
  -v sql_edge_backup:/var/opt/mssql/backup \
  -it \
  mcr.microsoft.com/azure-sql-edge
```

**Parámetros explicados:**
- `--name azure-sql-edge-dev`: Nombre del contenedor para desarrollo
- `--cap-add SYS_PTRACE`: Permite depuración avanzada dentro del contenedor
- `-e ACCEPT_EULA=1`: Acepta los términos de licencia
- `-e MSSQL_SA_PASSWORD=Sql.Secure99**`: Contraseña del usuario `sa` (admin)
- `-e MSSQL_PID=Developer`: Usa la edición Developer de SQL Edge (sin límites de licencia)
- `-p 1433:1433`: Mapea puerto 1433 (SQL Server) del contenedor al host
- `-v sql_edge_data:/var/opt/mssql`: Volumen persistente para la base de datos
- `-v sql_edge_backup:/var/opt/mssql/backup`: Volumen persistente para backups
- `-it`: Modo interactivo con terminal (útil para logs en tiempo real)

---

## 6. Verificar que el Contenedor Está Corriendo

```bash
# Ver contenedores en ejecución
docker ps

# Ver logs del contenedor
docker logs azure-sql-edge-dev

# Esperar a que esté listo (puede tomar 30-60 segundos)
docker logs -f azure-sql-edge-dev
```

Cuando veas un mensaje similar a esto, está listo:

```
2026-05-30 12:34:56.789  INFO: SQL Engine initialized successfully
```

---

## 7. Probar Conexión a SQL Edge

### Opción A: Con sqlcmd (si tienes SQL Server tools)

```bash
sqlcmd -S localhost -U sa -P "Sql.Secure99**" -Q "SELECT @@VERSION"
```

### Opción B: Dentro del contenedor

```bash
docker exec -it azure-sql-edge-dev /opt/mssql-tools18/bin/sqlcmd -U sa -P "Sql.Secure99**" -Q "SELECT @@VERSION"
```

### Opción C: Desde Python (test del proyecto)

```python
import pyodbc

conn_str = (
    'Driver={ODBC Driver 18 for SQL Server};'
    'Server=localhost,1433;'
    'Database=master;'
    'UID=sa;'
    'PWD=Sql.Secure99**;'
)

try:
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    cursor.execute("SELECT @@VERSION")
    print(cursor.fetchone())
    conn.close()
    print("✓ Conexión exitosa!")
except Exception as e:
    print(f"✗ Error: {e}")
```

---

## 8. Configurar Variables de Entorno del Proyecto

Edita el archivo `.env` en la raíz del proyecto:

```bash
# SQL Edge
SQLEDGE_HOST=localhost
SQLEDGE_PORT=1433
SQLEDGE_DATABASE=master
SQLEDGE_USER=sa
SQLEDGE_PASSWORD=

# Resto de configuración
ANTHROPIC_API_KEY=sk-ant-...
DATABRICKS_HOST=...
DATABRICKS_TOKEN=...
```

---

## Troubleshooting

### ❌ "Cannot connect to SQL Edge"

**Causa**: El contenedor no está en ejecución o toma demasiado tiempo en iniciar.

**Solución**:
```bash
docker ps  # Verifica si está en ejecución
docker logs azure-sql-edge-dev  # Revisa los logs
docker restart azure-sql-edge-dev  # Reinicia el contenedor
```

---

### ❌ "Login failed for user 'sa'"

**Causa**: Contraseña incorrecta.

**Solución**:
```bash
# Detén el contenedor
docker stop azure-sql-edge-dev
docker rm azure-sql-edge-dev

# Ejecuta nuevamente con la contraseña correcta
docker run \
  --name azure-sql-edge-dev \
  --cap-add SYS_PTRACE \
  -e 'ACCEPT_EULA=1' \
  -e 'MSSQL_SA_PASSWORD=Sql.Secure99**' \
  -e 'MSSQL_PID=Developer' \
  -p 1433:1433 \
  -v sql_edge_data:/var/opt/mssql \
  -v sql_edge_backup:/var/opt/mssql/backup \
  -it \
  mcr.microsoft.com/azure-sql-edge
```

---

### ❌ "Port 1433 already in use"

**Causa**: Otro contenedor o servicio usa el puerto 1433.

**Solución**:

**Windows/macOS:**
```bash
# Identifica qué usa el puerto
lsof -i :1433

# Usa un puerto diferente
docker run \
  --name azure-sql-edge-dev \
  --cap-add SYS_PTRACE \
  -e 'ACCEPT_EULA=1' \
  -e 'MSSQL_SA_PASSWORD=Sql.Secure99**' \
  -e 'MSSQL_PID=Developer' \
  -p 1434:1433 \
  -v sql_edge_data:/var/opt/mssql \
  -v sql_edge_backup:/var/opt/mssql/backup \
  -it \
  mcr.microsoft.com/azure-sql-edge
```

Luego actualiza `.env`:
```
SQLEDGE_PORT=1434
```

---

### ❌ "ODBC Driver not found"

**Causa**: ODBC Driver 18 no instalado.

**Solución**:
```bash
# Verifica drivers instalados
odbcinst -j

# Instala ODBC Driver 18 (ver sección 2)
```

---

### ❌ "Permission denied" (Linux)

**Causa**: El usuario no tiene permisos para ejecutar Docker.

**Solución**:
```bash
# Agrega el usuario al grupo docker
sudo usermod -aG docker $USER
newgrp docker

# O ejecuta con sudo
sudo docker run ...
```

---

## Operaciones Comunes

### Detener el contenedor

```bash
docker stop azure-sql-edge-dev
```

### Iniciar el contenedor (después de detenerlo)

```bash
docker start azure-sql-edge-dev
```

### Ver logs en tiempo real

```bash
docker logs -f azure-sql-edge-dev
```

### Acceder al contenedor interactivamente

```bash
docker exec -it azure-sql-edge-dev /bin/bash
```

### Eliminar el contenedor (cuando ya no lo necesites)

```bash
docker stop azure-sql-edge-dev
docker rm azure-sql-edge-dev
docker volume rm sql_edge_data  # Si usaste volumen persistente
docker volume rm sql_edge_backup  # Si usaste volumen de backup
```

### Limpiar todo (contenedores, imágenes, volúmenes no usados)

```bash
docker system prune -a --volumes
```

---

# Databricks Setup

⚠️ **Prerequisitos**: Antes de continuar, completa la configuración en el README:
- [Databricks workspace with SQL warehouse](README.md#requirements)
- [Unity Catalog (`localuc`) exists](README.md#requirements)

Consulta la sección **Setup** del README para crear/verificar SQL Warehouse y Unity Catalog.

---

## 1. Generar Token de Acceso Personal (PAT)

1. En el workspace, haz clic en tu **avatar** (esquina superior derecha)
2. Selecciona **Settings** → **Developer**
3. Ve a **Access tokens**
4. Haz clic en **Generate new token**
5. Configura:
   - **Token name**: `ai-migration-token`
   - **Lifetime**: `90 days` (o según tu política)
6. Haz clic en **Generate**
7. **Copia y guarda el token** en un lugar seguro (solo se muestra una vez)

⚠️ **Importante**: El token es sensible como una contraseña. No lo compartas ni lo comits al repositorio.

---

## 2. Configurar Variables de Entorno

Edita o crea el archivo `.env` en la raíz del proyecto con los valores del README:

```bash
# Databricks (ver tabla en README → Databricks connection)
DATABRICKS_HOST=https://adb-1234567890123456.XX.databricks.com
DATABRICKS_TOKEN=dapi1234567890abcdef1234567890abcd
DATABRICKS_WAREHOUSE_ID=warehouse-id-123456
UC_CATALOG=localuc
UC_SCHEMA=default
```

---

## 3. Probar Conexión a Databricks

### Opción A: Desde el SQL Editor de Databricks

1. Ve a **SQL** → **SQL Editor**
2. Selecciona el warehouse en el dropdown superior
3. Ejecuta una query simple:

```sql
SELECT 1 AS test
```

Si funciona, tu warehouse está activo y accesible.

### Opción B: Desde Python (test del proyecto)

```python
from databricks.sql import connect

try:
    conn = connect(
        server_hostname="adb-1234567890123456.XX.databricks.com",
        http_path="/sql/1.0/warehouses/warehouse-id-123456",
        auth_type="pat",
        token="dapi1234567890abcdef1234567890abcd"
    )
    cursor = conn.cursor()
    cursor.execute("SELECT 1 AS test")
    result = cursor.fetchone()
    print(f"✓ Conexión exitosa! Resultado: {result}")
    conn.close()
except Exception as e:
    print(f"✗ Error: {e}")
```

### Opción C: Verificar Unity Catalog

```sql
-- En el SQL editor de Databricks
SELECT * FROM localuc.default.information_schema.tables
LIMIT 5;
```

Si devuelve resultados, tu Unity Catalog está accesible.

---

## 4. Crear Tablas de Prueba (Opcional)

Para probar la migración desde SQL Edge:

```sql
-- En el SQL editor de Databricks
USE CATALOG localuc;
USE SCHEMA default;

CREATE TABLE IF NOT EXISTS pharmacy_db (
    sk_patient_id INT,
    first_name STRING,
    last_name STRING,
    date_of_birth DATE,
    is_active INT
);

INSERT INTO pharmacy_db VALUES
    (1, 'John', 'Doe', '1980-01-15', 1),
    (2, 'Jane', 'Smith', '1985-06-20', 1);

SELECT * FROM pharmacy_db;
```

---

## Troubleshooting Databricks

### ❌ "Invalid token / Unauthorized"

**Causa**: Token inválido, expirado o incorrecto.

**Solución**:
```bash
# Genera un nuevo token:
# 1. Ve a Settings → Developer → Access tokens
# 2. Haz clic en "Generate new token"
# 3. Copia el token y actualiza .env
```

---

### ❌ "Warehouse not found / Invalid warehouse ID"

**Causa**: El warehouse ID es incorrecto o no existe.

**Solución**:
```bash
# 1. Ve a SQL → SQL Warehouses
# 2. Selecciona el warehouse que quieras usar
# 3. Copia el ID exacto de los detalles
# 4. Actualiza DATABRICKS_WAREHOUSE_ID en .env
```

---

### ❌ "Catalog 'localuc' not found"

**Causa**: El Unity Catalog no existe o no tienes permisos.

**Solución**:
```sql
-- En el SQL editor de Databricks
-- Verifica que exista:
SHOW CATALOGS;

-- Si no existe localuc, créalo:
CREATE CATALOG IF NOT EXISTS localuc;

-- Si tienes permisos insuficientes, pide a un admin que ejecute:
GRANT USE CATALOG ON CATALOG localuc TO `your-email@company.com`;
```

---

### ❌ "Schema 'default' not found"

**Causa**: El schema dentro del catalog no existe.

**Solución**:
```sql
-- En el SQL editor de Databricks
-- Verifica que exista:
SHOW SCHEMAS IN CATALOG localuc;

-- Si no existe default, créalo:
CREATE SCHEMA IF NOT EXISTS localuc.default;

-- Otorga permisos si es necesario:
GRANT USE SCHEMA ON SCHEMA localuc.default TO `your-email@company.com`;
```

---

### ❌ "Query timeout / Warehouse too slow"

**Causa**: El warehouse es muy pequeño o está sobrecargado.

**Solución**:
1. Ve a **SQL** → **SQL Warehouses**
2. Selecciona tu warehouse
3. Haz clic en **Edit**
4. Aumenta el **Cluster size** (ej: `2X-Small` → `Small`)
5. Haz clic en **Update**

---

### ❌ "Connection refused / Host unreachable"

**Causa**: El host de Databricks es incorrecto o la red está bloqueada.

**Solución**:
```bash
# Verifica la URL del workspace:
# 1. Ve a Databricks
# 2. Copia la URL de la barra de direcciones
# 3. Debería ser: https://adb-XXXXXXX.XX.databricks.com
# 4. Actualiza DATABRICKS_HOST en .env

# Prueba la conexión:
curl -I https://your-databricks-host.com
```

---

## Operaciones Comunes en Databricks

### Detener un SQL Warehouse (para ahorrar créditos)

1. Ve a **SQL** → **SQL Warehouses**
2. Selecciona el warehouse
3. Haz clic en **Stop**

⚠️ **Nota**: Detener un warehouse pausará las operaciones pero no eliminará los datos.

---

### Eliminar un Catalog (si es necesario)

```sql
-- En el SQL editor de Databricks
-- Primero, elimina todos los schemas dentro del catalog
DROP SCHEMA localuc.default CASCADE;

-- Luego, elimina el catalog
DROP CATALOG localuc;
```

---

### Monitorear uso de créditos

1. Ve a **Account** (si tienes acceso de admin)
2. Selecciona **Billing**
3. Revisa el **Cost analysis** para ver el consumo de créditos

---

## Recursos Adicionales para Databricks

- [Databricks Documentation](https://docs.databricks.com/)
- [Unity Catalog Setup](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)
- [SQL Warehouse Guide](https://docs.databricks.com/en/sql/admin/warehouse-type.html)
- [Personal Access Tokens](https://docs.databricks.com/en/dev-tools/auth.html#personal-access-tokens)
- [databricks-sql-connector Python](https://github.com/databricks/databricks-sql-python)

---

## Recursos Adicionales

- [Azure SQL Edge Documentation](https://docs.microsoft.com/en-us/azure/azure-sql-edge/)
- [Docker Documentation](https://docs.docker.com/)
- [ODBC Driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)
- [pyodbc Documentation](https://github.com/mkleehammer/pyodbc)

---

## Checklist de Verificación

### Azure SQL Edge
- [ ] Docker Desktop instalado y en ejecución
- [ ] ODBC Driver 18 instalado
- [ ] Imagen `azure-sql-edge` descargada
- [ ] Contenedor ejecutándose (`docker ps` muestra `azure-sql-edge-dev`)
- [ ] Conexión exitosa a `localhost:1433`
- [ ] Variables `.env` configuradas para SQL Edge (SQLEDGE_*)

### Databricks
- [ ] Cuenta Databricks activa con workspace accesible
- [ ] SQL Warehouse creado y en estado `RUNNING`
- [ ] Warehouse ID anotado
- [ ] Unity Catalog `localuc` creado
- [ ] Schema `default` creado dentro del catalog
- [ ] Token de acceso personal (PAT) generado
- [ ] Variables `.env` configuradas para Databricks (DATABRICKS_*, UC_*)
- [ ] Conexión exitosa a Databricks (test desde Python o SQL Editor)

### Proyecto
- [ ] Proyecto `ai-sql-migration` sincronizado (`uv sync`)
- [ ] Archivo `.env` completo con todas las variables
- [ ] Script principal ejecutado exitosamente (`uv run python main.py`)
- [ ] Ejemplo de migración SQL funciona correctamente

