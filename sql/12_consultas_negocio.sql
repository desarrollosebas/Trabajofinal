-- =============================================================================
-- 12 — Consultas de Negocio, Vistas e Índices para SolarDB (Producción)
-- =============================================================================
-- Proyecto: SolarDB — Integridad y calidad de datos en una microrred híbrida
-- Asignatura: Bases de Datos I · Grupo 811 · Semestre 2026-II
-- Institución: Institución Universitaria Pascual Bravo
-- Integrante responsable: Deysi Carolina Echavarria Soto
-- Docente: Ramiro Grisales Montoya
-- Motor: PostgreSQL 18
-- Fecha: 2026-11-14 (Revisión y certificación para producción: 2026-11-17)
-- =============================================================================

-- *****************************************************************************
-- SECCIÓN A: CONSULTAS DE NEGOCIO (10 consultas certificadas)
-- *****************************************************************************

-- =============================================================================
-- CONSULTA 1 (OBLIGATORIA): Energía por inversor, día y mes
-- Pregunta de negocio: ¿Cuánta energía solar se generó, cuánta se entregó a
-- la carga y cuánta se tomó de la red, por inversor, por día y por mes?
-- =============================================================================
-- Lógica: Se aproxima la energía integrando la potencia en el tiempo.
-- Dado que el muestreo es ~12.6 s, se calcula el intervalo real entre lecturas
-- consecutivas con LAG() y se multiplica potencia × intervalo (método rectangular).
-- La energía se expresa en kWh: (W × s) / 3,600,000 = kWh.
-- =============================================================================

-- 1A. Energía DIARIA por inversor
WITH lecturas_con_intervalo AS (
    SELECT
        lt.inversor_id,
        lt.ts_lectura,
        lt.pv1power,
        lt.outsumw,
        lt.gridpowerw_a,
        EXTRACT(EPOCH FROM (
            lt.ts_lectura - LAG(lt.ts_lectura) OVER (
                PARTITION BY lt.inversor_id ORDER BY lt.ts_lectura
            )
        )) AS intervalo_s
    FROM solardb.lectura_telemetria lt
)
SELECT
    inversor_id,
    date_trunc('day', ts_lectura)::DATE                       AS dia,
    ROUND((SUM(COALESCE(pv1power, 0)     * COALESCE(intervalo_s, 12.6))
          / 3600000.0)::NUMERIC, 3)                                     AS energia_solar_kwh,
    ROUND((SUM(COALESCE(outsumw, 0)       * COALESCE(intervalo_s, 12.6))
          / 3600000.0)::NUMERIC, 3)                                     AS energia_carga_kwh,
    ROUND((SUM(GREATEST(COALESCE(gridpowerw_a, 0), 0)
                                          * COALESCE(intervalo_s, 12.6))
          / 3600000.0)::NUMERIC, 3)                                     AS energia_red_kwh
FROM lecturas_con_intervalo
WHERE intervalo_s IS NOT NULL
  AND intervalo_s BETWEEN 1 AND 120  -- Descarta gaps >2 min (apagones/mantenimiento)
GROUP BY inversor_id, dia
ORDER BY inversor_id, dia;

-- 1B. Energía MENSUAL por inversor
WITH lecturas_con_intervalo AS (
    SELECT
        lt.inversor_id,
        lt.ts_lectura,
        lt.pv1power,
        lt.outsumw,
        lt.gridpowerw_a,
        EXTRACT(EPOCH FROM (
            lt.ts_lectura - LAG(lt.ts_lectura) OVER (
                PARTITION BY lt.inversor_id ORDER BY lt.ts_lectura
            )
        )) AS intervalo_s
    FROM solardb.lectura_telemetria lt
)
SELECT
    inversor_id,
    date_trunc('month', ts_lectura)::DATE                     AS mes,
    ROUND((SUM(COALESCE(pv1power, 0)     * COALESCE(intervalo_s, 12.6))
          / 3600000.0)::NUMERIC, 2)                                     AS energia_solar_kwh,
    ROUND((SUM(COALESCE(outsumw, 0)       * COALESCE(intervalo_s, 12.6))
          / 3600000.0)::NUMERIC, 2)                                     AS energia_carga_kwh,
    ROUND((SUM(GREATEST(COALESCE(gridpowerw_a, 0), 0)
                                          * COALESCE(intervalo_s, 12.6))
          / 3600000.0)::NUMERIC, 2)                                     AS energia_red_kwh
FROM lecturas_con_intervalo
WHERE intervalo_s IS NOT NULL
  AND intervalo_s BETWEEN 1 AND 120
