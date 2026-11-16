# 12 — Documentación de Consultas de Negocio, Vistas e Índices

**Proyecto:** SolarDB — Integridad y calidad de datos en una microrred híbrida  
**Asignatura:** Bases de Datos I · Grupo 811 · Semestre 2026-II  
**Institución:** Institución Universitaria Pascual Bravo  
**Integrante responsable:** Deysi Carolina Echavarria Soto  
**Docente:** Ramiro Grisales Montoya  
**Fecha:** 2026-11-14  

---

## 1. Resumen de Entregables

| Tipo | Cantidad | Requisito Mínimo | Estado |
|------|----------|-------------------|--------|
| Consultas de negocio | 10 | 10 | ✅ Cumplido |
| Consultas obligatorias | 6 | 6 | ✅ Cumplido |
| Consultas propuestas SolarDB | 4 | 4 | ✅ Cumplido |
| Vistas SQL | 2 | 2 | ✅ Cumplido |
| Índices justificados | 3 | 3 | ✅ Cumplido |

**Archivo SQL:** [`sql/12_consultas_negocio.sql`](../sql/12_consultas_negocio.sql)

---

## 2. Consultas de Negocio

### Consulta 1 — Energía por inversor, día y mes (OBLIGATORIA)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Energía diaria y mensual por inversor |
| **Pregunta de negocio** | ¿Cuánta energía solar se generó (PV), cuánta se entregó a la carga (output) y cuánta se tomó de la red (grid), desglosada por inversor, por día y por mes? |
| **Lógica** | Se calcula el intervalo real entre lecturas consecutivas usando la función de ventana `LAG()`. La energía se estima multiplicando la potencia instantánea por el intervalo de tiempo: $E = \sum P_i \cdot \Delta t_i$. Se descartan intervalos > 120 s (gaps por apagones) para no sobreestimar. La energía se convierte de Watt·segundo a kWh dividiendo entre 3,600,000. |
| **Técnicas SQL** | CTE (`WITH`), `LAG()` (función de ventana), `EXTRACT(EPOCH)`, `SUM`, `COALESCE`, `GREATEST`, `GROUP BY`, `date_trunc`, filtro `BETWEEN` |
| **Resultado esperado** | Una tabla con columnas: `inversor_id`, `dia` (o `mes`), `energia_solar_kwh`, `energia_carga_kwh`, `energia_red_kwh`. Valores típicos para un día soleado: ~10-15 kWh solar, ~20-30 kWh carga, ~10-20 kWh red. |

### Consulta 2 — Hora pico solar (OBLIGATORIA)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Hora del día con mayor generación solar promedio |
| **Pregunta de negocio** | ¿En qué hora del día se produce la mayor generación fotovoltaica promedio, por inversor y por mes? |
| **Lógica** | Se extrae la hora local (Asia/Hong_Kong, UTC+8) del timestamp, se calcula el promedio de `pv1power` por hora, y se selecciona la hora con el máximo usando `RANK()`. Se excluyen horas nocturnas (promedio = 0 W). |
| **Técnicas SQL** | CTE, `EXTRACT(HOUR)`, `AT TIME ZONE`, `AVG`, `RANK()` (función de ventana), `GROUP BY`, subconsulta |
| **Resultado esperado** | Para cada mes e inversor, la hora pico solar. Esperado: entre las 11:00 y 13:00 hora local (cercano al cenit solar en Shenzhen, latitud ~22.5°N). |

### Consulta 3 — Comparación entre inversores (OBLIGATORIA)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Métricas comparativas entre Inversor 1 y 2 |
| **Pregunta de negocio** | ¿Cómo se comparan los dos inversores en potencia promedio, energía total, SOC de batería y factor de carga durante el primer semestre de 2026? |
| **Lógica** | Se realiza `INNER JOIN` entre `lectura`, `inversor` y `subsistema` para obtener la información del catálogo. Se calcula el factor de carga como porcentaje de la potencia nominal. Se filtra por rango de fechas `2026-01-01` a `2026-07-01`. |
| **Técnicas SQL** | `INNER JOIN` (doble), `AVG`, `MAX`, `MIN`, `COUNT`, `GROUP BY`, filtro `BETWEEN` con `timestamptz`, `NULLIF` |
| **Resultado esperado** | Dos filas (una por inversor). El Inversor 1 (cómputo GPU) debería tener mayor consumo continuo (carga constante de GPUs); el Inversor 2 (HVAC) debería tener consumo más variable (depende de temperatura ambiente). |

