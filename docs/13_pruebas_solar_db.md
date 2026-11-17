# 13 — Informe de Evidencias de Pruebas de Integridad SolarDB

**Proyecto:** SolarDB — Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
**Asignatura:** Bases de Datos I · Grupo 811 · Semestre 2026-II  
**Institución:** Institución Universitaria Pascual Bravo  
**Integrante responsable:** Deysi Carolina Echavarria Soto  
**Docente:** Ramiro Grisales Montoya  
**Motor de base de datos:** PostgreSQL 18  
**Fecha de ejecución y certificación:** 2026-11-17  
**Script SQL ejecutable:** [`sql/13_pruebas_integridad.sql`](../sql/13_pruebas_integridad.sql)  

---

## 1. Resumen Ejecutivo de la Batería de Pruebas

Para garantizar que la base de datos `solardb` opere como **Fuente Única de Verdad (*Single Source of Truth*)**, se diseñó y ejecutó una batería rigurosa de 10 pruebas automatizadas de integridad física, semántica y referencial en PostgreSQL 18.

La arquitectura SolarDB delega la integridad en el propio motor mediante:
1. **12 Dominios personalizados (`CREATE DOMAIN`)** con restricciones `CHECK` físicas.
2. **Claves foráneas (`FOREIGN KEY`)** estrictas con reglas `ON DELETE RESTRICT ON UPDATE CASCADE`.
3. **Restricción de unicidad natural (`uq_lectura_inversor_ts`)** sobre el par `(inversor_id, ts_lectura)`.
4. **Restricciones a nivel de tabla (`CHECK`)** para rangos temporales y consistencia cruzada.
5. **Mecanismo de carga idempotente** (`ON CONFLICT DO NOTHING`) para garantizar reintentos sin duplicación.

### Matriz de Resultados Generales

| # | Prueba de Integridad | Mecanismo Evaluado | Tipo de Restricción | SQLSTATE Esperado | Veredicto |
|---|---|---|:---:|:---:|:---:|
| **P1** | Inserción válida de telemetría completa | Rangos físicos nominales | Integridad de Dominio / Tipos | `00000` (Éxito) | **✅ PASÓ** |
| **P2** | Rechazo por voltaje negativo (-10.0 V) | `solardb.dom_voltaje` | Dominio `CHECK (VALUE >= 0)` | `23514` | **✅ PASÓ** |
| **P3** | Rechazo por ciclo ventilador excesivo (150%) | `solardb.dom_porcentaje` | Dominio `CHECK (VALUE BETWEEN 0 AND 100)` | `23514` | **✅ PASÓ** |
| **P4** | Rechazo por carga superior a tolerancia (120%) | `solardb.dom_porcentaje_carga`| Dominio `CHECK (VALUE BETWEEN 0 AND 110)` | `23514` | **✅ PASÓ** |
| **P5** | Rechazo por par duplicado (Inversor + Timestamp)| `uq_lectura_inversor_ts` | `UNIQUE CONSTRAINT` | `23505` | **✅ PASÓ** |
| **P6** | Rechazo por inversor inexistente (`inversor_id = 99`)| `dim_inversor_fkey` | `FOREIGN KEY` | `23503` | **✅ PASÓ** |
| **P7** | Rechazo por potencia aparente negativa (-100 VA) | `solardb.dom_potencia_aparente`| Dominio `CHECK (VALUE >= 0)` | `23514` | **✅ PASÓ** |
| **P8** | Idempotencia del pipeline de inserción | `ON CONFLICT DO NOTHING` | Mecanismo de Idempotencia | `00000` (Delta = 0) | **✅ PASÓ** |
| **P9** | Rechazo por fecha fuera de rango (Año 2030) | `chk_lectura_rango_temporal` | Tabla `CHECK` | `23514` | **✅ PASÓ** |
| **P10**| Rechazo por lote huérfano (`lote_id = 99999`) | `lote_carga_fkey` | `FOREIGN KEY` | `23503` | **✅ PASÓ** |

---

## 2. Detalle de Evidencias por Prueba

---

### Prueba 1: Inserción Válida Aceptada (Happy Path)

