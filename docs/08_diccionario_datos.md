# Diccionario de Datos — SolarDB (versión 2, con métricas reales post-migración)

| | |
|---|---|
| **Proyecto** | Taller 6 — Bases de Datos I. SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL |
| **Institución / grupo** | Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II |
| **Docente** | Ramiro Grisales Montoya |
| **Integrante responsable** | Jose Miguel Sosa Cartagena (diccionario de datos, diseño físico, privacidad e informe final) |
| **Fecha** | 17 de noviembre de 2026 |
| **Motor y herramientas** | PostgreSQL 18, DBeaver 26.2.2, Git y GitHub |
| **Dataset** | OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223) |

**Cita del dataset (APA 7.ª ed.):** Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

---

## 1. Introducción y convenciones

Este documento describe, tabla por tabla y columna por columna, la base de datos **SolarDB** ya implementada y migrada por el coordinador (Juan Sebastian Raigosa Gil). Reemplaza las estimaciones teóricas de la primera versión por los **resultados certificados de la migración**.

### 1.1 Convenciones

- **Esquemas PostgreSQL:** `solardb` (producción), `staging` (carga temporal) y `calidad` (reglas, cuarentena y auditoría).
- **Nulabilidad:** `NN` = `NOT NULL`; `NULL` = admite nulos. La nulabilidad de las columnas de medición corresponde al diseño (~2 % de las lecturas originales tiene nulos por *timeouts* de Modbus); debe verificarse contra el DDL final.
- **Unidades de medida:** provienen del archivo `column_dictionary.json` de los autores de OpenCEM, campo `unit` de cada variable. Las unidades de las variables de la primera versión fueron verificadas por el coordinador contra la base SQLite. Las 8 variables nuevas (marcadas con **†**) **no tenían evidencia de unidad en el material disponible**: su unidad se **dedujo del dominio** y debe confirmarse en `column_dictionary.json` (sección 10).
- **Rango observado:** es el rango verificado en la base SQLite (`analog_measurements`); no es un límite físico del equipo.
- **Cifras:** todas las métricas de las secciones 2 y 8 son las certificadas por la migración y se reproducen **sin redondear**.

### 1.2 Resumen de objetos del modelo

| Esquema | Objeto | Tipo | Filas reales |
|---|---|---|---:|
| `solardb` | `dim_sitio` | Catálogo | 1 |
| `solardb` | `dim_subsistema` | Catálogo | 2 |
| `solardb` | `dim_inversor` | Catálogo | 2 |
| `solardb` | `cat_variable_fisica` | Catálogo | 38 o más |
| `solardb` | `cat_unidad_medida` | Catálogo | unidades V, A, W, VA, Hz, °C, %, kΩ (y las que el DDL añada) |
| `solardb` | `cat_tipo_contexto` | Catálogo | 7 |
| `solardb` | `lectura_telemetria` | Hechos | **2.965.337** |
| `solardb` | `registro_contexto` | Hechos | **25.178** |
| `calidad` | `lote_carga` | Auditoría | 2 lotes completados (IDs 4 y 6) |
| `calidad` | `regla_calidad` | Calidad | 6 reglas activas |
| `calidad` | `registro_cuarentena` | Calidad | **24.422** |
| `staging` | tabla(s) de aterrizaje | Staging | transitoria (nombres pendientes de confirmación) |

---

## 2. Resultados reales de la migración

### 2.1 Balance general

| Indicador | Valor |
|---|---:|
| Filas leídas de telemetría (SQLite, `analog_measurements`) | **2.989.759** |
| Filas aceptadas en `solardb.lectura_telemetria` | **2.965.337** (99,18 %) |
| Filas aisladas en `calidad.registro_cuarentena` | **24.422** (0,82 %) |
| Filas de contexto en `solardb.registro_contexto` | **25.178** (100 %) |
| Cuadratura | 2.965.337 + 24.422 = 2.989.759 (exacta) |
| Meta del profesor (≥ 1.000.000 lecturas) | Superada (298,9 %) |

### 2.2 Cuarentena por regla de calidad

| Código de regla | Filas | Motivo técnico (según el coordinador) |
|---|---:|---|
| `R_P_MAYOR_S` | **24.375** | Potencia activa mayor que la aparente. Viola P ≤ S en corriente alterna; atribuida a desfase temporal en el muestreo Modbus. |
| `R_TEMP1_IMPOSIBLE` | **38** | `temper1 = -20,3 °C`; valor considerado imposible para el sitio; falla de sensor o circuito abierto. |
| `R_LINEPOWERVA_NEG` | **8** | Potencia aparente negativa (S < 0); la potencia aparente es una magnitud no negativa por definición. |
| `R_LINECURRA_NEG` | **1** | Corriente de red negativa; lectura espuria aislada de un sensor monofásico unidireccional. |
| **Total** | **24.422** | Almacenadas en `calidad.registro_cuarentena` como `JSONB` con estado `PENDIENTE`. |

