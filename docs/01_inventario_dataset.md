# 01 — Inventario del Dataset OpenCEM v1.0.0

**Proyecto:** SolarDB — Integridad y calidad de datos en una microrred híbrida  
**Asignatura:** Bases de Datos I · Grupo 811 · Semestre 2026-II  
**Institución:** Institución Universitaria Pascual Bravo  
**Integrantes:** Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto  
**Docente:** Ramiro Grisales Montoya  
**Línea de profundización:** SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
**Fecha de inventario:** 2026-11-14  

---

## 1. Identificación y Verificación Criptográfica de la Fuente

El dataset oficial utilizado es **OpenCEM v1.0.0** (*Open In-Context Energy Management*), alojado en el repositorio abierto Zenodo bajo el DOI `10.5281/zenodo.21436223`.

### Verificación de Integridad SHA-256

Se calculó el hash criptográfico SHA-256 de los paquetes descargados y se contrastó contra el manifiesto oficial `opencem-v1.0.0-SHA256SUMS.txt`:

| Archivo | Tamaño Comprimido | Tamaño Descomprimido | SHA-256 Esperado (Zenodo) | SHA-256 Calculado Local | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `opencem-v1.0.0-support.zip` | 9.97 MB (9,972,654 B) | 22.4 MB | `5debdbebb82ed784e1c11ac70c81fe876400a049a001a8dc2230446e2f460439` | `5debdbebb82ed784e1c11ac70c81fe876400a049a001a8dc2230446e2f460439` | **COINCIDE (OK)** |
| `opencem-v1.0.0.sqlite.zst` | 288.07 MB (302,059,978 B) | 4.13 GB (4,439,408,640 B) | `8e38f98209029367a3775799ee9a7c0757cc7e8f2742e4df4eccc45dd4b27517` | `8e38f98209029367a3775799ee9a7c0757cc7e8f2742e4df4eccc45dd4b27517` | **COINCIDE (OK)** |

*Herramienta y método de descompresión:* Script en Python 3.11 utilizando la biblioteca `zstandard` (algoritmo Zstandard / Facebook RFC 8878) mediante `zstd.ZstdDecompressor().copy_stream()`, completado en 101.61 segundos.

---

## 2. Inventario General de Tablas en SQLite

La base de datos original contiene 8 tablas de datos de telemetría y contexto, sumando **15,568,277 filas** en total:

| Tabla SQLite | Esquema Original Postgres | Columnas | Filas Reales | Tamaño en Origen | Descripción del Contenido |
| :--- | :--- | :---: | :---: | :---: | :--- |
| `analog_measurements` | `measurement` | 44 | **2,989,759** | Principal | Telemetría analógica de alta frecuencia (voltajes, corrientes, potencias, frecuencias, SOC, temperaturas). |
| `status` | `measurement` | 20 | 2,240,052 | Secundario | Banderas y estados de operación del inversor, BMS, autochequeo y relés de contacto seco. |
| `totals` | `measurement` | 21 | 2,279,918 | Secundario | Potencias acumuladas trifásicas/bifásicas, demanda requerida por BMS y subtotales. |
| `settings` | `measurement` | 176 | 2,284,775 | Secundario | Parámetros de configuración del inversor y curvas de protección P-Q, U-P, LVRT, HVRT. |
| `specs` | `measurement` | 16 | 1,333,174 | Catálogo | Especificaciones de hardware, número de serie, versión de firmware y protocolo. |
| `statistics` | `measurement` | 31 | 2,285,904 | Resumen | Contadores de energía diaria, semanal e histórica (kWh) y tiempos de operación. |
| `fault_history` | `measurement` | 66 | 2,129,517 | Eventos | Registros históricos de fallas con marca de tiempo relativa y código de falla. |
| `context` | `public` | 5 | **25,178** | Contexto | Anotaciones humanas, calendarios académicos y registros de carga de trabajo en JSON. |

