/*
 * ============================================================================
 *  SolarDB — Script 08: Creación de Tablas de Staging
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Crea las tablas de staging (zona de aterrizaje) que reciben los
 *      datos crudos desde SQLite SIN restricciones de dominio ni CHECK.
 *
 *      Diseño clave:
 *        • TODAS las columnas de medición son DOUBLE PRECISION (sin dominio).
 *        • Las columnas JSON se reciben como TEXT (se convierten a JSONB
 *          al mover a producción).
 *        • estado_validacion permite clasificar cada fila.
 *        • Después de la migración, staging puede truncarse sin afectar
 *          producción.
 *
 *  Prerequisito : Scripts 00 y 03 (esquemas y calidad.lote_carga).
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  1. staging.staging_telemetria — Zona de aterrizaje para telemetría
-- ═══════════════════════════════════════════════════════════════════════════
-- NOTA: Los nombres de columna coinciden con el dataset SQLite original
-- para facilitar la carga directa con COPY o INSERT.

CREATE TABLE staging.staging_telemetria (
    stg_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lote_id             INTEGER NOT NULL
        REFERENCES calidad.lote_carga(lote_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    -- ── Columnas originales del SQLite (44) ─────────────────────────────
    -- Tipos flexibles: todo DOUBLE PRECISION o TEXT, sin dominios.

    read_ts             DOUBLE PRECISION,       -- Unix timestamp
    inverter            DOUBLE PRECISION,       -- 1 o 2 (como float)

    -- Batería
    battvolt            DOUBLE PRECISION,
    battcurr            DOUBLE PRECISION,
    battsoc             DOUBLE PRECISION,
    battchgpower        DOUBLE PRECISION,
    battreserve         TEXT,                   -- JSON como texto

    -- Carga
    linechgcurr         DOUBLE PRECISION,
    pvchgcurr           DOUBLE PRECISION,

    -- PV
    pv1volt             DOUBLE PRECISION,
    pv1curr             DOUBLE PRECISION,
    pv1power            DOUBLE PRECISION,
    pvreserve           TEXT,

    -- Salida
    outvolta            DOUBLE PRECISION,
    outcurra            DOUBLE PRECISION,
    outfreq             DOUBLE PRECISION,
    invcurra            DOUBLE PRECISION,
    outw_a              DOUBLE PRECISION,
    outva_a             DOUBLE PRECISION,
    loadpercenta        DOUBLE PRECISION,
    normalloadw_a       DOUBLE PRECISION,

    -- Totales
    outsumw             DOUBLE PRECISION,
    outsumva            DOUBLE PRECISION,
    sumloadpercent      DOUBLE PRECISION,

    -- Generada
    generatedpowerp_a   DOUBLE PRECISION,
    generatedpowers_a   DOUBLE PRECISION,
    generatedpowerq_a   DOUBLE PRECISION,

    -- Línea/Red
    linevolta           DOUBLE PRECISION,
    linecurra           DOUBLE PRECISION,
    linefreq            DOUBLE PRECISION,
    linepowerva_a       DOUBLE PRECISION,
    linepowerw_a        DOUBLE PRECISION,

    -- Bus DC
    busvoltp            DOUBLE PRECISION,
    busvoltn            DOUBLE PRECISION,

    -- Temperaturas
    temper1             DOUBLE PRECISION,
    temper2             DOUBLE PRECISION,
    temper3             DOUBLE PRECISION,
    temper4             DOUBLE PRECISION,

    -- Otros
    sir                 DOUBLE PRECISION,
    fanduty             DOUBLE PRECISION,
    otherreserve        TEXT,

    -- Grid
    gridpowerw_a        DOUBLE PRECISION,
    gridcurr_a          DOUBLE PRECISION,
    grid_reserve        TEXT,

    -- ── Columna de control de validación ────────────────────────────────
    estado_validacion   VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado_validacion IN ('PENDIENTE', 'VALIDA', 'RECHAZADA'))
);

COMMENT ON TABLE staging.staging_telemetria IS
    'Zona de aterrizaje para datos de telemetría desde SQLite. '
    'Sin restricciones de dominio: acepta cualquier valor para '
    'posterior clasificación por el pipeline de validación. '
    'Después de completar la migración, puede truncarse.';
COMMENT ON COLUMN staging.staging_telemetria.read_ts IS
    'Marca temporal como DOUBLE PRECISION (Unix epoch en UTC). '
    'Se convierte a TIMESTAMPTZ con to_timestamp() al mover a producción.';
COMMENT ON COLUMN staging.staging_telemetria.estado_validacion IS
    'Estado de clasificación: PENDIENTE (no procesada), '
    'VALIDA (pasa reglas), RECHAZADA (viola alguna regla).';


-- ═══════════════════════════════════════════════════════════════════════════
--  2. staging.staging_contexto — Zona de aterrizaje para contexto
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE staging.staging_contexto (
    stg_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lote_id             INTEGER NOT NULL
        REFERENCES calidad.lote_carga(lote_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Columnas originales del SQLite (context tiene 5 columnas)
    read_ts             DOUBLE PRECISION,       -- Unix timestamp
    source              TEXT,                   -- Fuente del contexto
    key                 TEXT,                   -- Clave del evento
    value               TEXT,                   -- Valor (JSON como texto)
    description         TEXT,                   -- Descripción

    estado_validacion   VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado_validacion IN ('PENDIENTE', 'VALIDA', 'RECHAZADA'))
);

COMMENT ON TABLE staging.staging_contexto IS
    'Zona de aterrizaje para registros de contexto operativo desde '
    'SQLite. Se procesan y transforman antes de insertar en '
    'solardb.registro_contexto.';


-- ═══════════════════════════════════════════════════════════════════════════
--  3. Índice auxiliar en staging para el pipeline
-- ═══════════════════════════════════════════════════════════════════════════
-- Acelera las consultas del pipeline que filtran por (lote_id, estado).

CREATE INDEX idx_stg_telemetria_lote_estado
    ON staging.staging_telemetria (lote_id, estado_validacion);

CREATE INDEX idx_stg_contexto_lote_estado
    ON staging.staging_contexto (lote_id, estado_validacion);


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'staging' AND table_type = 'BASE TABLE';
    RAISE NOTICE '✓ Tablas de staging creadas: %', v_count;
END
$$;