### 2.3 Distribución por inversor en producción

| Inversor | Carga que alimenta | Filas aceptadas | % | Rango temporal |
|---|---|---:|---:|---|
| 1 | Cómputo (GPU/CPU) | **1.594.461** | 53,77 % | 2025-07-12 13:31:35 → 2026-07-13 05:13:53 (~1 año) |
| 2 | Climatización (HVAC) | **1.370.876** | 46,23 % | 2025-07-14 05:53:32 → 2026-06-22 05:35:24 (~11 meses) |
| **Total** | | **2.965.337** | 100 % | Cadencia mediana: 12,58 s |

### 2.4 Lotes de carga auditados

| `lote_id` | `tabla_origen` | Estado | Filas leídas | Filas aceptadas | Filas rechazadas |
|---:|---|---|---:|---:|---:|
| 4 | `analog_measurements` | COMPLETADO | 2.989.759 | 2.965.337 | 24.422 |
| 6 | `context` | COMPLETADO | 25.178 | 25.178 | 0 |

---

## 3. Dominios personalizados (`CREATE DOMAIN`, esquema `solardb`)

Un dominio es un tipo de dato propio, basado en un tipo existente, con restricciones incluidas. Define una sola vez la regla de una magnitud física y la reutiliza en muchas columnas.

| Dominio | Tipo base | Restricción `CHECK` | Columnas que lo usan |
|---|---|---|---|
| `dom_voltaje` | `DOUBLE PRECISION` | `VALUE >= 0` | `battvolt`, `pv1volt`, `outvolta`, `linevolta`, `busvoltp`, `busvoltn` |
| `dom_corriente` | `DOUBLE PRECISION` | Sin CHECK (con signo) | `battcurr` |
| `dom_corriente_no_neg` | `DOUBLE PRECISION` | `VALUE >= 0` | `linechgcurr`, `pvchgcurr`, `pv1curr`, `outcurra`, `invcurra`†, `linecurra`, `gridcurr_a` |
| `dom_potencia_activa` | `INTEGER` | Sin CHECK (con signo) | `battchgpower`, `linepowerw_a`, `gridpowerw_a`, `generatedpowerp_a`† |
| `dom_potencia_activa_no_neg` | `INTEGER` | `VALUE >= 0` | `pv1power`, `outw_a`, `normalloadw_a`†, `outsumw` |
| `dom_potencia_aparente` | `INTEGER` | `VALUE >= 0` | `outva_a`, `outsumva`, `linepowerva_a`†, `generatedpowers_a`† |
| `dom_potencia_reactiva` | `INTEGER` | Sin CHECK (con signo) | `generatedpowerq_a`† |
| `dom_frecuencia` | `DOUBLE PRECISION` | `VALUE >= 0` | `outfreq`, `linefreq` |
| `dom_temperatura` | `DOUBLE PRECISION` | Sin CHECK (las anomalías van a cuarentena) | `temper1`, `temper2`, `temper3`†, `temper4`† |
| `dom_porcentaje` | `SMALLINT` | `VALUE BETWEEN 0 AND 100` | `battsoc`, `fanduty` |
| `dom_porcentaje_carga` | `SMALLINT` | `VALUE BETWEEN 0 AND 110` | `loadpercenta`, `sumloadpercent` |
| `dom_resistencia_aislamiento` | `INTEGER` | `VALUE >= 0` | `sir` |

**Decisiones de diseño explicadas:**

1. **Dominios con signo:** la corriente de batería (positiva al cargar, negativa al descargar), las potencias de batería y de red (flujo en ambos sentidos) y la potencia reactiva pueden ser negativas, por lo que sus dominios no restringen el signo.
2. **`dom_temperatura` sin CHECK:** el valor anómalo `temper1 = -20,3 °C` (38 filas) no se impide con una restricción, porque el motor rechazaría la fila completa durante la migración. Se detecta con la regla `R_TEMP1_IMPOSIBLE` y la fila se conserva en cuarentena con su valor original.
3. **`dom_frecuencia` admite 0:** las lecturas de frecuencia 0 Hz corresponden a modo isla legítimo y no deben rechazarse.
4. **Reglas entre columnas fuera del dominio:** un dominio solo ve su propio valor; por eso la relación P ≤ S entre dos columnas no puede ser un dominio y se controla con `R_P_MAYOR_S` en el proceso de staging.
5. **Dominios y cuarentena trabajan juntos:** los dominios son la **última barrera** (una inserción directa inválida falla con un error `check_violation`); la cuarentena es el **filtro previo** del proceso de carga. Por ejemplo, `linepowerva_a` pertenece a `dom_potencia_aparente` (`>= 0`): las 8 filas con S negativa se desviaron a cuarentena **antes** de que el dominio las rechazara.

