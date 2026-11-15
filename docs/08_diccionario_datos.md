# Diccionario de Datos — SolarDB

| | |
|---|---|
| **Proyecto** | Taller 6 — Bases de Datos I. SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL |
| **Institución / grupo** | Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II |
| **Docente** | Ramiro Grisales Montoya |
| **Integrante responsable** | Jose Miguel Sosa Cartagena (diccionario de datos, diseño físico, privacidad y documento final) |
| **Fecha** | 15 de noviembre de 2026 |
| **Dataset** | OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223) |
| **Motor** | PostgreSQL (administración con DBeaver) |

**Cita del dataset:** Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

---

## 1. Introducción y convenciones

Este documento describe, tabla por tabla y columna por columna, el modelo físico de **SolarDB**. El modelo fue propuesto por el coordinador (Juan Sebastian Raigosa Gil) y aún está pendiente de implementación. Todo detalle que no esté confirmado se marca como **«pendiente de confirmación por el coordinador»**, acompañado de un valor propuesto.

### 1.1 Convenciones del documento

- **Esquemas PostgreSQL:** `solardb` (producción: catálogos y hechos), `staging` (carga temporal) y `calidad` (control de calidad y cuarentena).
- **Nulabilidad:** `NN` = `NOT NULL`; `NULL` = admite nulos.
- **Evidencia de la unidad:** todas las unidades de las variables físicas provienen del archivo `column_dictionary.json` de los autores de OpenCEM, campo `unit` del registro de cada variable, y fueron verificadas por el coordinador contra la base SQLite descomprimida (4,13 GB). Para evitar repetir la misma cita 30 veces, la columna «Evidencia» de las tablas indica el registro consultado, siempre bajo esta fuente.
- **Rango observado:** corresponde al rango verificado empíricamente en `analog_measurements` (no es un límite físico del equipo). Los CHECK de los dominios no se derivan de rangos observados salvo que se indique expresamente, para no declarar como imposible un valor que solo es poco frecuente.

### 1.2 Origen de los datos (SQLite original)

| Tabla original | Columnas | Filas | Uso en SolarDB |
|---|---:|---:|---|
| `analog_measurements` | 44 | 2.989.759 | Origen de `lectura_telemetria` |
| `context` | 5 | 25.178 | Origen de `registro_contexto` |
| `status` | 20 | 2.240.052 | Fuera del alcance actual (pendiente de confirmación) |
| `totals` | 21 | 2.279.918 | Fuera del alcance actual (pendiente de confirmación) |
| `settings` | 176 | 2.284.775 | Fuera del alcance actual (columnas estáticas redundantes) |
| `specs` | 16 | 1.333.174 | Fuera del alcance actual (redundancia masiva) |
| `statistics` | 31 | 2.285.904 | Fuera del alcance actual (contadores de energía histórica) |
| `fault_history` | 66 | 2.129.517 | Fuera del alcance actual |

### 1.3 Resumen de tablas del modelo

| Esquema | Tabla | Tipo | Filas esperadas |
|---|---|---|---|
| `solardb` | `dim_sitio` | Catálogo | 1 |
| `solardb` | `dim_subsistema` | Catálogo | 2 |
| `solardb` | `dim_inversor` | Catálogo | 2 |
| `solardb` | `cat_unidad_medida` | Catálogo | 9 (pendiente de confirmación) |
| `solardb` | `cat_variable_fisica` | Catálogo | 30 (pendiente de confirmación) |
| `solardb` | `lectura_telemetria` | Hechos | hasta 2.989.759 |
| `solardb` | `registro_contexto` | Hechos | hasta 25.178 |
| `calidad` | `lote_carga` | Calidad | según lotes ejecutados |
| `calidad` | `regla_calidad` | Calidad | por definir (pendiente de confirmación) |
| `calidad` | `registro_cuarentena` | Calidad | según reglas aplicadas |
| `staging` | `staging_telemetria` | Staging | transitoria |

---

## 2. Dominios personalizados (`CREATE DOMAIN`)

Los dominios centralizan el tipo y la restricción de una magnitud física. Si cambia una regla, se modifica en un único lugar.