GROUP BY inversor_id, mes
ORDER BY inversor_id, mes;


-- =============================================================================
-- CONSULTA 2 (OBLIGATORIA): Hora pico solar
-- Pregunta de negocio: ¿En qué hora del día se produce la mayor generación
-- solar promedio, por inversor y por mes?
-- =============================================================================
-- Lógica: Se extrae la hora local del timestamp (Asia/Shanghai o Asia/Hong_Kong),
-- se agrupa por inversor, mes y hora, se calcula la potencia solar promedio,
-- y se filtra la hora con el máximo usando una subconsulta con RANK().
-- Técnicas: GROUP BY, AVG, subconsulta, RANK(), AT TIME ZONE.
-- =============================================================================

WITH promedio_por_hora AS (
    SELECT
        lt.inversor_id,
        date_trunc('month', lt.ts_lectura)::DATE                  AS mes,
        EXTRACT(HOUR FROM lt.ts_lectura AT TIME ZONE 'Asia/Shanghai') AS hora_local,
        ROUND(AVG(COALESCE(lt.pv1power, 0))::NUMERIC, 2)          AS potencia_solar_promedio_w,
        COUNT(*)                                                  AS num_lecturas
    FROM solardb.lectura_telemetria lt
    GROUP BY lt.inversor_id, mes, hora_local
),
ranking AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY inversor_id, mes
            ORDER BY potencia_solar_promedio_w DESC
        ) AS rnk
    FROM promedio_por_hora
    WHERE potencia_solar_promedio_w > 0  -- Excluir horas nocturnas (0 W)
)
SELECT
    inversor_id,
    mes,
    hora_local                    AS hora_pico_solar,
    potencia_solar_promedio_w,
    num_lecturas
FROM ranking
WHERE rnk = 1
ORDER BY inversor_id, mes;


-- =============================================================================
-- CONSULTA 3 (OBLIGATORIA): Comparación entre inversores
-- Pregunta de negocio: ¿Cómo se comparan el Inversor 1 (Cómputo) y el
-- Inversor 2 (HVAC) en términos de potencia promedio, energía total y factor
-- de carga durante un periodo seleccionado?
-- =============================================================================
-- Lógica: Se calcula para cada inversor la potencia promedio de salida, la
-- potencia máxima, y se estima el factor de carga como P_promedio / P_nominal.
-- Se filtra por un periodo de ejemplo (primer semestre 2026).
-- Técnicas: GROUP BY, AVG, MAX, COUNT, INNER JOIN con catálogo dimensional,
--           filtro por rango de fechas.
-- =============================================================================

SELECT
    i.inversor_id,
    s.nombre_subsistema                                    AS subsistema,
    i.fabricante,
    COUNT(lt.ts_lectura)                                   AS total_lecturas,
    ROUND(AVG(COALESCE(lt.outsumw, 0))::NUMERIC, 2)        AS potencia_salida_promedio_w,
    MAX(lt.outsumw)                                        AS potencia_salida_maxima_w,
    ROUND(AVG(COALESCE(lt.pv1power, 0))::NUMERIC, 2)       AS potencia_solar_promedio_w,
    ROUND(AVG(COALESCE(lt.battsoc, 0))::NUMERIC, 1)        AS soc_promedio_pct,
    MIN(lt.battsoc)                                        AS soc_minimo_pct,
    ROUND(AVG(COALESCE(lt.temper1, 0))::NUMERIC, 1)        AS temp_promedio_c,
    -- Factor de carga = P_promedio / P_nominal
    ROUND(
        (AVG(COALESCE(lt.outsumw, 0))::NUMERIC
        / NULLIF(i.potencia_nominal_w, 0) * 100)::NUMERIC, 2
    )                                                      AS factor_carga_pct
FROM solardb.lectura_telemetria lt
INNER JOIN solardb.dim_inversor i   ON lt.inversor_id = i.inversor_id
INNER JOIN solardb.dim_subsistema s ON i.subsistema_id = s.subsistema_id
WHERE lt.ts_lectura BETWEEN '2026-01-01'::timestamptz
                        AND '2026-07-01'::timestamptz
GROUP BY i.inversor_id, s.nombre_subsistema, i.fabricante, i.potencia_nominal_w
ORDER BY i.inversor_id;


