# Diseño Físico de PostgreSQL — SolarDB (versión 2, con métricas reales post-migración)

| | |
|---|---|
| **Proyecto** | Taller 6 — Bases de Datos I. SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL |
| **Institución / grupo** | Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II |
| **Docente** | Ramiro Grisales Montoya |
| **Integrante responsable** | Jose Miguel Sosa Cartagena (diccionario de datos, diseño físico, privacidad e informe final) |
| **Fecha** | 17 de noviembre de 2026 |
| **Motor y herramientas** | PostgreSQL 18, DBeaver 26.2.2, Git y GitHub |
| **Dataset** | OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223) |
| **Documento relacionado** | `docs/08_diccionario_datos.md` |

**Cita del dataset (APA 7.ª ed.):** Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

**Convención:** las cifras de las secciones 1 y 2 son las **certificadas por la migración** y se reproducen sin redondear. Los cálculos propios se marcan como «derivado». Donde la evidencia no alcanza para afirmar algo, se presenta como **hipótesis** o **pendiente de verificación**.

---

## 1. Datos reales de la migración

| Indicador | Valor |
|---|---:|
| Filas leídas de telemetría (SQLite) | 2.989.759 |
| Filas aceptadas en `solardb.lectura_telemetria` | 2.965.337 (99,18 %) |
| Filas en `calidad.registro_cuarentena` | 24.422 (0,82 %) |
| Filas en `solardb.registro_contexto` | 25.178 |
| Cadencia mediana de muestreo | 12,58 s |
| Inversor 1 (cómputo) | 1.594.461 filas; 2025-07-12 13:31:35 → 2026-07-13 05:13:53 |
| Inversor 2 (HVAC) | 1.370.876 filas; 2025-07-14 05:53:32 → 2026-06-22 05:35:24 |

---

## 2. Almacenamiento: estimación frente a realidad

### 2.1 Tamaños reales en disco (PostgreSQL 18)

| Tabla | Total | Datos | Índices |
|---|---:|---:|---:|
| `solardb.lectura_telemetria` | 3.824 MB (3,73 GB) | 3.440 MB | 384 MB |
| `calidad.registro_cuarentena` | 34 MB | 32 MB | 2,2 MB |
| `solardb.registro_contexto` | 26 MB | 17 MB | 9,3 MB |
| Catálogos dimensionales y reglas | < 1 MB | < 100 KB | < 200 KB |
| **Total SolarDB** | **≈ 3,88 GB** | | |

### 2.2 Cuadro comparativo

La versión 1 de este documento estimó el tamaño **antes** de la migración. La comparación es:

| Concepto | Estimación (versión 1) | Real | Relación real / estimado |
|---|---|---|---|
| `lectura_telemetria`, datos (*heap*) | ≈ 0,67 GiB (≈ 718 MB) | 3.440 MB | ≈ 4,8 veces mayor |
| `lectura_telemetria`, índices | ≈ 280 a 380 MB (4 índices) | 384 MB (5 índices) | Dentro del orden esperado |
| `lectura_telemetria`, total | ≈ 1,0 a 1,1 GiB | 3.824 MB (3,73 GB) | ≈ 3,5 veces mayor |
| `registro_contexto` | ≈ 12 a 50 MB (supuesto) | 26 MB | Dentro del rango |
| `registro_cuarentena` | ≈ 3 a 6 MB (con ≥ 3.849 filas supuestas) | 34 MB (24.422 filas) | ≈ 6 a 11 veces mayor |
| Catálogos | < 1 MB | < 1 MB | Coincide |
| **Total de la base** | **≈ 1,1 a 1,2 GiB** | **≈ 3,88 GB** | ≈ 3,3 a 3,5 veces mayor |

### 2.3 Por qué la estimación quedó corta

1. **Cuarentena: el error principal fue el número de filas.** La versión 1 supuso ≥ 3.849 filas (38 + 3.811, según el diagnóstico de la Fase 1). La migración certificó **24.422** (6,3 veces más), dominadas por `R_P_MAYOR_S` con 24.375. Con ≈ 1,4 KB por fila (derivado: 34 MB entre 24.422 filas), el tamaño observado es coherente con el número real de filas. La estimación por fila (0,7 a 1 KB) fue razonable; la cantidad de filas, no.
2. **Tabla de lecturas: el modelo real tiene 46 columnas**, no las 34 de la estimación. Aun así, esas columnas adicionales son casi todas numéricas de 4 u 8 bytes. Recalculando con las 46 columnas (derivado):