| Dominio | Tipo base | Restricción propuesta | Variables que lo usan | Estado |
|---|---|---|---|---|
| `dom_voltaje` | `DOUBLE PRECISION` | `CHECK (VALUE >= 0)` | `battvolt`, `pv1volt`, `outvolta`, `linevolta`, `busvoltp`, `busvoltn` | Pendiente de confirmación |
| `dom_corriente` | `DOUBLE PRECISION` | Sin restricción de signo | `battcurr` | Pendiente de confirmación |
| `dom_corriente_no_neg` | `DOUBLE PRECISION` | `CHECK (VALUE >= 0)` | `linechgcurr`, `pvchgcurr`, `pv1curr`, `outcurra`, `linecurra`, `gridcurr_a` | Pendiente de confirmación |
| `dom_potencia_activa` | `INTEGER` | Sin restricción de signo | `battchgpower`, `linepowerw_a`, `gridpowerw_a` | Pendiente de confirmación |
| `dom_potencia_activa_no_neg` | `INTEGER` | `CHECK (VALUE >= 0)` | `pv1power`, `outw_a`, `outsumw` | Pendiente de confirmación |
| `dom_potencia_aparente` | `INTEGER` | `CHECK (VALUE >= 0)` | `outva_a`, `outsumva` | Pendiente de confirmación |
| `dom_frecuencia` | `DOUBLE PRECISION` | `CHECK (VALUE >= 0)` | `outfreq`, `linefreq` | Pendiente de confirmación |
| `dom_temperatura` | `DOUBLE PRECISION` | Sin límites en el dominio (los valores anómalos se tratan en `regla_calidad`) | `temper1`, `temper2` | Pendiente de confirmación |
| `dom_porcentaje` | `SMALLINT` | `CHECK (VALUE BETWEEN 0 AND 100)` | `battsoc`, `fanduty` | Pendiente de confirmación |
| `dom_porcentaje_carga` | `SMALLINT` | `CHECK (VALUE BETWEEN 0 AND 110)` | `loadpercenta`, `sumloadpercent` | Pendiente de confirmación |
| `dom_resistencia_aislamiento` | `INTEGER` | `CHECK (VALUE >= 0)` | `sir` | Pendiente de confirmación |

**Notas sobre las decisiones:**

1. Los dominios con `>= 0` se basan en que ninguna de esas variables presenta valores negativos en el rango observado. La corriente de batería (`battcurr`, [-66,30; 54,00] A) y las potencias `battchgpower`, `linepowerw_a` y `gridpowerw_a` sí son negativas por definición (la documentación indica que `battcurr` es positiva al cargar y negativa al descargar), por eso usan dominios sin restricción de signo.
2. `dom_porcentaje_carga` admite hasta 110 porque `loadpercenta` y `sumloadpercent` tienen rango observado [0, 110].
3. **Condiciones que NO se implementan como CHECK:** la regla P > S (potencia activa mayor que la aparente, 3.811 filas) y el valor `temper1 = -20,3 °C` (38 filas) no pueden ser restricciones rígidas, porque PostgreSQL rechazaría la fila completa durante la migración. Se clasifican en `staging` antes del `INSERT` y se envían a `calidad.registro_cuarentena` (véase la sección 6).
4. Los 342.592 registros con frecuencia 0 Hz corresponden a modo isla legítimo, por lo que `dom_frecuencia` **debe admitir 0**.

---

## 3. Esquema `solardb` — Catálogos

### 3.1 `solardb.dim_sitio`

- **Propósito:** identifica el sitio físico donde opera la microrred (campus universitario en Shenzhen, China, CUHK-Shenzhen).
- **Filas esperadas:** 1.

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|
| `sitio_id` | `SMALLINT` (identidad) | — | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | Identificador subrogado del sitio. |
| `nombre_sitio` | `VARCHAR(100)` | — | NN | — | — | — | ✅ | — | Nombre del sitio (CUHK-Shenzhen). |
| `ciudad` | `VARCHAR(60)` | — | NN | — | — | — | — | — | Ciudad (Shenzhen). |
| `pais` | `VARCHAR(60)` | — | NN | — | — | — | — | — | País (China). |
| `zona_horaria` | `VARCHAR(40)` | — | NULL | — | — | — | — | — | Zona horaria IANA del sitio. **Pendiente de confirmación por el coordinador** (valor propuesto: `Asia/Shanghai`). |

### 3.2 `solardb.dim_subsistema`

- **Propósito:** representa cada uno de los 2 subsistemas independientes de la microrred híbrida (arreglo solar, banco de baterías, inversor y conexión a la red pública).
- **Filas esperadas:** 2.

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|
| `subsistema_id` | `SMALLINT` (identidad) | — | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | Identificador subrogado. |
| `sitio_id` | `SMALLINT` | — | NN | — | — | → `dim_sitio.sitio_id` | — | — | Sitio al que pertenece. |
| `nombre_subsistema` | `VARCHAR(100)` | — | NN | — | — | — | ✅ | — | Nombre descriptivo del subsistema. |
| `carga_alimentada` | `VARCHAR(120)` | — | NN | — | — | — | — | — | Qué alimenta: estaciones de cómputo de investigación (GPU/CPU) o sistemas de climatización (HVAC). |
| `num_paneles` | `SMALLINT` | — | NN | — | — | — | — | `CHECK (num_paneles > 0)` | Número de paneles solares (26 por subsistema). |
| `potencia_panel_w` | `SMALLINT` | — | NN | — | — | — | — | `CHECK (potencia_panel_w > 0)` | Potencia de cada panel en W (480). |
| `quimica_bateria` | `VARCHAR(30)` | — | NN | — | — | — | — | — | Química del banco de baterías (LiFePO4). |
| `capacidad_bateria_ah` | `NUMERIC(6,1)` | — | NULL | — | — | — | — | `CHECK (capacidad_bateria_ah > 0)` | Capacidad aproximada del banco (~200 Ah). |
| `voltaje_nominal_bateria_v` | `NUMERIC(4,1)` | — | NULL | — | — | — | — | `CHECK (voltaje_nominal_bateria_v > 0)` | Voltaje nominal del banco (51,2 V). |