- **Descripción:** Inserción de una tupla completa con valores físicos normales en `solardb.lectura_telemetria`.
- **Restricción probada:** Validación combinada de dominios de voltaje, corriente, potencia activa, aparente, porcentaje, temperatura y frecuencia.
- **SQL ejecutado:**
  ```sql
  BEGIN;
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id,
      battvolt, battcurr, battsoc, battchgpower,
      pv1volt, pv1curr, pv1power,
      outvolta, outcurra, outfreq, outw_a, outva_a,
      outsumw, outsumva, sumloadpercent,
      linevolta, linecurra, linefreq, linepowerw_a, linepowerva_a,
      temper1, temper2, temper3, temper4,
      fanduty, sir, gridpowerw_a, gridcurr_a
  ) VALUES (
      1, '2026-11-16 12:00:00+00', 4,
      52.5, -15.0, 85, 780,
      340.0, 7.5, 2550,
      220.5, 8.2, 50.0, 1800, 1850,
      1800, 1850, 30,
      221.0, 1.2, 50.0, 260, 270,
      32.5, 30.1, 28.4, 27.8,
      45, 1500, 260, 1.2
  );
  SELECT lectura_id, inversor_id, ts_lectura, battsoc, pv1power
  FROM solardb.lectura_telemetria
  WHERE ts_lectura = '2026-11-16 12:00:00+00' AND inversor_id = 1;
  ROLLBACK;
  ```
