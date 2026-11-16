/*
 * ============================================================================
 *  SolarDB — Script 06: Creación de Vistas
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Crea vistas que encapsulan consultas frecuentes:
 *        • v_resumen_diario_energia  — Resumen diario de generación PV.
 *        • v_dashboard_calidad       — Panel de calidad de datos.
 *        • v_estado_baterias         — Último estado de cada inversor.
 *
 *  Prerequisito : Scripts 00–05 (esquemas, tablas, índices).
 *                 Pueden crearse antes de cargar datos (retornarán 0 filas).
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  Vista 1: Resumen diario de generación de energía PV
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Esta vista resume por día e inversor: energía PV generada, consumo,
--   y métricas de batería. Es la vista más consultada en un sistema de
--   monitoreo de microrred porque permite:
--     • Comparar rendimiento entre inversores.
--     • Detectar días con baja generación solar.
--     • Calcular energía neta (generada - consumida).
--
--   NOTA: "energía" se aproxima como promedio de potencia × 24h / 1000
--   porque la cadencia no es uniforme. Para producción, se usaría
--   integración trapezoidal sobre ts_lectura.
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW solardb.v_resumen_diario_energia AS
SELECT
    -- Dimensiones
    lt.inversor_id,
    DATE(lt.ts_lectura AT TIME ZONE 'Asia/Shanghai') AS fecha_local,

    -- Conteo de lecturas
    COUNT(*)                                        AS num_lecturas,

    -- PV (Panel Solar)
    ROUND(AVG(lt.pv1power)::NUMERIC, 2)             AS pv_potencia_media_w,
    MAX(lt.pv1power)                                AS pv_potencia_max_w,
    ROUND(AVG(lt.pv1volt)::NUMERIC, 2)              AS pv_voltaje_medio_v,

    -- Salida del inversor
    ROUND(AVG(lt.outsumw)::NUMERIC, 2)              AS salida_potencia_media_w,
    MAX(lt.outsumw)                                 AS salida_potencia_max_w,

    -- Batería
    ROUND(AVG(lt.battsoc)::NUMERIC, 1)              AS bateria_soc_medio_pct,
    MIN(lt.battsoc)                                 AS bateria_soc_min_pct,
    MAX(lt.battsoc)                                 AS bateria_soc_max_pct,
    ROUND(AVG(lt.battvolt)::NUMERIC, 2)             AS bateria_voltaje_medio_v,

    -- Temperaturas
    ROUND(AVG(lt.temper1)::NUMERIC, 1)              AS temp1_media_c,
    MAX(lt.temper1)                                 AS temp1_max_c,

    -- Red eléctrica
    ROUND(AVG(lt.linefreq)::NUMERIC, 2)             AS red_frecuencia_media_hz,

    -- Rango temporal
    MIN(lt.ts_lectura)                              AS primera_lectura,
    MAX(lt.ts_lectura)                              AS ultima_lectura

FROM solardb.lectura_telemetria lt
GROUP BY lt.inversor_id,
         DATE(lt.ts_lectura AT TIME ZONE 'Asia/Shanghai')
ORDER BY fecha_local DESC, lt.inversor_id;

COMMENT ON VIEW solardb.v_resumen_diario_energia IS
    'Resumen diario de generación PV, consumo, batería y temperatura '
    'por inversor. Fecha en hora local de Shenzhen (Asia/Shanghai). '
    'Consulta obligatoria del Taller 6: métricas de energía.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Vista 2: Dashboard de calidad de datos
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Vista central del sistema de calidad SolarDB. Muestra en un solo
--   lugar el estado de todos los lotes de carga con sus conteos de
--   aceptación/rechazo y el desglose por regla de calidad.
--   Útil para:
--     • Monitorear la salud de la migración.
--     • Identificar reglas que generan más rechazos.
--     • Verificar que la migración es idempotente.
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW calidad.v_dashboard_calidad AS
SELECT
    lc.lote_id,
    lc.tabla_origen,
    lc.estado                                       AS estado_lote,
    lc.fecha_inicio,
    lc.fecha_fin,
    lc.filas_leidas,
    lc.filas_aceptadas,
    lc.filas_rechazadas,

    -- Tasa de rechazo
    CASE WHEN lc.filas_leidas > 0
         THEN ROUND(
             (lc.filas_rechazadas::NUMERIC / lc.filas_leidas) * 100, 2
         )
         ELSE 0
    END                                             AS tasa_rechazo_pct,

    -- Desglose de cuarentena por regla
    rc_stats.reglas_activadas,
    rc_stats.pendientes,
    rc_stats.corregidos,
    rc_stats.descartados

FROM calidad.lote_carga lc
LEFT JOIN LATERAL (
    SELECT
        COUNT(DISTINCT rc.regla_id)                 AS reglas_activadas,
        COUNT(*) FILTER (WHERE rc.estado = 'PENDIENTE')   AS pendientes,
        COUNT(*) FILTER (WHERE rc.estado = 'CORREGIDO')   AS corregidos,
        COUNT(*) FILTER (WHERE rc.estado = 'DESCARTADO')  AS descartados
    FROM calidad.registro_cuarentena rc
    WHERE rc.lote_id = lc.lote_id
) rc_stats ON TRUE
ORDER BY lc.lote_id DESC;

COMMENT ON VIEW calidad.v_dashboard_calidad IS
    'Dashboard centralizado de calidad: estado de cada lote de carga, '
    'conteos de aceptación/rechazo, tasa de rechazo y desglose por '
    'regla de calidad. Línea de especialización SolarDB.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Vista 3: Último estado conocido de cada inversor
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Muestra la lectura más reciente de cada inversor. Útil para
--   monitoreo en tiempo real y verificación post-migración.
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW solardb.v_estado_baterias AS
SELECT DISTINCT ON (lt.inversor_id)
    lt.inversor_id,
    lt.ts_lectura,
    lt.battvolt     AS voltaje_bateria_v,
    lt.battcurr     AS corriente_bateria_a,
    lt.battsoc      AS soc_pct,
    lt.pv1power     AS potencia_pv_w,
    lt.outsumw      AS potencia_salida_w,
    lt.linefreq     AS frecuencia_red_hz,
    lt.temper1      AS temperatura_c,
    di.modelo       AS modelo_inversor
FROM solardb.lectura_telemetria lt
JOIN solardb.dim_inversor di ON lt.inversor_id = di.inversor_id
ORDER BY lt.inversor_id, lt.ts_lectura DESC;

COMMENT ON VIEW solardb.v_estado_baterias IS
    'Último estado conocido de cada inversor: voltaje, corriente, '
    'SOC, potencia PV, potencia salida, frecuencia, temperatura. '
    'Útil para monitoreo y verificación post-migración.';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.views
    WHERE table_schema IN ('solardb', 'calidad');
    RAISE NOTICE '✓ Vistas creadas: %', v_count;
END
$$;