> `NUMERIC` se usa aquí porque son datos de especificación (valores nominales exactos que se capturan manualmente), no mediciones de sensor.

### 3.3 `solardb.dim_inversor`

- **Propósito:** identifica a cada inversor híbrido que genera las lecturas. Inversor 1 alimenta estaciones de cómputo; inversor 2 alimenta climatización (HVAC).
- **Filas esperadas:** 2.

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|
| `inversor_id` | `SMALLINT` | — | NN | — | ✅ | — | — | `CHECK (inversor_id IN (1, 2))` | Identificador del inversor. Se conserva el valor original de la columna `inverter` (rango observado [1, 2]). |
| `subsistema_id` | `SMALLINT` | — | NN | — | — | → `dim_subsistema.subsistema_id` | ✅ | — | Subsistema al que pertenece (relación 1 a 1 propuesta, pendiente de confirmación). |
| `frecuencia_nominal_hz` | `SMALLINT` | — | NN | `50` | — | — | — | `CHECK (frecuencia_nominal_hz > 0)` | Frecuencia nominal de la red (50 Hz). |
| `tension_nominal_red_v` | `VARCHAR(10)` | — | NULL | — | — | — | — | — | Tensión nominal de la red pública (220 V / 230 V CA). |

### 3.4 `solardb.cat_unidad_medida`

- **Propósito:** catálogo de unidades de medida usadas por las variables físicas.
- **Filas esperadas:** 9 (V, A, W, VA, Hz, °C, %, kΩ, s). **Pendiente de confirmación por el coordinador.**

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|
| `unidad_id` | `SMALLINT` (identidad) | — | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | Identificador subrogado. |
| `simbolo` | `VARCHAR(10)` | — | NN | — | — | — | ✅ | — | Símbolo (V, A, W, VA, Hz, °C, %, kΩ, s). |
| `nombre` | `VARCHAR(40)` | — | NN | — | — | — | — | — | Nombre completo (voltio, amperio, vatio, voltamperio, hercio, grado Celsius, porcentaje, kiloohmio, segundo). |
| `magnitud` | `VARCHAR(40)` | — | NN | — | — | — | — | — | Magnitud física que mide. |

### 3.5 `solardb.cat_variable_fisica`

- **Propósito:** catálogo de las 30 variables físicas de `analog_measurements`, con su unidad oficial y rango observado. Es el vínculo documental entre cada columna de `lectura_telemetria` y la fuente de los autores.
- **Filas esperadas:** 30. **Pendiente de confirmación por el coordinador.**

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|
| `variable_id` | `SMALLINT` (identidad) | — | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | Identificador subrogado. |
| `nombre_columna` | `VARCHAR(30)` | — | NN | — | — | — | ✅ | — | Nombre de la variable en el dataset (ej. `battvolt`). |
| `descripcion` | `TEXT` | — | NN | — | — | — | — | — | Descripción funcional de la variable. |
| `unidad_id` | `SMALLINT` | — | NN | — | — | → `cat_unidad_medida.unidad_id` | — | — | Unidad de medida oficial. |
| `rango_min_observado` | `DOUBLE PRECISION` | — | NULL | — | — | — | — | — | Mínimo observado en `analog_measurements`. |
| `rango_max_observado` | `DOUBLE PRECISION` | — | NULL | — | — | — | — | `CHECK (rango_max_observado >= rango_min_observado)` | Máximo observado. |
| `fuente_unidad` | `VARCHAR(120)` | — | NN | `'column_dictionary.json, campo unit'` | — | — | — | — | Evidencia documental de la unidad. |

---

## 4. Esquema `solardb` — Tablas de hechos

### 4.1 `solardb.lectura_telemetria`

- **Propósito:** almacena cada lectura de telemetría analógica de un inversor. El muestreo se realiza aproximadamente cada 12,6 segundos mediante Modbus/RS485.
- **Filas esperadas:** hasta 2.989.759 (cantidad de `analog_measurements`), menos las filas enviadas a cuarentena. **El total efectivo depende de la migración (pendiente).**
- **Formato:** se propone **formato ancho** (una columna por variable física), igual al origen. La decisión ancho/largo está **pendiente de confirmación por el coordinador**.
- **Evidencia de las unidades:** `column_dictionary.json`, campo `unit` del registro de cada variable.

