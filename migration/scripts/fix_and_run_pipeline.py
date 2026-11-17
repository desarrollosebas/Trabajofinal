"""
SolarDB — Fix & Run: Corregir dominio de generatedpowerp_a,
agregar reglas de cuarentena nuevas, y ejecutar el pipeline completo.
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

# ═══ 1. Corregir dominio de generatedpowerp_a ═══════════════════════════
print('1. Corrigiendo dominio de generatedpowerp_a...')
cur.execute("""
    ALTER TABLE solardb.lectura_telemetria
    ALTER COLUMN generatedpowerp_a TYPE solardb.dom_potencia_activa
""")
print('   ✓ generatedpowerp_a → dom_potencia_activa (permite negativos)')

# ═══ 2. Agregar nuevas reglas de calidad ═════════════════════════════════
print('2. Agregando reglas de calidad nuevas...')
cur.execute("""
    INSERT INTO calidad.regla_calidad (codigo_regla, descripcion, variable_afectada, severidad, accion)
    VALUES
    ('R_LINECURRA_NEG',
     'Corriente de red linecurra < 0: imposible en sensor AC unidireccional. '
     'Ruido de medición. Evidencia: 1 fila.',
     'linecurra', 'ERROR', 'CUARENTENA'),
    ('R_LINEPOWERVA_NEG',
     'Potencia aparente linepowerva_a < 0: imposible por definición S = |V|x|I| >= 0. '
     'Error de sensor. Evidencia: 8 filas.',
     'linepowerva_a', 'ERROR', 'CUARENTENA')
    ON CONFLICT (codigo_regla) DO NOTHING
""")
print('   ✓ R_LINECURRA_NEG y R_LINEPOWERVA_NEG agregadas')

# ═══ 3. Recrear función de validación con las nuevas reglas ══════════════
print('3. Actualizando función de validación...')
cur.execute("""
CREATE OR REPLACE FUNCTION staging.fn_validar_staging_telemetria(p_lote_id INTEGER)
RETURNS TABLE(validadas BIGINT, rechazadas BIGINT)
LANGUAGE plpgsql AS $$
DECLARE
    v_regla SMALLINT;
    v_count BIGINT;
    v_rechazadas BIGINT := 0;
    v_validadas  BIGINT := 0;
BEGIN
    -- R_TEMP1_IMPOSIBLE: temper1 <= -20
    SELECT regla_id INTO v_regla FROM calidad.regla_calidad
    WHERE codigo_regla = 'R_TEMP1_IMPOSIBLE' AND activa;
    IF v_regla IS NOT NULL THEN
        UPDATE staging.staging_telemetria SET estado_validacion = 'RECHAZADA'
        WHERE lote_id = p_lote_id AND estado_validacion = 'PENDIENTE'
          AND temper1 IS NOT NULL AND temper1 <= -20.0;
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RAISE NOTICE 'R_TEMP1_IMPOSIBLE: % rechazadas', v_count;
    END IF;

    -- R_P_MAYOR_S: outw_a > outva_a OR outsumw > outsumva
    SELECT regla_id INTO v_regla FROM calidad.regla_calidad
    WHERE codigo_regla = 'R_P_MAYOR_S' AND activa;
    IF v_regla IS NOT NULL THEN
        UPDATE staging.staging_telemetria SET estado_validacion = 'RECHAZADA'
        WHERE lote_id = p_lote_id AND estado_validacion = 'PENDIENTE'
          AND ((outw_a IS NOT NULL AND outva_a IS NOT NULL AND outw_a > outva_a)
            OR (outsumw IS NOT NULL AND outsumva IS NOT NULL AND outsumw > outsumva));
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RAISE NOTICE 'R_P_MAYOR_S: % rechazadas', v_count;
    END IF;

    -- R_LINECURRA_NEG: linecurra < 0
    SELECT regla_id INTO v_regla FROM calidad.regla_calidad
    WHERE codigo_regla = 'R_LINECURRA_NEG' AND activa;
    IF v_regla IS NOT NULL THEN
        UPDATE staging.staging_telemetria SET estado_validacion = 'RECHAZADA'
        WHERE lote_id = p_lote_id AND estado_validacion = 'PENDIENTE'
          AND linecurra IS NOT NULL AND linecurra < 0;
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RAISE NOTICE 'R_LINECURRA_NEG: % rechazadas', v_count;
    END IF;

    -- R_LINEPOWERVA_NEG: linepowerva_a < 0
    SELECT regla_id INTO v_regla FROM calidad.regla_calidad
    WHERE codigo_regla = 'R_LINEPOWERVA_NEG' AND activa;
    IF v_regla IS NOT NULL THEN
        UPDATE staging.staging_telemetria SET estado_validacion = 'RECHAZADA'
        WHERE lote_id = p_lote_id AND estado_validacion = 'PENDIENTE'
          AND linepowerva_a IS NOT NULL AND linepowerva_a < 0;
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RAISE NOTICE 'R_LINEPOWERVA_NEG: % rechazadas', v_count;
    END IF;

    -- Marcar el resto como VALIDA
    UPDATE staging.staging_telemetria SET estado_validacion = 'VALIDA'
    WHERE lote_id = p_lote_id AND estado_validacion = 'PENDIENTE';
    GET DIAGNOSTICS v_validadas = ROW_COUNT;

    SELECT COUNT(*) INTO v_rechazadas FROM staging.staging_telemetria
    WHERE lote_id = p_lote_id AND estado_validacion = 'RECHAZADA';

    RAISE NOTICE 'Total: % válidas, % rechazadas', v_validadas, v_rechazadas;
    RETURN QUERY SELECT v_validadas, v_rechazadas;