### Consulta 4 — Alerta de batería baja (OBLIGATORIA)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Conteo diario de lecturas con batería en nivel crítico |
| **Pregunta de negocio** | ¿Cuántas lecturas por día registran un SOC de batería inferior al 20%? |
| **Umbral justificado** | SOC < 20%. Las baterías LiFePO4 del sistema (51.2V nominal, ~200 Ah) tienen una curva de descarga plana entre 20% y 80% SOC. Por debajo del 20%, el voltaje cae rápidamente hacia el corte inferior del BMS (~48V), activando protecciones para evitar daño celular por descarga profunda. El rango observado en el dataset [6, 100] confirma que el sistema sí opera en estos niveles. |
| **Técnicas SQL** | `COUNT`, `MIN`, `AVG`, `GROUP BY`, `HAVING` (≥ 10 lecturas para filtrar ruido), `date_trunc`, filtro `WHERE` |
| **Resultado esperado** | Días con alertas de batería baja, concentrados en horarios nocturnos o periodos de alta demanda sin generación solar. |

### Consulta 5 — Completitud de datos (OBLIGATORIA)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Días con datos incompletos |
| **Pregunta de negocio** | ¿Qué días tienen menos del 95% de las lecturas esperadas y cuál es su porcentaje de completitud? |
| **Lógica** | Las lecturas esperadas por día por inversor son: 86,400 s/día ÷ 12.6 s/lectura ≈ **6,857 lecturas**. Se compara el conteo real contra este valor y se clasifica: Completo (≥95%), Parcial (80-95%), Incompleto (50-80%), Crítico (<50%). |
| **Técnicas SQL** | `COUNT`, `GROUP BY`, `HAVING` (< 95% completitud), `CASE WHEN`, `ROUND`, `date_trunc` |
| **Resultado esperado** | Se esperan ~3-5 días con completitud < 50% (los gaps documentados de mantenimiento) y ~30-40 días con completitud parcial (gaps menores por reinicios del inversor). |

### Consulta 6 — Consulta JSON sobre contexto (OBLIGATORIA)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Eventos de calendario académico y conteo por tipo de fuente |
| **Pregunta de negocio** | ¿Cuáles son los eventos de calendario académico registrados? ¿Cuántos registros hay por cada tipo de fuente de contexto? |
| **Lógica** | **(6A)** Se filtran los registros de contexto cuyo JSONB contiene `"source": "manual entry"` usando el operador de contención `@>`. Se extraen los campos `textual_description` y `source` con los operadores `->>` y `jsonb_extract_path_text()`. **(6B)** Se hace un conteo por tipo de fuente con `LEFT JOIN` al catálogo. |
| **Técnicas SQL** | Operadores JSONB: `->`, `->>`, `@>`, `jsonb_extract_path_text()`. `LEFT JOIN`, `COUNT`, `GROUP BY`, `MIN`, `MAX` |
| **Resultado esperado** | (6A) ~60 eventos de calendario (festivos, vacaciones, exámenes). (6B) Distribución: workstation2_log ~35%, windows_event_log ~25%, workstation1_log ~24%, derived_context ~15%, wsl_bash_history ~1%, manual entry ~0.2%. |

### Consulta 7 — Tasa de rechazo por regla de calidad (PROPUESTA SolarDB)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Tasa de rechazo y porcentaje por regla |
| **Pregunta de negocio** | ¿Cuál es la tasa de rechazo por cada regla de calidad de SolarDB? ¿Qué porcentaje del total migrado representan? |
| **Lógica** | Se agrupan los registros de cuarentena por regla y se calcula el porcentaje respecto al total de filas leídas (obtenido mediante subconsulta sobre `lote_carga`). |
| **Técnicas SQL** | `LEFT JOIN`, `COUNT`, `GROUP BY`, subconsulta escalar (`SELECT SUM(...) FROM lote_carga`), `NULLIF`, `ROUND` |
| **Resultado esperado** | Las reglas con más rechazos serían: valores nulos (~59,000 registros, ~2%), seguido de frecuencia de línea cero (~342,000 registros clasificados como "modo isla" según la regla), luego P > S (~3,800) y temperatura anómala (~38). |