> [!IMPORTANT]
> **Definición de "Lectura" para el requisito del millón:**  
> En el dominio de microrredes, una **lectura de telemetría** corresponde a un vector instantáneo de mediciones físicas emitido por un inversor en un instante de tiempo $t$. En la tabla `analog_measurements`, cada fila representa exactamente una lectura física completa de un inversor.  
> Con **2,989,759 filas de telemetría analógica real**, el proyecto supera ampliamente el umbral exigido de 1,000,000 sin necesidad de sumar artificialmente variables ni registros de contexto.

---

## 3. Cobertura Temporal y Desglose por Inversor

El sistema físico opera dos subsistemas independientes en el campus universitario:
- **Inversor 1 (ID: 1):** Alimenta las estaciones de cómputo para investigación de alto rendimiento (GPU/CPU).
- **Inversor 2 (ID: 2):** Alimenta los sistemas de acondicionamiento de aire y climatización (HVAC).

| Subsistema / Inversor | Total Lecturas | Timestamp Inicial (UTC) | Timestamp Final (UTC) | Periodo Cubierto | Cadencia Mediana |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Inversor 1** (Cómputo / GPU) | 1,610,276 | 2025-07-12 13:31:35 | 2026-07-13 05:13:53 | 365 días (1 año completo) | 12.57 s |
| **Inversor 2** (Climatización / HVAC) | 1,379,483 | 2025-07-14 05:53:32 | 2026-06-22 05:35:24 | 343 días (~11 meses) | 12.60 s |
| **Total Telemetría** | **2,989,759** | **2025-07-12 13:31:35** | **2026-07-13 05:13:53** | **366 días** | **~12.58 s** |

---

## 4. Inventario de Variables Físicas y Unidades de Medida (`analog_measurements`)

A partir del diccionario oficial de columnas (`column_dictionary.json` y `column_dictionary.csv`) entregado por los autores en el paquete de soporte, se inventarían las 44 columnas de `analog_measurements`:

