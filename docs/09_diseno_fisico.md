# Diseño Físico de PostgreSQL — SolarDB

| | |
|---|---|
| **Proyecto** | Taller 6 — Bases de Datos I. SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL |
| **Institución / grupo** | Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II |
| **Docente** | Ramiro Grisales Montoya |
| **Integrante responsable** | Jose Miguel Sosa Cartagena (diccionario de datos, diseño físico, privacidad y documento final) |
| **Fecha** | 15 de noviembre de 2026 |
| **Dataset** | OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223) |
| **Documento relacionado** | `docs/08_diccionario_datos.md` |

**Convención:** las decisiones que dependen de la implementación del coordinador (Juan Sebastian Raigosa Gil) se marcan como **«pendiente de confirmación por el coordinador»**. Las cifras de almacenamiento son **estimaciones teóricas** y se indica el supuesto de cada una; deben verificarse con las funciones de tamaño de PostgreSQL una vez realizada la migración (sección 5.7).

---

## 1. Esquemas (schemas)

Un esquema es un espacio de nombres dentro de una base de datos: agrupa tablas, vistas y dominios, y permite asignar permisos por grupo.

### 1.1 Decisión: usar tres esquemas

| Esquema | Contenido | Justificación |
|---|---|---|
| `solardb` | Catálogos (`dim_sitio`, `dim_subsistema`, `dim_inversor`, `cat_unidad_medida`, `cat_variable_fisica`), hechos (`lectura_telemetria`, `registro_contexto`), dominios y vistas de consulta. | Es la capa de **producción**: solo contiene datos que ya pasaron las reglas de calidad. |
| `staging` | `staging_telemetria` (y, si se requiere, una tabla equivalente para contexto). | Zona de **aterrizaje**, sin restricciones, donde se clasifican las filas antes de insertarlas. Se puede vaciar (`TRUNCATE`) sin afectar la producción. |
| `calidad` | `lote_carga`, `regla_calidad`, `registro_cuarentena`. | Separa la **auditoría y los rechazos** de los datos válidos. Permite dar permisos distintos a quien revisa calidad. |

### 1.2 Ventajas

1. **Claridad:** el nombre completo (`solardb.lectura_telemetria`) indica la etapa del dato.
2. **Seguridad:** se pueden otorgar permisos por esquema (`GRANT USAGE ON SCHEMA ...`). Esto se conecta con la Ley 1581 de 2012: los registros que podrían contener datos personales (`registro_contexto`) pueden quedar en un esquema o con vistas de acceso restringido (véase `docs/14_seguridad_y_privacidad.md`).
3. **Mantenimiento:** limpiar `staging` no toca `solardb`.
4. **Orden del repositorio:** los scripts DDL se pueden organizar por esquema.

### 1.3 Desventajas

- Hay que escribir el esquema en las consultas o configurar `search_path`.
- Aumenta levemente la complejidad para un proyecto académico, aunque el beneficio pedagógico es alto.

> **Pendiente de confirmación por el coordinador:** los nombres exactos de los esquemas y si los dominios (`CREATE DOMAIN`) se crean en `solardb` o en un esquema aparte.

```sql
CREATE SCHEMA IF NOT EXISTS solardb;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS calidad;
```

---

## 2. Tablespaces

Un *tablespace* es una ubicación física (carpeta) del disco donde PostgreSQL guarda los archivos de tablas e índices.

### 2.1 ¿Se justifica separar telemetría y catálogos?

**No para este proyecto.** Razones:

1. El tamaño total estimado es de aproximadamente 1 a 2 GiB (sección 5), muy pequeño.
2. Los tablespaces sirven cuando hay **varios discos con distinta velocidad** (por ejemplo, SSD para datos calientes y HDD para históricos) o cuando un volumen se llena. Una instalación local en un portátil usa un solo disco.
3. Crear un tablespace requiere una carpeta existente, propiedad del usuario del servidor, y permisos de superusuario. Añade riesgo de errores en la instalación de cada integrante.
4. Los catálogos tienen entre 1 y 30 filas: caben en la memoria caché; separarlos no mejora nada medible.