END;
$$
""")
print('   ✓ fn_validar_staging_telemetria actualizada con 4 reglas')

# ═══ 4. Recrear función de cuarentena con las nuevas reglas ══════════════
print('4. Actualizando función de cuarentena...')
cur.execute("""
CREATE OR REPLACE FUNCTION staging.fn_mover_rechazadas_a_cuarentena(p_lote_id INTEGER)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    v_total BIGINT := 0;
    v_count BIGINT;
    v_regla SMALLINT;
    r RECORD;
BEGIN
    -- Para cada regla de tipo CUARENTENA
    FOR r IN
        SELECT regla_id, codigo_regla FROM calidad.regla_calidad
        WHERE accion = 'CUARENTENA' AND activa
    LOOP
        INSERT INTO calidad.registro_cuarentena (
            lote_id, regla_id, read_ts_original, inversor_original,
            fila_original, motivo_rechazo
        )
        SELECT
            p_lote_id, r.regla_id, s.read_ts, s.inverter::SMALLINT,
            to_jsonb(s) - 'stg_id' - 'lote_id' - 'estado_validacion',
            CASE r.codigo_regla
                WHEN 'R_TEMP1_IMPOSIBLE' THEN
                    format('temper1 = %s°C: sensor abierto', s.temper1)
                WHEN 'R_P_MAYOR_S' THEN
                    format('P>S: outw_a=%s>outva_a=%s o outsumw=%s>outsumva=%s',
                           s.outw_a, s.outva_a, s.outsumw, s.outsumva)
                WHEN 'R_LINECURRA_NEG' THEN
                    format('linecurra=%s A: negativa imposible', s.linecurra)
                WHEN 'R_LINEPOWERVA_NEG' THEN
                    format('linepowerva_a=%s VA: aparente negativa imposible', s.linepowerva_a)
                ELSE 'Regla: ' || r.codigo_regla
            END
        FROM staging.staging_telemetria s
        WHERE s.lote_id = p_lote_id AND s.estado_validacion = 'RECHAZADA'
          AND CASE r.codigo_regla
                WHEN 'R_TEMP1_IMPOSIBLE' THEN s.temper1 IS NOT NULL AND s.temper1 <= -20.0
                WHEN 'R_P_MAYOR_S' THEN
                    (s.outw_a IS NOT NULL AND s.outva_a IS NOT NULL AND s.outw_a > s.outva_a)
                    OR (s.outsumw IS NOT NULL AND s.outsumva IS NOT NULL AND s.outsumw > s.outsumva)
                WHEN 'R_LINECURRA_NEG' THEN s.linecurra IS NOT NULL AND s.linecurra < 0
                WHEN 'R_LINEPOWERVA_NEG' THEN s.linepowerva_a IS NOT NULL AND s.linepowerva_a < 0
                ELSE FALSE
              END;
        GET DIAGNOSTICS v_count = ROW_COUNT;
        v_total := v_total + v_count;
        RAISE NOTICE '%: % filas a cuarentena', r.codigo_regla, v_count;
    END LOOP;

    RAISE NOTICE 'Total en cuarentena: %', v_total;
    RETURN v_total;
