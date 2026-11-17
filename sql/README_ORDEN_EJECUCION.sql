/*
 * ============================================================================
 *  SolarDB — Script Maestro: Ejecutar Todos los DDL en Orden
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  INSTRUCCIONES PARA DBeaver:
 *  ══════════════════════════
 *  Opción A — Ejecutar cada script individualmente EN ORDEN:
 *      1. Abrir DBeaver y conectarse a la base de datos PostgreSQL.
 *      2. Ejecutar cada script en el siguiente orden:
 *
 *         sql/00_crear_esquemas.sql
 *         sql/01_crear_dominios.sql
 *         sql/02_crear_catalogos.sql
 *         sql/03_crear_tablas.sql
 *         sql/04_crear_restricciones.sql
 *         sql/05_crear_indices.sql
 *         sql/06_crear_vistas.sql
 *         sql/07_crear_funciones_triggers.sql
 *         sql/08_crear_staging.sql
 *         sql/09_carga_catalogos.sql
 *
 *  Opción B — Ejecutar este script maestro:
 *      Este archivo contiene sentencias \i para psql. Si usas DBeaver,
 *      puedes abrir y ejecutar cada archivo manualmente en orden.
 *
 *  NOTA: Para re-ejecutar desde cero, ejecutar primero:
 *      DROP SCHEMA IF EXISTS solardb CASCADE;
 *      DROP SCHEMA IF EXISTS staging CASCADE;
 *      DROP SCHEMA IF EXISTS calidad CASCADE;
 *
 *  Después de los DDL, ejecutar la migración:
 *      migration/scripts/migrate_to_postgres.py
 *
 *  Después de la migración, ejecutar las consultas de negocio:
 *      sql/12_consultas_negocio.sql
 *
 *  Después de las consultas, ejecutar la batería de pruebas de integridad:
 *      sql/13_pruebas_integridad.sql
 * ============================================================================
 */

-- Para psql (línea de comandos):
-- \i sql/00_crear_esquemas.sql
-- \i sql/01_crear_dominios.sql
-- \i sql/02_crear_catalogos.sql
-- \i sql/03_crear_tablas.sql
-- \i sql/04_crear_restricciones.sql
-- \i sql/05_crear_indices.sql
-- \i sql/06_crear_vistas.sql
-- \i sql/07_crear_funciones_triggers.sql
-- \i sql/08_crear_staging.sql
-- \i sql/09_carga_catalogos.sql
--
-- Consultas y Pruebas (Deysi Carolina Echavarria Soto):
-- \i sql/12_consultas_negocio.sql
-- \i sql/13_pruebas_integridad.sql

-- Para DBeaver: abrir y ejecutar cada archivo en orden.
-- Cada script incluye verificación con RAISE NOTICE al final.