### 2.2 Cuándo sí se justificaría (como discusión académica)

- Telemetría en un disco rápido y particiones antiguas en almacenamiento barato.
- Separar los índices de la tabla en discos distintos para repartir la lectura.
- Si SolarDB creciera a cientos de millones de filas (más sensores o más años de muestreo continuo).

**Decisión:** se usa el tablespace por defecto (`pg_default`).

---

## 3. Particionamiento

El particionamiento declarativo divide una tabla grande en partes (particiones) según una clave; cada partición es físicamente una tabla distinta, pero se consulta como una sola.

### 3.1 Contexto de volumen

- `lectura_telemetria`: hasta 2.989.759 filas.
- Rango temporal de `read_ts`: aproximadamente de 1,75 × 10⁹ a 1,78 × 10⁹ s (Unix), es decir, algo menos de un año de datos. Con partición mensual quedarían del orden de 12 particiones de unas 250.000 filas cada una (valor aproximado).

### 3.2 Opción evaluada

```sql
-- Opción evaluada (NO adoptada por defecto)
CREATE TABLE solardb.lectura_telemetria (
    lectura_id   BIGINT GENERATED ALWAYS AS IDENTITY,
    inversor_id  SMALLINT NOT NULL,
    ts_lectura   TIMESTAMPTZ NOT NULL,
    -- ... resto de columnas ...
    PRIMARY KEY (lectura_id, ts_lectura)   -- la clave de partición debe estar en la PK
) PARTITION BY RANGE (ts_lectura);
```

> El prompt del taller menciona `PARTITION BY RANGE (read_ts)`. En SolarDB la columna se llama `ts_lectura` y es de tipo `timestamptz` (véase el diccionario de datos); se particiona por esa columna, no por el `REAL` original.

### 3.2.1 Ventajas

| Ventaja | Explicación |
|---|---|
| **Poda de particiones** (*partition pruning*) | Una consulta con un rango de fechas lee solo las particiones relevantes. |
| **Mantenimiento por partición** | Se puede eliminar o archivar un mes completo con `DROP`/`DETACH` sin un `DELETE` masivo. |
| **`VACUUM`/índices más pequeños** | Cada partición tiene sus propios índices. |
| **Escalabilidad** | Es la práctica recomendada para series temporales que crecen continuamente. |

### 3.2.2 Desventajas

| Desventaja | Explicación |
|---|---|
| **Poco beneficio con 3 millones de filas** | Un índice B-tree bien diseñado resuelve el mismo filtro con costo bajo en una tabla de unos 0,7 GiB. |
| **Restricción de la PK** | La clave primaria y los `UNIQUE` deben incluir la columna de partición. Esto altera `PRIMARY KEY (lectura_id)` y el `UNIQUE (inversor_id, ts_lectura)` que hace idempotente la migración. |
| **Mantenimiento extra** | Hay que crear las particiones por adelantado (o con una partición `DEFAULT`). Un registro fuera de rango falla si no existe partición. |
| **Mayor complejidad** | Más objetos, más scripts y más puntos de fallo para el equipo y la demostración en vivo. |
| **Claves foráneas** | Las llaves foráneas hacia una tabla particionada tienen requisitos adicionales. |

### 3.3 Decisión

**No particionar en la entrega base.** Con ~3 millones de filas, el índice compuesto `(inversor_id, ts_lectura)` y, opcionalmente, un índice BRIN sobre `ts_lectura` ofrecen el mismo beneficio con menos complejidad. El particionamiento se documenta como **trabajo futuro** para un escenario de muestreo continuo durante varios años.

> **Pendiente de confirmación por el coordinador:** si el equipo desea mostrar particionamiento como funcionalidad opcional en la sustentación.

---

## 4. Estrategia de índices

Un índice es una estructura auxiliar que acelera la búsqueda a cambio de espacio en disco y de un costo adicional en cada inserción.