END;
$$
""")
print('   ✓ fn_mover_rechazadas_a_cuarentena actualizada')

# ═══ 5. Resetear staging y ejecutar pipeline ═════════════════════════════
print('\n5. Reseteando staging a PENDIENTE...')
conn.autocommit = False

# Limpiar todo en orden correcto (respetar FK)
cur.execute('DELETE FROM calidad.registro_cuarentena')
cur.execute('DELETE FROM solardb.lectura_telemetria')
cur.execute('DELETE FROM solardb.registro_contexto')
cur.execute('TRUNCATE staging.staging_telemetria')
cur.execute('TRUNCATE staging.staging_contexto')
cur.execute('DELETE FROM calidad.lote_carga')
conn.commit()

# Crear lote nuevo
cur.execute("""
    INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
    VALUES ('analog_measurements', 'Migración completa OpenCEM v1.0.0 - corregida')
    RETURNING lote_id
""")
lote_id = cur.fetchone()[0]
conn.commit()
print(f'   Lote creado: {lote_id}')

# Actualizar lote_id en staging y resetear estado
cur.execute(f'UPDATE staging.staging_telemetria SET lote_id = {lote_id}, estado_validacion = \'PENDIENTE\'')
conn.commit()
print('   staging limpiado')

# Crear lote nuevo
cur.execute("""
    INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
    VALUES ('analog_measurements', 'Migración completa OpenCEM v1.0.0 - corregida')
    RETURNING lote_id
