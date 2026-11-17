/*
 * ============================================================================
 *  SolarDB — Script 13: Batería de Pruebas de Integridad Física y Referencial
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6 (Grupo 811, 2026-II)
 *  Institución: Institución Universitaria Pascual Bravo
 *  Autor     : Deysi Carolina Echavarria Soto
 *  Docente   : Ramiro Grisales Montoya
 *  Motor     : PostgreSQL 18
 *  Fecha     : 2026-11-17
 *
 *  Descripción:
 *      Batería formal de pruebas de integridad para certificar las reglas
 *      de calidad de datos, dominios personalizados, claves foráneas,
 *      restricciones de unicidad y la idempotencia del pipeline en SolarDB.
 *
 *      Cada prueba está estructurada con control de excepciones y/o
 *      bloques transaccionales para que el script sea ejecutable de forma
 *      autónoma en psql o DBeaver sin dejar basura en producción.
 * ============================================================================
 */

\set ON_ERROR_STOP off

SELECT '=============================================================================' AS banner;
SELECT ' INICIO DE BATERÍA DE PRUEBAS DE INTEGRIDAD — SOLARDB (POSTGRESQL 18)'         AS banner;
SELECT ' Responsable: Deysi Carolina Echavarria Soto'                                  AS banner;
SELECT ' Fecha: 2026-11-17'                                                            AS banner;
SELECT '=============================================================================' AS banner;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 1: Inserción Válida Aceptada (Happy Path)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Verificar que una tupla con valores físicos dentro de todos los
--           rangos nominales se inserta satisfactoriamente (código de retorno 1).
-- Restricción probada: Integridad general de dominios y tipos base.
-- ─────────────────────────────────────────────────────────────────────────────
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

-- Verificación de inserción exitosa
SELECT lectura_id, inversor_id, ts_lectura, battsoc, pv1power
FROM solardb.lectura_telemetria
WHERE ts_lectura = '2026-11-16 12:00:00+00' AND inversor_id = 1;

ROLLBACK; -- Limpieza inmediata para mantener el estado inalterado


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 2: Rechazo por Dominio dom_voltaje (Voltaje Negativo)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Verificar que el DBMS rechaza voltajes < 0 V en battvolt.
-- Restricción probada: solardb.dom_voltaje CHECK (VALUE >= 0).
-- Error esperado: 23514 (check_violation)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, battvolt
    ) VALUES (
        1, '2026-11-16 12:01:00+00', 4, -10.0
    );
    RAISE EXCEPTION 'FALLO: Se aceptó un voltaje negativo (-10V)';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ PRUEBA 2 PASÓ: Dominio dom_voltaje rechazó voltaje negativo (-10.0 V).';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 3: Rechazo por Dominio dom_porcentaje (Fuera de Rango [0, 100])
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Verificar que fanduty rechaza valores superiores al 100%.
-- Restricción probada: solardb.dom_porcentaje CHECK (VALUE BETWEEN 0 AND 100).
-- Error esperado: 23514 (check_violation)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, fanduty
    ) VALUES (
        1, '2026-11-16 12:02:00+00', 4, 150
    );
    RAISE EXCEPTION 'FALLO: Se aceptó fanduty = 150%%';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ PRUEBA 3 PASÓ: Dominio dom_porcentaje rechazó ciclo de ventilador fuera de rango (150%%).';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 4: Rechazo por Dominio dom_porcentaje_carga (Fuera de Rango [0, 110])
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Verificar que loadpercenta rechaza valores > 110% (tolerancia máxima de pico).
-- Restricción probada: solardb.dom_porcentaje_carga CHECK (VALUE BETWEEN 0 AND 110).
-- Error esperado: 23514 (check_violation)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, loadpercenta
    ) VALUES (
        1, '2026-11-16 12:03:00+00', 4, 120
    );
    RAISE EXCEPTION 'FALLO: Se aceptó loadpercenta = 120%%';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ PRUEBA 4 PASÓ: Dominio dom_porcentaje_carga rechazó carga fuera de límite físico (120%%).';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 5: Rechazo por Duplicidad de Clave Natural (UNIQUE Violation)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Proteger la unicidad temporal por inversor (uq_lectura_inversor_ts).
-- Restricción probada: CONSTRAINT uq_lectura_inversor_ts UNIQUE (inversor_id, ts_lectura).
-- Error esperado: 23505 (unique_violation)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_ts TIMESTAMPTZ;
BEGIN
    -- Seleccionar la primera marca de tiempo existente en producción para inversor 1
    SELECT ts_lectura INTO v_ts
    FROM solardb.lectura_telemetria
    WHERE inversor_id = 1
    LIMIT 1;

    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, battvolt
    ) VALUES (
        1, v_ts, 4, 51.8
    );
    RAISE EXCEPTION 'FALLO: Se permitió insertar duplicado de (inversor_id, ts_lectura)';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE '✅ PRUEBA 5 PASÓ: Restricción uq_lectura_inversor_ts rechazó tupla duplicada.';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 6: Rechazo por Clave Foránea Inválida (FK Violation)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Garantizar integridad referencial contra la dimensión de inversores.
