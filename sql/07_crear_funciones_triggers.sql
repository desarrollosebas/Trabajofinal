/*
 * ============================================================================
 *  SolarDB — Script 07: Funciones y Triggers del Pipeline de Validación
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Implementa el pipeline de validación en PL/pgSQL:
 *
 *      1. fn_validar_staging_telemetria(p_lote_id):
 *         Recorre staging.staging_telemetria, aplica reglas de calidad,
 *         y clasifica cada fila como VALIDA o RECHAZADA.
 *
 *      2. fn_mover_validas_a_produccion(p_lote_id):
 *         Inserta las filas VALIDAS de staging en lectura_telemetria
 *         (con dominios y CHECK activos), usando ON CONFLICT DO NOTHING
 *         para idempotencia.
 *
 *      3. fn_mover_rechazadas_a_cuarentena(p_lote_id):
 *         Inserta las filas RECHAZADAS en registro_cuarentena con
 *         la fila original completa como JSONB.
 *
 *      4. fn_ejecutar_pipeline_telemetria(p_lote_id):
 *         Orquesta los 3 pasos anteriores y actualiza lote_carga.
 *
 *  Prerequisito : Scripts 00–05.
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  Función 1: Validar filas en staging — aplicar reglas de calidad
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION staging.fn_validar_staging_telemetria(
    p_lote_id INTEGER
)
RETURNS TABLE(validadas BIGINT, rechazadas BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_regla_temp    SMALLINT;
    v_regla_ps      SMALLINT;
    v_rechazadas    BIGINT := 0;
    v_validadas     BIGINT := 0;
    v_total         BIGINT := 0;
BEGIN
    -- Obtener IDs de reglas activas
    SELECT regla_id INTO v_regla_temp
    FROM calidad.regla_calidad
    WHERE codigo_regla = 'R_TEMP1_IMPOSIBLE' AND activa = TRUE;

    SELECT regla_id INTO v_regla_ps
    FROM calidad.regla_calidad
    WHERE codigo_regla = 'R_P_MAYOR_S' AND activa = TRUE;

    -- ─── Regla R_TEMP1_IMPOSIBLE ────────────────────────────────────────
    -- Temperatura temper1 ≤ -20°C: físicamente imposible en Shenzhen
    -- (clima subtropical, mínima histórica ~0°C). Indica fallo de sensor.
    -- Evidencia: 38 filas con temper1 = -20.3°C
    IF v_regla_temp IS NOT NULL THEN
        UPDATE staging.staging_telemetria
        SET estado_validacion = 'RECHAZADA'
        WHERE lote_id = p_lote_id
          AND estado_validacion = 'PENDIENTE'
          AND temper1 IS NOT NULL
          AND temper1 <= -20.0;

        GET DIAGNOSTICS v_rechazadas = ROW_COUNT;
        RAISE NOTICE 'Regla R_TEMP1_IMPOSIBLE: % filas rechazadas', v_rechazadas;
    END IF;

    -- ─── Regla R_P_MAYOR_S ─────────────────────────────────────────────
    -- Potencia activa P > Potencia aparente S: viola ley física P ≤ S.
    -- Se verifica en las columnas outw_a vs outva_a y outsumw vs outsumva.
    -- Evidencia: 3,811 filas (Inv1: 3,574, Inv2: 237)
    IF v_regla_ps IS NOT NULL THEN
        UPDATE staging.staging_telemetria
        SET estado_validacion = 'RECHAZADA'
        WHERE lote_id = p_lote_id
          AND estado_validacion = 'PENDIENTE'
          AND (
              (outw_a IS NOT NULL AND outva_a IS NOT NULL AND outw_a > outva_a)
              OR
              (outsumw IS NOT NULL AND outsumva IS NOT NULL AND outsumw > outsumva)
          );

        GET DIAGNOSTICS v_rechazadas = ROW_COUNT;
        RAISE NOTICE 'Regla R_P_MAYOR_S: % filas rechazadas', v_rechazadas;
    END IF;

    -- ─── Marcar las restantes como VALIDA ───────────────────────────────
    UPDATE staging.staging_telemetria
    SET estado_validacion = 'VALIDA'
    WHERE lote_id = p_lote_id
      AND estado_validacion = 'PENDIENTE';

    GET DIAGNOSTICS v_validadas = ROW_COUNT;

    -- Contar rechazadas totales
    SELECT COUNT(*) INTO v_rechazadas
    FROM staging.staging_telemetria
    WHERE lote_id = p_lote_id
      AND estado_validacion = 'RECHAZADA';

    RAISE NOTICE 'Validación completada: % válidas, % rechazadas',
        v_validadas, v_rechazadas;

    RETURN QUERY SELECT v_validadas, v_rechazadas;
END;
$$;

COMMENT ON FUNCTION staging.fn_validar_staging_telemetria(INTEGER) IS
    'Aplica reglas de calidad a las filas de staging de un lote dado. '
    'Marca cada fila como VALIDA o RECHAZADA según las reglas activas. '
    'Reglas: R_TEMP1_IMPOSIBLE (temper1 ≤ -20°C), '
    'R_P_MAYOR_S (potencia activa > aparente).';


-- ═══════════════════════════════════════════════════════════════════════════
--  Función 2: Mover filas válidas a producción
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION staging.fn_mover_validas_a_produccion(
    p_lote_id INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_insertadas BIGINT;
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id,
        battvolt, battcurr, battsoc, battchgpower, battreserve,
        linechgcurr, pvchgcurr,
        pv1volt, pv1curr, pv1power, pvreserve,
        outvolta, outcurra, outfreq, invcurra,
        outw_a, outva_a, loadpercenta, normalloadw_a,
        outsumw, outsumva, sumloadpercent,
        generatedpowerp_a, generatedpowers_a, generatedpowerq_a,
        linevolta, linecurra, linefreq, linepowerva_a, linepowerw_a,
        busvoltp, busvoltn,
        temper1, temper2, temper3, temper4,
        sir, fanduty, otherreserve,
        gridpowerw_a, gridcurr_a, grid_reserve
    )
    SELECT
        s.inverter::SMALLINT,
        to_timestamp(s.read_ts) AT TIME ZONE 'UTC',
        p_lote_id,
        s.battvolt, s.battcurr, s.battsoc::SMALLINT, s.battchgpower::INTEGER,
        CASE WHEN s.battreserve IS NOT NULL
             THEN s.battreserve::JSONB ELSE NULL END,
        s.linechgcurr, s.pvchgcurr,
        s.pv1volt, s.pv1curr, s.pv1power::INTEGER,
        CASE WHEN s.pvreserve IS NOT NULL
             THEN s.pvreserve::JSONB ELSE NULL END,
        s.outvolta, s.outcurra, s.outfreq, s.invcurra,
        s.outw_a::INTEGER, s.outva_a::INTEGER,
        s.loadpercenta::SMALLINT, s.normalloadw_a::INTEGER,
        s.outsumw::INTEGER, s.outsumva::INTEGER, s.sumloadpercent::SMALLINT,
        s.generatedpowerp_a::INTEGER, s.generatedpowers_a::INTEGER,
        s.generatedpowerq_a::INTEGER,
        s.linevolta, s.linecurra, s.linefreq,
        s.linepowerva_a::INTEGER, s.linepowerw_a::INTEGER,
        s.busvoltp, s.busvoltn,
        s.temper1, s.temper2, s.temper3, s.temper4,
        s.sir::INTEGER, s.fanduty::SMALLINT,
        CASE WHEN s.otherreserve IS NOT NULL
             THEN s.otherreserve::JSONB ELSE NULL END,
        s.gridpowerw_a::INTEGER, s.gridcurr_a,
        CASE WHEN s.grid_reserve IS NOT NULL
             THEN s.grid_reserve::JSONB ELSE NULL END
    FROM staging.staging_telemetria s
    WHERE s.lote_id = p_lote_id
      AND s.estado_validacion = 'VALIDA'
    ON CONFLICT (inversor_id, ts_lectura) DO NOTHING;

    GET DIAGNOSTICS v_insertadas = ROW_COUNT;
    RAISE NOTICE 'Filas insertadas en producción: %', v_insertadas;
    RETURN v_insertadas;
END;
$$;

COMMENT ON FUNCTION staging.fn_mover_validas_a_produccion(INTEGER) IS
    'Mueve filas marcadas VALIDA de staging a solardb.lectura_telemetria. '
    'Convierte read_ts (Unix float) a TIMESTAMPTZ, TEXT a JSONB, '
    'DOUBLE PRECISION a INTEGER/SMALLINT según dominios. '
    'ON CONFLICT DO NOTHING garantiza idempotencia.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Función 3: Mover filas rechazadas a cuarentena
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION staging.fn_mover_rechazadas_a_cuarentena(
    p_lote_id INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_insertadas BIGINT := 0;
    v_regla_temp SMALLINT;
    v_regla_ps   SMALLINT;
    v_count      BIGINT;
BEGIN
    -- Obtener IDs de reglas
    SELECT regla_id INTO v_regla_temp
    FROM calidad.regla_calidad WHERE codigo_regla = 'R_TEMP1_IMPOSIBLE';

    SELECT regla_id INTO v_regla_ps
    FROM calidad.regla_calidad WHERE codigo_regla = 'R_P_MAYOR_S';

    -- ─── Cuarentena por R_TEMP1_IMPOSIBLE ───────────────────────────────
    IF v_regla_temp IS NOT NULL THEN
        INSERT INTO calidad.registro_cuarentena (
            lote_id, regla_id, read_ts_original, inversor_original,
            fila_original, motivo_rechazo
        )
        SELECT
            p_lote_id,
            v_regla_temp,
            s.read_ts,
            s.inverter::SMALLINT,
            to_jsonb(s) - 'stg_id' - 'lote_id' - 'estado_validacion',
            FORMAT('temper1 = %s°C: imposible en clima subtropical Shenzhen (sensor abierto)',
                   s.temper1)
        FROM staging.staging_telemetria s
        WHERE s.lote_id = p_lote_id
          AND s.estado_validacion = 'RECHAZADA'
          AND s.temper1 IS NOT NULL
          AND s.temper1 <= -20.0;

        GET DIAGNOSTICS v_count = ROW_COUNT;
        v_insertadas := v_insertadas + v_count;
        RAISE NOTICE 'Cuarentena R_TEMP1_IMPOSIBLE: % filas', v_count;
    END IF;

    -- ─── Cuarentena por R_P_MAYOR_S ─────────────────────────────────────
    IF v_regla_ps IS NOT NULL THEN
        INSERT INTO calidad.registro_cuarentena (
            lote_id, regla_id, read_ts_original, inversor_original,
            fila_original, motivo_rechazo
        )
        SELECT
            p_lote_id,
            v_regla_ps,
            s.read_ts,
            s.inverter::SMALLINT,
            to_jsonb(s) - 'stg_id' - 'lote_id' - 'estado_validacion',
            FORMAT('P > S: outw_a=%s > outva_a=%s o outsumw=%s > outsumva=%s',
                   s.outw_a, s.outva_a, s.outsumw, s.outsumva)
        FROM staging.staging_telemetria s
        WHERE s.lote_id = p_lote_id
          AND s.estado_validacion = 'RECHAZADA'
          AND s.temper1 IS NULL OR s.temper1 > -20.0  -- excluir las ya contadas por temp
          AND (
              (s.outw_a IS NOT NULL AND s.outva_a IS NOT NULL AND s.outw_a > s.outva_a)
              OR
              (s.outsumw IS NOT NULL AND s.outsumva IS NOT NULL AND s.outsumw > s.outsumva)
          );

        GET DIAGNOSTICS v_count = ROW_COUNT;
        v_insertadas := v_insertadas + v_count;
        RAISE NOTICE 'Cuarentena R_P_MAYOR_S: % filas', v_count;
    END IF;

    RAISE NOTICE 'Total filas en cuarentena: %', v_insertadas;
    RETURN v_insertadas;
END;
$$;

COMMENT ON FUNCTION staging.fn_mover_rechazadas_a_cuarentena(INTEGER) IS
    'Mueve filas RECHAZADAS de staging a calidad.registro_cuarentena. '
    'Cada fila se almacena completa como JSONB con motivo de rechazo '
    'específico. Clasifica por regla para trazabilidad.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Función 4: Orquestador del pipeline completo
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION staging.fn_ejecutar_pipeline_telemetria(
    p_lote_id INTEGER
)
RETURNS TABLE(
    filas_validadas  BIGINT,
    filas_rechazadas BIGINT,
    filas_insertadas BIGINT,
    filas_cuarentena BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_validadas     BIGINT;
    v_rechazadas    BIGINT;
    v_insertadas    BIGINT;
    v_cuarentena    BIGINT;
    v_total_staging BIGINT;
BEGIN
    RAISE NOTICE '═══ Pipeline SolarDB — Lote % ═══', p_lote_id;

    -- Contar filas en staging para este lote
    SELECT COUNT(*) INTO v_total_staging
    FROM staging.staging_telemetria
    WHERE lote_id = p_lote_id;

    RAISE NOTICE 'Filas en staging para lote %: %', p_lote_id, v_total_staging;

    IF v_total_staging = 0 THEN
        RAISE NOTICE 'No hay filas en staging para este lote. Abortando.';
        RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT;
        RETURN;
    END IF;

    -- Paso 1: Validar (clasificar VALIDA / RECHAZADA)
    RAISE NOTICE '── Paso 1: Validación ──';
    SELECT * INTO v_validadas, v_rechazadas
    FROM staging.fn_validar_staging_telemetria(p_lote_id);

    -- Paso 2: Mover válidas a producción
    RAISE NOTICE '── Paso 2: Inserción en producción ──';
    v_insertadas := staging.fn_mover_validas_a_produccion(p_lote_id);

    -- Paso 3: Mover rechazadas a cuarentena
    RAISE NOTICE '── Paso 3: Envío a cuarentena ──';
    v_cuarentena := staging.fn_mover_rechazadas_a_cuarentena(p_lote_id);

    -- Paso 4: Actualizar lote_carga (filas_rechazadas = v_rechazadas filas unicas)
    UPDATE calidad.lote_carga
    SET filas_leidas     = v_total_staging,
        filas_aceptadas  = v_insertadas,
        filas_rechazadas = v_rechazadas,
        fecha_fin        = now(),
        estado           = 'COMPLETADO'
    WHERE lote_id = p_lote_id;

    RAISE NOTICE '═══ Pipeline completado ═══';
    RAISE NOTICE 'Leídas: %  |  Insertadas: %  |  Cuarentena: %',
        v_total_staging, v_insertadas, v_cuarentena;

    RETURN QUERY SELECT v_validadas, v_rechazadas, v_insertadas, v_cuarentena;
END;
$$;

COMMENT ON FUNCTION staging.fn_ejecutar_pipeline_telemetria(INTEGER) IS
    'Orquestador del pipeline de validación completo: '
    '1) Clasifica filas en staging (VALIDA/RECHAZADA). '
    '2) Inserta válidas en producción con dominios activos. '
    '3) Envía rechazadas a cuarentena con trazabilidad. '
    '4) Actualiza contadores del lote de carga. '
    'Idempotente: re-ejecución no duplica filas (ON CONFLICT DO NOTHING).';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.routines
    WHERE routine_schema IN ('staging', 'solardb', 'calidad')
      AND routine_type = 'FUNCTION';
    RAISE NOTICE '✓ Funciones PL/pgSQL creadas: %', v_count;
END
$$;