""")
lote_id = cur.fetchone()[0]
conn.commit()
print(f'   Lote creado: {lote_id}')

# Re-cargar desde SQLite a staging
print('\n5b. Cargando SQLite → staging...')
import csv, io
cur.execute("SET search_path TO staging, solardb, calidad, public")
sqlite_conn2 = sqlite3.connect(SQLITE_PATH)
sqlite_cur2 = sqlite_conn2.cursor()

SQLITE_COLS = [
    'read_ts', 'inverter',
    'battvolt', 'battcurr', 'battsoc', 'battchgpower', 'battreserve',
    'linechgcurr', 'pvchgcurr',
    'pv1volt', 'pv1curr', 'pv1power', 'pvreserve',
    'outvolta', 'outcurra', 'outfreq', 'invcurra',
    'outw_a', 'outva_a', 'loadpercenta', 'normalloadw_a',
    'outsumw', 'outsumva', 'sumloadpercent',
    'generatedpowerp_a', 'generatedpowers_a', 'generatedpowerq_a',
    'linevolta', 'linecurra', 'linefreq', 'linepowerva_a', 'linepowerw_a',
    'busvoltp', 'busvoltn',
    'temper1', 'temper2', 'temper3', 'temper4',
    'sir', 'fanduty', 'otherreserve',
    'gridpowerw_a', 'gridcurr_a', 'grid_reserve',
]
STAGING_COLS = ['lote_id'] + SQLITE_COLS

cols_str = ', '.join(SQLITE_COLS)
sqlite_cur2.execute(f'SELECT {cols_str} FROM analog_measurements ORDER BY read_ts, inverter')

loaded = 0
t_load = time.time()
BATCH = 50000
while True:
    rows = sqlite_cur2.fetchmany(BATCH)
    if not rows:
        break
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter='\t', lineterminator='\n')
    for row in rows:
        values = [lote_id]
        for val in row:
            values.append(r'\N' if val is None else val)
        writer.writerow(values)
    buf.seek(0)
    cur.copy_from(buf, 'staging_telemetria', sep='\t', null=r'\N', columns=STAGING_COLS)
    conn.commit()
    loaded += len(rows)
    pct = loaded / 2989759 * 100
    print(f'   {loaded:>10,} / 2,989,759 ({pct:5.1f}%)  {loaded/(time.time()-t_load):,.0f} f/s', end='\r')

sqlite_conn2.close()
print(f'\n   Staging cargado: {loaded:,} filas en {time.time()-t_load:.0f}s')
# Ejecutar pipeline
print('\n6. Ejecutando pipeline de validación...')
t0 = time.time()
cur.execute('SELECT * FROM staging.fn_ejecutar_pipeline_telemetria(%s)', (lote_id,))
result = cur.fetchone()
conn.commit()

for n in conn.notices:
    msg = n.strip().replace('NOTICE:', '').replace('NOTICE', '').strip()
    if msg:
        print(f'   {msg}')
conn.notices.clear()

t_pipe = time.time() - t0
print(f'\n   Pipeline completado en {t_pipe:.1f}s')
print(f'   Validadas:  {result[0]:,}')
print(f'   Rechazadas: {result[1]:,}')
print(f'   Insertadas: {result[2]:,}')
print(f'   Cuarentena: {result[3]:,}')

# ═══ 7. Verificación post-migración ══════════════════════════════════════
print(f'\n{"="*60}')
print('  VERIFICACIÓN POST-MIGRACIÓN')
print(f'{"="*60}')

cur.execute('SELECT COUNT(*) FROM solardb.lectura_telemetria')
n_prod = cur.fetchone()[0]

cur.execute('SELECT COUNT(*) FROM calidad.registro_cuarentena')
n_quar = cur.fetchone()[0]

cur.execute("""
    SELECT rc.codigo_regla, COUNT(*) FROM calidad.registro_cuarentena rq
    JOIN calidad.regla_calidad rc ON rq.regla_id = rc.regla_id
    GROUP BY rc.codigo_regla ORDER BY COUNT(*) DESC
""")
reglas = cur.fetchall()

cur.execute("""
    SELECT inversor_id, COUNT(*), MIN(ts_lectura)::text, MAX(ts_lectura)::text
    FROM solardb.lectura_telemetria GROUP BY inversor_id ORDER BY inversor_id
""")
inversores = cur.fetchall()

cur.execute("""
    SELECT estado, filas_leidas, filas_aceptadas, filas_rechazadas
    FROM calidad.lote_carga WHERE lote_id = %s
""", (lote_id,))
lote = cur.fetchone()

print(f'  Producción:  {n_prod:,} filas')
print(f'  Cuarentena:  {n_quar:,} filas')
print(f'  Lote: estado={lote[0]}, leídas={lote[1]:,}, aceptadas={lote[2]:,}, rechazadas={lote[3]:,}')

print(f'\n  Desglose cuarentena:')
for regla, cnt in reglas:
    print(f'    {regla}: {cnt:,}')

print(f'\n  Por inversor:')
for inv_id, cnt, ts_min, ts_max in inversores:
    print(f'    Inv {inv_id}: {cnt:,} filas  [{ts_min} → {ts_max}]')

# Tamaños
cur.execute("""
    SELECT relname, pg_total_relation_size(c.oid) as total_bytes
    FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname IN ('solardb','calidad','staging')
      AND c.relkind = 'r'
    ORDER BY total_bytes DESC