| Grupo | Cantidad | Bytes por columna | Subtotal |
|---|---:|---:|---:|
| `DOUBLE PRECISION` (voltajes, corrientes, frecuencias, temperaturas) | 20 | 8 | 160 |
| `INTEGER` (potencias y `sir`) | 14 | 4 | 56 |
| `SMALLINT` (porcentajes) | 4 | 2 | 8 |
| Control: `lectura_id` (8), `ts_lectura` (8), `inversor_id` (2), `lote_id` (4) | 4 | — | 22 |
| **Datos sin las 4 columnas `JSONB`** | **42** | | **246** |

   Con encabezado de fila (≈ 32 bytes con el mapa de nulos), puntero de página y alineación, la fila queda en **≈ 290 bytes**, es decir, ≈ 860 MB (≈ 0,8 GiB) para 2.965.337 filas. **El tamaño real es de 3.440 MB, unos 1,2 KB por fila** (derivado: 3.440 MB × 1.048.576 / 2.965.337 ≈ 1.216 bytes).
3. **Hipótesis para la diferencia (≈ 900 bytes por fila).** La tabla tiene **4 columnas `JSONB` reservadas** (`battreserve`, `pvreserve`, `otherreserve`, `grid_reserve`) cuyo contenido no está documentado. Si guardan contenido no nulo, explicarían la mayor parte de la diferencia. **Esto es una hipótesis**, no un hecho; se verifica con:
```sql
SELECT avg(pg_column_size(battreserve))   AS battreserve,
       avg(pg_column_size(pvreserve))     AS pvreserve,
       avg(pg_column_size(otherreserve))  AS otherreserve,
       avg(pg_column_size(grid_reserve))  AS grid_reserve,
       avg(pg_column_size(t.*))           AS fila_completa
FROM solardb.lectura_telemetria t;
```
   Otra causa posible, menos probable en una tabla cargada una sola vez, es el espacio no reutilizado (*bloat*), que se comprobaría con la extensión `pgstattuple`.
4. **Cuenta de unidades.** Las cifras de la base usan «MB» de 1.024 × 1.024 bytes, como las muestra PostgreSQL (3.824 MB = 3,73 GiB). La suma de las tablas listadas (3.824 + 34 + 26 + < 1 MB ≈ 3.885 MB, o ≈ 3,79 GiB) y el total reportado de ≈ 3,88 GB difieren según la unidad usada o por objetos no listados (tablas de `staging`, catálogos del sistema). **Pendiente:** confirmar con `pg_database_size`.

> **Lección de diseño:** la estimación teórica sirve para dimensionar el orden de magnitud, pero depende de que se conozcan las columnas y el número de filas reales. Por eso se recomienda medir siempre con `pg_total_relation_size` después de la carga.

### 2.4 Consultas para verificar los tamaños

```sql
-- Tamaño total de una tabla (datos + índices + TOAST)
SELECT pg_size_pretty(pg_total_relation_size('solardb.lectura_telemetria'));

-- Solo los datos
SELECT pg_size_pretty(pg_relation_size('solardb.lectura_telemetria'));

-- Tamaño de cada índice
SELECT schemaname, relname, indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS tamano
FROM pg_stat_user_indexes
WHERE schemaname IN ('solardb', 'calidad')
ORDER BY pg_relation_size(indexrelid) DESC;

-- Tamaño de toda la base de datos
SELECT pg_size_pretty(pg_database_size(current_database()));
```

---

## 3. Arquitectura multiesquema

Un esquema es un espacio de nombres dentro de la base de datos que agrupa tablas, vistas y dominios, y permite asignar permisos por grupo.

| Esquema | Contenido real | Justificación |
|---|---|---|
| `solardb` | 6 catálogos, `lectura_telemetria`, `registro_contexto`, los 12 dominios y las vistas | Capa de **producción**: solo datos que ya pasaron las reglas de calidad. |
| `staging` | Tablas de aterrizaje de la carga | Zona **temporal y sin restricciones**, donde se clasifica cada fila antes de insertarla. Se puede vaciar con `TRUNCATE` sin afectar la producción. |
| `calidad` | `lote_carga`, `regla_calidad`, `registro_cuarentena` | Separa la **auditoría y los rechazos** de los datos válidos. |

