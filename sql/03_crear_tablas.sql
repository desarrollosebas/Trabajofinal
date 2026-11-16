/*
 * ============================================================================
 *  SolarDB — Script 03: Creación de Tablas de Hechos y Calidad
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Crea las tablas principales del modelo:
 *
 *      Esquema calidad (se crean primero porque son referenciadas por FK):
 *        • calidad.lote_carga          — Auditoría de cada ejecución de carga.
 *        • calidad.regla_calidad       — Catálogo de reglas de validación.
 *        • calidad.registro_cuarentena — Filas rechazadas con trazabilidad.
 *
 *      Esquema solardb:
 *        • solardb.lectura_telemetria  — Tabla de hechos: ~2.9M lecturas.
 *        • solardb.registro_contexto   — Registros de contexto operativo.
 *
 *  Prerequisito : Scripts 00, 01 y 02 (esquemas, dominios, catálogos).
 *
 *  Decisiones de diseño documentadas:
 *      1. PK surrogate (lectura_id BIGINT IDENTITY) + UNIQUE natural
 *         (inversor_id, ts_lectura): permite FK simples y particionamiento
 *         futuro sin cambiar la PK.
 *      2. Las 38 columnas de medición usan dominios personalizados que
 *         validan restricciones físicas a nivel de tipo.
 *      3. Las 4 columnas JSON (battreserve, pvreserve, otherreserve,
 *         grid_reserve) se almacenan como JSONB.
 *      4. lote_id es NOT NULL + ON DELETE RESTRICT: los lotes de auditoría
 *         nunca deben eliminarse.
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  1. calidad.lote_carga — Registro de auditoría por ejecución de carga
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE calidad.lote_carga (
    lote_id           INTEGER  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabla_origen      VARCHAR(40)   NOT NULL,
    fecha_inicio      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    fecha_fin         TIMESTAMPTZ   CHECK (fecha_fin >= fecha_inicio),
    filas_leidas      BIGINT        NOT NULL DEFAULT 0
        CHECK (filas_leidas >= 0),
    filas_aceptadas   BIGINT        NOT NULL DEFAULT 0
        CHECK (filas_aceptadas >= 0),
    filas_rechazadas  BIGINT        NOT NULL DEFAULT 0
        CHECK (filas_rechazadas >= 0),
    estado            VARCHAR(12)   NOT NULL DEFAULT 'EN_CURSO'
        CHECK (estado IN ('EN_CURSO', 'COMPLETADO', 'FALLIDO')),
    observaciones     TEXT
);

COMMENT ON TABLE calidad.lote_carga IS
    'Registro de auditoría para cada ejecución del pipeline de migración. '
    'Permite trazabilidad: cuántas filas se leyeron, aceptaron y rechazaron '
    'en cada lote, con marcas temporales de inicio y fin.';
COMMENT ON COLUMN calidad.lote_carga.tabla_origen IS
    'Nombre de la tabla fuente en SQLite (ej: analog_measurements, context).';
COMMENT ON COLUMN calidad.lote_carga.estado IS
    'Estado del lote: EN_CURSO (procesando), COMPLETADO (éxito), FALLIDO (error).';


-- ═══════════════════════════════════════════════════════════════════════════
--  2. calidad.regla_calidad — Catálogo de reglas de validación
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE calidad.regla_calidad (
    regla_id        SMALLINT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_regla    VARCHAR(30)   NOT NULL UNIQUE,
    descripcion     TEXT          NOT NULL,
    variable_afectada VARCHAR(30),
    severidad       VARCHAR(12)   NOT NULL
        CHECK (severidad IN ('INFO', 'ADVERTENCIA', 'ERROR')),
    accion          VARCHAR(12)   NOT NULL
        CHECK (accion IN ('CUARENTENA', 'ANULAR', 'ACEPTAR')),
    activa          BOOLEAN       NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE calidad.regla_calidad IS
    'Catálogo de reglas de validación que clasifican filas durante '
    'el pipeline de staging. Cada regla tiene severidad y acción.';
COMMENT ON COLUMN calidad.regla_calidad.codigo_regla IS
    'Código mnemónico de la regla (ej: R_TEMP1_IMPOSIBLE, R_P_MAYOR_S).';
COMMENT ON COLUMN calidad.regla_calidad.severidad IS
    'Nivel de severidad: INFO (aceptable), ADVERTENCIA (revisar), ERROR (rechazar).';
COMMENT ON COLUMN calidad.regla_calidad.accion IS
    'Acción a tomar: CUARENTENA (mover a registro_cuarentena), '
    'ANULAR (poner valor en NULL), ACEPTAR (dejar pasar).';


-- ═══════════════════════════════════════════════════════════════════════════
--  3. calidad.registro_cuarentena — Filas rechazadas con trazabilidad
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE calidad.registro_cuarentena (
    cuarentena_id       BIGINT    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lote_id             INTEGER   NOT NULL
        REFERENCES calidad.lote_carga(lote_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    regla_id            SMALLINT  NOT NULL
        REFERENCES calidad.regla_calidad(regla_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    read_ts_original    DOUBLE PRECISION,
    inversor_original   SMALLINT,
    fila_original       JSONB     NOT NULL,
    motivo_rechazo      TEXT      NOT NULL,
    estado              VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'CORREGIDO', 'DESCARTADO', 'REPROCESADO')),
    fecha_registro      TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_resolucion    TIMESTAMPTZ
        CHECK (fecha_resolucion >= fecha_registro)
);

COMMENT ON TABLE calidad.registro_cuarentena IS
    'Almacena las filas rechazadas por el pipeline de validación. '
    'Cada registro conserva la fila original completa como JSONB, '
    'la regla que la rechazó y un ciclo de vida de resolución. '
    'Línea de especialización SolarDB: trazabilidad completa.';
COMMENT ON COLUMN calidad.registro_cuarentena.fila_original IS
    'Copia completa de la fila rechazada en formato JSONB. '
    'Permite auditoría y reprocesamiento sin pérdida de datos.';
COMMENT ON COLUMN calidad.registro_cuarentena.estado IS
    'Ciclo de vida: PENDIENTE → CORREGIDO | DESCARTADO | REPROCESADO.';


-- ═══════════════════════════════════════════════════════════════════════════
--  4. solardb.lectura_telemetria — Tabla de hechos principal
-- ═══════════════════════════════════════════════════════════════════════════
--
--  Contiene hasta ~2,989,759 lecturas de telemetría de los inversores
--  solares del campus CUHK-Shenzhen.
--
--  Las 38 columnas numéricas de medición conservan los nombres originales
--  del dataset SQLite para facilitar la trazabilidad. Cada una usa un
--  dominio personalizado que valida restricciones físicas.
--
--  Las 4 columnas JSON (battreserve, pvreserve, otherreserve, grid_reserve)
--  se convierten de TEXT (SQLite) a JSONB (PostgreSQL).
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE solardb.lectura_telemetria (

    -- ── Columnas de control ─────────────────────────────────────────────
    lectura_id      BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inversor_id     SMALLINT    NOT NULL
        REFERENCES solardb.dim_inversor(inversor_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    ts_lectura      TIMESTAMPTZ NOT NULL,
    lote_id         INTEGER     NOT NULL
        REFERENCES calidad.lote_carga(lote_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    -- ── Batería ─────────────────────────────────────────────────────────
    battvolt        solardb.dom_voltaje,            -- V  (voltaje terminal)
    battcurr        solardb.dom_corriente,          -- A  (con signo: +=descarga)
    battsoc         solardb.dom_porcentaje,         -- %  (estado de carga)
    battchgpower    solardb.dom_potencia_activa,    -- W  (potencia de carga)
    battreserve     JSONB,                          -- JSON payload reservado

    -- ── Carga (line + PV) ───────────────────────────────────────────────
    linechgcurr     solardb.dom_corriente_no_neg,   -- A  (corriente carga red)
    pvchgcurr       solardb.dom_corriente_no_neg,   -- A  (corriente carga PV)

    -- ── Panel fotovoltaico (PV canal 1) ─────────────────────────────────
    pv1volt         solardb.dom_voltaje,            -- V
    pv1curr         solardb.dom_corriente_no_neg,   -- A
    pv1power        solardb.dom_potencia_activa_no_neg, -- W
    pvreserve       JSONB,                          -- JSON payload reservado

    -- ── Salida del inversor (fase A) ────────────────────────────────────
    outvolta        solardb.dom_voltaje,            -- V  (voltaje salida)
    outcurra        solardb.dom_corriente_no_neg,   -- A  (corriente salida)
    outfreq         solardb.dom_frecuencia,         -- Hz (frecuencia salida)
    invcurra        solardb.dom_corriente_no_neg,   -- A  (corriente inversor)
    outw_a          solardb.dom_potencia_activa_no_neg,  -- W  (P salida)
    outva_a         solardb.dom_potencia_aparente,  -- VA (S salida)
    loadpercenta    solardb.dom_porcentaje_carga,   -- %  (carga fase A)
    normalloadw_a   solardb.dom_potencia_activa_no_neg,  -- W  (carga normal)

    -- ── Salida total (suma de fases) ────────────────────────────────────
    outsumw         solardb.dom_potencia_activa_no_neg,  -- W  (P total)
    outsumva        solardb.dom_potencia_aparente,  -- VA (S total)
    sumloadpercent  solardb.dom_porcentaje_carga,   -- %  (carga total)

    -- ── Potencia generada (fase A) ──────────────────────────────────────
    generatedpowerp_a  solardb.dom_potencia_activa_no_neg,  -- W  (P generada)
    generatedpowers_a  solardb.dom_potencia_aparente,       -- VA (S generada)
    generatedpowerq_a  solardb.dom_potencia_reactiva,       -- VAR(Q generada)

    -- ── Línea / red eléctrica (fase A) ──────────────────────────────────
    linevolta       solardb.dom_voltaje,            -- V  (voltaje red)
    linecurra       solardb.dom_corriente_no_neg,   -- A  (corriente red)
    linefreq        solardb.dom_frecuencia,         -- Hz (frecuencia red)
    linepowerva_a   solardb.dom_potencia_aparente,  -- VA (S red)
    linepowerw_a    solardb.dom_potencia_activa,    -- W  (P red)

    -- ── Bus DC ──────────────────────────────────────────────────────────
    busvoltp        solardb.dom_voltaje,            -- V  (bus positivo)
    busvoltn        solardb.dom_voltaje,            -- V  (bus negativo)

    -- ── Temperaturas ────────────────────────────────────────────────────
    temper1         solardb.dom_temperatura,         -- °C (sensor 1)
    temper2         solardb.dom_temperatura,         -- °C (sensor 2)
    temper3         solardb.dom_temperatura,         -- °C (sensor 3)
    temper4         solardb.dom_temperatura,         -- °C (sensor 4)

    -- ── Otros ───────────────────────────────────────────────────────────
    sir             solardb.dom_resistencia_aislamiento,  -- kΩ
    fanduty         solardb.dom_porcentaje,          -- % (ciclo ventilador)
    otherreserve    JSONB,                           -- JSON payload reservado

    -- ── Grid (red, medición separada) ───────────────────────────────────
    gridpowerw_a    solardb.dom_potencia_activa,     -- W  (P red directa)
    gridcurr_a      solardb.dom_corriente_no_neg,    -- A  (corriente red)
    grid_reserve    JSONB,                           -- JSON payload reservado

    -- ── Restricción de unicidad natural ─────────────────────────────────
    CONSTRAINT uq_lectura_inversor_ts
        UNIQUE (inversor_id, ts_lectura)
);

COMMENT ON TABLE solardb.lectura_telemetria IS
    'Tabla de hechos principal de SolarDB. Cada fila es una lectura '
    'de telemetría de un inversor solar en un instante dado. '
    'Fuente: analog_measurements de OpenCEM v1.0.0 (2,989,759 filas). '
    'Período: 2025-07-12 a 2026-07-13, cadencia mediana: 12.58 s. '
    'PK surrogate + UNIQUE natural (inversor_id, ts_lectura) '
    'garantiza idempotencia de la migración.';


-- ═══════════════════════════════════════════════════════════════════════════
--  5. solardb.registro_contexto — Eventos de contexto operativo
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.registro_contexto (
    contexto_id             BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_contexto_id        SMALLINT    NOT NULL
        REFERENCES solardb.cat_tipo_contexto(tipo_contexto_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    ts_contexto             TIMESTAMPTZ,
    valor                   JSONB       NOT NULL
        CHECK (jsonb_typeof(valor) = 'object'),
    contiene_datos_personales BOOLEAN   NOT NULL DEFAULT FALSE,
    lote_id                 INTEGER     NOT NULL
        REFERENCES calidad.lote_carga(lote_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

COMMENT ON TABLE solardb.registro_contexto IS
    'Registros de contexto operativo del campus. '
    'Fuente: tabla "context" de OpenCEM (25,178 filas). '
    'Almacena eventos de log, carga de trabajo manual, '
    'y contexto derivado en formato JSONB.';
COMMENT ON COLUMN solardb.registro_contexto.contiene_datos_personales IS
    'Flag de Ley 1581/2012 (Colombia): TRUE si el registro puede '
    'contener datos personales (ej: fuente wsl_bash_history con '
    'rutas de usuario). Permite filtrado en consultas.';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_solardb INTEGER;
    v_calidad INTEGER;
BEGIN
    SELECT count(*) INTO v_solardb
    FROM information_schema.tables
    WHERE table_schema = 'solardb' AND table_type = 'BASE TABLE';

    SELECT count(*) INTO v_calidad
    FROM information_schema.tables
    WHERE table_schema = 'calidad' AND table_type = 'BASE TABLE';

    RAISE NOTICE '✓ Tablas en solardb: %  |  Tablas en calidad: %',
        v_solardb, v_calidad;
END
$$;