""")
sizes = cur.fetchall()
print(f'\n  Tamaños de tablas:')
for name, sz in sizes:
    if sz > 1024*1024:
        print(f'    {name}: {sz/(1024*1024):.1f} MB')
    else:
        print(f'    {name}: {sz/1024:.1f} KB')

# ═══ 8. Limpiar staging y ANALYZE ════════════════════════════════════════
print('\n7. Limpiando staging y ejecutando ANALYZE...')
cur.execute('TRUNCATE staging.staging_telemetria')
conn.commit()
conn.autocommit = True
cur.execute('ANALYZE solardb.lectura_telemetria')
cur.execute('ANALYZE calidad.registro_cuarentena')
cur.execute('ANALYZE calidad.lote_carga')
print('   ✓ Staging truncado y estadísticas actualizadas')

# ═══ 9. Migrar contexto ══════════════════════════════════════════════════
print(f'\n{"="*60}')
print('  MIGRACIÓN DE CONTEXTO')
print(f'{"="*60}')

conn.autocommit = False
cur.execute("""
    INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
    VALUES ('context', 'Migración de contexto operativo OpenCEM v1.0.0')
    RETURNING lote_id
""")
lote_ctx = cur.fetchone()[0]
conn.commit()

# Leer tipo_contexto map
cur.execute('SELECT codigo_fuente, tipo_contexto_id FROM solardb.cat_tipo_contexto')
tipo_map = dict(cur.fetchall())

sqlite_conn = sqlite3.connect(SQLITE_PATH)
sqlite_cur = sqlite_conn.cursor()
sqlite_cur.execute('SELECT read_ts, source, key, value, description FROM context ORDER BY read_ts')

inserted = 0
skipped = 0
for row in sqlite_cur:
    read_ts, source, key, value, description = row
    tipo_id = tipo_map.get(source)
    if tipo_id is None:
        skipped += 1
        continue

    valor_dict = {}
    if key: valor_dict['key'] = key
    if value:
        try:
            valor_dict['value'] = json.loads(value)
        except (json.JSONDecodeError, TypeError):
            valor_dict['value'] = value
    if description: valor_dict['description'] = description
    if not valor_dict: valor_dict = {'raw': True}

    contiene_pii = (source == 'wsl_bash_history')

    cur.execute("""
        INSERT INTO solardb.registro_contexto
            (tipo_contexto_id, ts_contexto, valor, contiene_datos_personales, lote_id)
        VALUES (%s, to_timestamp(%s), %s::jsonb, %s, %s)
    """, (tipo_id, read_ts, json.dumps(valor_dict, ensure_ascii=False), contiene_pii, lote_ctx))
    inserted += 1

    if inserted % 5000 == 0:
        conn.commit()

cur.execute("""
    UPDATE calidad.lote_carga
    SET filas_leidas=%s, filas_aceptadas=%s, filas_rechazadas=%s,
        fecha_fin=now(), estado='COMPLETADO'
    WHERE lote_id=%s
""", (inserted + skipped, inserted, skipped, lote_ctx))
conn.commit()
sqlite_conn.close()

print(f'  Contexto insertado: {inserted:,} filas')
print(f'  Contexto omitido:   {skipped:,} filas')

conn.autocommit = True
cur.execute('ANALYZE solardb.registro_contexto')

# ═══ RESUMEN FINAL ═══════════════════════════════════════════════════════
print(f'\n{"="*60}')
print('  MIGRACIÓN COMPLETA')
print(f'{"="*60}')
cur.execute('SELECT COUNT(*) FROM solardb.lectura_telemetria')
print(f'  lectura_telemetria: {cur.fetchone()[0]:,} filas')
cur.execute('SELECT COUNT(*) FROM solardb.registro_contexto')
print(f'  registro_contexto:  {cur.fetchone()[0]:,} filas')
cur.execute('SELECT COUNT(*) FROM calidad.registro_cuarentena')
print(f'  registro_cuarentena: {cur.fetchone()[0]:,} filas')
cur.execute('SELECT COUNT(*) FROM calidad.lote_carga')
print(f'  lotes_carga:         {cur.fetchone()[0]:,} lotes')

conn.close()
print('\n✓ Todo listo.')