**Ventajas comprobadas por el proyecto:**
1. **Claridad:** el nombre completo (`solardb.lectura_telemetria`, `calidad.registro_cuarentena`) indica la etapa del dato.
2. **Trazabilidad:** el esquema `calidad` permitió cuadrar la migración de forma exacta (2.965.337 + 24.422 = 2.989.759).
3. **Seguridad y privacidad:** se pueden otorgar permisos por esquema o por vista, y limitar el acceso a los registros marcados con `contiene_datos_personales` (véase `docs/14_seguridad_y_privacidad.md`).
4. **Mantenimiento:** limpiar `staging` no toca los datos de producción.

**Desventajas:** hay que escribir el nombre del esquema en las consultas (o configurar `search_path`) y se añade algo de complejidad. Para un proyecto con 3 etapas distintas, el beneficio compensa ese costo.

---

## 4. Tablespaces

Un *tablespace* es una ubicación física (carpeta) del disco donde PostgreSQL guarda los archivos.

**Decisión: no se usan; se emplea `pg_default`.**

- El tamaño total (≈ 3,88 GB) cabe en un solo disco; los tablespaces sirven para repartir datos entre **discos con distinta velocidad** o cuando un volumen se llena.
- Crear un tablespace exige una carpeta existente con permisos del usuario del servidor, lo que añadiría riesgo de errores en el equipo de cada integrante.
- Los catálogos tienen entre 1 y 38 o más filas (< 1 MB en conjunto): caben en memoria y separarlos no mejora nada medible.
- Se justificarían con cientos de millones de filas, o con un disco rápido (SSD) para los datos recientes y uno barato para los históricos.

---

## 5. Estrategia de índices

Un índice es una estructura auxiliar que acelera la búsqueda a cambio de espacio en disco y de un costo adicional en cada inserción.

### 5.1 Tipos de índice de PostgreSQL

| Tipo | Funcionamiento | Operadores | Uso adecuado | ¿Se usa? |
|---|---|---|---|---|
| **B-tree** | Árbol balanceado ordenado (el predeterminado) | `=`, `<`, `>`, `BETWEEN`, `ORDER BY` | Igualdad y rangos sobre valores escalares | **Sí** |
| **Hash** | Tabla hash de la clave | Solo `=` | Igualdad exacta | No: el B-tree cubre la igualdad y los rangos |
| **GIN** | Índice invertido (cada elemento apunta a las filas que lo contienen) | `@>`, `?`, `?&`, `?\|` | `JSONB`, arreglos, texto | **Sí**, en el contexto |
| **GiST** | Árbol para datos espaciales o de solapamiento | Rangos, geometría | Geometría, rangos | No aplica |
| **BRIN** | Resumen (mínimo y máximo) por bloque de páginas | `<`, `>`, `=`, `BETWEEN` | Tablas enormes con la columna correlacionada con el orden físico | Alternativa evaluada (sección 5.4) |

### 5.2 Los 7 índices creados en producción

Además de los índices que PostgreSQL crea por cada `PRIMARY KEY` y `UNIQUE`.

| # | Índice | Tabla | Para qué sirve | Definición esperada (verificar) |
|---:|---|---|---|---|
| 1 | `idx_lectura_ts` | `lectura_telemetria` | Búsqueda por instante o rango de fechas | B-tree sobre `ts_lectura` |
| 2 | `idx_lectura_lote` | `lectura_telemetria` | Auditar o reprocesar un lote (la clave foránea no se indexa sola) | B-tree sobre `lote_id` |
| 3 | `idx_lectura_inversor_ts` | `lectura_telemetria` | Filtrar por inversor y rango de fechas | B-tree compuesto sobre `(inversor_id, ts_lectura)` |
| 4 | `idx_cuarentena_regla` | `registro_cuarentena` | Contar o listar los rechazos por regla | B-tree sobre `regla_id` |
| 5 | `idx_cuarentena_estado` | `registro_cuarentena` | Buscar registros por estado (por ejemplo, `PENDIENTE`) | B-tree sobre `estado` (posiblemente parcial) |
| 6 | `idx_contexto_tipo` | `registro_contexto` | Filtrar eventos por tipo de contexto (fuente) | B-tree sobre `tipo_contexto_id` |
| 7 | `idx_contexto_valor_gin` | `registro_contexto` | Consultas por contenido JSON (`@>`, `?`) | GIN sobre `valor` |