| Columna | Tipo SQLite | Tipo Físico | Unidad Oficial | Rango Observado [Mín, Máx] | Evidencia y Descripción Técnica |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `read_ts` | REAL | Timestamp | `s (Unix UTC)` | [1.7523e9, 1.7839e9] | Marca de tiempo fraccionaria Unix en UTC (muestreo Modbus). |
| `inverter` | INTEGER | Identificador | `adimensional` | [1, 2] | ID lógico del inversor híbrido (1 = Estaciones GPU, 2 = HVAC). |
| `battvolt` | REAL | Voltaje | $\text{V}$ | [0.0, 57.60] | Tensión en terminales del banco de baterías de litio (LiFePO4 51.2V nom.). |
| `battcurr` | REAL | Corriente | $\text{A}$ | [-66.30, 54.00] | Corriente de batería (+ carga / - descarga). |
| `battsoc` | INTEGER | Porcentaje | $\%$ | [6, 100] | Estado de carga relativo de la batería (*State of Charge*). |
| `battchgpower` | INTEGER | Potencia | $\text{W}$ | [-3400, 2800] | Potencia de carga/descarga calculada en el inversor. |
| `linechgcurr` | REAL | Corriente | $\text{A}$ | [0.0, 50.0] | Corriente tomada de la red de CA para cargar la batería. |
| `pvchgcurr` | REAL | Corriente | $\text{A}$ | [0.0, 60.0] | Corriente solar aportada para cargar la batería. |
| `pv1volt` | REAL | Voltaje | $\text{V}$ | [0.0, 492.60] | Tensión del arreglo fotovoltaico en MPPT 1 (26 paneles serie/paralelo). |
| `pv1curr` | REAL | Corriente | $\text{A}$ | [0.0, 10.60] | Corriente del arreglo fotovoltaico MPPT 1. |
| `pv1power` | INTEGER | Potencia | $\text{W}$ | [0, 3933] | Potencia activa generada por el arreglo solar 1. |
| `outvolta` | REAL | Voltaje | $\text{V}$ | [0.0, 245.80] | Tensión de salida de CA suministrada a las cargas (Fase A). |
| `outcurra` | REAL | Corriente | $\text{A}$ | [0.0, 26.80] | Corriente eficaz de salida suministrada a las cargas. |
| `outfreq` | REAL | Frecuencia | $\text{Hz}$ | [0.0, 50.10] | Frecuencia de la tensión de salida suministrada a la carga. |
| `invcurra` | REAL | Corriente | $\text{A}$ | [0.0, 28.50] | Corriente interna del puente inversor. |
| `outw_a` | INTEGER | Potencia Activa | $\text{W}$ | [0, 5502] | Potencia activa entregada a la carga en Fase A. |
| `outva_a` | INTEGER | Potencia Aparente | $\text{VA}$ | [0, 5630] | Potencia aparente entregada a la carga en Fase A. |
| `loadpercenta` | INTEGER | Porcentaje | $\%$ | [0, 110] | Porcentaje de carga relativo a la capacidad nominal del inversor (Fase A). |
| `normalloadw_a` | INTEGER | Potencia Activa | $\text{W}$ | [0, 5500] | Potencia activa en el puerto de cargas normales. |
| `outsumw` | INTEGER | Potencia Activa | $\text{W}$ | [0, 5502] | Potencia activa total entregada a la microrred. |
| `outsumva` | INTEGER | Potencia Aparente | $\text{VA}$ | [0, 5630] | Potencia aparente total entregada a la microrred. |
| `sumloadpercent`| INTEGER | Porcentaje | $\%$ | [0, 110] | Porcentaje total de carga sobre la capacidad nominal. |
| `linevolta` | REAL | Voltaje | $\text{V}$ | [0.0, 306.20] | Tensión de la red eléctrica pública (Fase A). Nominal 220V/230V CA. |
| `linecurra` | REAL | Corriente | $\text{A}$ | [0.0, 35.40] | Corriente tomada de la red eléctrica pública. |
| `linefreq` | REAL | Frecuencia | $\text{Hz}$ | [0.0, 50.07] | Frecuencia de la red eléctrica pública (Nominal 50.0 Hz). |
| `linepowerw_a` | INTEGER | Potencia Activa | $\text{W}$ | [-5500, 5500] | Potencia activa intercambiada con la red eléctrica pública. |
| `linepowerva_a`| INTEGER | Potencia Aparente | $\text{VA}$ | [0, 5600] | Potencia aparente intercambiada con la red eléctrica pública. |
| `gridpowerw_a` | INTEGER | Potencia Activa | $\text{W}$ | [-5500, 5500] | Potencia neta de red medida en el punto de acometida general. |
| `gridcurr_a` | REAL | Corriente | $\text{A}$ | [0.0, 35.40] | Corriente neta de red medida en acometida. |
| `busvoltp` | REAL | Voltaje | $\text{V}$ | [0.0, 480.00] | Tensión del bus de continua positivo ($V_{\text{BUS+}}$). |
| `busvoltn` | REAL | Voltaje | $\text{V}$ | [0.0, 480.00] | Tensión del bus de continua negativo ($V_{\text{BUS-}}$). |
| `temper1` | REAL | Temperatura | $^\circ\text{C}$ | [-20.30, 49.30] | Temperatura sensor 1 (Módulo / Disipador de calor del inversor). |
| `temper2` | REAL | Temperatura | $^\circ\text{C}$ | [0.0, 58.00] | Temperatura sensor 2 (Transformador interno / Chasis). |
| `temper3` | REAL | Temperatura | $^\circ\text{C}$ | Canal inactivo | Sensor auxiliar de temperatura 3. |
| `temper4` | REAL | Temperatura | $^\circ\text{C}$ | Canal inactivo | Sensor auxiliar de temperatura 4. |
| `sir` | INTEGER | Resistencia Aisl. | $\text{k}\Omega$ | [0, 9999] | Resistencia de aislamiento (*Solar Insulation Resistance*). |
| `fanduty` | INTEGER | Porcentaje | $\%$ | [0, 100] | Ciclo de trabajo del ventilador de refrigeración PWM. |
| `battreserve` | TEXT | Cadena cruda | `texto` | NULL / JSON | Registros de reserva de registros Modbus de batería. |
| `pvreserve` | TEXT | Cadena cruda | `texto` | NULL / JSON | Registros de reserva de registros Modbus solares. |
| `otherreserve` | TEXT | Cadena cruda | `texto` | NULL / JSON | Registros de reserva varios. |
| `grid_reserve` | TEXT | Cadena cruda | `texto` | NULL / JSON | Registros de reserva de red. |

