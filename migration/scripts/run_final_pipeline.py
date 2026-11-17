"""
SolarDB — Ejecución final del pipeline sobre el lote ya cargado en staging.
"""
import psycopg2
import time
import json
import sqlite3
import os

PG = dict(host='localhost', port=5432, dbname='solardb', user='postgres', password='postgres')
SQLITE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'data', 'opencem-v1.0.0.sqlite'
)

conn = psycopg2.connect(**PG)
conn.autocommit = True
cur = conn.cursor()

# 1. Actualizar la función del pipeline para usar v_rechazadas (conteo exacto de filas)
print('1. Actualizando fn_ejecutar_pipeline_telemetria con conteo consistente...')
cur.execute("""
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
    RAISE NOTICE '=== Pipeline SolarDB — Lote % ===', p_lote_id;

    SELECT COUNT(*) INTO v_total_staging
    FROM staging.staging_telemetria
    WHERE lote_id = p_lote_id;

    RAISE NOTICE 'Filas en staging para lote %: %', p_lote_id, v_total_staging;

    IF v_total_staging = 0 THEN
        RAISE NOTICE 'No hay filas en staging. Abortando.';
        RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::BIGINT;
        RETURN;
    END IF;

    -- Paso 1: Validar (clasificar VALIDA / RECHAZADA)
    RAISE NOTICE 'Paso 1: Validando reglas de calidad...';
    SELECT * INTO v_validadas, v_rechazadas
    FROM staging.fn_validar_staging_telemetria(p_lote_id);

    -- Paso 2: Mover válidas a producción
    RAISE NOTICE 'Paso 2: Insertando filas validas en produccion...';
    v_insertadas := staging.fn_mover_validas_a_produccion(p_lote_id);

    -- Paso 3: Mover rechazadas a cuarentena
    RAISE NOTICE 'Paso 3: Enviando filas rechazadas a cuarentena...';
    v_cuarentena := staging.fn_mover_rechazadas_a_cuarentena(p_lote_id);

    -- Paso 4: Actualizar lote_carga con conteo coherente (filas unicas rechazadas)
    RAISE NOTICE 'Paso 4: Actualizando lote_carga...';
    UPDATE calidad.lote_carga
    SET filas_leidas     = v_total_staging,
        filas_aceptadas  = v_insertadas,
        filas_rechazadas = v_rechazadas,
        fecha_fin        = now(),
        estado           = 'COMPLETADO'
    WHERE lote_id = p_lote_id;

    RAISE NOTICE '=== Pipeline completado exitosamente ===';
    RETURN QUERY SELECT v_validadas, v_rechazadas, v_insertadas, v_cuarentena;
END;
$$;
""")
print('   ✓ Función actualizada')

# 2. Resetear estado_validacion en staging
print('2. Reseteando estado_validacion en staging a PENDIENTE...')
cur.execute("UPDATE staging.staging_telemetria SET estado_validacion = 'PENDIENTE' WHERE lote_id = 4")
cur.execute("DELETE FROM calidad.registro_cuarentena WHERE lote_id = 4")
cur.execute("DELETE FROM solardb.lectura_telemetria WHERE lote_id = 4")
print('   ✓ Staging reseteado')

# 3. Ejecutar pipeline
print('\n3. Ejecutando pipeline completo sobre lote 4...')
t0 = time.time()
cur.execute("SELECT * FROM staging.fn_ejecutar_pipeline_telemetria(4)")
res = cur.fetchone()
t_elapsed = time.time() - t0

print(f'\n✓ PIPELINE FINALIZADO en {t_elapsed:.1f}s ({t_elapsed/60:.2f} min)')
print(f'   Validadas:  {res[0]:,}')
print(f'   Rechazadas: {res[1]:,}')
print(f'   Insertadas: {res[2]:,}')
print(f'   Cuarentena: {res[3]:,}')

# 4. Limpiar staging
print('\n4. Limpiando tabla staging_telemetria...')
cur.execute("TRUNCATE staging.staging_telemetria")
print('   ✓ Staging truncado.')