**Columnas de control**

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Unidad | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|---|
| `lectura_id` | `BIGINT` (identidad) | — | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | adimensional | Llave subrogada de la lectura. |
| `inversor_id` | `SMALLINT` | — | NN | — | — | → `dim_inversor.inversor_id` | ✅ (con `ts_lectura`) | — | adimensional | Inversor que generó la lectura (origen: `inverter`, rango [1, 2]). |
| `ts_lectura` | `TIMESTAMP WITH TIME ZONE` | — | NN | — | — | — | ✅ (con `inversor_id`) | — | s (Unix UTC) → fecha-hora | Instante de la lectura. Se obtiene de `read_ts` (timestamp Unix fraccionario, rango [1,75e9; 1,78e9]) con `to_timestamp(read_ts)`. |
| `lote_id` | `INTEGER` | — | NN | — | — | → `calidad.lote_carga.lote_id` | — | — | — | Lote de carga que insertó la fila (trazabilidad). |

> La restricción `UNIQUE (inversor_id, ts_lectura)` es la que haría idempotente la migración (si se ejecuta dos veces, no duplica filas). **Pendiente de confirmación:** el coordinador debe verificar que no existan duplicados en el origen.

**Variables de batería**

| Nombre | Tipo | Dominio | Nulabilidad | Unidad | Rango observado | Evidencia | Descripción |
|---|---|---|---|---|---|---|---|
| `battvolt` | `DOUBLE PRECISION` | `dom_voltaje` | NULL | V | [0,0; 57,60] | `column_dictionary.json`, `unit` de `battvolt` | Voltaje de la batería. |
| `battcurr` | `DOUBLE PRECISION` | `dom_corriente` | NULL | A | [-66,30; 54,00] | `column_dictionary.json`, `unit` de `battcurr` | Corriente de batería (positiva: carga; negativa: descarga). |
| `battsoc` | `SMALLINT` | `dom_porcentaje` | NULL | % | [6; 100] | `column_dictionary.json`, `unit` de `battsoc` | Estado de carga (SOC) de la batería. |
| `battchgpower` | `INTEGER` | `dom_potencia_activa` | NULL | W | [-3400; 2800] | `column_dictionary.json`, `unit` de `battchgpower` | Potencia de carga/descarga de la batería. |
| `linechgcurr` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | NULL | A | [0,0; 50,0] | `column_dictionary.json`, `unit` de `linechgcurr` | Corriente de carga desde la red. |
| `pvchgcurr` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | NULL | A | [0,0; 60,0] | `column_dictionary.json`, `unit` de `pvchgcurr` | Corriente de carga desde la fuente solar. |

**Variables fotovoltaicas**

| Nombre | Tipo | Dominio | Nulabilidad | Unidad | Rango observado | Evidencia | Descripción |
|---|---|---|---|---|---|---|---|
| `pv1volt` | `DOUBLE PRECISION` | `dom_voltaje` | NULL | V | [0,0; 492,60] | `column_dictionary.json`, `unit` de `pv1volt` | Voltaje del arreglo fotovoltaico. |
| `pv1curr` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | NULL | A | [0,0; 10,60] | `column_dictionary.json`, `unit` de `pv1curr` | Corriente del arreglo fotovoltaico. |
| `pv1power` | `INTEGER` | `dom_potencia_activa_no_neg` | NULL | W | [0; 3933] | `column_dictionary.json`, `unit` de `pv1power` | Potencia activa solar generada. |

**Variables de salida (carga)**

| Nombre | Tipo | Dominio | Nulabilidad | Unidad | Rango observado | Evidencia | Descripción |
|---|---|---|---|---|---|---|---|
| `outvolta` | `DOUBLE PRECISION` | `dom_voltaje` | NULL | V | [0,0; 245,80] | `column_dictionary.json`, `unit` de `outvolta` | Voltaje de salida CA a las cargas. |
| `outcurra` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | NULL | A | [0,0; 26,80] | `column_dictionary.json`, `unit` de `outcurra` | Corriente de salida a las cargas. |
| `outfreq` | `DOUBLE PRECISION` | `dom_frecuencia` | NULL | Hz | [0,0; 50,10] | `column_dictionary.json`, `unit` de `outfreq` | Frecuencia de salida. |
| `outw_a` | `INTEGER` | `dom_potencia_activa_no_neg` | NULL | W | [0; 5502] | `column_dictionary.json`, `unit` de `outw_a` | Potencia activa entregada a la carga. |
| `outva_a` | `INTEGER` | `dom_potencia_aparente` | NULL | VA | [0; 5630] | `column_dictionary.json`, `unit` de `outva_a` | Potencia aparente a la carga. |
| `outsumw` | `INTEGER` | `dom_potencia_activa_no_neg` | NULL | W | [0; 5502] | `column_dictionary.json`, `unit` de `outsumw` | Potencia activa total a la microrred. |
| `outsumva` | `INTEGER` | `dom_potencia_aparente` | NULL | VA | [0; 5630] | `column_dictionary.json`, `unit` de `outsumva` | Potencia aparente total. |
| `loadpercenta` | `SMALLINT` | `dom_porcentaje_carga` | NULL | % | [0; 110] | `column_dictionary.json`, `unit` de `loadpercenta` | Porcentaje de carga sobre la capacidad nominal. |
| `sumloadpercent` | `SMALLINT` | `dom_porcentaje_carga` | NULL | % | [0; 110] | `column_dictionary.json`, `unit` de `sumloadpercent` | Porcentaje total de carga. |

