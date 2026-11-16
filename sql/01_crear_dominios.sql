/*
 * ============================================================================
 *  SolarDB — Script 01: Creación de Dominios Personalizados
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Define 12 dominios personalizados (CREATE DOMAIN) en el esquema
 *      solardb.  Cada dominio encapsula un tipo base + restricción CHECK
 *      que refleja las leyes físicas del sistema de microrred solar.
 *
 *      Línea de especialización: «dominios personalizados» — el DBMS
 *      rechaza automáticamente cualquier valor que viole la restricción
 *      del dominio, sin necesidad de código adicional en la aplicación.
 *
 *  Justificación de tipos base:
 *      • DOUBLE PRECISION para magnitudes analógicas continuas (voltaje,
 *        corriente, frecuencia, temperatura): coincide con el tipo REAL
 *        de SQLite (IEEE 754 de 64 bits) y evita truncamiento de
 *        decimales que ocurriría con NUMERIC(p,s).
 *      • SMALLINT / INTEGER para magnitudes discretas (porcentajes enteros,
 *        potencias en vatios enteros): coincide con INTEGER de SQLite y
 *        ocupa menos espacio.
 *
 *  Prerequisito : Script 00 (esquemas creados).
 *  Idempotente  : No — falla si los dominios ya existen.
 *                 Para re-ejecutar: DROP DOMAIN ... CASCADE primero.
 * ============================================================================
 */

-- ─── Dominios de voltaje ────────────────────────────────────────────────────

-- dom_voltaje: voltaje DC o AC, siempre ≥ 0.
-- Aplica a: battvolt, pv1volt, outvolta, linevolta, busvoltp, busvoltn.
CREATE DOMAIN solardb.dom_voltaje AS DOUBLE PRECISION
    CHECK (VALUE >= 0);
COMMENT ON DOMAIN solardb.dom_voltaje IS
    'Voltaje en voltios (V). Restricción: ≥ 0. '
    'Fuente: column_dictionary.json — unidad V, valores observados ≥ 0.';


-- ─── Dominios de corriente ──────────────────────────────────────────────────

-- dom_corriente: corriente con signo (positivo = descarga, negativo = carga).
-- Aplica a: battcurr (corriente de batería con signo).
CREATE DOMAIN solardb.dom_corriente AS DOUBLE PRECISION;
    -- Sin CHECK: battcurr puede ser positivo (descarga) o negativo (carga).
COMMENT ON DOMAIN solardb.dom_corriente IS
    'Corriente con signo en amperios (A). Sin restricción de rango: '
    'positivo = descarga de batería, negativo = carga. '
    'Fuente: column_dictionary.json — battcurr "Signed battery current".';

-- dom_corriente_no_neg: corriente que físicamente no puede ser negativa.
-- Aplica a: linechgcurr, pvchgcurr, pv1curr, outcurra, invcurra,
--           linecurra, gridcurr_a.
CREATE DOMAIN solardb.dom_corriente_no_neg AS DOUBLE PRECISION
    CHECK (VALUE >= 0);
COMMENT ON DOMAIN solardb.dom_corriente_no_neg IS
    'Corriente no negativa en amperios (A). Restricción: ≥ 0. '
    'Aplica a corrientes de carga, PV, salida, red — siempre positivas. '
    'Fuente: column_dictionary.json — valores observados ≥ 0.';


-- ─── Dominios de potencia ───────────────────────────────────────────────────

-- dom_potencia_activa: potencia activa P (W) con signo.
-- Aplica a: battchgpower, linepowerw_a, gridpowerw_a.
-- Permite negativos: potencia inyectada vs consumida.
CREATE DOMAIN solardb.dom_potencia_activa AS INTEGER;
COMMENT ON DOMAIN solardb.dom_potencia_activa IS
    'Potencia activa P en vatios (W), con signo. '
    'Negativo = inyección a red, positivo = consumo. '
    'Sin restricción de rango.';

-- dom_potencia_activa_no_neg: potencia activa que no debe ser negativa.
-- Aplica a: pv1power, outw_a, normalloadw_a, outsumw, generatedpowerp_a.
CREATE DOMAIN solardb.dom_potencia_activa_no_neg AS INTEGER
    CHECK (VALUE >= 0);
COMMENT ON DOMAIN solardb.dom_potencia_activa_no_neg IS
    'Potencia activa P en vatios (W), no negativa. Restricción: ≥ 0. '
    'Aplica a PV, salida, carga normal — siempre ≥ 0.';

-- dom_potencia_aparente: potencia aparente S (VA), siempre ≥ 0.
-- Aplica a: outva_a, outsumva, linepowerva_a, generatedpowers_a.
CREATE DOMAIN solardb.dom_potencia_aparente AS INTEGER
    CHECK (VALUE >= 0);
