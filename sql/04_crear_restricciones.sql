/*
 * ============================================================================
 *  SolarDB — Script 04: Restricciones Adicionales a Nivel de Tabla
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Agrega restricciones CHECK a nivel de tabla (cross-column) que
 *      no pueden expresarse en un dominio (que opera sobre una sola
 *      columna). Estas restricciones complementan los dominios.
 *
 *      NOTA IMPORTANTE SOBRE P ≤ S:
 *      La regla "potencia activa P ≤ potencia aparente S" NO se implementa
 *      como CHECK constraint en la tabla de producción. ¿Por qué?
 *        • En el dataset real, 3,811 filas violan P > S.
 *        • Un CHECK rechazaría esas filas silenciosamente.
 *        • En SolarDB, esas filas van a CUARENTENA con trazabilidad.
 *        • La regla se aplica en el pipeline de staging (script 07).
 *
 *  Prerequisito : Script 03 (tablas creadas).
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  1. Restricciones cross-column en lectura_telemetria
-- ═══════════════════════════════════════════════════════════════════════════

-- Restricción: si battsoc es 100% (batería llena), battchgpower debe ser
-- ≤ valor de flotación (aceptamos NULL o cualquier valor porque el inversor
-- puede seguir reportando potencia residual de flotación).
-- DESACTIVADA: dejamos como documentación. En la práctica, el inversor
-- reporta valores transitorios durante la transición a flotación.

-- Restricción: ts_lectura debe estar en el rango temporal del dataset.
-- Período conocido: 2025-07-12 a 2026-07-13 (con margen).
ALTER TABLE solardb.lectura_telemetria
    ADD CONSTRAINT chk_lectura_rango_temporal
    CHECK (ts_lectura BETWEEN '2025-01-01'::TIMESTAMPTZ
                           AND '2027-01-01'::TIMESTAMPTZ);

COMMENT ON CONSTRAINT chk_lectura_rango_temporal
    ON solardb.lectura_telemetria IS
    'Validación de rango temporal: el dataset OpenCEM cubre '
    '2025-07-12 a 2026-07-13. Se aplica margen amplio (2025-01 a 2027-01) '
    'para permitir futuros datasets sin modificar la restricción.';


-- ═══════════════════════════════════════════════════════════════════════════
--  2. Restricciones en registro_cuarentena
-- ═══════════════════════════════════════════════════════════════════════════

-- Si el estado es CORREGIDO o REPROCESADO, debe tener fecha_resolucion.
ALTER TABLE calidad.registro_cuarentena
    ADD CONSTRAINT chk_cuarentena_resolucion_coherente
    CHECK (
        (estado IN ('PENDIENTE', 'DESCARTADO'))
        OR (fecha_resolucion IS NOT NULL)
    );

COMMENT ON CONSTRAINT chk_cuarentena_resolucion_coherente
    ON calidad.registro_cuarentena IS
    'Si una fila en cuarentena fue CORREGIDA o REPROCESADA, '
    'debe tener fecha de resolución registrada.';


-- ═══════════════════════════════════════════════════════════════════════════
--  3. Restricciones en lote_carga
-- ═══════════════════════════════════════════════════════════════════════════

-- La suma de filas aceptadas + rechazadas no puede exceder filas leídas.
ALTER TABLE calidad.lote_carga
    ADD CONSTRAINT chk_lote_conteo_coherente
    CHECK (filas_aceptadas + filas_rechazadas <= filas_leidas);

COMMENT ON CONSTRAINT chk_lote_conteo_coherente
    ON calidad.lote_carga IS
    'Invariante de auditoría: filas_aceptadas + filas_rechazadas '
    'nunca puede exceder filas_leidas.';

-- Si estado es COMPLETADO, debe tener fecha_fin.
ALTER TABLE calidad.lote_carga
    ADD CONSTRAINT chk_lote_fin_coherente
    CHECK (
        estado != 'COMPLETADO'
        OR fecha_fin IS NOT NULL
    );

COMMENT ON CONSTRAINT chk_lote_fin_coherente
    ON calidad.lote_carga IS
    'Un lote COMPLETADO debe tener fecha_fin registrada.';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.table_constraints
    WHERE constraint_type = 'CHECK'
      AND table_schema IN ('solardb', 'calidad', 'staging')
      AND constraint_name LIKE 'chk_%';
    RAISE NOTICE '✓ Restricciones CHECK adicionales (chk_*): %', v_count;
END
$$;