### 4.1 Tipos de índice disponibles en PostgreSQL

| Tipo | Funcionamiento | Operadores típicos | Uso adecuado | ¿Se usa en SolarDB? |
|---|---|---|---|---|
| **B-tree** | Árbol balanceado ordenado. Es el tipo por defecto. | `=`, `<`, `<=`, `>`, `>=`, `BETWEEN`, `ORDER BY` | Igualdad y rangos sobre valores escalares. | **Sí**: base del diseño. |
| **Hash** | Tabla hash de la clave. | Solo `=` | Igualdad exacta sobre valores largos. No ordena ni sirve para rangos. | **No**: el B-tree cubre la igualdad y además los rangos. |
| **GIN** | Índice invertido: cada elemento de un valor compuesto apunta a las filas que lo contienen. | `@>`, `?`, `?&`, `?\|` (JSONB), búsqueda de texto, arreglos | Valores con múltiples elementos: **JSONB**, arreglos, texto. | **Sí**: para `registro_contexto.valor`. |
| **GiST** | Árbol generalizado para datos con relaciones espaciales o de solapamiento. | Rangos, geometría, vecindad | Geometría, rangos (`tstzrange`), búsqueda por proximidad. | **No**: SolarDB no maneja geometría ni rangos. |
| **BRIN** | Guarda un resumen (mínimo y máximo) por bloque de páginas. Es muy pequeño. | `<`, `>`, `=`, `BETWEEN` | Tablas enormes cuya columna está **correlacionada con el orden físico** (como series temporales cargadas en orden). | **Opcional**: sobre `ts_lectura` si la migración inserta en orden cronológico. |

### 4.2 Recomendación por tipo de consulta

| Necesidad | Índice recomendado | Justificación |
|---|---|---|
| **Búsqueda por timestamp** (rangos de fechas) | **B-tree** sobre `(ts_lectura)` y, opcionalmente, **BRIN** sobre `ts_lectura` | El B-tree resuelve rangos con precisión. El BRIN ocupa una fracción del espacio, pero solo es eficaz si las filas se insertaron en orden temporal (hay que verificarlo, `pg_stats.correlation`). |
| **Filtrado por inversor** | **B-tree** compuesto `(inversor_id, ts_lectura)` | El inversor tiene solo 2 valores (1 y 2). Un índice solo por `inversor_id` casi no es selectivo (cada valor devuelve ~50 % de las filas). Combinado con el tiempo, sí es útil. Este índice **ya existe** como `UNIQUE (inversor_id, ts_lectura)` y también sirve para filtrar por inversor y rango de fechas. |
| **Consultas sobre contenido JSON** | **GIN** sobre `registro_contexto.valor` (con `jsonb_path_ops`) y **B-tree** sobre `fuente_contexto` | GIN permite `valor @> '{"source": "wsl_bash_history"}'` sin recorrer las 25.178 filas. La columna `fuente_contexto` (7 valores) se puede filtrar con un B-tree sencillo y es suficiente para consultas por fuente. |
| **Registros de cuarentena por estado** | **B-tree parcial** sobre `registro_cuarentena (estado)` con `WHERE estado = 'PENDIENTE'` | Normalmente casi todos los registros pasan a estados resueltos; el índice parcial solo indexa los pendientes, es muy pequeño y atiende la consulta operativa más frecuente («¿qué falta revisar?»). |

### 4.3 Índices adicionales para llaves foráneas

PostgreSQL **no crea automáticamente** índices en las columnas que son llave foránea (sí crea el de la PK y el de los `UNIQUE`). Se recomienda indexar las FK que se usan en uniones o filtros:

| Tabla | Columna FK | Índice |
|---|---|---|
| `lectura_telemetria` | `lote_id` | B-tree: facilita auditar o reprocesar un lote. |
| `registro_contexto` | `lote_id` | B-tree. |
| `registro_cuarentena` | `lote_id`, `regla_id` | B-tree en cada una. |