**Variables de la red eléctrica pública**

| Nombre | Tipo | Dominio | Nulabilidad | Unidad | Rango observado | Evidencia | Descripción |
|---|---|---|---|---|---|---|---|
| `linevolta` | `DOUBLE PRECISION` | `dom_voltaje` | NULL | V | [0,0; 306,20] | `column_dictionary.json`, `unit` de `linevolta` | Voltaje de la red pública. |
| `linecurra` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | NULL | A | [0,0; 35,40] | `column_dictionary.json`, `unit` de `linecurra` | Corriente tomada de la red. |
| `linefreq` | `DOUBLE PRECISION` | `dom_frecuencia` | NULL | Hz | [0,0; 50,07] | `column_dictionary.json`, `unit` de `linefreq` | Frecuencia de la red (nominal 50 Hz). |
| `linepowerw_a` | `INTEGER` | `dom_potencia_activa` | NULL | W | [-5500; 5500] | `column_dictionary.json`, `unit` de `linepowerw_a` | Potencia activa con la red. |
| `gridpowerw_a` | `INTEGER` | `dom_potencia_activa` | NULL | W | [-5500; 5500] | `column_dictionary.json`, `unit` de `gridpowerw_a` | Potencia neta de red en la acometida. |
| `gridcurr_a` | `DOUBLE PRECISION` | `dom_corriente_no_neg` | NULL | A | [0,0; 35,40] | `column_dictionary.json`, `unit` de `gridcurr_a` | Corriente neta de red. |

**Variables del bus DC, térmicas y auxiliares**

| Nombre | Tipo | Dominio | Nulabilidad | Unidad | Rango observado | Evidencia | Descripción |
|---|---|---|---|---|---|---|---|
| `busvoltp` | `DOUBLE PRECISION` | `dom_voltaje` | NULL | V | [0,0; 480,00] | `column_dictionary.json`, `unit` de `busvoltp` | Voltaje del bus DC positivo. |
| `busvoltn` | `DOUBLE PRECISION` | `dom_voltaje` | NULL | V | [0,0; 480,00] | `column_dictionary.json`, `unit` de `busvoltn` | Voltaje del bus DC negativo. |
| `temper1` | `DOUBLE PRECISION` | `dom_temperatura` | NULL | °C | [-20,30; 49,30] | `column_dictionary.json`, `unit` de `temper1` | Temperatura del sensor 1. El valor -20,3 °C (38 filas) es un error de sensor y se trata por regla de calidad. |
| `temper2` | `DOUBLE PRECISION` | `dom_temperatura` | NULL | °C | [0,0; 58,00] | `column_dictionary.json`, `unit` de `temper2` | Temperatura del sensor 2. |
| `sir` | `INTEGER` | `dom_resistencia_aislamiento` | NULL | kΩ | [0; 9999] | `column_dictionary.json`, `unit` de `sir` | Resistencia de aislamiento del lado solar. |
| `fanduty` | `SMALLINT` | `dom_porcentaje` | NULL | % | [0; 100] | `column_dictionary.json`, `unit` de `fanduty` | Ciclo de trabajo del ventilador. |

**Nulabilidad de las variables:** todas las columnas de medición admiten `NULL`, porque aproximadamente el 2 % de las filas (≈58.000–60.000) tiene valores nulos por *timeouts* de Modbus. Declararlas `NOT NULL` provocaría el rechazo de datos que son legítimos como «medición no disponible».

### 4.2 `solardb.registro_contexto`

- **Propósito:** almacena las anotaciones de contexto (logs de estaciones de trabajo, eventos de Windows, historial de comandos, eventos climáticos derivados, calendario institucional y pruebas de carga).
- **Filas esperadas:** hasta 25.178.
- **Nota importante:** el contexto proporcionado no detalla las 5 columnas de la tabla `context` original, salvo el campo JSON `value` y su clave `$.source`. Las columnas siguientes son una **propuesta, pendiente de confirmación por el coordinador**.

| Nombre | Tipo | Dominio | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|---|:-:|---|:-:|---|---|
| `contexto_id` | `BIGINT` (identidad) | — | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | Llave subrogada. |
| `fuente_contexto` | `VARCHAR(40)` | — | NN | — | — | — | — | — | Fuente del registro, extraída de `value->>'source'`. Valores observados: `workstation2_log`, `windows_event_log`, `workstation1_log`, `derived_context_pipeline`, `wsl_bash_history`, `manual entry`, `manual_workload_entry`. |
| `ts_contexto` | `TIMESTAMP WITH TIME ZONE` | — | NULL | — | — | — | — | — | Instante del evento. Columna temporal original **pendiente de confirmación**. |
| `valor` | `JSONB` | — | NN | — | — | — | — | `CHECK (jsonb_typeof(valor) = 'object')` | Contenido original del registro (campo `value`). |
| `contiene_datos_personales` | `BOOLEAN` | — | NN | `FALSE` | — | — | — | — | Marca los registros con posibles datos personales (principalmente `wsl_bash_history`, 204 filas). Soporta el análisis de la Ley 1581 de 2012. |
| `lote_id` | `INTEGER` | — | NN | — | — | → `calidad.lote_carga.lote_id` | — | — | Lote de carga (trazabilidad). |