---

## 4. Esquema `solardb` — Catálogos

### 4.1 `solardb.dim_sitio` (1 fila)

Sitio físico donde opera la microrred: campus universitario de CUHK-Shenzhen, en Shenzhen, China.

| Columna | Tipo | NN | PK / FK / UNIQUE | Descripción |
|---|---|:-:|---|---|
| `sitio_id` | `SMALLINT` (identidad) | ✅ | PK | Identificador del sitio. |
| `nombre_sitio` | `VARCHAR` | ✅ | UNIQUE | Nombre del sitio (CUHK-Shenzhen). |
| Otras columnas descriptivas (ciudad, país, zona horaria) | — | — | — | Definidas en el DDL del coordinador; **verificar nombres y tipos contra el DDL**. |

### 4.2 `solardb.dim_subsistema` (2 filas: Cómputo y HVAC)

Cada uno de los dos subsistemas independientes de la microrred: 26 paneles de 480 W, banco de baterías LiFePO4 (~200 Ah, 51,2 V nominales), inversor híbrido y conexión a la red.

| Columna | Tipo | NN | PK / FK / UNIQUE | Descripción |
|---|---|:-:|---|---|
| `subsistema_id` | `SMALLINT` (identidad) | ✅ | PK | Identificador del subsistema. |
| `sitio_id` | `SMALLINT` | ✅ | FK → `dim_sitio.sitio_id` | Sitio al que pertenece. |
| Nombre, carga alimentada y especificaciones (paneles, potencia por panel, batería) | — | — | — | Definidas en el DDL; **verificar contra el DDL**. Los valores nominales exactos se almacenan como `NUMERIC` (sección 9.1). |

### 4.3 `solardb.dim_inversor` (2 filas: Inv1 e Inv2)

| Columna | Tipo | NN | PK / FK / UNIQUE | CHECK | Descripción |
|---|---|:-:|---|---|---|
| `inversor_id` | `SMALLINT` | ✅ | PK | valores 1 y 2 | Identificador original del inversor (columna `inverter`, rango observado [1, 2]). Inversor 1: cómputo (GPU/CPU). Inversor 2: climatización (HVAC). |
| `subsistema_id` | `SMALLINT` | ✅ | FK → `dim_subsistema.subsistema_id` | — | Subsistema al que pertenece. |
| Otras columnas descriptivas | — | — | — | — | **Verificar contra el DDL.** |

### 4.4 `solardb.cat_unidad_medida`

Catálogo de unidades: V, A, W, VA, Hz, °C, %, kΩ (y la unidad de potencia reactiva si el DDL la incluye).

| Columna | Tipo | NN | PK / FK / UNIQUE | Descripción |
|---|---|:-:|---|---|
| `unidad_id` | `SMALLINT` (identidad) | ✅ | PK | Identificador. |
| `simbolo` | `VARCHAR` | ✅ | UNIQUE | Símbolo de la unidad. |
| Nombre y magnitud | — | — | — | **Verificar contra el DDL.** |

### 4.5 `solardb.cat_variable_fisica` (38 o más filas)

Catálogo de las variables de telemetría, con su unidad oficial.

| Columna | Tipo | NN | PK / FK / UNIQUE | Descripción |
|---|---|:-:|---|---|
| `variable_id` | `SMALLINT` (identidad) | ✅ | PK | Identificador. |
| `nombre_columna` | `VARCHAR` | ✅ | UNIQUE | Nombre de la variable (ej. `battvolt`). |
| `unidad_id` | `SMALLINT` | ✅ | FK → `cat_unidad_medida.unidad_id` | Unidad de medida. |
| Descripción y rangos | — | — | — | **Verificar contra el DDL.** |

### 4.6 `solardb.cat_tipo_contexto` (7 filas)

Tipos de contexto, que corresponden a las 7 fuentes del campo `source` del JSON: `workstation1_log`, `workstation2_log`, `windows_event_log`, `derived_context_pipeline`, `wsl_bash_history`, `manual entry` y `manual_workload_entry`.

| Columna | Tipo | NN | PK / FK / UNIQUE | Descripción |
|---|---|:-:|---|---|
| `tipo_contexto_id` | `SMALLINT` (identidad) | ✅ | PK | Identificador. |
| Nombre de la fuente y descripción | — | — | — | **Verificar contra el DDL.** |

---

## 5. Esquema `solardb` — `lectura_telemetria`