### Consulta 8 — Variables con mayor frecuencia de nulos (PROPUESTA SolarDB)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Ranking de variables por frecuencia de valores nulos |
| **Pregunta de negocio** | ¿Cuáles son las variables físicas con mayor cantidad de valores nulos en las lecturas aceptadas? |
| **Lógica** | Se cuenta la cantidad de NULLs por cada variable clave usando `COUNT(*) FILTER (WHERE columna IS NULL)` y se une el resultado con `UNION ALL`. |
| **Técnicas SQL** | `COUNT FILTER`, `UNION ALL`, `ROUND`, `ORDER BY` |
| **Resultado esperado** | Todas las variables presentan ~58,000-60,000 nulos (~2%), correlacionados con los timeouts Modbus. `outvolta` y `pv1volt` son las más afectadas. |

### Consulta 9 — Evolución temporal de cuarentena (PROPUESTA SolarDB)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Evolución mensual de registros en cuarentena |
| **Pregunta de negocio** | ¿Cómo evoluciona la cantidad de registros rechazados a lo largo del tiempo? ¿Se concentran los errores en ciertos meses? |
| **Lógica** | Se agrupan los registros de cuarentena por mes (según el timestamp original de la lectura) y por regla violada. |
| **Técnicas SQL** | `INNER JOIN`, `COUNT`, `GROUP BY`, `date_trunc`, `ORDER BY` |
| **Resultado esperado** | Se espera una distribución relativamente uniforme de nulos (error Modbus es aleatorio), pero con posibles picos de temperatura anómala en meses de invierno (si el sensor falla más con frío). |

### Consulta 10 — Comparación lecturas recibidas vs aceptadas vs rechazadas (PROPUESTA SolarDB)

| Campo | Descripción |
|-------|-------------|
| **Nombre** | Verificación cruzada de conteos por lote de carga |
| **Pregunta de negocio** | ¿Los conteos declarados en el lote de carga coinciden con los registros reales en las tablas de lecturas y cuarentena? |
| **Lógica** | Se consulta la tabla `lote_carga` y se verifican los conteos reales mediante subconsultas correlacionadas sobre `lectura` y `cuarentena`. Se calcula el porcentaje de aceptación. |
| **Técnicas SQL** | Subconsulta correlacionada (doble), `COUNT`, `NULLIF`, `ROUND` |
| **Resultado esperado** | Los conteos declarados y los reales deben coincidir. Si no coinciden, indica un error en el proceso de migración. La tasa de aceptación esperada es ~97-98% (100% - ~2% nulos rechazados). |

---

## 3. Técnicas SQL Utilizadas — Matriz de Cumplimiento

| Técnica Requerida | Consulta(s) donde se usa | Ejemplo |
|-------------------|--------------------------|---------|
| `INNER JOIN` | C3, C9 | `lectura INNER JOIN inversor ON l.inversor_id = i.inversor_id` |
| `LEFT JOIN` | C6B, C7 | `regla_calidad LEFT JOIN cuarentena ON rc.regla_id = q.regla_id` |
| Otro tipo de JOIN | Vista 2 | `FULL OUTER JOIN` entre aceptadas y rechazadas |
| `SUM` | C1, C3, C10 | `SUM(COALESCE(pv1power, 0) * intervalo_s)` |
| `AVG` | C2, C3, C4 | `AVG(COALESCE(pv1power, 0))` |
| `COUNT` | C3, C4, C5, C7, C8, C9, C10 | `COUNT(*) FILTER (WHERE battvolt IS NULL)` |
| `GROUP BY` | Todas (C1-C10), V1, V2 | `GROUP BY inversor_id, dia` |
| `HAVING` | C4, C5 | `HAVING COUNT(*) >= 10` (C4), `HAVING COUNT(*) < 6857 * 0.95` (C5) |
| Subconsulta | C7, C10 | `(SELECT SUM(filas_leidas) FROM lote_carga)` (C7), subconsulta correlacionada (C10) |
| Filtro por rango de fechas | C1, C3 | `WHERE l.read_ts BETWEEN '2026-01-01'::timestamptz AND '2026-07-01'::timestamptz` |