**Distribución por fuente (datos reales):**

| Fuente (`$.source`) | Cantidad |
|---|---:|
| `workstation2_log` | 8.902 |
| `windows_event_log` | 6.271 |
| `workstation1_log` | 6.028 |
| `derived_context_pipeline` | 3.708 |
| `wsl_bash_history` | 204 |
| `manual entry` | 60 |
| `manual_workload_entry` | 5 |
| **Total** | **25.178** |

---

## 5. Esquema `staging`

### 5.1 `staging.staging_telemetria`

- **Propósito:** zona de aterrizaje de los datos crudos del SQLite. **No tiene dominios ni CHECK**, de modo que cualquier fila pueda entrar. Allí se clasifica cada fila (válida o inválida) *antes* de insertar en `solardb`; esa clasificación es la que decide el envío a cuarentena. PostgreSQL no envía filas rechazadas a cuarentena de forma automática.
- **Filas esperadas:** transitoria (hasta 2.989.759 durante la carga; puede vaciarse después).

| Nombre | Tipo | Nulabilidad | Descripción |
|---|---|---|---|
| `stg_id` | `BIGINT` (identidad), PK | NN | Llave subrogada temporal. |
| `lote_id` | `INTEGER`, FK → `calidad.lote_carga.lote_id` | NN | Lote al que pertenece. |
| `read_ts` | `DOUBLE PRECISION` | NULL | Timestamp Unix fraccionario original (s). |
| `inverter` | `SMALLINT` | NULL | ID original del inversor. |
| Las 30 variables físicas (`battvolt` … `fanduty`) | `DOUBLE PRECISION` | NULL | Mismos nombres que en `lectura_telemetria`, sin dominio, para conservar el valor original. |
| `estado_validacion` | `VARCHAR(12)`, `DEFAULT 'PENDIENTE'`, `CHECK (estado_validacion IN ('PENDIENTE','VALIDA','RECHAZADA'))` | NN | Resultado de la clasificación. |

---

## 6. Esquema `calidad`

### 6.1 `calidad.lote_carga`

- **Propósito:** registra cada ejecución de carga, para auditar cuántas filas se leyeron, aceptaron y rechazaron.
- **Filas esperadas:** una por cada ejecución de migración. **Estructura propuesta, pendiente de confirmación por el coordinador.**

| Nombre | Tipo | Nulabilidad | Default | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|---|:-:|---|:-:|---|---|
| `lote_id` | `INTEGER` (identidad) | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | — | Identificador del lote. |
| `tabla_origen` | `VARCHAR(40)` | NN | — | — | — | — | — | Tabla del SQLite de la que proviene (ej. `analog_measurements`, `context`). |
| `fecha_inicio` | `TIMESTAMP WITH TIME ZONE` | NN | `now()` | — | — | — | — | Inicio de la carga. |
| `fecha_fin` | `TIMESTAMP WITH TIME ZONE` | NULL | — | — | — | — | `CHECK (fecha_fin >= fecha_inicio)` | Fin de la carga. |
| `filas_leidas` | `BIGINT` | NN | `0` | — | — | — | `CHECK (filas_leidas >= 0)` | Filas leídas del origen. |
| `filas_aceptadas` | `BIGINT` | NN | `0` | — | — | — | `CHECK (filas_aceptadas >= 0)` | Filas insertadas en `solardb`. |
| `filas_rechazadas` | `BIGINT` | NN | `0` | — | — | — | `CHECK (filas_rechazadas >= 0)` | Filas enviadas a cuarentena. |
| `estado` | `VARCHAR(12)` | NN | `'EN_CURSO'` | — | — | — | `CHECK (estado IN ('EN_CURSO','COMPLETADO','FALLIDO'))` | Estado del lote. |

### 6.2 `calidad.regla_calidad`

- **Propósito:** catálogo de reglas de validación aplicadas en staging (nulos, rangos, P > S, sensor imposible).
- **Filas esperadas:** por definir. **Pendiente de confirmación por el coordinador.**

