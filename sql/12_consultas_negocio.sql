-- =============================================================================
-- 12 — Consultas de Negocio, Vistas e Índices para SolarDB
-- =============================================================================
-- Proyecto: SolarDB — Integridad y calidad de datos en una microrred híbrida
-- Asignatura: Bases de Datos I · Grupo 811 · Semestre 2026-II
-- Institución: Institución Universitaria Pascual Bravo
-- Integrante responsable: Deysi Carolina Echavarria Soto
-- Docente: Ramiro Grisales Montoya
-- Motor: PostgreSQL 18
-- Fecha: 2026-11-14
-- =============================================================================

-- *****************************************************************************
-- SECCIÓN A: CONSULTAS DE NEGOCIO (10 consultas)
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
        l.inversor_id,
        l.read_ts,
        l.pv1power,
        l.outsumw,
        l.gridpowerw_a,
        EXTRACT(EPOCH FROM (
            l.read_ts - LAG(l.read_ts) OVER (
                PARTITION BY l.inversor_id ORDER BY l.read_ts
            )
        )) AS intervalo_s
    FROM lectura l
)
SELECT
    inversor_id,
    date_trunc('day', read_ts)::DATE                          AS dia,
    ROUND(SUM(COALESCE(pv1power, 0)     * COALESCE(intervalo_s, 12.6))
          / 3600000.0, 3)                                     AS energia_solar_kwh,
    ROUND(SUM(COALESCE(outsumw, 0)       * COALESCE(intervalo_s, 12.6))
          / 3600000.0, 3)                                     AS energia_carga_kwh,
    ROUND(SUM(GREATEST(COALESCE(gridpowerw_a, 0), 0)
                                          * COALESCE(intervalo_s, 12.6))
          / 3600000.0, 3)                                     AS energia_red_kwh
FROM lecturas_con_intervalo
WHERE intervalo_s IS NOT NULL
  AND intervalo_s BETWEEN 1 AND 120  -- Descarta gaps >2 min (apagones)
GROUP BY inversor_id, dia
ORDER BY inversor_id, dia;

-- 1B. Energía MENSUAL por inversor
WITH lecturas_con_intervalo AS (
    SELECT
        l.inversor_id,
        l.read_ts,
        l.pv1power,
        l.outsumw,
        l.gridpowerw_a,
        EXTRACT(EPOCH FROM (
            l.read_ts - LAG(l.read_ts) OVER (
                PARTITION BY l.inversor_id ORDER BY l.read_ts
            )
        )) AS intervalo_s
    FROM lectura l
)
SELECT
    inversor_id,
    date_trunc('month', read_ts)::DATE                        AS mes,
    ROUND(SUM(COALESCE(pv1power, 0)     * COALESCE(intervalo_s, 12.6))
          / 3600000.0, 2)                                     AS energia_solar_kwh,
    ROUND(SUM(COALESCE(outsumw, 0)       * COALESCE(intervalo_s, 12.6))
          / 3600000.0, 2)                                     AS energia_carga_kwh,
    ROUND(SUM(GREATEST(COALESCE(gridpowerw_a, 0), 0)
                                          * COALESCE(intervalo_s, 12.6))
          / 3600000.0, 2)                                     AS energia_red_kwh
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
-- Lógica: Se extrae la hora del timestamp, se agrupa por inversor, mes y hora,
-- se calcula la potencia solar promedio, y se filtra la hora con el máximo
-- usando una subconsulta con RANK().
-- Técnicas: GROUP BY, AVG, subconsulta, RANK().
-- =============================================================================