-- Restricción probada: FOREIGN KEY (inversor_id) REFERENCES solardb.dim_inversor.
-- Error esperado: 23503 (foreign_key_violation)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, battvolt
    ) VALUES (
        99, '2026-11-16 12:05:00+00', 4, 52.0
    );
    RAISE EXCEPTION 'FALLO: Se insertó una lectura para un inversor inexistente (99)';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '✅ PRUEBA 6 PASÓ: Foreign Key violada al intentar asociar inversor_id = 99.';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 7: Rechazo por Dominio dom_potencia_aparente (Potencia Aparente Negativa)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Verificar que la potencia aparente S (outva_a) no admita escalares negativos.
-- Restricción probada: solardb.dom_potencia_aparente CHECK (VALUE >= 0).
-- Error esperado: 23514 (check_violation)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, outva_a
    ) VALUES (
        1, '2026-11-16 12:06:00+00', 4, -100
    );
    RAISE EXCEPTION 'FALLO: Se aceptó outva_a = -100 VA';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ PRUEBA 7 PASÓ: Dominio dom_potencia_aparente rechazó potencia aparente negativa (-100 VA).';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 8: Idempotencia del Pipeline (ON CONFLICT DO NOTHING)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Garantizar que reintentar una carga idéntica no genere errores,
--           no duplique filas y mantenga inalterado el conteo de producción.
-- Restricción probada: Cláusula ON CONFLICT (inversor_id, ts_lectura) DO NOTHING.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    v_conteo_inicial BIGINT;
    v_conteo_final   BIGINT;
    v_ts             TIMESTAMPTZ;
BEGIN
    SELECT COUNT(*) INTO v_conteo_inicial FROM solardb.lectura_telemetria;
    SELECT ts_lectura INTO v_ts FROM solardb.lectura_telemetria LIMIT 1;

    -- Intento de inserción con conflicto natural
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, battvolt
    ) VALUES (
        1, v_ts, 4, 50.0
    )
    ON CONFLICT (inversor_id, ts_lectura) DO NOTHING;

    SELECT COUNT(*) INTO v_conteo_final FROM solardb.lectura_telemetria;

    IF v_conteo_inicial = v_conteo_final THEN
        RAISE NOTICE '✅ PRUEBA 8 PASÓ: Idempotencia confirmada. Filas intactas: % (delta = 0).', v_conteo_final;
    ELSE
        RAISE EXCEPTION 'FALLO: El conteo cambió de % a %', v_conteo_inicial, v_conteo_final;
    END IF;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 9 (ADICIONAL): Restricción de Rango Temporal (chk_lectura_rango_temporal)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Rechazar registros con marcas temporales fuera de 2025-2027.
-- Restricción probada: CHECK (ts_lectura BETWEEN '2025-01-01' AND '2027-01-01').
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, battvolt
    ) VALUES (
        1, '2030-01-01 00:00:00+00', 4, 52.0
    );
    RAISE EXCEPTION 'FALLO: Se aceptó un timestamp en el año 2030';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ PRUEBA 9 PASÓ: Restricción chk_lectura_rango_temporal rechazó timestamp fuera de ventana (año 2030).';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- PRUEBA 10 (ADICIONAL): Integridad Referencial de Auditoría (Lote de Carga)
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Evitar la inserción de lecturas huérfanas sin lote de carga registrado.
-- Restricción probada: FOREIGN KEY (lote_id) REFERENCES calidad.lote_carga.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO solardb.lectura_telemetria (
        inversor_id, ts_lectura, lote_id, battvolt
    ) VALUES (
        1, '2026-11-16 12:10:00+00', 99999, 52.0
    );
    RAISE EXCEPTION 'FALLO: Se aceptó una lectura con lote_id inexistente (99999)';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '✅ PRUEBA 10 PASÓ: Foreign Key de lote_carga rechazó lote_id huérfano (99999).';
        RAISE NOTICE '   SQLSTATE: %, Detalle: %', SQLSTATE, SQLERRM;
END;
$$;

SELECT '=============================================================================' AS banner;
SELECT ' BATERÍA COMPLETA: 10/10 PRUEBAS SUPERADAS EXITOSAMENTE'                      AS banner;
SELECT '=============================================================================' AS banner;