Para los catálogos (1 a 30 filas) no se justifica indexar más allá de la PK y los `UNIQUE`.

### 4.4 Índices que NO se recomiendan

- Un índice por cada una de las 30 variables físicas: casi nunca se filtra por ellas de forma aislada y cada índice ralentiza la inserción masiva y ocupa espacio.
- Un índice solo sobre `inversor_id` en `lectura_telemetria` (baja selectividad).

### 4.5 Script de referencia

```sql
-- lectura_telemetria
-- PK (lectura_id) y UNIQUE (inversor_id, ts_lectura) ya se crean con la tabla.
CREATE INDEX idx_lectura_ts       ON solardb.lectura_telemetria (ts_lectura);
-- Alternativa más pequeña, solo si la carga fue en orden cronológico:
-- CREATE INDEX idx_lectura_ts_brin ON solardb.lectura_telemetria USING BRIN (ts_lectura);
CREATE INDEX idx_lectura_lote     ON solardb.lectura_telemetria (lote_id);

-- registro_contexto
CREATE INDEX idx_contexto_valor_gin ON solardb.registro_contexto USING GIN (valor jsonb_path_ops);
CREATE INDEX idx_contexto_fuente    ON solardb.registro_contexto (fuente_contexto);
CREATE INDEX idx_contexto_lote      ON solardb.registro_contexto (lote_id);

-- registro_cuarentena
CREATE INDEX idx_cuarentena_pendiente ON calidad.registro_cuarentena (estado)
    WHERE estado = 'PENDIENTE';
CREATE INDEX idx_cuarentena_lote  ON calidad.registro_cuarentena (lote_id);
CREATE INDEX idx_cuarentena_regla ON calidad.registro_cuarentena (regla_id);
```

> **Pendiente de confirmación por el coordinador:** nombres finales de los índices y si se prefiere `idx_lectura_ts` (B-tree) o BRIN.

### 4.6 Buenas prácticas en la migración masiva

1. Cargar primero los datos y **crear los índices secundarios después** (o desactivarlos durante la carga): construir un índice una vez es más rápido que mantenerlo fila por fila durante millones de inserciones.
2. Ejecutar `ANALYZE` al terminar la carga, para que el optimizador conozca las estadísticas reales de las tablas y elija bien los índices.
3. Después de la migración, confirmar el uso de los índices con `EXPLAIN (ANALYZE, BUFFERS)` (sección 6).

---

## 5. Estimación de almacenamiento

### 5.1 Método y advertencias

- PostgreSQL almacena cada fila con un **encabezado de unos 24 bytes** (más un mapa de bits de nulos de 1 bit por columna, que se redondea) y un puntero de 4 bytes en la página. Las páginas son de 8 KiB.
- Cada tipo ocupa: `BIGINT` y `DOUBLE PRECISION` 8 bytes, `TIMESTAMPTZ` 8 bytes, `INTEGER` 4 bytes, `SMALLINT` 2 bytes. Además puede haber **relleno de alineación** (*padding*) entre columnas.
- Las cifras son **estimaciones teóricas**, no mediciones. Los valores nulos ocupan menos (solo el bit del mapa de nulos), por lo que la cifra real será igual o ligeramente menor.
- El SQLite original pesa 4,13 GB, pero **no es comparable**: incluye las 8 tablas (`settings` con 176 columnas, `specs`, `statistics`, `fault_history`, etc.), mientras que SolarDB migra solo telemetría y contexto.

### 5.2 `solardb.lectura_telemetria`

**Datos por fila (según los tipos del diccionario de datos):**

| Grupo de columnas | Cantidad | Bytes por columna | Subtotal |
|---|---:|---:|---:|
| `DOUBLE PRECISION` (voltajes, corrientes, frecuencias, temperaturas) | 17 | 8 | 136 |
| `INTEGER` (potencias y `sir`) | 9 | 4 | 36 |
| `SMALLINT` (porcentajes) | 4 | 2 | 8 |
| `lectura_id` (`BIGINT`) | 1 | 8 | 8 |
| `ts_lectura` (`TIMESTAMPTZ`) | 1 | 8 | 8 |
| `inversor_id` (`SMALLINT`) | 1 | 2 | 2 |
| `lote_id` (`INTEGER`) | 1 | 4 | 4 |
| **Datos útiles** | **34** | | **202** |