---

## 5. Inventario de Registros de Contexto (`context`)

La tabla `context` contiene **25,178 registros semiestructurados** diseñados para relacionar la telemetría eléctrica con actividades humanas, cargas de cómputo y condiciones ambientales.

| Columna | Tipo SQLite | Nulabilidad | Descripción Técnica |
| :--- | :--- | :---: | :--- |
| `id` | INTEGER | NOT NULL (PK) | Identificador entero autoincremental del evento de contexto. |
| `recorded` | INTEGER | NULL | Timestamp Unix (segundos) en que se persistió el registro de contexto. |
| `start` | INTEGER | NULL | Timestamp Unix (segundos) en que inicia la ventana de validez del evento. |
| `end` | INTEGER | NULL | Timestamp Unix (segundos) en que expira la ventana de validez del evento. |
| `value` | TEXT (JSON) | NULL | Carga útil en formato JSON con la descripción textual y el origen. |

### Distribución por Familia de Origen (`source`) en el JSON

Analizado mediante `json_extract(value, '$.source')`:

| Fuente (`source`) | Cantidad Filas | Porcentaje | Descripción del Contenido |
| :--- | :---: | :---: | :--- |
| `workstation2_log` | 8,902 | 35.36% | Logs de ejecución de tareas de cómputo y uso de GPU/CPU en estación 2. |
| `windows_event_log` | 6,271 | 24.91% | Eventos del visor de sucesos del sistema operativo (encendido, reinicio, servicios). |
| `workstation1_log` | 6,028 | 23.94% | Logs de tareas de investigación y procesamiento numérico en estación 1. |
| `derived_context_pipeline`| 3,708 | 14.73% | Eventos climáticos y solares derivados (salida del sol, cenit, puesta de sol). |
| `wsl_bash_history` | 204 | 0.81% | Historial de comandos en terminal Linux WSL ejecutados por investigadores. |
| `manual entry` | 60 | 0.24% | Entradas de calendario institucional (festivos, periodos de exámenes, vacaciones). |
| `manual_workload_entry` | 5 | 0.02% | Anotaciones explícitas de pruebas de carga programadas. |
| **Total** | **25,178** | **100.00%** | |

---

## 6. Conclusiones del Inventario

1. **Volumen de Telemetría:** El dataset posee casi 3 millones de instantes analógicos reales ($2,989,759$), lo que permite no solo cumplir la meta del millón de lecturas con holgura sino evaluar particionamiento, índices y migraciones masivas reales.
2. **Homogeneidad de Muestreo:** La cadencia nominal es de aproximadamente 12.6 segundos entre capturas Modbus sucesivas en ambos inversores, con el 95% de las lecturas dentro de 60 segundos.
3. **Multi-tabla con Redundancia Severa:** La fuente almacena especificaciones de fábrica (`specs`) y configuraciones estáticas (`settings`) repitiendo filas por cada lectura temporal, lo que exige una normalización rigurosa hacia 3FN.
4. **Unidades de Medida Claras:** Todas las unidades físicas han sido documentadas y verificadas contra el `column_dictionary.json` oficial de OpenCEM, garantizando que no se asuman rangos ni unidades arbitrarias.