- **Propósito:** una fila por lectura de un inversor en un instante (muestreo cada ~12,6 s por Modbus/RS485; cadencia mediana 12,58 s).
- **Filas reales:** **2.965.337**. **Tamaño real:** 3.824 MB (datos 3.440 MB; índices 384 MB).
- **Formato:** ancho (una columna por variable). **Columnas: 46** = 4 de control + 38 de medición + 4 `JSONB` reservadas.
- **Clave primaria:** `lectura_id` (`BIGINT GENERATED ALWAYS AS IDENTITY`).
- **Clave única natural:** `(inversor_id, ts_lectura)`.
- **Claves foráneas:** `inversor_id → dim_inversor(inversor_id)`; `lote_id → calidad.lote_carga(lote_id)`.
- **Evidencia de las unidades:** `column_dictionary.json`, campo `unit` del registro de cada variable. Marca **†**: unidad deducida del dominio, pendiente de verificar.

### 5.1 Columnas de control (4)

| # | Columna | Tipo | Dominio | NN | PK / FK / UNIQUE | Unidad | Descripción |
|---:|---|---|---|:-:|---|---|---|
| 1 | `lectura_id` | `BIGINT` (`GENERATED ALWAYS AS IDENTITY`) | — | ✅ | PK | adimensional | Llave subrogada de la lectura. |
| 2 | `inversor_id` | `SMALLINT` | — | ✅ | FK → `dim_inversor.inversor_id`; UNIQUE con `ts_lectura` | adimensional | Inversor que generó la lectura (origen: `inverter`). |
| 3 | `ts_lectura` | `TIMESTAMP WITH TIME ZONE` | — | ✅ | UNIQUE con `inversor_id` | s (Unix UTC) → fecha-hora | Instante de la lectura. Se obtiene de `read_ts` (Unix fraccionario, rango [1,75 × 10⁹; 1,78 × 10⁹]) con `to_timestamp(read_ts)`. |
| 4 | `lote_id` | `INTEGER` | — | ✅ | FK → `calidad.lote_carga.lote_id` | — | Lote de carga que insertó la fila (trazabilidad). |

### 5.2 Variables de batería (6)

| # | Columna | Tipo base | Dominio | Unidad | Rango observado | Descripción |
|---:|---|---|---|---|---|---|
| 5 | `battvolt` | `DOUBLE PRECISION` | `dom_voltaje` | V | [0,0; 57,60] | Voltaje de la batería. |
| 6 | `battcurr` | `DOUBLE PRECISION` | `dom_corriente` | A | [-66,30; 54,00] | Corriente de batería (positiva: carga; negativa: descarga). |
| 7 | `battsoc` | `SMALLINT` | `dom_porcentaje` | % | [6; 100] | Estado de carga (SOC). |
| 8 | `battchgpower` | `INTEGER` | `dom_potencia_activa` | W | [-3400; 2800] | Potencia de carga/descarga de la batería. |
| 9 | `linechgcurr` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A | [0,0; 50,0] | Corriente de carga desde la red. |
| 10 | `pvchgcurr` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A | [0,0; 60,0] | Corriente de carga desde la fuente solar. |

### 5.3 Variables fotovoltaicas (3)

| # | Columna | Tipo base | Dominio | Unidad | Rango observado | Descripción |
|---:|---|---|---|---|---|---|
| 11 | `pv1volt` | `DOUBLE PRECISION` | `dom_voltaje` | V | [0,0; 492,60] | Voltaje del arreglo fotovoltaico. |
| 12 | `pv1curr` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A | [0,0; 10,60] | Corriente del arreglo fotovoltaico. |
| 13 | `pv1power` | `INTEGER` | `dom_potencia_activa_no_neg` | W | [0; 3933] | Potencia activa solar generada. |

### 5.4 Variables de salida a las cargas (11)

| # | Columna | Tipo base | Dominio | Unidad | Rango observado | Descripción |
|---:|---|---|---|---|---|---|
| 14 | `outvolta` | `DOUBLE PRECISION` | `dom_voltaje` | V | [0,0; 245,80] | Voltaje de salida CA a las cargas. |
| 15 | `outcurra` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A | [0,0; 26,80] | Corriente de salida a las cargas. |
| 16 | `outfreq` | `DOUBLE PRECISION` | `dom_frecuencia` | Hz | [0,0; 50,10] | Frecuencia de salida. |
| 17 | `outw_a` | `INTEGER` | `dom_potencia_activa_no_neg` | W | [0; 5502] | Potencia activa entregada a la carga. |
| 18 | `outva_a` | `INTEGER` | `dom_potencia_aparente` | VA | [0; 5630] | Potencia aparente a la carga. |
| 19 | `outsumw` | `INTEGER` | `dom_potencia_activa_no_neg` | W | [0; 5502] | Potencia activa total a la microrred. |
| 20 | `outsumva` | `INTEGER` | `dom_potencia_aparente` | VA | [0; 5630] | Potencia aparente total. |
| 21 | `loadpercenta` | `SMALLINT` | `dom_porcentaje_carga` | % | [0; 110] | Porcentaje de carga sobre la capacidad nominal. |
| 22 | `sumloadpercent` | `SMALLINT` | `dom_porcentaje_carga` | % | [0; 110] | Porcentaje total de carga. |
| 23 | `invcurra`† | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A† | sin dato | Corriente asociada al inversor (nombre de la variable en el dataset; descripción por verificar). |
| 24 | `normalloadw_a`† | `INTEGER` | `dom_potencia_activa_no_neg` | W† | sin dato | Potencia activa de carga normal (descripción por verificar). |