> **Pendiente:** el material disponible da los nombres de los índices, no su definición exacta. Las definiciones de la columna final son las esperadas por el nombre y deben verificarse con:
```sql
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname IN ('solardb', 'calidad')
ORDER BY tablename, indexname;
```

### 5.3 Justificación por necesidad

| Necesidad | Índice | Razón |
|---|---|---|
| Búsqueda por timestamp | `idx_lectura_ts` | Resuelve rangos de fechas con precisión. |
| Filtrado por inversor | `idx_lectura_inversor_ts` | El inversor solo toma 2 valores (1 y 2): un índice solo por `inversor_id` casi no es selectivo (≈ 54 % y ≈ 46 % de las filas). Combinado con el tiempo, sí es útil. |
| Consultas sobre contenido JSON | `idx_contexto_valor_gin` y `idx_contexto_tipo` | GIN permite buscar por contenido sin recorrer las 25.178 filas; el B-tree por tipo atiende el filtro por fuente. |
| Búsqueda de cuarentena por estado | `idx_cuarentena_estado` y `idx_cuarentena_regla` | Atienden las consultas operativas («qué está pendiente», «qué regla rechazó más filas»). |

### 5.4 Observaciones para la sustentación

1. **Posible índice redundante.** `solardb.lectura_telemetria` tiene una restricción `UNIQUE (inversor_id, ts_lectura)`, que PostgreSQL respalda con su propio índice. Si `idx_lectura_inversor_ts` indexa **las mismas columnas en el mismo orden**, sería redundante y ocuparía espacio (del orden de 80 MB, derivado del tamaño medio de los índices de la tabla: 384 MB repartidos en 5). Comprobarlo con la consulta de `pg_indexes`. Si coinciden, se puede eliminar uno; si el índice se creó con otra intención (por ejemplo, el orden de las columnas), debe explicarse.
2. **Alternativa para `idx_lectura_ts`:** un índice BRIN sobre `ts_lectura` ocuparía una fracción del tamaño del B-tree, siempre que las filas se hayan insertado en orden cronológico. Es una mejora posible, no una necesidad.
3. **Costo de los índices en la carga:** en una migración masiva conviene crear los índices secundarios **después** de cargar los datos y ejecutar `ANALYZE` al final, para que el optimizador conozca las estadísticas reales.
4. **Tamaño real de los índices:** 384 MB en la tabla de lecturas (10 % de su tamaño total); 2,2 MB en cuarentena y 9,3 MB en contexto (el GIN explica buena parte de esos 9,3 MB, hipótesis a verificar con la consulta de la sección 2.4).

---

## 6. Particionamiento

El particionamiento declarativo divide una tabla grande en partes (particiones) según una clave; cada partición es físicamente una tabla distinta, pero se consulta como una sola.

### 6.1 Decisión: no se particionó

**Justificación técnica:**

| Criterio | Situación real de SolarDB |
|---|---|
| Volumen | 2.965.337 filas, 3.824 MB (≈ 3,73 GB) |
| Tamaño respecto de la memoria | La guía oficial de PostgreSQL indica, como regla general, que una tabla se beneficia del particionamiento cuando su tamaño **supera la memoria física del servidor**; no es el caso en un equipo de estudiante con 3,7 GB de tabla |
| Alternativa disponible | Los índices `idx_lectura_ts` e `idx_lectura_inversor_ts` ya resuelven los filtros por fecha e inversor |
| Restricción de la clave primaria | La PK y los `UNIQUE` de una tabla particionada deben **incluir la clave de partición**: la PK `lectura_id` y el `UNIQUE (inversor_id, ts_lectura)` tendrían que redefinirse |
| Complejidad | Más objetos, más scripts y más puntos de fallo en la demostración |

### 6.2 Ventajas y desventajas

