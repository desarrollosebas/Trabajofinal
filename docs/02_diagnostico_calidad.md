# 02 — Diagnóstico de Diseño y Calidad de Datos

**Proyecto:** SolarDB — Integridad y calidad de datos en una microrred híbrida  
**Asignatura:** Bases de Datos I · Grupo 811 · Semestre 2026-II  
**Institución:** Institución Universitaria Pascual Bravo  
**Integrantes:** Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto  
**Docente:** Ramiro Grisales Montoya  
**Línea de profundización:** SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
**Fecha de diagnóstico:** 2026-11-14  

---

## 1. Resumen Ejecutivo del Diagnóstico

El análisis integral del dataset oficial **OpenCEM v1.0.0** sobre su base original SQLite (4.13 GB descomprimida, 15.5+ millones de registros) revela que, si bien el dataset es una fuente invaluable de telemetría real, presenta deficiencias estructurales graves tanto en su **diseño relacional** como en la **calidad intrínseca de los datos**.

La estructura original fue concebida para almacenamiento plano o científico (series de tiempo crudas) y **no cumple con los estándares de una base de datos relacional operativa ni como Fuente Única de Verdad (*Single Source of Truth*)**.

---

## 2. Diagnóstico de Problemas de Diseño Relacional

### 2.1. Violación Severa de Formas Normales (Redundancia Extrema)

| Tabla Afectada | Filas en Origen | Columnas Estáticas Repetidas | Anomalía de Diseño Identificada |
| :--- | :---: | :---: | :--- |
| `specs` | 1,333,174 | `machcode`, `manufacturename`, `sourcesn`, `hwver_m1`, `protocolver`, `bmsver` | **Violación de 2FN y 3FN:** Atributos estáticos de hardware y firmware se repiten 1.33 millones de veces por cada instante temporal `read_ts`. No existe catálogo de inversores. |
| `settings` | 2,284,775 | 176 columnas de parámetros de protección y consignas | **Redundancia masiva:** Parámetros fijos (ej. contraseñas de usuario, voltajes de corte, banderas de control) se registran cada 12 segundos sin haber cambiado. |
| `statistics` | 2,285,904 | 31 columnas acumulativas (`*total`, `*last7day`) | Mezcla de contadores acumulativos de largo plazo con lecturas instantáneas de alta frecuencia. |
| `analog_measurements` | 2,989,759 | 44 columnas físicas en una sola fila plana | **Modelo plano desnormalizado:** Mezcla en la misma tupla variables solares (PV), electroquímicas (Batería), de red eléctrica (Grid), de salida a cargas (Load) y térmicas. |

*Consecuencias:*
- Desperdicio masivo de almacenamiento en disco (~70% del tamaño de la base son datos estáticos duplicados).
- Riesgo de anomalías de modificación e inserción: si un inversor actualiza su versión de firmware o consigna, no hay una tupla única donde registrarlo, sino millones de registros históricos inconsistentes.

### 2.2. Inadecuación y Fragilidad de Tipos de Datos

1. **Marcas de tiempo como punto flotante (`read_ts REAL`):**
   - SQLite almacena `read_ts` como segundos Unix fraccionarios en formato IEEE 754 de doble precisión (`REAL`).
   - *Consecuencia:* Pérdida de precisión temporal por redondeo de coma flotante, incapacidad de indexación btree determinista exacta, ausencia de noción de zona horaria nativa y dificultad para realizar operaciones de agregación temporal (`date_trunc`, intervalos). Debe migrarse a `TIMESTAMP WITH TIME ZONE` (`timestamptz`).
2. **Columnas de "Reserva" crudas no tipadas:**
   - Columnas como `battreserve`, `pvreserve`, `otherreserve`, `grid_reserve` existen como texto crudo o valores residuales no parseados de tramas Modbus.
3. **Carga útil de contexto como texto plano (`value TEXT`):**
   - En la tabla `context`, el JSON se almacena como texto genérico sin validación de esquema, lo que impide indexar propiedades internas o garantizar restricciones de integridad.

### 2.3. Ausencia de Catálogos e Integridad Referencial

- El campo `inverter` es un simple entero (`1` o `2`) sin clave foránea (`FOREIGN KEY`) a una tabla de catálogo que describa la potencia nominal, fabricante, subsistema al que abastece o ubicación física.
- No existen catálogos de variables físicas, unidades de medida, tipos de fuentes de contexto ni estados operativos.

---

## 3. Diagnóstico de Problemas de Calidad de Datos (Con Conteos Reales)

El análisis empírico realizado mediante scripts directos sobre SQLite arrojó los siguientes hallazgos cuantitativos:

### 3.1. Incompletitud y Valores Nulos (Tasa ~2%)

En `analog_measurements`, existen aproximadamente **58,000 a 60,000 registros con valores nulos** en variables críticas:

| Variable | Registros Nulos | Porcentaje sobre Total (2,989,759) | Impacto en el Negocio |
| :--- | :---: | :---: | :--- |
| `outvolta` (Voltaje de salida CA) | 59,953 | 2.01% | Imposibilita el cálculo de calidad de energía entregada a cargas. |
| `pv1volt` (Voltaje arreglo solar) | 59,379 | 1.99% | Distorsiona el cálculo de potencia fotovoltaica generada. |
| `gridpowerw_a` (Potencia de red) | 58,968 | 1.97% | Afecta el balance neto de energía importada/exportada. |
| `outfreq` (Frecuencia de salida) | 58,841 | 1.97% | Impide auditar la estabilidad de la microrred. |
| `pv1power` (Potencia arreglo solar) | 58,660 | 1.96% | Subestima la generación solar en integraciones diarias. |
| `temper1` / `temper2` (Temperaturas) | 58,299 | 1.95% | Afecta el monitoreo térmico preventivo de los inversores. |
| `battcurr` / `battvolt` (Batería) | 58,217 | 1.95% | Rompe el seguimiento del estado electroquímico de las celdas. |