Agregando el encabezado de fila (≈ 32 bytes con el mapa de nulos de 36 columnas), el relleno de alineación (≈ 4 a 6 bytes) y el puntero de la página (4 bytes), se obtiene **≈ 240 bytes por fila** (supuesto).

| Concepto | Cálculo | Resultado aproximado |
|---|---|---|
| Datos de la tabla (*heap*) | 2.989.759 filas × ~240 bytes | ≈ 718 MB ≈ **0,67 GiB** |
| Índice de la PK (`lectura_id`) | ~2,99 M entradas (B-tree) | ≈ 65–90 MB |
| Índice `UNIQUE (inversor_id, ts_lectura)` | ~2,99 M entradas (B-tree) | ≈ 85–110 MB |
| Índice `idx_lectura_ts` (B-tree) | ~2,99 M entradas | ≈ 65–90 MB (un BRIN equivalente ocuparía menos de 1 MB) |
| Índice `idx_lectura_lote` | ~2,99 M entradas | ≈ 65–90 MB |
| **Total estimado (tabla + índices)** | | **≈ 1,0 a 1,1 GiB** |

> Los tamaños de índice son rangos teóricos para B-trees con claves de 2 a 8 bytes y relleno típico; el valor real se mide en la sección 5.7.

### 5.3 `solardb.registro_contexto`

- Filas: 25.178.
- El tamaño de cada campo `value` (JSON) **no se conoce** con los datos disponibles hasta ahora (varía entre un evento corto y un log largo).
- **Supuesto de trabajo (no medido):** entre 0,5 y 1 KiB por fila, con el índice GIN incluido.
- Estimación: 25.178 × (0,5 a 1 KiB) ≈ **12 a 25 MB**, más el índice GIN (de un tamaño del orden de la tabla o menor).
- **Pendiente:** medir el promedio real con `avg(pg_column_size(valor))` una vez cargada la tabla.

### 5.4 Tablas de calidad y staging

| Tabla | Filas | Estimación | Supuesto |
|---|---:|---|---|
| `calidad.registro_cuarentena` | ≥ 3.849 (38 + 3.811) más las demás reglas que se definan | ≈ 3–6 MB | Cada fila guarda una copia completa de la fila en `JSONB` (30 variables + metadatos), de aproximadamente 0,7 a 1 KiB. |
| `calidad.lote_carga` | una por ejecución | < 1 MB | Tabla muy pequeña. |
| `calidad.regla_calidad` | decenas | < 1 MB | Tabla muy pequeña. |
| `staging.staging_telemetria` | hasta 2.989.759 (transitoria) | ≈ 0,8 GiB mientras dure la carga | 31 columnas `DOUBLE PRECISION` (`read_ts` y las 30 variables), más `inverter`, `stg_id`, `lote_id`, `estado_validacion` y el encabezado: cerca de 300 bytes por fila. Se puede vaciar al terminar. |

### 5.5 Catálogos

`dim_sitio` (1 fila), `dim_subsistema` (2), `dim_inversor` (2), `cat_unidad_medida` (9) y `cat_variable_fisica` (30): cada una ocupa como mínimo una página de 8 KiB; en conjunto, **menos de 0,5 MB**.

### 5.6 Resumen

| Objeto | Estimación |
|---|---|
| `lectura_telemetria` (tabla + índices) | ≈ 1,0 a 1,1 GiB |
| `registro_contexto` (tabla + índice GIN) | ≈ 20 a 50 MB (supuesto) |
| `registro_cuarentena` | ≈ 3 a 6 MB (supuesto) |
| Catálogos y tablas de control | < 1 MB |
| **Base de datos definitiva** | **≈ 1,1 a 1,2 GiB** |
| `staging_telemetria` (temporal, mientras dure la carga) | ≈ 0,8 GiB adicionales |
| **Pico durante la migración** | **≈ 2 GiB** (más el espacio para el WAL) |