-- =============================================================================
-- CONSULTA 4 (OBLIGATORIA): Alerta de batería baja
-- Pregunta de negocio: ¿Cuántas lecturas por día registran un estado de carga
-- de batería críticamente bajo?
-- =============================================================================
-- Umbral definido: SOC < 20%
-- Justificación del umbral: Las baterías LiFePO4 del sistema tienen voltaje
-- nominal de 51.2V / 48V. Un SOC por debajo del 20% implica un voltaje terminal
-- cercano al corte inferior del BMS, activando protecciones para evitar
-- daño celular por descarga profunda irreversible.
-- Técnicas: GROUP BY, COUNT, HAVING, filtro WHERE.
-- =============================================================================

SELECT
    inversor_id,
    date_trunc('day', ts_lectura)::DATE                    AS dia,
    COUNT(*)                                               AS lecturas_bateria_baja,
    MIN(battsoc)                                           AS soc_minimo_pct,
    ROUND(AVG(battvolt)::NUMERIC, 2)                       AS voltaje_promedio_v
FROM solardb.lectura_telemetria
WHERE battsoc < 20            -- Umbral: SOC menor al 20%
  AND battsoc IS NOT NULL
GROUP BY inversor_id, dia
HAVING COUNT(*) >= 10         -- Al menos 10 lecturas (~2 min) para no ser ruido
ORDER BY lecturas_bateria_baja DESC, dia;


-- =============================================================================
-- CONSULTA 5 (OBLIGATORIA): Completitud de datos
-- Pregunta de negocio: ¿Qué días tienen datos incompletos y cuál es el
-- porcentaje de lecturas recibidas frente a las esperadas?
-- =============================================================================
-- Lecturas esperadas por día por inversor:
-- 86,400 s/día ÷ 12.6 s/lectura ≈ 6,857 lecturas/día/inversor
-- Técnicas: GROUP BY, COUNT, expresión aritmética, filtro con HAVING.
-- =============================================================================

SELECT
    inversor_id,
    date_trunc('day', ts_lectura)::DATE                    AS dia,
    COUNT(*)                                               AS lecturas_recibidas,
    6857                                                   AS lecturas_esperadas,
    ROUND(COUNT(*) * 100.0 / 6857, 2)                     AS pct_completitud,
    CASE
        WHEN COUNT(*) >= 6857 * 0.95 THEN 'Completo (≥95%)'
        WHEN COUNT(*) >= 6857 * 0.80 THEN 'Parcial (80-95%)'
        WHEN COUNT(*) >= 6857 * 0.50 THEN 'Incompleto (50-80%)'
        ELSE 'Crítico (<50%)'
    END                                                    AS clasificacion
FROM solardb.lectura_telemetria
GROUP BY inversor_id, dia
HAVING COUNT(*) < 6857 * 0.95   -- Solo días con <95% de completitud
ORDER BY pct_completitud ASC, dia;


-- =============================================================================
-- CONSULTA 6 (OBLIGATORIA): Consulta JSON sobre registros de contexto
-- Pregunta de negocio: ¿Cuáles son los eventos de calendario académico
-- (festivos, vacaciones, exámenes) registrados, con sus fechas y descripciones?
-- ¿Cuál es la distribución de eventos de contexto por fuente?
-- =============================================================================
-- Lógica: Se consulta la tabla de contexto filtrando por tipo 'manual entry'
-- mediante operador @>, y se extraen campos JSONB con ->> y rutas.
-- Técnicas: JSONB (->, ->>, @>), LEFT JOIN a solardb.cat_tipo_contexto.
-- =============================================================================

-- 6A. Extraer eventos de calendario con operadores JSONB
SELECT
    c.contexto_id,
    tc.codigo_fuente                                       AS tipo_fuente,
    c.ts_contexto                                          AS inicio_evento,
    to_timestamp((c.valor ->> 'end_ts')::DOUBLE PRECISION) AS fin_evento,
    c.valor ->> 'textual_description'                      AS descripcion,
    c.valor ->> 'source'                                   AS fuente_original,
    to_timestamp((c.valor ->> 'end_ts')::DOUBLE PRECISION) - c.ts_contexto AS duracion
FROM solardb.registro_contexto c
LEFT JOIN solardb.cat_tipo_contexto tc ON c.tipo_contexto_id = tc.tipo_contexto_id
WHERE c.valor @> '{"source": "manual entry"}'::jsonb
ORDER BY c.ts_contexto;

-- 6B. Conteo de eventos de contexto por tipo de fuente
SELECT
    tc.codigo_fuente                                       AS tipo_fuente,
    tc.contiene_pii                                        AS es_dato_personal,
    COUNT(c.contexto_id)                                   AS total_registros,
    MIN(c.ts_contexto)                                     AS primer_evento,
    MAX(c.ts_contexto)                                     AS ultimo_evento