| Ventajas | Desventajas |
|---|---|
| Poda de particiones: una consulta con rango de fechas lee solo las particiones relevantes | Poco beneficio con ~3 millones de filas |
| Retención simple: eliminar o archivar un mes con `DROP` o `DETACH` sin un `DELETE` masivo | Hay que crear las particiones por adelantado (o usar una partición `DEFAULT`) |
| Índices y `VACUUM` más pequeños por partición | La PK y los `UNIQUE` deben incluir la clave de partición |
| Escalabilidad en series temporales que crecen sin parar | Mayor complejidad operativa |

### 6.3 ¿Cuándo valdría la pena? (umbral de > 50 millones de filas)

Proyección con las cifras reales (cálculo derivado):

- Cada inversor genera una lectura cada ≈ 12,58 s: ≈ 2,5 millones de filas por año por inversor (31.536.000 s / 12,58 s ≈ 2.506.837), es decir, **≈ 5 millones de filas por año** con los dos inversores.
- Con el tamaño real por fila, ≈ 1,3 KB entre datos e índices (3.824 MB entre 2.965.337 filas), cada año añadiría **≈ 6 GB**.
- A 50 millones de filas (≈ 10 años de operación continua con 2 inversores, o antes si se añadieran más equipos o sensores) la tabla pesaría **≈ 63 GiB**, un tamaño que ya supera la memoria de un servidor típico.

**Cómo se haría (trabajo futuro):** `PARTITION BY RANGE (ts_lectura)` con particiones mensuales o trimestrales (≈ 417.000 filas por mes con 2 inversores), y la PK redefinida como `(lectura_id, ts_lectura)`.

---

## 7. Verificación con `EXPLAIN ANALYZE`

Sirve para demostrar que el índice se usa. Se sugiere consultar **un día dentro del rango certificado** del inversor 1 (2025-07-12 a 2026-07-13):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ts_lectura, battvolt, battsoc
FROM solardb.lectura_telemetria
WHERE inversor_id = 1
  AND ts_lectura >= '2025-08-01 00:00:00+00'
  AND ts_lectura <  '2025-08-02 00:00:00+00';
```

**Qué buscar en el plan:**
- `Index Scan` o `Bitmap Index Scan` sobre `idx_lectura_inversor_ts` (o sobre el índice de la restricción `UNIQUE`): el índice se está usando.
- `Seq Scan`: recorre toda la tabla. Puede ser lo correcto si el rango abarca gran parte de la tabla; con un día de datos (≈ 6.900 filas por inversor, derivado: 86.400 s / 12,58 s) lo esperable es que use el índice.
- `Execution Time`: tiempo total. Para comparar con y sin índice, usar `SET enable_indexscan = off; SET enable_bitmapscan = off;` **solo en una sesión de prueba**.

> Si los tiempos de los resultados se citan en el informe o la sustentación, deben provenir de una ejecución real del equipo, no de este documento.

---

## 8. Resumen de decisiones de diseño físico

| Aspecto | Decisión | Evidencia real |
|---|---|---|
| Esquemas | Tres: `solardb`, `staging`, `calidad` | Cuadratura exacta de la migración gracias al esquema `calidad` |
| Tablespaces | No se usan (`pg_default`) | ≈ 3,88 GB en un solo disco |
| Particionamiento | No; se considera a partir de > 50 millones de filas | 2.965.337 filas; ≈ 5 millones por año |
| Índices | 7 índices propios, más PK y `UNIQUE` | 384 MB en lecturas; 2,2 MB en cuarentena; 9,3 MB en contexto |
| Almacenamiento | ≈ 3,88 GB reales frente a ≈ 1,1 a 1,2 GiB estimados | Diferencia explicada por el número real de filas en cuarentena y por el contenido de las columnas `JSONB` (hipótesis) |

---

## 9. Pendientes

1. Confirmar con `pg_indexes` la definición de los 7 índices y si `idx_lectura_inversor_ts` duplica el índice de la restricción `UNIQUE`.
2. Medir el tamaño de las columnas `JSONB` reservadas para confirmar la hipótesis de la sección 2.3.
3. Confirmar el total de la base con `pg_database_size`.
4. Ejecutar y registrar un `EXPLAIN ANALYZE` real para la demostración.

---

## 10. Protección del repositorio

Este documento no contiene contraseñas, tokens ni cadenas de conexión. Los scripts del repositorio no deben incluir credenciales; el detalle está en `docs/14_seguridad_y_privacidad.md`.