# 5. Migrar contexto si falta
cur.execute("SELECT COUNT(*) FROM solardb.registro_contexto")
ctx_count = cur.fetchone()[0]
if ctx_count == 0:
    print('\n5. Migrando tabla context...')
    cur.execute("""
        INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
        VALUES ('context', 'Migracion de contexto operativo OpenCEM v1.0.0')
        RETURNING lote_id
    """)
    lote_ctx = cur.fetchone()[0]
    
    cur.execute("SELECT codigo_fuente, tipo_contexto_id FROM solardb.cat_tipo_contexto")
    tipo_map = dict(cur.fetchall())
    
    s_conn = sqlite3.connect(SQLITE_PATH)
    s_cur = s_conn.cursor()
    s_cur.execute("SELECT read_ts, source, key, value, description FROM context ORDER BY read_ts")
    
    ctx_inserted = 0
    for r in s_cur:
        ts, src, k, v, desc = r
        tid = tipo_map.get(src)
        if tid is None: continue
        vd = {}
        if k: vd['key'] = k
        if v:
            try: vd['value'] = json.loads(v)
            except: vd['value'] = v
        if desc: vd['description'] = desc
        if not vd: vd = {'raw': True}
        
        cur.execute("""
            INSERT INTO solardb.registro_contexto
                (tipo_contexto_id, ts_contexto, valor, contiene_datos_personales, lote_id)
            VALUES (%s, to_timestamp(%s), %s::jsonb, %s, %s)
        """, (tid, ts, json.dumps(vd, ensure_ascii=False), src == 'wsl_bash_history', lote_ctx))
        ctx_inserted += 1
    
    s_conn.close()
    cur.execute("""
        UPDATE calidad.lote_carga
        SET filas_leidas = %s, filas_aceptadas = %s, filas_rechazadas = 0,
            fecha_fin = now(), estado = 'COMPLETADO'
        WHERE lote_id = %s
    """, (ctx_inserted, ctx_inserted, lote_ctx))
    print(f'   ✓ Contexto migrado: {ctx_inserted:,} filas')

# 6. ANALYZE
print('\n6. Ejecutando ANALYZE en todas las tablas...')
cur.execute("ANALYZE solardb.lectura_telemetria")
cur.execute("ANALYZE solardb.registro_contexto")
cur.execute("ANALYZE calidad.registro_cuarentena")
cur.execute("ANALYZE calidad.lote_carga")
print('   ✓ Estadisticas actualizadas.')

# 7. Metricas finales
print('\n' + '='*60)
print('  RESUMEN FINAL DE LA BASE DE DATOS SOLARDB')
print('='*60)
cur.execute("SELECT COUNT(*) FROM solardb.lectura_telemetria")
n_prod = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM calidad.registro_cuarentena")
n_quar = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM solardb.registro_contexto")
n_ctx = cur.fetchone()[0]

print(f'  solardb.lectura_telemetria: {n_prod:,} filas')
print(f'  calidad.registro_cuarentena: {n_quar:,} filas')
print(f'  solardb.registro_contexto:   {n_ctx:,} filas')

cur.execute("""
    SELECT rc.codigo_regla, COUNT(*)
    FROM calidad.registro_cuarentena rq
    JOIN calidad.regla_calidad rc ON rq.regla_id = rc.regla_id
    GROUP BY rc.codigo_regla ORDER BY COUNT(*) DESC
""")
print('\n  Motivos de cuarentena:')
for r in cur.fetchall():
    print(f'    - {r[0]}: {r[1]:,} filas')

cur.execute("""
    SELECT relname, pg_size_pretty(pg_total_relation_size(c.oid)) as total_size
    FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname IN ('solardb','calidad') AND c.relkind = 'r'
    ORDER BY pg_total_relation_size(c.oid) DESC
    LIMIT 5
""")
print('\n  Top 5 tablas por tamaño en disco:')
for r in cur.fetchall():
    print(f'    - {r[0]}: {r[1]}')

conn.close()
print('\n¡PROCESO COMPLETADO AL 100%!')