FROM solardb.cat_tipo_contexto tc
LEFT JOIN solardb.registro_contexto c ON tc.tipo_contexto_id = c.tipo_contexto_id
GROUP BY tc.tipo_contexto_id, tc.codigo_fuente, tc.contiene_pii
ORDER BY total_registros DESC;


-- =============================================================================
-- CONSULTA 7 (PROPUESTA SolarDB): Tasa de rechazo por regla de calidad
-- Pregunta de negocio: ¿Cuál es la tasa de rechazo y el porcentaje de
-- registros en cuarentena por cada regla de calidad aplicada?
-- =============================================================================
-- Lógica: Se agrupan los registros de cuarentena por regla y se calcula
-- el porcentaje respecto al total migrado (2,989,759 filas leídas).
-- Técnicas: LEFT JOIN, GROUP BY, subconsulta para total.
-- =============================================================================

SELECT
    rc.regla_id,
    rc.codigo_regla                                        AS regla,
    rc.variable_afectada,
    rc.accion,
    COUNT(q.cuarentena_id)                                 AS registros_rechazados,
    ROUND(
        COUNT(q.cuarentena_id) * 100.0 /
        NULLIF((SELECT SUM(filas_leidas) FROM calidad.lote_carga WHERE tabla_origen = 'analog_measurements'), 0),
        4
    )                                                      AS pct_rechazo
FROM calidad.regla_calidad rc
LEFT JOIN calidad.registro_cuarentena q ON rc.regla_id = q.regla_id
GROUP BY rc.regla_id, rc.codigo_regla, rc.variable_afectada, rc.accion
ORDER BY registros_rechazados DESC;


-- =============================================================================
-- CONSULTA 8 (PROPUESTA SolarDB): Variables con mayor frecuencia de nulos
-- Pregunta de negocio: ¿Cuáles son las variables físicas con mayor cantidad
-- de valores nulos o fuera de rango en las lecturas aceptadas?
-- =============================================================================
-- Lógica: Se cuenta la cantidad de NULLs por cada columna física relevante
-- mediante agregaciones condicionales FILTER.
-- Técnicas: COUNT(*) FILTER (WHERE ... IS NULL), UNION ALL.
-- =============================================================================