| Nombre | Tipo | Nulabilidad | PK | FK | UNIQUE | CHECK | Descripción |
|---|---|---|:-:|---|:-:|---|---|
| `regla_id` | `SMALLINT` (identidad) | NN | ✅ | — | — | — | Identificador de la regla. |
| `codigo_regla` | `VARCHAR(30)` | NN | — | — | ✅ | — | Código corto (ej. `R_P_MAYOR_S`). |
| `descripcion` | `TEXT` | NN | — | — | — | — | Qué valida la regla. |
| `variable_id` | `SMALLINT` | NULL | — | → `solardb.cat_variable_fisica.variable_id` | — | — | Variable afectada (NULL si involucra varias). |
| `severidad` | `VARCHAR(10)` | NN | — | — | — | `CHECK (severidad IN ('INFO','ADVERTENCIA','ERROR'))` | Gravedad. |
| `accion` | `VARCHAR(12)` | NN | — | — | — | `CHECK (accion IN ('CUARENTENA','ANULAR','ACEPTAR'))` | Acción al incumplirse. |
| `activa` | `BOOLEAN` | NN | — | — | — | — | Si la regla está vigente (`DEFAULT TRUE`). |

**Casos reales que justifican reglas (diagnóstico del coordinador):**

| Caso | Filas | Tratamiento propuesto |
|---|---:|---|
| Valores nulos por timeouts Modbus | ≈58.000–60.000 (~2 %) | Aceptar con `NULL` (dato faltante legítimo). |
| `temper1 = -20,3 °C` (error de sensor) | 38 | Cuarentena. |
| Potencia activa P mayor que aparente S (violación en CA) | 3.811 | Cuarentena. |
| Frecuencia = 0 Hz (modo isla) | 342.592 | Aceptar (condición legítima). |

### 6.3 `calidad.registro_cuarentena`

- **Propósito:** conserva las filas rechazadas por una regla, con su valor original, para revisarlas o reprocesarlas sin perder información.
- **Filas esperadas:** al menos 3.849 si se aplican las reglas de la tabla anterior (38 + 3.811), sin contar las demás reglas que se definan. **Pendiente de confirmación.**

| Nombre | Tipo | Nulabilidad | Default | PK | FK | CHECK | Descripción |
|---|---|---|---|:-:|---|---|---|
| `cuarentena_id` | `BIGINT` (identidad) | NN | `GENERATED ALWAYS AS IDENTITY` | ✅ | — | — | Identificador. |
| `lote_id` | `INTEGER` | NN | — | — | → `lote_carga.lote_id` | — | Lote en que ocurrió. |
| `regla_id` | `SMALLINT` | NN | — | — | → `regla_calidad.regla_id` | — | Regla incumplida. |
| `read_ts_original` | `DOUBLE PRECISION` | NULL | — | — | — | — | Timestamp Unix original (s). |
| `inversor_original` | `SMALLINT` | NULL | — | — | — | — | Inversor original. |
| `fila_original` | `JSONB` | NN | — | — | — | — | Copia completa de la fila rechazada. |
| `estado` | `VARCHAR(12)` | NN | `'PENDIENTE'` | — | — | `CHECK (estado IN ('PENDIENTE','CORREGIDO','DESCARTADO','REPROCESADO'))` | Estado de revisión. Se consulta con frecuencia (véase `09_diseno_fisico.md`). |
| `fecha_registro` | `TIMESTAMP WITH TIME ZONE` | NN | `now()` | — | — | — | Cuándo se envió a cuarentena. |
| `fecha_resolucion` | `TIMESTAMP WITH TIME ZONE` | NULL | — | — | — | `CHECK (fecha_resolucion >= fecha_registro)` | Cuándo se resolvió. |

---

## 7. Justificación técnica de los tipos de datos

### 7.1 `NUMERIC` frente a `DOUBLE PRECISION`

| Aspecto | `NUMERIC(p,s)` | `DOUBLE PRECISION` |
|---|---|---|
| Representación | Decimal exacto, precisión arbitraria | Punto flotante binario IEEE 754 de 64 bits |
| Exactitud | Sin error de redondeo binario | Algunos decimales (ej. 0,1) no son representables exactamente |
| Velocidad | Más lento (aritmética por software) | Más rápido (aritmética por hardware) |
| Espacio | Variable (aprox. 2 bytes por cada 4 dígitos, más encabezado) | 8 bytes fijos |

**Decisión en SolarDB:**

- **Telemetría instantánea → `DOUBLE PRECISION`.** El valor es una medición con incertidumbre propia del sensor; la resolución de los datos observados es de una décima (ej. 57,60 V, 54,00 A), por lo que un error del orden de 10⁻¹⁵ relativo es irrelevante. Además, el origen (`REAL` en SQLite) ya es un flotante de 8 bytes, de modo que la conversión **no pierde información**, y las agregaciones sobre casi 3 millones de filas son más rápidas.
- **Acumuladores de energía y datos nominales → `NUMERIC`.** Un acumulador suma millones de términos; el error de redondeo binario se acumula y los totales dejan de ser reproducibles. Con `NUMERIC` la suma es exacta. En el modelo actual esto aplica a las especificaciones de `dim_subsistema` (`capacidad_bateria_ah`, `voltaje_nominal_bateria_v`) y a cualquier tabla de energía acumulada que se incorpore a futuro (la tabla original `statistics` contiene contadores de energía histórica, pero está fuera del alcance actual).
- **Consultas de energía (kWh):** al integrar potencia en el tiempo, se recomienda convertir el resultado con `CAST(... AS NUMERIC(14,3))` al final del cálculo, para presentar totales estables.

