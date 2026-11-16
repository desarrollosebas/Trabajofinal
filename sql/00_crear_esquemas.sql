/*
 * ============================================================================
 *  SolarDB — Script 00: Creación de Esquemas
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *  Institución: Institución Universitaria Pascual Bravo
 *  Grupo     : 811, Semestre 2026-II
 *  Profesor  : Ramiro Grisales Montoya
 *  Equipo    : Juan Sebastian Raigosa Gil
 *              Jose Miguel Sosa Cartagena
 *              Deysi Carolina Echavarria Soto
 *
 *  Descripción:
 *      Crea los tres esquemas lógicos que organizan SolarDB:
 *        • solardb  — Producción: catálogos, dimensiones, hechos y dominios.
 *        • staging  — Zona de aterrizaje temporal sin restricciones de dominio.
 *        • calidad  — Auditoría: lotes de carga, reglas y cuarentena.
 *
 *  Prerequisito: Ejecutar sobre una base de datos PostgreSQL limpia.
 *  Idempotente:  Sí (IF NOT EXISTS).
 * ============================================================================
 */

-- ─── Esquema de producción ──────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS solardb;
COMMENT ON SCHEMA solardb IS
    'Producción SolarDB: catálogos dimensionales, tabla de hechos '
    '(lectura_telemetria), dominios personalizados y contexto operativo.';

-- ─── Esquema de staging (zona de aterrizaje) ────────────────────────────────
CREATE SCHEMA IF NOT EXISTS staging;
COMMENT ON SCHEMA staging IS
    'Zona de aterrizaje temporal para la migración desde SQLite. '
    'Las tablas aquí NO tienen restricciones de dominio ni CHECK, '
    'permitiendo cargar cualquier valor para su posterior clasificación.';

-- ─── Esquema de calidad (auditoría y cuarentena) ────────────────────────────
CREATE SCHEMA IF NOT EXISTS calidad;
COMMENT ON SCHEMA calidad IS
    'Auditoría y trazabilidad de calidad: lotes de carga, reglas de '
    'validación y registros de cuarentena con ciclo de vida completo.';

-- ─── Verificación ───────────────────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '✓ Esquemas creados: solardb, staging, calidad';
END
$$;