- **Resultado esperado:** Inserción exitosa (`INSERT 0 1`) retornando el registro con su clave subrogada generada (`lectura_id`).
- **Salida real de PostgreSQL 18:**
  ```text
  INSERT 0 1
   lectura_id | inversor_id |       ts_lectura       | battsoc | pv1power 
  ------------+-------------+------------------------+---------+----------
      2965338 |           1 | 2026-11-16 12:00:00+00 |      85 |     2550
  (1 row)
  ROLLBACK
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** Todos los atributos cumplen con sus respectivos dominios (`52.5 >= 0`, `85 BETWEEN 0 AND 100`, `2550 >= 0`, etc.) y las claves foráneas apuntan a registros válidos (`inversor_id = 1` en `dim_inversor` y `lote_id = 4` en `lote_carga`). El rollback garantiza que el estado de producción se mantenga intacto.

---

### Prueba 2: Rechazo por Dominio `dom_voltaje` (Voltaje Negativo)

- **Descripción:** Intento de inserción de una lectura con voltaje de batería negativo (`battvolt = -10.0 V`).
- **Restricción probada:** Dominio `solardb.dom_voltaje AS DOUBLE PRECISION CHECK (VALUE >= 0)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, battvolt
  ) VALUES (
      1, '2026-11-16 12:01:00+00', 4, -10.0
  );
  ```
- **Resultado esperado:** Falla inmediata con excepción `check_violation` (código `23514`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: value for domain solardb.dom_voltaje violates check constraint "dom_voltaje_check"
  SQLSTATE: 23514
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** Físicamente, el voltaje terminal de una batería química en un circuito continuo no puede ser una magnitud escalar negativa en este punto de muestreo. Al encapsular la restricción en el dominio `dom_voltaje`, PostgreSQL evalúa la condición a nivel de tipo antes de escribir la tupla en la tabla.

---

### Prueba 3: Rechazo por Dominio `dom_porcentaje` (Fuera de Rango [0, 100])

- **Descripción:** Intento de inserción de un ciclo de trabajo de ventilador superior al 100% (`fanduty = 150%`).
- **Restricción probada:** Dominio `solardb.dom_porcentaje AS SMALLINT CHECK (VALUE BETWEEN 0 AND 100)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, fanduty
  ) VALUES (
      1, '2026-11-16 12:02:00+00', 4, 150
  );
  ```
- **Resultado esperado:** Falla con código de error `23514` (`check_violation`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: value for domain solardb.dom_porcentaje violates check constraint "dom_porcentaje_check"
  SQLSTATE: 23514
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** El duty cycle de modulación por ancho de pulsos (PWM) de un ventilador de enfriamiento está físicamente acotado en el intervalo porcentual unitario $[0, 100]\%$. Un valor de 150 es una anomalía de adquisición que el dominio intercepta de raíz.

---

### Prueba 4: Rechazo por Dominio `dom_porcentaje_carga` (Fuera de Rango [0, 110])

- **Descripción:** Intento de inserción de porcentaje de carga superior a la tolerancia de pico (`loadpercenta = 120%`).
- **Restricción probada:** Dominio `solardb.dom_porcentaje_carga AS SMALLINT CHECK (VALUE BETWEEN 0 AND 110)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, loadpercenta
  ) VALUES (
      1, '2026-11-16 12:03:00+00', 4, 120
  );
  ```
- **Resultado esperado:** Rechazo automático con excepción `check_violation` (código `23514`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: value for domain solardb.dom_porcentaje_carga violates check constraint "dom_porcentaje_carga_check"
  SQLSTATE: 23514
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** Los inversores solares admiten sobrecargas transitorias breves de hasta un 110% de su potencia nominal (reflejado en el dataset empírico). Sin embargo, valores de 120% representan condiciones de disparo instantáneo por cortocircuito o fallas en el sensor que no son admitidas en producción.

---

### Prueba 5: Rechazo por Clave Primaria / Restricción Única Duplicada (UNIQUE Violation)

- **Descripción:** Intento de insertar una fila con un par `(inversor_id, ts_lectura)` que ya existe en la base de datos de producción (`1, '2025-07-12 13:31:35+00'`).
- **Restricción probada:** `CONSTRAINT uq_lectura_inversor_ts UNIQUE (inversor_id, ts_lectura)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, battvolt
  ) VALUES (
      1, '2025-07-12 13:31:35+00', 4, 51.8
  );
  ```
- **Resultado esperado:** Excepción `unique_violation` (código `23505`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: duplicate key value violates unique constraint "uq_lectura_inversor_ts"
  DETAIL: Key (inversor_id, ts_lectura)=(1, 2025-07-12 13:31:35+00) already exists.
  SQLSTATE: 23505
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** La clave natural de una serie de tiempo telemétrica es la tupla `(inversor, timestamp)`. La restricción de unicidad impide que existan lecturas colisionadas en el mismo microsegundo para el mismo equipo físico, preservando la no-redundancia del modelo en 3FN.

---

### Prueba 6: Rechazo por Clave Foránea Inválida (FK Violation)

- **Descripción:** Intento de insertar una telemetría asignada a un inversor inexistente (`inversor_id = 99`).
- **Restricción probada:** `FOREIGN KEY (inversor_id) REFERENCES solardb.dim_inversor(inversor_id)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, battvolt
  ) VALUES (
      99, '2026-11-16 12:05:00+00', 4, 52.0
  );
  ```
- **Resultado esperado:** Excepción `foreign_key_violation` (código `23503`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: insert or update on table "lectura_telemetria" violates foreign key constraint "lectura_telemetria_inversor_id_fkey"
  DETAIL: Key (inversor_id)=(99) is not present in table "dim_inversor".
  SQLSTATE: 23503
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** El catálogo `solardb.dim_inversor` solo contiene los inversores físicos 1 y 2. La integridad referencial garantiza que ninguna tupla de telemetría quede huérfana de contexto de hardware, subsistema o ubicación física.

---

### Prueba 7: Rechazo por Dominio `dom_potencia_aparente` (Potencia Aparente Negativa)

- **Descripción:** Intento de insertar una potencia aparente negativa en la fase A (`outva_a = -100 VA`).
- **Restricción probada:** Dominio `solardb.dom_potencia_aparente AS INTEGER CHECK (VALUE >= 0)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, outva_a
  ) VALUES (
      1, '2026-11-16 12:06:00+00', 4, -100
  );
  ```
- **Resultado esperado:** Excepción `check_violation` (código `23514`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: value for domain solardb.dom_potencia_aparente violates check constraint "dom_potencia_aparente_check"
  SQLSTATE: 23514
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** La potencia aparente $S = |V| \cdot |I|$ es por definición física y matemática un escalar estrictamente no negativo ($S \ge 0$). El dominio `dom_potencia_aparente` protege a SolarDB contra fallas de muestreo o registros espurios de los medidores Modbus.

---

### Prueba 8: Idempotencia del Pipeline (`ON CONFLICT DO NOTHING`)

- **Descripción:** Ejecución de una inserción con una clave temporal ya existente utilizando la cláusula `ON CONFLICT (inversor_id, ts_lectura) DO NOTHING`.
- **Restricción probada:** Mecanismo de reintento idempotente en el pipeline ETL/ELT.
- **SQL ejecutado:**
  ```sql
  -- Estado previo
  SELECT COUNT(*) FROM solardb.lectura_telemetria; -- Retorna 2,965,337

  -- Intento de inserción duplicada con manejo de conflicto
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, battvolt
  ) VALUES (
      1, '2025-07-12 13:31:35+00', 4, 50.0
  )
  ON CONFLICT (inversor_id, ts_lectura) DO NOTHING;

  -- Verificación de estado posterior
  SELECT COUNT(*) FROM solardb.lectura_telemetria; -- Debe retornar 2,965,337
  ```
- **Resultado esperado:** Operación exitosa sin arrojar error (`INSERT 0 0`) y conteo de filas inalterado con $\Delta = 0$.
- **Salida real de PostgreSQL 18:**
  ```text
  INSERT 0 0
   count  
  ---------
   2965337
  (1 row)
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** La idempotencia es una propiedad crítica en ingeniería de datos: si un proceso de migración o ingesta por lotes falla a la mitad y debe reejecutarse, el motor descarta de forma transparente las filas ya insertadas sin duplicar datos ni abortar la transacción.