### 7.2 `TIMESTAMP WITH TIME ZONE` frente a `TIMESTAMP WITHOUT TIME ZONE`

- Los datos originales son **timestamps Unix fraccionarios en UTC** (`read_ts`).
- `timestamptz` guarda internamente el instante en UTC y lo convierte a la zona horaria de la sesión del cliente al mostrarlo. Representa un **instante absoluto**.
- `timestamp` (sin zona) guarda el valor literal sin información de zona: el mismo valor puede significar instantes distintos según quién lo lea.
- **Decisión:** `timestamptz`. Los datos provienen de un sitio en Shenzhen (UTC+8) y se analizan desde Colombia (UTC-5); con `timestamptz` ambas consultas apuntan al mismo instante sin errores de interpretación, y los cálculos de diferencia de tiempo (esenciales para integrar potencia en energía con muestreo no uniforme) son correctos. La conversión se hace con `to_timestamp(read_ts)`, que devuelve `timestamptz` y conserva la parte fraccionaria.

### 7.3 `JSONB` frente a `JSON`

| Aspecto | `JSON` | `JSONB` |
|---|---|---|
| Almacenamiento | Texto tal cual (conserva espacios y orden de claves) | Representación binaria descompuesta |
| Consulta | Se reanaliza (parsea) en cada acceso | Ya está procesado: más rápido |
| Indexación | No admite índice GIN | Admite índice GIN |
| Operadores | Limitados | Contención `@>`, existencia `?`, `?&`, `?\|` |
| Escritura | Algo más rápida | Algo más lenta (convierte al insertar) |

**Decisión:** `JSONB` para `registro_contexto.valor` y `registro_cuarentena.fila_original`. El campo `value` de OpenCEM es semiestructurado y se filtra por contenido (ej. por `source`, que toma 7 valores distintos). Con `JSONB` se puede crear un índice GIN y usar `@>` para filtrar sin recorrer los 25.178 registros. La pérdida del orden original de las claves y de los espacios no afecta al análisis. El costo extra en escritura es despreciable en una carga por lotes.

### 7.4 `BIGINT` frente a `INTEGER`

| Tipo | Tamaño | Rango aproximado |
|---|---|---|
| `SMALLINT` | 2 bytes | ±32.767 |
| `INTEGER` | 4 bytes | ±2,1 × 10⁹ |
| `BIGINT` | 8 bytes | ±9,2 × 10¹⁸ |

- **Llaves subrogadas de hechos (`lectura_id`, `contexto_id`, `cuarentena_id`) → `BIGINT`.** Con 2.989.759 lecturas, `INTEGER` alcanzaría de sobra hoy (usa ~0,14 % de su rango). Se elige `BIGINT` por crecimiento: el muestreo es continuo (cada ~12,6 s por inversor) y la tabla sigue creciendo; migrar el tipo de una llave primaria con millones de filas más adelante es costoso. El sobrecosto es de 4 bytes por fila, es decir, unos 12 MB para 3 millones de filas (el índice de la PK también crece), un costo aceptable.
- **Contadores acumulativos de energía → `NUMERIC`** (no `BIGINT`), porque son magnitudes decimales (kWh); si se almacenaran en Wh como enteros, `BIGINT` sería suficiente.
- **Catálogos (`sitio_id`, `subsistema_id`, `inversor_id`, `variable_id`, `unidad_id`) → `SMALLINT`.** Tienen pocas filas (1, 2, 2, 30, 9) y reducen el tamaño de las llaves foráneas en la tabla de hechos.
- **`lote_id` → `INTEGER`:** el número de lotes es pequeño.

---

## 8. Resumen de detalles pendientes de confirmación por el coordinador

1. Formato ancho (una columna por variable) o formato largo para `lectura_telemetria`.
2. Valores definitivos de `zona_horaria`, y número y contenido de `cat_unidad_medida` y `cat_variable_fisica`.
3. Existencia de duplicados `(inversor, read_ts)` en el origen, para confirmar el `UNIQUE (inversor_id, ts_lectura)`.
4. Las 5 columnas reales de la tabla `context` y su mapeo a `registro_contexto`.
5. Definición final de las reglas de `calidad.regla_calidad` y de sus límites (en especial temperatura).
6. Si las tablas `status`, `totals`, `settings`, `specs`, `statistics` y `fault_history` se incorporan al modelo.
7. Estructura final de `lote_carga` y `registro_cuarentena`.
8. Cantidad final de filas migradas (el contexto del proyecto menciona «más de un millón de lecturas» para la demostración; el origen tiene 2.989.759).

---

## 9. Reglas de protección del repositorio

Este documento no contiene contraseñas, tokens ni cadenas de conexión. Los scripts DDL que se versionen en el repositorio deben respetar lo mismo (el detalle está en `docs/14_seguridad_y_privacidad.md`).
