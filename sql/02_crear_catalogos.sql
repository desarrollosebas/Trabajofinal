/*
 * ============================================================================
 *  SolarDB — Script 02: Creación de Tablas de Catálogo (Dimensiones)
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Crea las tablas dimensionales y catálogos de referencia:
 *        • solardb.dim_sitio           — Sitio físico de la microrred.
 *        • solardb.dim_subsistema      — Subsistema eléctrico dentro del sitio.
 *        • solardb.dim_inversor        — Inversor solar híbrido.
 *        • solardb.cat_tipo_contexto   — Catálogo de fuentes de contexto.
 *        • solardb.cat_unidad_medida   — Catálogo de unidades de medida.
 *        • solardb.cat_variable_fisica — Catálogo de variables telemetricas.
 *
 *  Prerequisito : Scripts 00 y 01 (esquemas y dominios).
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  1. dim_sitio — Sitio físico de la microrred
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.dim_sitio (
    sitio_id        SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_sitio    VARCHAR(100)  NOT NULL UNIQUE,
    ciudad          VARCHAR(60)   NOT NULL,
    pais            VARCHAR(60)   NOT NULL,
    zona_horaria    VARCHAR(40)   -- Ej: 'Asia/Shanghai'
);

COMMENT ON TABLE  solardb.dim_sitio IS
    'Sitio físico donde se ubica la microrred solar. '
    'Dataset OpenCEM: campus CUHK-Shenzhen, China.';
COMMENT ON COLUMN solardb.dim_sitio.zona_horaria IS
    'Zona horaria IANA del sitio. Las marcas temporales del dataset '
    'están en UTC; esta columna facilita conversiones a hora local.';


-- ═══════════════════════════════════════════════════════════════════════════
--  2. dim_subsistema — Subsistema eléctrico dentro del sitio
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.dim_subsistema (
    subsistema_id               SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sitio_id                    SMALLINT      NOT NULL
        REFERENCES solardb.dim_sitio(sitio_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    nombre_subsistema           VARCHAR(100)  NOT NULL UNIQUE,
    carga_alimentada            VARCHAR(120)  NOT NULL,
    num_paneles                 SMALLINT      NOT NULL CHECK (num_paneles > 0),
    potencia_panel_w            SMALLINT      NOT NULL CHECK (potencia_panel_w > 0),
    quimica_bateria             VARCHAR(30)   NOT NULL,
    capacidad_bateria_ah        NUMERIC(6,1)  CHECK (capacidad_bateria_ah > 0),
    voltaje_nominal_bateria_v   NUMERIC(4,1)  CHECK (voltaje_nominal_bateria_v > 0)
);

COMMENT ON TABLE solardb.dim_subsistema IS
    'Subsistema eléctrico: conjunto de paneles solares, batería e '
    'inversor que alimenta una carga específica.';
COMMENT ON COLUMN solardb.dim_subsistema.carga_alimentada IS
    'Descripción de la carga eléctrica (ej: "Estaciones de trabajo", "HVAC").';
COMMENT ON COLUMN solardb.dim_subsistema.quimica_bateria IS
    'Química de la batería: LiFePO4, Pb-ácido, Li-ion, etc.';


-- ═══════════════════════════════════════════════════════════════════════════
--  3. dim_inversor — Inversor solar híbrido
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.dim_inversor (
    inversor_id             SMALLINT PRIMARY KEY CHECK (inversor_id IN (1, 2)),
    subsistema_id           SMALLINT      NOT NULL UNIQUE
        REFERENCES solardb.dim_subsistema(subsistema_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    modelo                  VARCHAR(60),
    fabricante              VARCHAR(60),
    potencia_nominal_w      INTEGER       CHECK (potencia_nominal_w > 0),
    frecuencia_nominal_hz   SMALLINT      NOT NULL DEFAULT 50
        CHECK (frecuencia_nominal_hz > 0),
    tension_nominal_red_v   VARCHAR(10)
);

COMMENT ON TABLE solardb.dim_inversor IS
    'Inversor solar híbrido del subsistema. PK = inversor_id (1 o 2), '
    'coincide con el campo "inverter" del dataset SQLite.';
COMMENT ON COLUMN solardb.dim_inversor.inversor_id IS
    'Identificador lógico del inversor: 1 o 2. Viene directamente '
    'del campo "inverter" en analog_measurements de OpenCEM.';
COMMENT ON COLUMN solardb.dim_inversor.frecuencia_nominal_hz IS
    'Frecuencia nominal de la red eléctrica: 50 Hz (China).';


-- ═══════════════════════════════════════════════════════════════════════════
--  4. cat_tipo_contexto — Catálogo de fuentes de contexto
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.cat_tipo_contexto (
    tipo_contexto_id    SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_fuente       VARCHAR(40)  NOT NULL UNIQUE,
    descripcion         TEXT         NOT NULL,
    contiene_pii        BOOLEAN      NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE solardb.cat_tipo_contexto IS
    'Catálogo de tipos/fuentes de contexto operativo encontrados '
    'en la tabla "context" del dataset OpenCEM.';
COMMENT ON COLUMN solardb.cat_tipo_contexto.codigo_fuente IS
    'Código de la fuente de contexto tal como aparece en el dataset '
    '(ej: workstation2_log, windows_event_log, manual_entry, etc.).';
COMMENT ON COLUMN solardb.cat_tipo_contexto.contiene_pii IS
    'TRUE si esta fuente puede contener datos personales (PII). '
    'Ej: wsl_bash_history puede contener rutas de usuario. '
    'Referencia: Ley 1581 de 2012 (Colombia) — Protección de datos.';


-- ═══════════════════════════════════════════════════════════════════════════
--  5. cat_unidad_medida — Catálogo de unidades de medida
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.cat_unidad_medida (
    unidad_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    simbolo     VARCHAR(10)  NOT NULL UNIQUE,
    nombre      VARCHAR(40)  NOT NULL,
    magnitud    VARCHAR(40)  NOT NULL
);

COMMENT ON TABLE solardb.cat_unidad_medida IS
    'Catálogo de unidades de medida del Sistema Internacional (SI) '
    'y derivadas, utilizadas por las variables de telemetría.';


-- ═══════════════════════════════════════════════════════════════════════════
--  6. cat_variable_fisica — Catálogo de variables telemétricas
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE solardb.cat_variable_fisica (
    variable_id         SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_columna      VARCHAR(30)   NOT NULL UNIQUE,
    descripcion         TEXT          NOT NULL,
    unidad_id           SMALLINT      NOT NULL
        REFERENCES solardb.cat_unidad_medida(unidad_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    dominio_pg          VARCHAR(40),
    rango_min_observado DOUBLE PRECISION,
    rango_max_observado DOUBLE PRECISION
        CHECK (rango_max_observado >= rango_min_observado),
    fuente_unidad       VARCHAR(120)  NOT NULL
        DEFAULT 'column_dictionary.json, campo unit'
);

COMMENT ON TABLE solardb.cat_variable_fisica IS
    'Catálogo de las 38 variables físicas de medición que componen '
    'la tabla lectura_telemetria. Incluye unidad, dominio PostgreSQL '
    'asignado y rangos observados en el dataset real.';
COMMENT ON COLUMN solardb.cat_variable_fisica.nombre_columna IS
    'Nombre exacto de la columna en lectura_telemetria y en el '
    'dataset SQLite original (ej: battvolt, linefreq).';
COMMENT ON COLUMN solardb.cat_variable_fisica.dominio_pg IS
    'Nombre del dominio PostgreSQL aplicado a esta variable '
    '(ej: dom_voltaje, dom_frecuencia). NULL si no tiene dominio.';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'solardb'
      AND table_type = 'BASE TABLE';
    RAISE NOTICE '✓ Tablas de catálogo creadas en solardb: %', v_count;
END
$$;