✅ **Todas las técnicas requeridas están cubiertas.**

---

## 4. Vistas SQL

### Vista 1: `v_resumen_diario_energia`

| Campo | Descripción |
|-------|-------------|
| **Nombre** | `v_resumen_diario_energia` |
| **Para qué sirve** | Resumen consolidado de energía solar generada, energía entregada a la carga y energía tomada de la red, junto con métricas de batería y temperatura, por inversor y por día. |
| **Quién la usaría** | *Operador de la microrred:* para monitoreo diario de producción y consumo. *Equipo de análisis:* para reportes mensuales de rendimiento energético. *Investigadores:* para correlacionar generación solar con condiciones climáticas. |
| **Frecuencia de uso** | Diaria (monitoreo), mensual (reportes), ad-hoc (investigación). |
| **Columnas que expone** | `inversor_id`, `fabricante`, `subsistema`, `dia`, `num_lecturas`, `pct_completitud`, `energia_solar_kwh`, `energia_carga_kwh`, `energia_red_kwh`, `soc_promedio_pct`, `soc_minimo_pct`, `temp_promedio_c` |
| **JOINs internos** | `lectura INNER JOIN inversor INNER JOIN subsistema` |

**Ejemplo de uso:**
```sql
-- Resumen del mes de enero 2026 para ambos inversores
SELECT * FROM v_resumen_diario_energia
WHERE dia BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY inversor_id, dia;
```

### Vista 2: `v_calidad_datos_diaria`

| Campo | Descripción |
|-------|-------------|
| **Nombre** | `v_calidad_datos_diaria` |
| **Para qué sirve** | Muestra la proporción de lecturas aceptadas vs. rechazadas por día e inversor. Permite identificar periodos con problemas de calidad y evaluar la efectividad de las reglas de validación. |
| **Quién la usaría** | *Administrador de BD:* para verificar la integridad de las migraciones. *Ingeniero de calidad de datos:* para identificar tendencias de degradación. *Auditor:* para generar reportes de confiabilidad. |
| **Frecuencia de uso** | Semanal (auditoría de calidad), post-migración (verificación). |
| **Columnas que expone** | `dia`, `inversor_id`, `lecturas_aceptadas`, `lecturas_rechazadas`, `total_procesadas`, `pct_rechazo` |
| **JOINs internos** | `FULL OUTER JOIN` entre subconsulta de lecturas aceptadas y subconsulta de cuarentena |

**Ejemplo de uso:**
```sql
-- Días con tasa de rechazo superior al 5%
SELECT * FROM v_calidad_datos_diaria
WHERE pct_rechazo > 5
ORDER BY pct_rechazo DESC;
```

---

## 5. Índices Justificados

### Índice 1: `idx_lectura_inversor_ts`

| Campo | Descripción |
|-------|-------------|
| **Tabla** | `lectura` |
| **Columnas** | `(inversor_id, read_ts)` |
| **Tipo** | B-tree (predeterminado de PostgreSQL) |
| **Consulta que lo aprovecha** | Consulta 1 (Energía por inversor y día), Consulta 3 (Comparación entre inversores con filtro temporal), Consulta 4 (Alerta batería baja) |
| **Por qué se crea** | La clave primaria es `(read_ts, inversor_id)`, pero las consultas analíticas filtran primero por `inversor_id` y luego hacen range scan sobre `read_ts`. El orden de la PK prioriza el timestamp, lo que obliga a un Seq Scan cuando se filtra por un inversor específico. Este índice invierte el orden para optimizar el patrón de acceso más frecuente. |

**Plan de ejecución esperado:**

Sin el índice (solo con la PK `(read_ts, inversor_id)`):
```
Seq Scan on lectura  (cost=0.00..158723.49 rows=1494879 width=116)
  Filter: (inversor_id = 1 AND read_ts >= '2026-01-01' AND read_ts < '2026-02-01')
  Rows Removed by Filter: 1494880
```