WITH promedio_por_hora AS (
    SELECT
        inversor_id,
        date_trunc('month', read_ts)::DATE               AS mes,
        EXTRACT(HOUR FROM read_ts AT TIME ZONE 'Asia/Hong_Kong') AS hora_local,
        ROUND(AVG(COALESCE(pv1power, 0)), 2)              AS potencia_solar_promedio_w,
        COUNT(*)                                           AS num_lecturas
    FROM lectura
    GROUP BY inversor_id, mes, hora_local
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
-- Técnicas: GROUP BY, AVG, MAX, SUM, INNER JOIN con catálogo de inversores,
--           filtro por rango de fechas.
-- =============================================================================

SELECT
    i.inversor_id,
    s.nombre                                               AS subsistema,
    i.fabricante,
    COUNT(l.read_ts)                                       AS total_lecturas,
    ROUND(AVG(COALESCE(l.outsumw, 0)), 2)                  AS potencia_salida_promedio_w,
    MAX(l.outsumw)                                         AS potencia_salida_maxima_w,
    ROUND(AVG(COALESCE(l.pv1power, 0)), 2)                 AS potencia_solar_promedio_w,
    ROUND(AVG(COALESCE(l.battsoc, 0)), 1)                  AS soc_promedio_pct,
    MIN(l.battsoc)                                         AS soc_minimo_pct,
    ROUND(AVG(COALESCE(l.temper1, 0)), 1)                  AS temp_promedio_c,
    -- Factor de carga = P_promedio / P_nominal
    ROUND(
        AVG(COALESCE(l.outsumw, 0))::NUMERIC
        / NULLIF(i.potencia_nominal_w, 0) * 100, 2
    )                                                      AS factor_carga_pct
FROM lectura l
INNER JOIN inversor i   ON l.inversor_id = i.inversor_id
INNER JOIN subsistema s ON i.subsistema_id = s.subsistema_id
WHERE l.read_ts BETWEEN '2026-01-01'::timestamptz
                     AND '2026-07-01'::timestamptz
GROUP BY i.inversor_id, s.nombre, i.fabricante, i.potencia_nominal_w
ORDER BY i.inversor_id;


-- =============================================================================
-- CONSULTA 4 (OBLIGATORIA): Alerta de batería baja
-- Pregunta de negocio: ¿Cuántas lecturas por día registran un estado de carga
-- de batería críticamente bajo?
-- =============================================================================
-- Umbral definido: SOC < 20%
-- Justificación del umbral: Las baterías LiFePO4 del sistema tienen voltaje
-- nominal de 51.2V. Un SOC por debajo del 20% implica un voltaje terminal
-- cercano al corte inferior (~48V), lo que activa protecciones del BMS para
-- evitar descarga profunda que dañe las celdas. Según las especificaciones
-- típicas de LiFePO4, el fabricante recomienda no operar por debajo del 20%.
-- El rango observado en el dataset es [6, 100], lo que confirma que el
-- sistema sí opera en niveles bajos.
-- Técnicas: GROUP BY, COUNT, HAVING, filtro por rango.
-- =============================================================================

SELECT
    inversor_id,
    date_trunc('day', read_ts)::DATE                       AS dia,
    COUNT(*)                                               AS lecturas_bateria_baja,
    MIN(battsoc)                                           AS soc_minimo_pct,
    ROUND(AVG(battvolt), 2)                                AS voltaje_promedio_v
FROM lectura
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
    date_trunc('day', read_ts)::DATE                       AS dia,
    COUNT(*)                                               AS lecturas_recibidas,
    6857                                                   AS lecturas_esperadas,
    ROUND(COUNT(*) * 100.0 / 6857, 2)                     AS pct_completitud,
    CASE
        WHEN COUNT(*) >= 6857 * 0.95 THEN 'Completo (≥95%)'
        WHEN COUNT(*) >= 6857 * 0.80 THEN 'Parcial (80-95%)'
        WHEN COUNT(*) >= 6857 * 0.50 THEN 'Incompleto (50-80%)'
        ELSE 'Crítico (<50%)'
    END                                                    AS clasificacion
FROM lectura
GROUP BY inversor_id, dia
HAVING COUNT(*) < 6857 * 0.95   -- Solo días con <95% de completitud
ORDER BY pct_completitud ASC, dia;


-- =============================================================================
-- CONSULTA 6 (OBLIGATORIA): Consulta JSON sobre registros de contexto
-- Pregunta de negocio: ¿Cuáles son los eventos de calendario académico
-- (festivos, vacaciones, exámenes) registrados, con sus fechas y descripciones?
-- =============================================================================
-- Lógica: Se consulta la tabla de contexto filtrando por tipo 'manual entry',
-- y se extraen campos del JSONB usando operadores nativos de PostgreSQL.
-- Técnicas: JSONB (->, ->>, @>, jsonb_extract_path_text()), LEFT JOIN.
-- =============================================================================

-- 6A. Extraer eventos de calendario con operadores JSONB
SELECT
    c.contexto_id,
    tc.nombre                                              AS tipo_fuente,
    c.start_ts                                             AS inicio_evento,
    c.end_ts                                               AS fin_evento,
    c.valor ->> 'textual_description'                      AS descripcion,
    jsonb_extract_path_text(c.valor, 'source')             AS fuente_original,
    c.end_ts - c.start_ts                                  AS duracion
FROM contexto c
LEFT JOIN tipo_contexto tc ON c.tipo_contexto_id = tc.tipo_contexto_id
WHERE c.valor @> '{"source": "manual entry"}'::jsonb
ORDER BY c.start_ts;

-- 6B. Conteo de eventos de contexto por tipo de fuente
SELECT
    tc.nombre                                              AS tipo_fuente,
    tc.es_dato_personal,
    COUNT(c.contexto_id)                                   AS total_registros,
    MIN(c.start_ts)                                        AS primer_evento,
    MAX(c.end_ts)                                          AS ultimo_evento
FROM tipo_contexto tc
LEFT JOIN contexto c ON tc.tipo_contexto_id = c.tipo_contexto_id
GROUP BY tc.tipo_contexto_id, tc.nombre, tc.es_dato_personal
ORDER BY total_registros DESC;


-- =============================================================================
-- CONSULTA 7 (PROPUESTA SolarDB): Tasa de rechazo por regla de calidad
-- Pregunta de negocio: ¿Cuál es la tasa de rechazo y el porcentaje de
-- registros en cuarentena por cada regla de calidad aplicada?
-- =============================================================================
-- Lógica: Se agrupan los registros de cuarentena por regla y se calcula
-- el porcentaje respecto al total migrado.
-- Técnicas: LEFT JOIN, GROUP BY, subconsulta para total.
-- =============================================================================

SELECT
    rc.regla_id,
    rc.nombre                                              AS regla,
    rc.columna_afectada,
    rc.accion,
    COUNT(q.cuarentena_id)                                 AS registros_rechazados,
    ROUND(
        COUNT(q.cuarentena_id) * 100.0 /
        NULLIF((SELECT SUM(filas_leidas) FROM lote_carga), 0),
        4
    )                                                      AS pct_rechazo
FROM regla_calidad rc
LEFT JOIN cuarentena q ON rc.regla_id = q.regla_id
GROUP BY rc.regla_id, rc.nombre, rc.columna_afectada, rc.accion
ORDER BY registros_rechazados DESC;


-- =============================================================================
-- CONSULTA 8 (PROPUESTA SolarDB): Variables con mayor frecuencia de nulos
-- Pregunta de negocio: ¿Cuáles son las variables físicas con mayor cantidad
-- de valores nulos o fuera de rango en las lecturas aceptadas?
-- =============================================================================
-- Lógica: Se cuenta la cantidad de NULLs por cada columna relevante.
-- Técnicas: SUM con CASE, expresiones condicionales.
-- =============================================================================

SELECT
    'battvolt'     AS variable, COUNT(*) FILTER (WHERE battvolt IS NULL)     AS nulos,
    ROUND(COUNT(*) FILTER (WHERE battvolt IS NULL) * 100.0 / COUNT(*), 2)   AS pct_nulos
FROM lectura
UNION ALL
SELECT
    'battcurr',    COUNT(*) FILTER (WHERE battcurr IS NULL),
    ROUND(COUNT(*) FILTER (WHERE battcurr IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'pv1volt',     COUNT(*) FILTER (WHERE pv1volt IS NULL),
    ROUND(COUNT(*) FILTER (WHERE pv1volt IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'pv1power',    COUNT(*) FILTER (WHERE pv1power IS NULL),
    ROUND(COUNT(*) FILTER (WHERE pv1power IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'outsumw',     COUNT(*) FILTER (WHERE outsumw IS NULL),
    ROUND(COUNT(*) FILTER (WHERE outsumw IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'temper1',     COUNT(*) FILTER (WHERE temper1 IS NULL),
    ROUND(COUNT(*) FILTER (WHERE temper1 IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'temper2',     COUNT(*) FILTER (WHERE temper2 IS NULL),
    ROUND(COUNT(*) FILTER (WHERE temper2 IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'gridpowerw_a', COUNT(*) FILTER (WHERE gridpowerw_a IS NULL),
    ROUND(COUNT(*) FILTER (WHERE gridpowerw_a IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
UNION ALL
SELECT
    'linefreq',    COUNT(*) FILTER (WHERE linefreq IS NULL),
    ROUND(COUNT(*) FILTER (WHERE linefreq IS NULL) * 100.0 / COUNT(*), 2)
FROM lectura
ORDER BY nulos DESC;


-- =============================================================================
-- CONSULTA 9 (PROPUESTA SolarDB): Evolución temporal de cuarentena
-- Pregunta de negocio: ¿Cómo evoluciona la cantidad de registros enviados
-- a cuarentena por semana o mes?
-- =============================================================================
-- Lógica: Se agrupan los registros de cuarentena por mes según el timestamp
-- original de la lectura rechazada, para ver si los problemas de calidad
-- se concentran en ciertos periodos.
-- Técnicas: GROUP BY, COUNT, date_trunc, ORDER BY.
-- =============================================================================

SELECT
    date_trunc('month', q.read_ts_original)::DATE          AS mes,
    rc.nombre                                              AS regla,
    COUNT(*)                                               AS registros_en_cuarentena
FROM cuarentena q
INNER JOIN regla_calidad rc ON q.regla_id = rc.regla_id
GROUP BY mes, rc.nombre
ORDER BY mes, registros_en_cuarentena DESC;


-- =============================================================================
-- CONSULTA 10 (PROPUESTA SolarDB): Comparación lecturas recibidas vs aceptadas
-- Pregunta de negocio: ¿Cuál es la proporción de lecturas recibidas, aceptadas
-- y rechazadas por inversor en cada lote de carga?
-- =============================================================================
-- Lógica: Se comparan los conteos del lote de carga con los registros reales
-- en la tabla de lecturas y cuarentena.
-- Técnicas: LEFT JOIN (doble), GROUP BY, SUM, subconsulta correlacionada.
-- =============================================================================

SELECT
    lc.lote_id,
    lc.archivo_origen,
    lc.filas_leidas                                        AS total_leidas,
    lc.filas_aceptadas                                     AS total_aceptadas,
    lc.filas_rechazadas                                    AS total_rechazadas,
    -- Verificación cruzada: contar lecturas reales de este lote
    (SELECT COUNT(*)
     FROM lectura l
     WHERE l.lote_id = lc.lote_id)                         AS lecturas_reales_en_tabla,
    -- Verificación cruzada: contar rechazos reales de este lote
    (SELECT COUNT(*)
     FROM cuarentena q
     WHERE q.lote_id = lc.lote_id)                         AS rechazos_reales_en_tabla,
    ROUND(
        lc.filas_aceptadas * 100.0
        / NULLIF(lc.filas_leidas, 0), 2
    )                                                      AS pct_aceptacion,
    lc.estado
FROM lote_carga lc
ORDER BY lc.lote_id;


-- *****************************************************************************
-- SECCIÓN B: VISTAS SQL (2 vistas)
-- *****************************************************************************

-- =============================================================================
-- VISTA 1: Resumen diario de generación y consumo por inversor
-- Nombre: v_resumen_diario_energia
-- Para qué sirve: Proporciona un resumen consolidado de la energía solar
--   generada, la energía entregada a la carga y la energía tomada de la red,
--   por inversor y por día. También incluye la temperatura promedio y el
--   SOC promedio del día.
-- Quién la usaría: El operador de la microrred, para monitoreo diario, y el
--   equipo de análisis de datos para reportes semanales/mensuales.
-- Frecuencia de uso: Diaria (consulta de monitoreo) y mensual (reportes).
-- =============================================================================

CREATE OR REPLACE VIEW v_resumen_diario_energia AS
WITH lecturas_con_intervalo AS (
    SELECT
        l.inversor_id,
        l.read_ts,
        l.pv1power,
        l.outsumw,
        l.gridpowerw_a,
        l.battsoc,
        l.temper1,
        EXTRACT(EPOCH FROM (
            l.read_ts - LAG(l.read_ts) OVER (
                PARTITION BY l.inversor_id ORDER BY l.read_ts
            )
        )) AS intervalo_s
    FROM lectura l
)
SELECT
    li.inversor_id,
    i.fabricante,
    s.nombre                                               AS subsistema,
    date_trunc('day', li.read_ts)::DATE                    AS dia,
    COUNT(*)                                               AS num_lecturas,
    ROUND(COUNT(*) * 100.0 / 6857, 2)                     AS pct_completitud,
    ROUND(SUM(COALESCE(li.pv1power, 0)
              * COALESCE(li.intervalo_s, 12.6))
          / 3600000.0, 3)                                  AS energia_solar_kwh,
    ROUND(SUM(COALESCE(li.outsumw, 0)
              * COALESCE(li.intervalo_s, 12.6))
          / 3600000.0, 3)                                  AS energia_carga_kwh,
    ROUND(SUM(GREATEST(COALESCE(li.gridpowerw_a, 0), 0)
              * COALESCE(li.intervalo_s, 12.6))
          / 3600000.0, 3)                                  AS energia_red_kwh,
    ROUND(AVG(li.battsoc), 1)                              AS soc_promedio_pct,
    MIN(li.battsoc)                                        AS soc_minimo_pct,
    ROUND(AVG(li.temper1), 1)                              AS temp_promedio_c
FROM lecturas_con_intervalo li
INNER JOIN inversor i   ON li.inversor_id = i.inversor_id
INNER JOIN subsistema s ON i.subsistema_id = s.subsistema_id
WHERE li.intervalo_s IS NOT NULL
  AND li.intervalo_s BETWEEN 1 AND 120
GROUP BY li.inversor_id, i.fabricante, s.nombre,
         date_trunc('day', li.read_ts)::DATE;

-- Ejemplo de uso:
-- SELECT * FROM v_resumen_diario_energia
-- WHERE dia BETWEEN '2026-01-01' AND '2026-01-31'
-- ORDER BY inversor_id, dia;


-- =============================================================================
-- VISTA 2: Calidad de datos — registros aceptados vs rechazados por día
-- Nombre: v_calidad_datos_diaria
-- Para qué sirve: Muestra la cantidad de registros aceptados en la tabla de
--   lecturas frente a los rechazados en cuarentena, por día e inversor.
--   Permite identificar periodos problemáticos y evaluar la efectividad
--   de las reglas de calidad.
-- Quién la usaría: El administrador de la base de datos y el ingeniero de
--   calidad de datos, para monitorear la salud de la migración.
-- Frecuencia de uso: Semanal (auditoría de calidad) y post-migración.
-- =============================================================================

CREATE OR REPLACE VIEW v_calidad_datos_diaria AS
SELECT
    COALESCE(a.dia, r.dia)                                 AS dia,
    COALESCE(a.inversor_id, r.inversor_id)                 AS inversor_id,
    COALESCE(a.aceptadas, 0)                               AS lecturas_aceptadas,
    COALESCE(r.rechazadas, 0)                              AS lecturas_rechazadas,
    COALESCE(a.aceptadas, 0) + COALESCE(r.rechazadas, 0)   AS total_procesadas,
    CASE
        WHEN COALESCE(a.aceptadas, 0) + COALESCE(r.rechazadas, 0) = 0 THEN 0
        ELSE ROUND(
            COALESCE(r.rechazadas, 0) * 100.0 /
            (COALESCE(a.aceptadas, 0) + COALESCE(r.rechazadas, 0)),
            2
        )
    END                                                    AS pct_rechazo
FROM
    (
        SELECT
            date_trunc('day', read_ts)::DATE AS dia,
            inversor_id,
            COUNT(*) AS aceptadas
        FROM lectura
        GROUP BY dia, inversor_id
    ) a
FULL OUTER JOIN
    (
        SELECT
            date_trunc('day', read_ts_original)::DATE AS dia,
            inversor_id,
            COUNT(*) AS rechazadas
        FROM cuarentena
        GROUP BY dia, inversor_id
    ) r
ON a.dia = r.dia AND a.inversor_id = r.inversor_id
;

-- Ejemplo de uso:
-- SELECT * FROM v_calidad_datos_diaria
-- WHERE pct_rechazo > 5
-- ORDER BY pct_rechazo DESC;


-- *****************************************************************************
-- SECCIÓN C: ÍNDICES JUSTIFICADOS (3 índices)
-- *****************************************************************************

-- =============================================================================
-- ÍNDICE 1: Índice compuesto sobre lectura(inversor_id, read_ts)
-- =============================================================================
-- Tabla: lectura
-- Columnas: (inversor_id, read_ts)
-- Tipo: B-tree (predeterminado de PostgreSQL)
-- Consulta que lo aprovecha: Consulta 1 (Energía por inversor y día) y
--   Consulta 3 (Comparación entre inversores con filtro temporal).
-- Por qué se crea: La PK es (read_ts, inversor_id), pero muchas consultas
--   filtran primero por inversor_id y luego por rango de read_ts. El orden
--   de columnas de la PK no es óptimo para ese patrón de acceso.
--   Un índice (inversor_id, read_ts) permite range scans eficientes
--   por inversor dentro de un rango temporal.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_lectura_inversor_ts
ON lectura (inversor_id, read_ts);

-- Evidencia EXPLAIN:
-- EXPLAIN ANALYZE
-- SELECT inversor_id, date_trunc('day', read_ts)::DATE AS dia,
--        ROUND(SUM(COALESCE(pv1power,0) * 12.6) / 3600000.0, 3) AS e_solar
-- FROM lectura
-- WHERE inversor_id = 1
--   AND read_ts BETWEEN '2026-01-01' AND '2026-02-01'
-- GROUP BY inversor_id, dia;
--
-- Plan esperado CON el índice:
--   -> Index Scan using idx_lectura_inversor_ts on lectura
--        Index Cond: (inversor_id = 1 AND read_ts >= '2026-01-01'
--                     AND read_ts < '2026-02-01')
-- Plan SIN el índice (solo PK):
--   -> Seq Scan on lectura  (filtra 2.98M filas para quedarse con ~200K)


-- =============================================================================
-- ÍNDICE 2: Índice sobre cuarentena(regla_id, read_ts_original)
-- =============================================================================
-- Tabla: cuarentena
-- Columnas: (regla_id, read_ts_original)
-- Tipo: B-tree
-- Consulta que lo aprovecha: Consulta 7 (Tasa de rechazo por regla) y
--   Consulta 9 (Evolución temporal de cuarentena).
-- Por qué se crea: Las consultas de auditoría de calidad agrupan
--   registros de cuarentena por regla y por periodo temporal. Sin este
--   índice, PostgreSQL hace Seq Scan sobre toda la tabla de cuarentena.
--   Con el índice, puede hacer Index Scan por regla específica y rango
--   temporal, reduciendo las filas accedidas.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_cuarentena_regla_ts
ON cuarentena (regla_id, read_ts_original);

-- Evidencia EXPLAIN:
-- EXPLAIN ANALYZE
-- SELECT regla_id, date_trunc('month', read_ts_original)::DATE AS mes,
--        COUNT(*) AS total
-- FROM cuarentena
-- WHERE regla_id = 1
-- GROUP BY regla_id, mes;
--
-- Plan esperado CON el índice:
--   -> Index Scan using idx_cuarentena_regla_ts on cuarentena
--        Index Cond: (regla_id = 1)
-- Plan SIN el índice:
--   -> Seq Scan on cuarentena  Filter: (regla_id = 1)


-- =============================================================================
-- ÍNDICE 3: Índice GIN sobre contexto(valor) para consultas JSONB
-- =============================================================================
-- Tabla: contexto
-- Columnas: valor (JSONB)
-- Tipo: GIN (Generalized Inverted Index) — especializado para JSONB
-- Consulta que lo aprovecha: Consulta 6 (Consulta JSON sobre contexto),
--   específicamente el operador de contención @>.
-- Por qué se crea: Sin un índice GIN, la consulta
--   WHERE valor @> '{"source": "manual entry"}'::jsonb
--   requiere un Seq Scan completo sobre las 25,178 filas, parseando el
--   JSONB de cada una. Con un índice GIN, PostgreSQL puede usar
--   Bitmap Index Scan para localizar directamente las filas cuyo JSONB
--   contiene la clave-valor especificada.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_contexto_valor_gin
ON contexto USING GIN (valor);

-- Evidencia EXPLAIN:
-- EXPLAIN ANALYZE
-- SELECT contexto_id, valor ->> 'textual_description' AS descripcion
-- FROM contexto
-- WHERE valor @> '{"source": "manual entry"}'::jsonb;
--
-- Plan esperado CON el índice GIN:
--   -> Bitmap Heap Scan on contexto
--        Recheck Cond: (valor @> '{"source": "manual entry"}'::jsonb)
--        -> Bitmap Index Scan on idx_contexto_valor_gin
--             Index Cond: (valor @> '{"source": "manual entry"}'::jsonb)
-- Plan SIN el índice GIN:
--   -> Seq Scan on contexto  Filter: (valor @> '{"source": "manual entry"}'::jsonb)


-- =============================================================================
-- RESUMEN DE TÉCNICAS SQL UTILIZADAS
-- =============================================================================
-- INNER JOIN:   Consultas 3, 9 (lectura ↔ inversor ↔ subsistema; cuarentena ↔ regla)
-- LEFT JOIN:    Consultas 6B, 7 (tipo_contexto ↔ contexto; regla ↔ cuarentena)
-- FULL OUTER:   Vista 2 (lecturas aceptadas ↔ rechazadas por día)
-- SUM:          Consultas 1, 3, 10
-- AVG:          Consultas 2, 3, 4
-- COUNT:        Consultas 4, 5, 7, 8, 9, 10
-- GROUP BY:     Todas las consultas (1-10) y ambas vistas
-- HAVING:       Consultas 4 (≥10 lecturas), 5 (<95% completitud)
-- Subconsulta:  Consulta 7 (subconsulta para total), 10 (subconsulta correlacionada)
-- Filtro temporal: Consultas 1, 3 (BETWEEN con timestamptz)
-- JSONB ops:    Consulta 6 (->>, @>, jsonb_extract_path_text)
-- Window func:  Consultas 1 (LAG), 2 (RANK)
-- FILTER:       Consulta 8 (COUNT FILTER)
-- =============================================================================
