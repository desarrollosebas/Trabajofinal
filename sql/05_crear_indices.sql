/*
 * ============================================================================
 *  SolarDB — Script 05: Creación de Índices
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Crea índices justificados para optimizar las consultas más
 *      frecuentes del sistema. Cada índice incluye su justificación.
 *
 *      NOTA: Los índices se crean DESPUÉS de la carga masiva (bulk load)
 *      para evitar penalización de rendimiento durante los INSERT.
 *      En producción, ejecutar este script después del script de migración.
 *      Para pruebas, se puede ejecutar antes.
 *
 *  Prerequisito : Script 03 (tablas creadas).
 *
 *  Índices automáticos (no se crean aquí, ya existen):
 *      • PK de cada tabla → índice B-tree implícito.
 *      • UNIQUE(inversor_id, ts_lectura) → índice B-tree implícito.
 * ============================================================================
 */

-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 1: B-tree en lectura_telemetria(ts_lectura)
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Las consultas de negocio más frecuentes filtran por rango temporal
--   (ej: "energía generada entre fecha X y fecha Y", "promedios por día").
--   El UNIQUE(inversor_id, ts_lectura) cubre consultas que filtran por
--   inversor + tiempo, pero NO cubre consultas que filtran SOLO por tiempo.
--   Este índice soporta:
--     • WHERE ts_lectura BETWEEN ... AND ...
--     • ORDER BY ts_lectura
--     • Consultas de resumen diario/horario sin filtro de inversor.
--
CREATE INDEX idx_lectura_ts
    ON solardb.lectura_telemetria (ts_lectura);

COMMENT ON INDEX solardb.idx_lectura_ts IS
    'B-tree en ts_lectura para consultas de rango temporal '
    'sin filtro de inversor (resúmenes diarios, ventanas de tiempo).';


-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 2: B-tree en lectura_telemetria(lote_id)
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Permite rastrear rápidamente qué lecturas pertenecen a un lote
--   específico. Útil para:
--     • Auditoría: "mostrar todas las filas del lote N"
--     • Rollback: "eliminar filas del lote fallido N"
--     • Dashboard de calidad: contar filas por lote.
--
CREATE INDEX idx_lectura_lote
    ON solardb.lectura_telemetria (lote_id);

COMMENT ON INDEX solardb.idx_lectura_lote IS
    'B-tree en lote_id para trazabilidad de auditoría: '
    'identificar filas por lote de carga.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 3: GIN en registro_contexto(valor) con jsonb_path_ops
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Los registros de contexto almacenan eventos heterogéneos como JSONB.
--   Un índice GIN con jsonb_path_ops permite búsquedas eficientes con
--   el operador @> (contención), ej:
--     WHERE valor @> '{"event_type": "shutdown"}'
--   jsonb_path_ops es más compacto que el operador por defecto y
--   suficiente para nuestras consultas de contención.
--
CREATE INDEX idx_contexto_valor_gin
    ON solardb.registro_contexto USING GIN (valor jsonb_path_ops);

COMMENT ON INDEX solardb.idx_contexto_valor_gin IS
    'GIN con jsonb_path_ops para búsquedas de contención (@>) '
    'en los eventos de contexto operativo JSONB.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 4: B-tree en registro_contexto(tipo_contexto_id)
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Filtra contextos por tipo de fuente. Útil para:
--     • Contar eventos por fuente
--     • Filtrar registros que contienen datos personales (PII)
--     • JOINs con cat_tipo_contexto.
--
CREATE INDEX idx_contexto_tipo
    ON solardb.registro_contexto (tipo_contexto_id);

COMMENT ON INDEX solardb.idx_contexto_tipo IS
    'B-tree en tipo_contexto_id para filtrado por fuente de contexto.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 5: B-tree parcial en cuarentena(estado) WHERE 'PENDIENTE'
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   El dashboard de calidad necesita contar y listar rápidamente las
--   filas en cuarentena que están PENDIENTES de resolución. Un índice
--   parcial (WHERE estado = 'PENDIENTE') es más compacto que un índice
--   completo porque solo indexa las filas activas, no las ya resueltas.
--   Estimación: ~3,849 filas pendientes vs ~0 resueltas inicialmente.
--
CREATE INDEX idx_cuarentena_pendiente
    ON calidad.registro_cuarentena (estado)
    WHERE estado = 'PENDIENTE';

COMMENT ON INDEX calidad.idx_cuarentena_pendiente IS
    'Índice parcial B-tree: solo filas PENDIENTES de resolución. '
    'Compacto y rápido para el dashboard de calidad.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 6: B-tree en cuarentena(regla_id)
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Permite agrupar y contar filas rechazadas por regla de calidad.
--   Útil para:
--     • Dashboard: "¿cuántas filas rechazó cada regla?"
--     • JOIN con regla_calidad para reportes.
--
CREATE INDEX idx_cuarentena_regla
    ON calidad.registro_cuarentena (regla_id);

COMMENT ON INDEX calidad.idx_cuarentena_regla IS
    'B-tree en regla_id para agrupar/filtrar filas rechazadas por regla.';


-- ═══════════════════════════════════════════════════════════════════════════
--  Índice 7: B-tree en cuarentena(lote_id)
-- ═══════════════════════════════════════════════════════════════════════════
-- Justificación:
--   Permite rastrear cuáles filas rechazadas pertenecen a cada lote.
--   Complementa la trazabilidad de auditoría.
--
CREATE INDEX idx_cuarentena_lote
    ON calidad.registro_cuarentena (lote_id);

COMMENT ON INDEX calidad.idx_cuarentena_lote IS
    'B-tree en lote_id para trazabilidad de rechazos por lote.';


-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_indexes
    WHERE schemaname IN ('solardb', 'calidad', 'staging')
      AND indexname LIKE 'idx_%';
    RAISE NOTICE '✓ Índices personalizados (idx_*) creados: %', v_count;
END
$$;