### 5.5 Variables de la red eléctrica pública (10)

| # | Columna | Tipo base | Dominio | Unidad | Rango observado | Descripción |
|---:|---|---|---|---|---|---|
| 25 | `linevolta` | `DOUBLE PRECISION` | `dom_voltaje` | V | [0,0; 306,20] | Voltaje de la red pública. |
| 26 | `linecurra` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A | [0,0; 35,40] | Corriente tomada de la red. Valor negativo → regla `R_LINECURRA_NEG` (1 fila). |
| 27 | `linefreq` | `DOUBLE PRECISION` | `dom_frecuencia` | Hz | [0,0; 50,07] | Frecuencia de la red (nominal 50 Hz). |
| 28 | `linepowerw_a` | `INTEGER` | `dom_potencia_activa` | W | [-5500; 5500] | Potencia activa con la red. |
| 29 | `gridpowerw_a` | `INTEGER` | `dom_potencia_activa` | W | [-5500; 5500] | Potencia neta de red en la acometida. |
| 30 | `gridcurr_a` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | A | [0,0; 35,40] | Corriente neta de red. |
| 31 | `linepowerva_a`† | `INTEGER` | `dom_potencia_aparente` | VA† | sin dato | Potencia aparente de red. Valor negativo → regla `R_LINEPOWERVA_NEG` (8 filas). |
| 32 | `generatedpowerp_a`† | `INTEGER` | `dom_potencia_activa` | W† | sin dato | Potencia activa «generada» (descripción por verificar). |
| 33 | `generatedpowers_a`† | `INTEGER` | `dom_potencia_aparente` | VA† | sin dato | Potencia aparente «generada» (descripción por verificar). |
| 34 | `generatedpowerq_a`† | `INTEGER` | `dom_potencia_reactiva` | VAr† | sin dato | Potencia reactiva «generada» (descripción por verificar). |

### 5.6 Bus DC, temperaturas y auxiliares (8)

| # | Columna | Tipo base | Dominio | Unidad | Rango observado | Descripción |
|---:|---|---|---|---|---|---|
| 35 | `busvoltp` | `DOUBLE PRECISION` | `dom_voltaje` | V | [0,0; 480,00] | Voltaje del bus DC positivo. |
| 36 | `busvoltn` | `DOUBLE PRECISION` | `dom_voltaje` | V | [0,0; 480,00] | Voltaje del bus DC negativo. |
| 37 | `temper1` | `DOUBLE PRECISION` | `dom_temperatura` | °C | [-20,30; 49,30] | Temperatura del sensor 1. El valor -20,3 °C (38 filas) activa `R_TEMP1_IMPOSIBLE`. |
| 38 | `temper2` | `DOUBLE PRECISION` | `dom_temperatura` | °C | [0,0; 58,00] | Temperatura del sensor 2. |
| 39 | `temper3`† | `DOUBLE PRECISION` | `dom_temperatura` | °C† | sin dato | Temperatura del sensor 3. |
| 40 | `temper4`† | `DOUBLE PRECISION` | `dom_temperatura` | °C† | sin dato | Temperatura del sensor 4. |
| 41 | `sir` | `INTEGER` | `dom_resistencia_aislamiento` | kΩ | [0; 9999] | Resistencia de aislamiento del lado solar. |
| 42 | `fanduty` | `SMALLINT` | `dom_porcentaje` | % | [0; 100] | Ciclo de trabajo del ventilador. |

### 5.7 Columnas `JSONB` reservadas (4)

| # | Columna | Tipo | NN | Descripción |
|---:|---|---|:-:|---|
| 43 | `battreserve` | `JSONB` | NULL | Campo reservado asociado a la batería. |
| 44 | `pvreserve` | `JSONB` | NULL | Campo reservado asociado al arreglo fotovoltaico. |
| 45 | `otherreserve` | `JSONB` | NULL | Otros campos reservados. |
| 46 | `grid_reserve` | `JSONB` | NULL | Campo reservado asociado a la red. |