SELECT
    'outvolta'     AS variable, COUNT(*) FILTER (WHERE outvolta IS NULL)     AS nulos,
    ROUND(COUNT(*) FILTER (WHERE outvolta IS NULL) * 100.0 / COUNT(*), 2)   AS pct_nulos
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'pv1volt',     COUNT(*) FILTER (WHERE pv1volt IS NULL),
    ROUND(COUNT(*) FILTER (WHERE pv1volt IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'gridpowerw_a', COUNT(*) FILTER (WHERE gridpowerw_a IS NULL),
    ROUND(COUNT(*) FILTER (WHERE gridpowerw_a IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'outfreq',     COUNT(*) FILTER (WHERE outfreq IS NULL),
    ROUND(COUNT(*) FILTER (WHERE outfreq IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'pv1power',    COUNT(*) FILTER (WHERE pv1power IS NULL),
    ROUND(COUNT(*) FILTER (WHERE pv1power IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'temper1',     COUNT(*) FILTER (WHERE temper1 IS NULL),
    ROUND(COUNT(*) FILTER (WHERE temper1 IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'temper2',     COUNT(*) FILTER (WHERE temper2 IS NULL),
    ROUND(COUNT(*) FILTER (WHERE temper2 IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'battvolt',    COUNT(*) FILTER (WHERE battvolt IS NULL),
    ROUND(COUNT(*) FILTER (WHERE battvolt IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'battcurr',    COUNT(*) FILTER (WHERE battcurr IS NULL),
    ROUND(COUNT(*) FILTER (WHERE battcurr IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'outsumw',     COUNT(*) FILTER (WHERE outsumw IS NULL),
    ROUND(COUNT(*) FILTER (WHERE outsumw IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
UNION ALL
SELECT
    'linefreq',    COUNT(*) FILTER (WHERE linefreq IS NULL),
    ROUND(COUNT(*) FILTER (WHERE linefreq IS NULL) * 100.0 / COUNT(*), 2)
FROM solardb.lectura_telemetria
ORDER BY nulos DESC;


-- =============================================================================
-- CONSULTA 9 (PROPUESTA SolarDB): Evolución temporal de cuarentena
-- Pregunta de negocio: ¿Cómo evoluciona la cantidad de registros enviados
-- a cuarentena por semana o mes?
-- =============================================================================
-- Lógica: Se agrupan los registros de cuarentena por mes según la fecha
-- original de la lectura (read_ts_original), identificando estacionalidad.
-- Técnicas: GROUP BY, COUNT, date_trunc, to_timestamp, ORDER BY.
-- =============================================================================

SELECT
    date_trunc('month', to_timestamp(q.read_ts_original))::DATE AS mes,
    rc.codigo_regla                                            AS regla,
    COUNT(*)                                                   AS registros_en_cuarentena
FROM calidad.registro_cuarentena q
INNER JOIN calidad.regla_calidad rc ON q.regla_id = rc.regla_id
GROUP BY mes, rc.codigo_regla
ORDER BY mes, registros_en_cuarentena DESC;


-- =============================================================================
-- CONSULTA 10 (PROPUESTA SolarDB): Comparación lecturas recibidas vs aceptadas
-- Pregunta de negocio: ¿Cuál es la proporción de lecturas recibidas, aceptadas
-- y rechazadas en cada lote de carga? ¿Coinciden con los registros reales?
-- =============================================================================
-- Lógica: Se comparan los conteos de auditoría de lote_carga con el recuento
-- físico real en solardb.lectura_telemetria y calidad.registro_cuarentena.
-- Técnicas: Subconsultas correlacionadas, cálculos de porcentaje.
-- =============================================================================

SELECT
    lc.lote_id,
    lc.tabla_origen,
    lc.filas_leidas                                        AS total_leidas,
    lc.filas_aceptadas                                     AS total_aceptadas,
    lc.filas_rechazadas                                    AS total_rechazadas,
    -- Verificación cruzada: contar lecturas reales en producción de este lote
    (SELECT COUNT(*)
     FROM solardb.lectura_telemetria lt
     WHERE lt.lote_id = lc.lote_id)                        AS lecturas_reales_en_tabla,
    -- Verificación cruzada: contar rechazos reales en cuarentena de este lote
    (SELECT COUNT(*)
     FROM calidad.registro_cuarentena q
     WHERE q.lote_id = lc.lote_id)                         AS rechazos_reales_en_tabla,
    ROUND(
        lc.filas_aceptadas * 100.0
        / NULLIF(lc.filas_leidas, 0), 2
    )                                                      AS pct_aceptacion,
    lc.estado
FROM calidad.lote_carga lc
ORDER BY lc.lote_id;


-- *****************************************************************************
-- SECCIÓN B: VISTAS SQL (Vistas implementadas en SolarDB)
-- *****************************************************************************

-- =============================================================================
-- VISTA 1: Resumen diario de generación y consumo por inversor
-- Vista: solardb.v_resumen_diario_energia
-- =============================================================================
SELECT *
FROM solardb.v_resumen_diario_energia
ORDER BY fecha_local DESC, inversor_id
LIMIT 15;

-- =============================================================================
-- VISTA 2: Dashboard de calidad de datos
-- Vista: calidad.v_dashboard_calidad
-- =============================================================================
SELECT *
FROM calidad.v_dashboard_calidad;

-- =============================================================================
-- VISTA 3: Último estado conocido de baterías e inversores
-- Vista: solardb.v_estado_baterias
-- =============================================================================
SELECT *
FROM solardb.v_estado_baterias;


-- *****************************************************************************
-- SECCIÓN C: ÍNDICES Y PLANES EXPLAIN ANALYZE
-- *****************************************************************************

-- Escenario 1: Rango temporal sobre ts_lectura (utiliza idx_lectura_ts)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT inversor_id, ts_lectura, pv1power, outsumw, gridpowerw_a
FROM solardb.lectura_telemetria
WHERE ts_lectura BETWEEN '2026-01-01 00:00:00+00' AND '2026-01-07 23:59:59+00';

-- Escenario 2: Filtrado por inversor + rango temporal (utiliza uq_lectura_inversor_ts)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ts_lectura, battsoc, battvolt, battcurr
FROM solardb.lectura_telemetria
WHERE inversor_id = 1
  AND ts_lectura BETWEEN '2025-12-01 00:00:00+00' AND '2025-12-31 23:59:59+00';

-- Escenario 3: Búsqueda en JSONB mediante GIN (utiliza idx_contexto_valor_gin)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT contexto_id, ts_contexto, valor
FROM solardb.registro_contexto
WHERE valor @> '{"source": "derived_context_pipeline"}';