COMMENT ON DOMAIN solardb.dom_potencia_aparente IS
    'Potencia aparente S en voltamperios (VA). Restricción: ≥ 0. '
    'S = |V| × |I| ≥ 0 por definición.';

-- dom_potencia_reactiva: potencia reactiva Q (VAR), con signo.
-- Aplica a: generatedpowerq_a.
CREATE DOMAIN solardb.dom_potencia_reactiva AS INTEGER;
COMMENT ON DOMAIN solardb.dom_potencia_reactiva IS
    'Potencia reactiva Q en voltamperios reactivos (VAR). '
    'Positivo = carga inductiva, negativo = carga capacitiva. '
    'Sin restricción de rango.';


-- ─── Dominio de frecuencia ──────────────────────────────────────────────────

-- dom_frecuencia: frecuencia eléctrica (Hz), ≥ 0.
-- Aplica a: outfreq, linefreq.
-- NOTA: linefreq = 0 Hz es legítimo (modo isla / standby). Se permite 0.
CREATE DOMAIN solardb.dom_frecuencia AS DOUBLE PRECISION
    CHECK (VALUE >= 0);
COMMENT ON DOMAIN solardb.dom_frecuencia IS
    'Frecuencia eléctrica en hercios (Hz). Restricción: ≥ 0. '
    'Valor 0 Hz es legítimo: indica modo isla o standby del inversor. '
    'Evidencia: 342,592 filas con linefreq = 0 (diagnóstico de calidad).';


-- ─── Dominio de temperatura ─────────────────────────────────────────────────

-- dom_temperatura: temperatura de sensores (°C), SIN restricción de rango.
-- Aplica a: temper1, temper2, temper3, temper4.
-- DECISIÓN DE DISEÑO: NO se pone CHECK aquí. Los valores anómalos
-- (ej: temper1 = -20.3°C, 38 filas) se detectan en el pipeline de
-- staging y van a cuarentena. Esto es intencional: el dominio valida
-- el tipo, la regla de calidad clasifica la anomalía.
CREATE DOMAIN solardb.dom_temperatura AS DOUBLE PRECISION;
COMMENT ON DOMAIN solardb.dom_temperatura IS
    'Temperatura en grados Celsius (°C). Sin restricción de rango en '
    'el dominio: las anomalías (ej: -20.3°C por fallo de sensor) se '
    'detectan mediante reglas de calidad en el pipeline de staging y '
    'se envían a cuarentena. Decisión: separar validación de tipo vs '
    'validación de negocio.';


-- ─── Dominios de porcentaje ─────────────────────────────────────────────────

-- dom_porcentaje: porcentaje estándar [0, 100].
-- Aplica a: battsoc (estado de carga), fanduty (ciclo de ventilador).
CREATE DOMAIN solardb.dom_porcentaje AS SMALLINT
    CHECK (VALUE BETWEEN 0 AND 100);
COMMENT ON DOMAIN solardb.dom_porcentaje IS
    'Porcentaje estándar [0–100]. Tipo SMALLINT (2 bytes). '
    'Aplica a SOC de batería y duty cycle de ventilador.';

-- dom_porcentaje_carga: porcentaje de carga, permite hasta 110%.
-- Aplica a: loadpercenta, sumloadpercent.
-- Justificación del 110%: el valor máximo observado en el dataset es 110;
-- esto ocurre por picos transitorios de carga o tolerancia del sensor.
CREATE DOMAIN solardb.dom_porcentaje_carga AS SMALLINT
    CHECK (VALUE BETWEEN 0 AND 110);
COMMENT ON DOMAIN solardb.dom_porcentaje_carga IS
    'Porcentaje de carga del inversor [0–110]. Permite hasta 110%% '
    'porque se observaron valores de 110 en el dataset real (picos '
    'transitorios de carga). Valor máximo observado: 110.';


-- ─── Dominio de resistencia de aislamiento ──────────────────────────────────

-- dom_resistencia_aislamiento: SIR (kΩ), siempre ≥ 0.
-- Aplica a: sir.
CREATE DOMAIN solardb.dom_resistencia_aislamiento AS INTEGER
    CHECK (VALUE >= 0);
COMMENT ON DOMAIN solardb.dom_resistencia_aislamiento IS
    'Resistencia de aislamiento SIR en kiloohmios (kΩ). '
    'Restricción: ≥ 0. Valores altos indican buen aislamiento.';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'solardb'
      AND t.typtype = 'd';  -- 'd' = domain
    RAISE NOTICE '✓ Dominios creados en solardb: %', v_count;
END
$$;