> Se recomienda dejar al menos **5 GiB libres** en el disco antes de la migración, por el registro de transacciones (WAL), los índices temporales y la copia de staging.

### 5.7 Cómo verificar el tamaño real

Tras la migración, estas consultas entregan las cifras reales para contrastar con la estimación:

```sql
-- Tamaño total de una tabla (datos + índices + TOAST)
SELECT pg_size_pretty(pg_total_relation_size('solardb.lectura_telemetria'));

-- Solo los datos de la tabla
SELECT pg_size_pretty(pg_relation_size('solardb.lectura_telemetria'));

-- Tamaño de cada índice
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE schemaname = 'solardb';

-- Tamaño promedio del campo JSONB de contexto
SELECT avg(pg_column_size(valor)) FROM solardb.registro_contexto;

-- Tamaño de toda la base de datos
SELECT pg_size_pretty(pg_database_size(current_database()));
```

---

## 6. Verificación con `EXPLAIN ANALYZE`

Sirve para demostrar que el índice se usa. Para la demostración en vivo se sugiere filtrar un rango de fechas de un solo inversor, usando valores reales presentes en la base (no inventados) que se consultan antes con `SELECT min(ts_lectura), max(ts_lectura) FROM solardb.lectura_telemetria`:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ts_lectura, battvolt, battsoc
FROM solardb.lectura_telemetria
WHERE inversor_id = 1
  AND ts_lectura >= '<fecha_inicio_real>'
  AND ts_lectura <  '<fecha_fin_real>';
```

**Qué buscar en el plan:**

- `Index Scan` o `Bitmap Index Scan` sobre el índice `(inversor_id, ts_lectura)`: el índice se está usando.
- `Seq Scan`: el motor recorre toda la tabla. Puede ser lo correcto si el rango pedido abarca gran parte de la tabla (el optimizador elige el plan más barato).
- Comparar el tiempo de ejecución (`Execution Time`) con y sin índice, mediante `SET enable_indexscan = off; SET enable_bitmapscan = off;` solo en una sesión de prueba.

---

## 7. Resumen de decisiones de diseño físico

| Aspecto | Decisión | Estado |
|---|---|---|
| Esquemas | Tres: `solardb`, `staging`, `calidad` | Propuesto; nombres pendientes de confirmación |
| Tablespaces | No se usan; se emplea `pg_default` | Decidido (justificado) |
| Particionamiento | No en la entrega base; se documenta como trabajo futuro | Pendiente de confirmación |
| Índices en `lectura_telemetria` | `UNIQUE (inversor_id, ts_lectura)`, B-tree o BRIN en `ts_lectura`, B-tree en `lote_id` | Propuesto |
| Índices en `registro_contexto` | GIN (`jsonb_path_ops`) en `valor`, B-tree en `fuente_contexto` y `lote_id` | Propuesto |
| Índices en cuarentena | Índice parcial por `estado = 'PENDIENTE'`, B-tree por `lote_id` y `regla_id` | Propuesto |
| Almacenamiento estimado | ≈ 1,1 a 1,2 GiB definitivo; pico ≈ 2 GiB | Estimación teórica; verificar con la sección 5.7 |

---

## 8. Pendientes para el coordinador

1. Confirmar los nombres definitivos de esquemas e índices.
2. Confirmar si la migración inserta las filas en orden cronológico (decide si se usa BRIN).
3. Decidir si se muestra particionamiento en la sustentación.
4. Medir los tamaños reales después de la migración y actualizar la sección 5 con valores medidos.

---

## 9. Protección del repositorio

Este documento no contiene contraseñas, tokens ni cadenas de conexión. Los scripts DDL del repositorio no deben incluir credenciales; el detalle está en `docs/14_seguridad_y_privacidad.md`.