> **Pendiente:** el material disponible no detalla el contenido de las columnas `*_reserve`. Antes de la sustentación hay que confirmar con el coordinador qué guardan (por ejemplo, con `SELECT count(*) FILTER (WHERE battreserve IS NOT NULL) ...`). Su efecto en el tamaño de la tabla se discute en `09_diseno_fisico.md`.

**Verificación de la cuenta de 46 columnas:** 4 (control) + 6 + 3 + 11 + 10 + 8 (= 38 de medición) + 4 (reservadas) = 46.

**Nulabilidad:** todas las columnas de medición admiten `NULL`, porque ~2 % de las lecturas originales tiene valores nulos por *timeouts* de Modbus (regla `R_NULOS_MODBUS`, que **acepta** la fila con el nulo y no la envía a cuarentena).

---

## 6. Esquema `solardb` — `registro_contexto`

- **Propósito:** anotaciones de contexto (logs de estaciones, eventos de Windows, historial de comandos, eventos climáticos derivados, calendario institucional y pruebas de carga).
- **Filas reales:** **25.178** (100 % de `context`), lote 6. **Tamaño real:** 26 MB (datos 17 MB; índices 9,3 MB). **Columnas: 6.**

| Columna | Tipo | NN | Default | PK / FK | CHECK | Descripción |
|---|---|:-:|---|---|---|---|
| `contexto_id` | `BIGINT` (`GENERATED ALWAYS AS IDENTITY`) | ✅ | — | PK | — | Llave subrogada. |
| `tipo_contexto_id` | `SMALLINT` | ✅ | — | FK → `cat_tipo_contexto` | — | Fuente del registro (reemplaza la columna `fuente_contexto` de la primera versión). |
| `valor` | `JSONB` | ✅ | — | — | `jsonb_typeof(valor) = 'object'` | Contenido original del registro (campo `value`). |
| `contiene_datos_personales` | `BOOLEAN` | ✅ | `FALSE` | — | — | Marca para la Ley 1581 de 2012: indica los registros que pueden contener datos personales. |
| `lote_id` | `INTEGER` | ✅ | — | FK → `calidad.lote_carga` | — | Lote de carga (trazabilidad). |
| (sexta columna) | — | — | — | — | — | **Pendiente de confirmación:** el material disponible no la nombra; podría ser la marca de tiempo del evento. **Verificar contra el DDL.** |

**Distribución por fuente (campo `source` dentro de `valor`):**

| Fuente | Registros | Contenido | ¿Datos personales? |
|---|---:|---|---|
| `workstation2_log` | 8.902 | Logs GPU/CPU de la estación 2 | Posible (nombres de tareas) |
| `windows_event_log` | 6.271 | Eventos de Windows | Sí (nombres de usuario) |
| `workstation1_log` | 6.028 | Logs de tareas de la estación 1 | Posible |
| `derived_context_pipeline` | 3.708 | Eventos climáticos y solares derivados | No |
| `wsl_bash_history` | **204** | Comandos de terminal Linux | **Sí (usuarios, rutas e IP)** |
| `manual entry` | 60 | Calendario institucional | No |
| `manual_workload_entry` | 5 | Pruebas de carga | No |
| **Total** | **25.178** | | |

---

## 7. Esquema `calidad` y esquema `staging`

### 7.1 `calidad.lote_carga` (2 lotes completados)

Auditoría de cada ejecución de carga.

| Columna (según los resultados certificados) | Tipo | Descripción |
|---|---|---|
| `lote_id` | `INTEGER` (identidad), PK | Identificador del lote (valores reales: 4 y 6). |
| `tabla_origen` | `VARCHAR` | Tabla del SQLite de origen (`analog_measurements`, `context`). |
| `estado` | `VARCHAR` | Estado del lote (`COMPLETADO`). |
| `filas_leidas` | `BIGINT` | Filas leídas del origen. |
| `filas_aceptadas` | `BIGINT` | Filas insertadas en producción. |
| `filas_rechazadas` | `BIGINT` | Filas enviadas a cuarentena. |

> Otras columnas (fechas de inicio y fin, por ejemplo) pueden existir en el DDL; **verificar contra el DDL**.

### 7.2 `calidad.regla_calidad` (6 reglas activas)

| Código | Qué valida | Acción | Filas en cuarentena |
|---|---|---|---:|
| `R_P_MAYOR_S` | Potencia activa mayor que la aparente | Cuarentena | 24.375 |
| `R_TEMP1_IMPOSIBLE` | `temper1 = -20,3 °C` | Cuarentena | 38 |
| `R_LINEPOWERVA_NEG` | Potencia aparente negativa | Cuarentena | 8 |
| `R_LINECURRA_NEG` | Corriente de red negativa | Cuarentena | 1 |
| `R_NULOS_MODBUS` | Nulos por *timeouts* de Modbus | Aceptar la fila con el nulo | 0 |
| `R_FREQ_CERO` | Frecuencia = 0 Hz | Aceptar (modo isla legítimo) | 0 |