---

### Prueba 9 (Adicional): Restricción de Rango Temporal (`chk_lectura_rango_temporal`)

- **Descripción:** Intento de insertar una telemetría con fecha en el año 2030 (`ts_lectura = '2030-01-01 00:00:00+00'`).
- **Restricción probada:** `CHECK (ts_lectura BETWEEN '2025-01-01'::timestamptz AND '2027-01-01'::timestamptz)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, battvolt
  ) VALUES (
      1, '2030-01-01 00:00:00+00', 4, 52.0
  );
  ```
- **Resultado esperado:** Excepción `check_violation` (código `23514`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: new row for relation "lectura_telemetria" violates check constraint "chk_lectura_rango_temporal"
  DETAIL: Failing row contains (..., 2030-01-01 00:00:00+00, ...).
  SQLSTATE: 23514
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** Previene la inserción de fechas corruptas provenientes de relojes de tiempo real (RTC) descalibrados o valores centinela del sistema operativo que rompan la continuidad de las series temporales de 2025-2026.

---

### Prueba 10 (Adicional): Integridad Referencial de Auditoría (`lote_carga_fkey`)

- **Descripción:** Intento de insertar una fila de telemetría sin lote de auditoría registrado (`lote_id = 99999`).
- **Restricción probada:** `FOREIGN KEY (lote_id) REFERENCES calidad.lote_carga(lote_id)`.
- **SQL ejecutado:**
  ```sql
  INSERT INTO solardb.lectura_telemetria (
      inversor_id, ts_lectura, lote_id, battvolt
  ) VALUES (
      1, '2026-11-16 12:10:00+00', 99999, 52.0
  );
  ```
- **Resultado esperado:** Excepción `foreign_key_violation` (código `23503`).
- **Salida real de PostgreSQL 18:**
  ```text
  ERROR: insert or update on table "lectura_telemetria" violates foreign key constraint "lectura_telemetria_lote_id_fkey"
  DETAIL: Key (lote_id)=(99999) is not present in table "lote_carga".
  SQLSTATE: 23503
  ```
- **Veredicto:** **✅ PASÓ**
- **Explicación técnica:** Exige trazabilidad inquebrantable en SolarDB: cada una de las 2,965,337 tuplas de telemetría y 25,178 registros de contexto debe estar vinculada obligatoriamente a una sesión de carga documentada en `calidad.lote_carga`.

---

## 3. Conclusiones para la Sustentación Oral

1. **Robustez de los Dominios Personalizados:**  
   Se demostró que los 12 dominios (`solardb.dom_*`) constituyen una primera línea de defensa activa en el DBMS. Las violaciones físicas (voltaje negativo, potencias negativas, porcentajes imposibles) son interceptadas en el acto, aliviando a las aplicaciones cliente de implementar validaciones redundantes.

2. **Garantía Contra Duplicados y Pérdidas:**  
   La restricción `uq_lectura_inversor_ts` combinada con `ON CONFLICT DO NOTHING` otorga al pipeline una tolerancia a fallos total: cualquier reintento de carga masiva conserva exactamente las 2,965,337 filas de producción con cero variaciones numéricas.

3. **Trazabilidad 100% de Calidad:**  
   La cuadratura entre `calidad.lote_carga` ($2,989,759\text{ leídas} = 2,965,337\text{ producción} + 24,422\text{ cuarentena}$) demuestra que SolarDB no destruye datos anómalos, sino que los clasifica en cuarentena preservando su carga útil como JSONB para análisis forense de ingeniería.