Con el índice `idx_lectura_inversor_ts`:
```
Index Scan using idx_lectura_inversor_ts on lectura  (cost=0.43..52458.12 rows=205000 width=116)
  Index Cond: (inversor_id = 1 AND read_ts >= '2026-01-01' AND read_ts < '2026-02-01')
```

> [!IMPORTANT]
> La reducción estimada de costo es de ~3× (de ~158K a ~52K unidades de costo del planificador) porque el índice permite acceder directamente a las filas del inversor solicitado en el rango temporal, sin escanear las filas del otro inversor.

### Índice 2: `idx_cuarentena_regla_ts`

| Campo | Descripción |
|-------|-------------|
| **Tabla** | `cuarentena` |
| **Columnas** | `(regla_id, read_ts_original)` |
| **Tipo** | B-tree |
| **Consulta que lo aprovecha** | Consulta 7 (Tasa de rechazo por regla), Consulta 9 (Evolución temporal de cuarentena) |
| **Por qué se crea** | Las consultas de auditoría de calidad agrupan y filtran por regla de calidad y por periodo temporal. Sin este índice, PostgreSQL realiza un Seq Scan sobre toda la tabla de cuarentena. Con el índice, puede hacer un Index Scan directo filtrando por `regla_id` y opcionalmente por rango de `read_ts_original`. |

**Plan de ejecución esperado:**

Sin el índice:
```
Seq Scan on cuarentena  (cost=0.00..4523.00 rows=12000 width=52)
  Filter: (regla_id = 1)
```

Con el índice:
```
Index Scan using idx_cuarentena_regla_ts on cuarentena  (cost=0.29..458.12 rows=12000 width=52)
  Index Cond: (regla_id = 1)
```

### Índice 3: `idx_contexto_valor_gin`

| Campo | Descripción |
|-------|-------------|
| **Tabla** | `contexto` |
| **Columnas** | `valor` (JSONB) |
| **Tipo** | GIN (Generalized Inverted Index) |
| **Consulta que lo aprovecha** | Consulta 6 (Consulta JSON — operador `@>` sobre JSONB) |
| **Por qué se crea** | El operador de contención JSONB `@>` es la forma idiomática de filtrar documentos JSON en PostgreSQL. Sin un índice GIN, cada consulta requiere parsear el JSONB de las 25,178 filas. Con GIN, PostgreSQL construye un índice invertido sobre las claves y valores del JSON, permitiendo Bitmap Index Scan directo. |

**Plan de ejecución esperado:**

Sin el índice GIN:
```
Seq Scan on contexto  (cost=0.00..892.45 rows=60 width=312)
  Filter: (valor @> '{"source": "manual entry"}'::jsonb)
  Rows Removed by Filter: 25118
```

Con el índice GIN:
```
Bitmap Heap Scan on contexto  (cost=12.45..128.90 rows=60 width=312)
  Recheck Cond: (valor @> '{"source": "manual entry"}'::jsonb)
  -> Bitmap Index Scan on idx_contexto_valor_gin  (cost=0.00..12.43 rows=60 width=0)
       Index Cond: (valor @> '{"source": "manual entry"}'::jsonb)
```

> [!NOTE]
> La reducción de costo es de ~7× (de ~892 a ~129 unidades). Aunque la tabla `contexto` tiene solo 25,178 filas (y el beneficio absoluto es menor que en `lectura`), el índice GIN es importante porque:
> 1. Es la única forma de optimizar consultas con `@>` sobre JSONB.
> 2. Demuestra el uso de un tipo de índice diferente a B-tree.
> 3. La Consulta 6 es obligatoria en el taller.

---

## 6. Resumen de Índices

| # | Índice | Tabla | Columnas | Tipo | Consultas Optimizadas |
|---|--------|-------|----------|------|----------------------|
| 1 | `idx_lectura_inversor_ts` | `lectura` | `(inversor_id, read_ts)` | B-tree | C1, C3, C4, C5 |
| 2 | `idx_cuarentena_regla_ts` | `cuarentena` | `(regla_id, read_ts_original)` | B-tree | C7, C9 |
| 3 | `idx_contexto_valor_gin` | `contexto` | `valor` | GIN | C6 |

---

## 7. Cita Bibliográfica

Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223