> Las acciones de las dos últimas reglas se deducen del desglose certificado (no generan filas en cuarentena). **Verificar contra el DDL.**

### 7.3 `calidad.registro_cuarentena` (24.422 filas)

- **Tamaño real:** 34 MB (datos 32 MB; índices 2,2 MB).
- Cada fila conserva la fila rechazada completa en `JSONB`, la regla incumplida (`regla_id`, con índice `idx_cuarentena_regla`) y su estado (`estado`, con índice `idx_cuarentena_estado`). Todos los registros actuales están en estado `PENDIENTE`.
- Columnas propuestas en la versión 1 y no contradichas por los resultados: `cuarentena_id` (`BIGINT`, PK), `lote_id` (FK), `regla_id` (FK), `fila_original` (`JSONB`), `estado` (`CHECK` con `PENDIENTE`, `CORREGIDO`, `DESCARTADO`, `REPROCESADO`), `fecha_registro` y `fecha_resolucion`. **Verificar nombres y tipos contra el DDL.**

### 7.4 Esquema `staging`

Zona de aterrizaje de los datos crudos, sin dominios ni `CHECK`, donde las filas se clasifican como válidas o inválidas **antes** de insertarse en `solardb`. PostgreSQL no envía las filas rechazadas a cuarentena de forma automática: es el proceso de staging el que las clasifica. Nombres y estructura de las tablas: **pendientes de confirmación contra el DDL**.

---

## 8. Almacenamiento real en disco (PostgreSQL 18)

| Tabla | Total | Datos | Índices |
|---|---:|---:|---:|
| `solardb.lectura_telemetria` | **3.824 MB** (3,73 GB) | 3.440 MB | 384 MB |
| `calidad.registro_cuarentena` | **34 MB** | 32 MB | 2,2 MB |
| `solardb.registro_contexto` | **26 MB** | 17 MB | 9,3 MB |
| Catálogos dimensionales y reglas | **< 1 MB** | < 100 KB | < 200 KB |
| **Total SolarDB** | **≈ 3,88 GB** | | |

**Dato derivado** (cálculo propio a partir de las cifras anteriores, con 1 MB = 1.048.576 bytes): 3.440 MB de datos entre 2.965.337 filas equivale a unos **1,2 KB por fila** en `lectura_telemetria`. La comparación con la estimación de diseño se hace en `09_diseno_fisico.md`.

---

## 9. Justificación técnica de los tipos de datos

### 9.1 `NUMERIC` frente a `DOUBLE PRECISION`

| Aspecto | `NUMERIC(p,s)` | `DOUBLE PRECISION` |
|---|---|---|
| Representación | Decimal exacto, precisión arbitraria | Punto flotante binario IEEE 754 de 64 bits |
| Exactitud | Sin error de redondeo binario | Algunos decimales (ej. 0,1) no se representan exactamente |
| Velocidad | Más lento (aritmética por software) | Más rápido (aritmética por hardware) |
| Espacio | Variable | 8 bytes fijos |

**Decisión en SolarDB:**

- **Telemetría instantánea → `DOUBLE PRECISION`.** Son mediciones de sensor con incertidumbre propia; la resolución observada es de una décima (por ejemplo 57,60 V, 54,00 A), por lo que un error relativo del orden de 10⁻¹⁵ es irrelevante. El origen (`REAL` de SQLite) ya es un flotante de 8 bytes: la conversión **no pierde información**. Con 2.965.337 filas, las agregaciones son más rápidas.
- **Magnitudes enteras → `INTEGER` o `SMALLINT`.** Las potencias (W, VA) y la resistencia de aislamiento se registran como enteros, y los porcentajes (0–110) caben en `SMALLINT`; esto ahorra espacio en una tabla con 38 variables.
- **Datos exactos → `NUMERIC`.** Se reserva para las especificaciones nominales de `dim_subsistema` (capacidad de batería, voltaje nominal) y para presentar los totales de energía (kWh) de las consultas de negocio, ya que la suma de millones de términos en punto flotante puede arrastrar error de redondeo y volver los totales no reproducibles. Convertir el resultado final con `CAST(... AS NUMERIC(14,3))` estabiliza la presentación.

### 9.2 `TIMESTAMP WITH TIME ZONE` frente a `TIMESTAMP WITHOUT TIME ZONE`