*Causa física:* Pérdida transitoria de comunicación Modbus/RS485 o ciclos de polling donde ciertos registros del mapa de memoria del inversor respondieron con timeout o CRC error.

### 3.2. Anomalías Físicas e Imposibilidades Eléctricas

#### A. Falla de Sensor Térmico (Glitch Imposible)
- **38 filas con `temper1 = -20.30 °C`** registradas en el inversor.
- *Justificación física:* El campus universitario está situado en Shenzhen, China (clima subtropical húmedo), donde la temperatura ambiente jamás desciende por debajo de 0 °C, y mucho menos a -20.3 °C dentro del chasis de un inversor en funcionamiento. Se trata de un código de error de circuito abierto o valor centinela del termopar/termistor.

#### B. Violación de la Ley de Potencia en Corriente Alterna ($P > S$)
- En circuitos de CA, la potencia activa ($P$, Watts) y la potencia aparente ($S$, Volt-Amperes) están relacionadas por el factor de potencia:
  $$\text{PF} = \frac{P}{S} \le 1.0 \implies P \le S$$
- En el dataset original se detectaron:
  - **3,574 registros en Inversor 1** donde $P_{\text{activa}} > S_{\text{aparente}} + 50\text{ VA}$.
  - **237 registros en Inversor 2** donde $P_{\text{activa}} > S_{\text{aparente}} + 50\text{ VA}$.
- *Causa física:* Desincronización en la lectura secuencial de registros Modbus entre el registro de potencia activa y el de aparente, o error de redondeo interno del DSP del inversor.

#### C. Frecuencia y Tensión en Cero por Operación en Isla / Desconexión
- **342,592 filas con `linefreq = 0.0 Hz`** y `linevolta = 0.0 V`.
- **149,624 filas con `outfreq = 0.0 Hz`**.
- *Interpretación de negocio:* No debe tratarse como un error corrupto ciego, sino como un **estado operacional legítimo**: la microrred entró en modo isla (desconectada de la red pública) o el inversor estuvo en modo reposo/espera. Esto demuestra la necesidad de una clasificación diferencial de errores en SolarDB.

### 3.3. Discontinuidades Temporales y Pérdida de Muestreo

El análisis de cobertura temporal (`analog_cadence`) de los autores y nuestras consultas revela:
- **Gaps > 10 minutos:** 117 eventos en Inversor 1, 40 eventos en Inversor 2.
- **Gaps > 1 hora:** 16 eventos en Inversor 1, 15 eventos en Inversor 2.
- **Gaps > 1 día:** 3 ventanas prolongadas de desconexión por mantenimiento institucional.
- *Consecuencia:* El cálculo de energía acumulada mediante la regla del trapecio o integración simple ($\int P \, dt$) requiere imputación consciente o partición temporal, ya que asumir un paso de tiempo constante de 12 segundos sobreestimaría la energía durante un apagón.

### 3.4. Registros de Contexto y Manejo de Privacidad (Ley 1581 de 2012)

La tabla `context` contiene **204 registros de tipo `wsl_bash_history`** y **6,271 registros de `windows_event_log`**.
- Estos registros contienen rutas de carpetas de usuarios (`/home/username/...`), nombres de scripts, comandos ejecutados por investigadores y parámetros de red.
- Conforme a la **Ley 1581 de 2012 (Protección de Datos Personales de Colombia)**, estos datos pueden contener información sensible o identificadores personales directos de los operadores. La arquitectura de SolarDB debe contemplar políticas de anonimización, control de acceso y separación de esquemas para estos registros.

---

## 4. Matriz de Síntesis de Calidad y Acciones de SolarDB

| Categoría | Problema Identificado | Cantidad Afectada | Causa Raíz | Acción en SolarDB |
| :--- | :--- | :---: | :--- | :--- |
| **Integridad** | Valores de temperatura físicamente absurdos ($-20.3^\circ\text{C}$) | 38 filas | Error de sensor / termistor abierto | **Rechazo a tabla de cuarentena** por violación de dominio térmico. |
| **Consistencia** | Inconsistencia de potencia CA ($P > S$) | 3,811 filas | Lectura asíncrona de registros Modbus | **Marcado como sospechoso** con advertencia en cuarentena/auditoría. |
| **Completitud** | Campos eléctricos nulos (`NULL`) | ~59,000 filas | Timeout de comunicación Modbus | **Clasificación como registro incompleto**; conservación para auditoría. |
| **Normalización**| Redundancia de catálogos en `specs` y `settings` | 3.6+ millones | Arquitectura plana de log | **Descomposición a 3FN** en tablas de catálogo `dim_inversor`, `parametro`. |
| **Precisión** | Timestamps Unix `REAL` | 2,989,759 filas | Almacenamiento float | **Conversión determinista a `timestamptz`**. |
| **Privacidad** | Comandos de consola y rutas en logs de contexto | 204 filas bash | Captura automatizada de telemetría OS | **Cifrado/anonimización y restricción de acceso** bajo Ley 1581. |

---

*Diagnóstico elaborado con base en la ejecución empírica de consultas sobre la base SQLite de OpenCEM v1.0.0.*