- Los datos originales son **timestamps Unix fraccionarios en UTC** (`read_ts`).
- `timestamptz` guarda internamente el instante en UTC y lo convierte a la zona de la sesión al mostrarlo: representa un **instante absoluto**. `timestamp` guarda el valor literal sin zona y puede interpretarse de formas distintas según quién lo lea.
- **Decisión:** `timestamptz` para `ts_lectura`. El sitio está en Shenzhen (UTC+8) y el análisis se hace desde otra zona horaria; además, los cálculos de diferencias de tiempo (esenciales para integrar potencia en energía con una cadencia mediana de 12,58 s) deben ser correctos. La conversión `to_timestamp(read_ts)` devuelve `timestamptz` y conserva la parte fraccionaria.
- **Verificación con datos reales:** los rangos certificados (por ejemplo, el inversor 1: 2025-07-12 13:31:35 a 2026-07-13 05:13:53) se muestran en la zona horaria de la sesión de DBeaver; hay que fijarla de forma explícita al presentar resultados.

### 9.3 `JSONB` frente a `JSON`

| Aspecto | `JSON` | `JSONB` |
|---|---|---|
| Almacenamiento | Texto tal cual (conserva espacios y orden de claves) | Representación binaria descompuesta |
| Consulta | Se reanaliza en cada acceso | Ya procesado: más rápido |
| Indexación | No admite índice GIN | Admite índice GIN (`idx_contexto_valor_gin`) |
| Operadores | Limitados | Contención `@>`, existencia `?`, `?&`, `?\|` |

**Decisión:** `JSONB` en `registro_contexto.valor` (25.178 registros semiestructurados con el campo `source`), en `registro_cuarentena` (copia de la fila rechazada) y en las 4 columnas `*_reserve` de `lectura_telemetria`. Permite filtrar por contenido con un índice GIN. La pérdida del orden de claves y de los espacios no afecta al análisis, y el costo extra en escritura es despreciable en una carga por lotes.

### 9.4 `BIGINT` frente a `INTEGER`

| Tipo | Tamaño | Rango aproximado |
|---|---|---|
| `SMALLINT` | 2 bytes | ±32.767 |
| `INTEGER` | 4 bytes | ±2,1 × 10⁹ |
| `BIGINT` | 8 bytes | ±9,2 × 10¹⁸ |

- **`lectura_id` → `BIGINT`.** Con 2.965.337 filas, `INTEGER` alcanzaría (usa ~0,14 % de su rango). Se eligió `BIGINT` por crecimiento: el muestreo es continuo y cambiar el tipo de una llave primaria con millones de filas es costoso. El sobrecosto es de 4 bytes por fila (≈ 12 MB en total, poco frente a los 3.824 MB de la tabla). Lo mismo aplica a `contexto_id`.
- **Catálogos → `SMALLINT`** (1, 2, 2, 38 o más, 7 filas): llaves foráneas más pequeñas.
- **`lote_id` → `INTEGER`:** el número de lotes es pequeño.
- **Contadores de energía:** son magnitudes decimales (kWh); si se almacenaran en Wh como enteros, `BIGINT` sería suficiente.

---

## 10. Notas de consistencia y pendientes

1. **Diferencia en la regla P > S.** El diagnóstico de la Fase 1 reportaba **3.811** filas con P > S; la migración certificó **24.375** en `R_P_MAYOR_S`. Este documento usa la cifra certificada. **Pendiente: pedir al coordinador la explicación** (por ejemplo, que la regla use otro criterio o tolerancia que la del diagnóstico), porque el profesor podría preguntarlo.
2. **8 variables nuevas (†):** `invcurra`, `normalloadw_a`, `linepowerva_a`, `generatedpowerp_a`, `generatedpowers_a`, `generatedpowerq_a`, `temper3` y `temper4`. Confirmar su unidad y descripción en `column_dictionary.json` y completar el rango observado.
3. **Columnas `*_reserve`:** confirmar qué contienen.
4. **Sexta columna de `registro_contexto`** y estructura exacta de `lote_carga`, `registro_cuarentena`, los catálogos y las tablas de `staging`: verificar contra el DDL.
5. **Mínima histórica en Shenzhen (~0 °C):** es el argumento del coordinador para `R_TEMP1_IMPOSIBLE`; si el informe lo cita, debe apoyarse en una fuente.
6. El archivo `docs/11_resultados_migracion.md`, mencionado como fuente de las métricas, **no estaba adjunto**; las cifras de este documento provienen del texto del prompt de la Ronda 2. Conviene cotejarlas con ese archivo.

---

## 11. Protección del repositorio

Este documento no contiene contraseñas, tokens ni cadenas de conexión. Los scripts del repositorio no deben incluir credenciales; el detalle está en `docs/14_seguridad_y_privacidad.md`.
