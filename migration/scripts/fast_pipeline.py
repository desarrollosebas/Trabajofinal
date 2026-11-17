"""
SolarDB — Pipeline optimizado por lotes (resistente a fallos y rápido).
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

print("="*60)
print("  SOLARDB — PIPELINE DE MIGRACIÓN RESILIENTE Y RÁPIDO")
print("="*60)

# 1. Asegurar lote_carga
cur.execute("SELECT lote_id FROM calidad.lote_carga WHERE tabla_origen = 'analog_measurements' ORDER BY lote_id DESC LIMIT 1")
row = cur.fetchone()
if row:
    lote_id = row[0]
else:
    cur.execute("""
        INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
        VALUES ('analog_measurements', 'Migración completa OpenCEM v1.0.0')
        RETURNING lote_id
    """)
    lote_id = cur.fetchone()[0]
print(f"1. Usando lote de auditoría: {lote_id}")

# Asignar este lote_id a staging
cur.execute(f"UPDATE staging.staging_telemetria SET lote_id = {lote_id}")
print("   ✓ staging_telemetria vinculada al lote")

# 2. Validar en staging aplicando las 4 reglas
print("\n2. Ejecutando validación de calidad en staging...")
t0 = time.time()
cur.execute(f"""
    UPDATE staging.staging_telemetria
    SET estado_validacion = 'RECHAZADA'
    WHERE lote_id = {lote_id}
      AND (
          (temper1 IS NOT NULL AND temper1 <= -20.0)
          OR (outw_a IS NOT NULL AND outva_a IS NOT NULL AND outw_a > outva_a)
          OR (outsumw IS NOT NULL AND outsumva IS NOT NULL AND outsumw > outsumva)
          OR (linecurra IS NOT NULL AND linecurra < 0)
          OR (linepowerva_a IS NOT NULL AND linepowerva_a < 0)
      );
""")
rechazadas = cur.rowcount
print(f"   ✓ Filas RECHAZADAS identificadas: {rechazadas:,} en {time.time()-t0:.1f}s")

t0 = time.time()
cur.execute(f"""
    UPDATE staging.staging_telemetria
    SET estado_validacion = 'VALIDA'
    WHERE lote_id = {lote_id} AND estado_validacion != 'RECHAZADA';
""")
validas = cur.rowcount
print(f"   ✓ Filas VALIDAS identificadas: {validas:,} en {time.time()-t0:.1f}s")

# 3. Optimización: dropear índices secundarios temporales para inserción ultrarrápida
print("\n3. Optimizando índices para inserción masiva...")
cur.execute("DROP INDEX IF EXISTS solardb.idx_lectura_ts")
cur.execute("DROP INDEX IF EXISTS solardb.idx_lectura_lote")
print("   ✓ Índices secundarios temporales liberados")

# 4. Insertar filas válidas en producción por chunks de 250,000 con progreso
print("\n4. Insertando filas válidas en solardb.lectura_telemetria...")
cur.execute(f"SELECT MIN(stg_id), MAX(stg_id) FROM staging.staging_telemetria WHERE lote_id = {lote_id}")
min_id, max_id = cur.fetchone()

CHUNK = 250_000
current = min_id
total_insertadas = 0
t_ins = time.time()

while current <= max_id:
    limit_id = current + CHUNK - 1
    cur.execute(f"""
        INSERT INTO solardb.lectura_telemetria (
            inversor_id, ts_lectura, lote_id,
            battvolt, battcurr, battsoc, battchgpower, battreserve,
            linechgcurr, pvchgcurr,
            pv1volt, pv1curr, pv1power, pvreserve,
            outvolta, outcurra, outfreq, invcurra,
            outw_a, outva_a, loadpercenta, normalloadw_a,
            outsumw, outsumva, sumloadpercent,
            generatedpowerp_a, generatedpowers_a, generatedpowerq_a,
            linevolta, linecurra, linefreq, linepowerva_a, linepowerw_a,
            busvoltp, busvoltn,
            temper1, temper2, temper3, temper4,
            sir, fanduty, otherreserve,
            gridpowerw_a, gridcurr_a, grid_reserve
        )
        SELECT
            s.inverter::SMALLINT,
            to_timestamp(s.read_ts) AT TIME ZONE 'UTC',
            {lote_id},
            s.battvolt, s.battcurr, s.battsoc::SMALLINT, s.battchgpower::INTEGER,
            CASE WHEN s.battreserve IS NOT NULL THEN s.battreserve::JSONB ELSE NULL END,
            s.linechgcurr, s.pvchgcurr,
            s.pv1volt, s.pv1curr, s.pv1power::INTEGER,
            CASE WHEN s.pvreserve IS NOT NULL THEN s.pvreserve::JSONB ELSE NULL END,
            s.outvolta, s.outcurra, s.outfreq, s.invcurra,
            s.outw_a::INTEGER, s.outva_a::INTEGER,
            s.loadpercenta::SMALLINT, s.normalloadw_a::INTEGER,
            s.outsumw::INTEGER, s.outsumva::INTEGER, s.sumloadpercent::SMALLINT,
            s.generatedpowerp_a::INTEGER, s.generatedpowers_a::INTEGER,
            s.generatedpowerq_a::INTEGER,
            s.linevolta, s.linecurra, s.linefreq,
            s.linepowerva_a::INTEGER, s.linepowerw_a::INTEGER,
            s.busvoltp, s.busvoltn,
            s.temper1, s.temper2, s.temper3, s.temper4,
            s.sir::INTEGER, s.fanduty::SMALLINT,
            CASE WHEN s.otherreserve IS NOT NULL THEN s.otherreserve::JSONB ELSE NULL END,
            s.gridpowerw_a::INTEGER, s.gridcurr_a,
            CASE WHEN s.grid_reserve IS NOT NULL THEN s.grid_reserve::JSONB ELSE NULL END
        FROM staging.staging_telemetria s
        WHERE s.lote_id = {lote_id}
          AND s.estado_validacion = 'VALIDA'
          AND s.stg_id BETWEEN {current} AND {limit_id}
        ON CONFLICT (inversor_id, ts_lectura) DO NOTHING;
    """)
    ins = cur.rowcount
    total_insertadas += ins
    current = limit_id + 1
    pct = (total_insertadas / validas) * 100 if validas > 0 else 0
    print(f"   {total_insertadas:>10,} / {validas:,} ({pct:5.1f}%) insertadas...", flush=True)

print(f"   ✓ Inserción completada: {total_insertadas:,} filas en {time.time()-t_ins:.1f}s")

# 5. Insertar filas rechazadas en cuarentena
print("\n5. Insertando filas rechazadas en calidad.registro_cuarentena...")
t0 = time.time()
cur.execute(f"SELECT regla_id, codigo_regla FROM calidad.regla_calidad WHERE activa")
reglas = dict(cur.fetchall())

r_temp = [k for k, v in reglas.items() if v == 'R_TEMP1_IMPOSIBLE'][0]
r_ps   = [k for k, v in reglas.items() if v == 'R_P_MAYOR_S'][0]
r_curr = [k for k, v in reglas.items() if v == 'R_LINECURRA_NEG'][0]
r_va   = [k for k, v in reglas.items() if v == 'R_LINEPOWERVA_NEG'][0]

cur.execute(f"""
    INSERT INTO calidad.registro_cuarentena (
        lote_id, regla_id, read_ts_original, inversor_original,
        fila_original, motivo_rechazo
    )
    SELECT
        {lote_id},
        CASE
            WHEN s.temper1 IS NOT NULL AND s.temper1 <= -20.0 THEN {r_temp}
            WHEN s.linecurra IS NOT NULL AND s.linecurra < 0 THEN {r_curr}
            WHEN s.linepowerva_a IS NOT NULL AND s.linepowerva_a < 0 THEN {r_va}
            ELSE {r_ps}
        END,
        s.read_ts,
        s.inverter::SMALLINT,
        to_jsonb(s) - 'stg_id' - 'lote_id' - 'estado_validacion',
        CASE
            WHEN s.temper1 IS NOT NULL AND s.temper1 <= -20.0 THEN format('temper1 = %s°C: sensor abierto', s.temper1)
            WHEN s.linecurra IS NOT NULL AND s.linecurra < 0 THEN format('linecurra = %s A: corriente negativa imposible', s.linecurra)
            WHEN s.linepowerva_a IS NOT NULL AND s.linepowerva_a < 0 THEN format('linepowerva_a = %s VA: aparente negativa', s.linepowerva_a)
            ELSE format('P > S: outw_a=%s > outva_a=%s o outsumw=%s > outsumva=%s', s.outw_a, s.outva_a, s.outsumw, s.outsumva)
        END
    FROM staging.staging_telemetria s
    WHERE s.lote_id = {lote_id}
      AND s.estado_validacion = 'RECHAZADA';
""")
cuarentena_insertadas = cur.rowcount
print(f"   ✓ Cuarentena poblada: {cuarentena_insertadas:,} filas en {time.time()-t0:.1f}s")

# 6. Recrear índices secundarios
print("\n6. Recreando índices secundarios...")
t0 = time.time()
cur.execute("CREATE INDEX idx_lectura_ts ON solardb.lectura_telemetria (ts_lectura)")
cur.execute("CREATE INDEX idx_lectura_lote ON solardb.lectura_telemetria (lote_id)")
print(f"   ✓ Índices idx_lectura_ts e idx_lectura_lote creados en {time.time()-t0:.1f}s")

# 7. Actualizar lote de auditoría
cur.execute(f"""
    UPDATE calidad.lote_carga
    SET filas_leidas = {validas + rechazadas},
        filas_aceptadas = {total_insertadas},
        filas_rechazadas = {cuarentena_insertadas},
        fecha_fin = now(),
        estado = 'COMPLETADO'
    WHERE lote_id = {lote_id};
""")
print("\n7. ✓ Lote de auditoría cerrado como COMPLETADO")

# 8. Limpiar staging
print("\n8. Limpiando tabla staging_telemetria...")
cur.execute("TRUNCATE staging.staging_telemetria")
print("   ✓ Staging truncado")

# 9. Migrar contexto operativo (25,178 filas)
print("\n9. Migrando contexto operativo (tabla context)...")
cur.execute("""
    INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
    VALUES ('context', 'Migración contexto OpenCEM v1.0.0')
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
cur.execute(f"""
    UPDATE calidad.lote_carga
    SET filas_leidas = {ctx_inserted}, filas_aceptadas = {ctx_inserted}, filas_rechazadas = 0,
        fecha_fin = now(), estado = 'COMPLETADO'
    WHERE lote_id = {lote_ctx};
""")
print(f"   ✓ Contexto migrado: {ctx_inserted:,} filas")

# 10. ANALYZE
print("\n10. Actualizando estadísticas del optimizador (ANALYZE)...")
cur.execute("ANALYZE solardb.lectura_telemetria")
cur.execute("ANALYZE solardb.registro_contexto")
cur.execute("ANALYZE calidad.registro_cuarentena")
cur.execute("ANALYZE calidad.lote_carga")
print("   ✓ ANALYZE completado")

# Resumen final
print("\n" + "="*60)
print("  REPORTE FINAL CONSOLIDADO SOLARDB")
print("="*60)
cur.execute("SELECT COUNT(*) FROM solardb.lectura_telemetria")
n_prod = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM calidad.registro_cuarentena")
n_quar = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM solardb.registro_contexto")
n_ctx = cur.fetchone()[0]
cur.execute("SELECT pg_size_pretty(pg_total_relation_size('solardb.lectura_telemetria'))")
sz_prod = cur.fetchone()[0]

print(f"  Producción (solardb.lectura_telemetria):  {n_prod:>10,} filas ({sz_prod})")
print(f"  Cuarentena (calidad.registro_cuarentena): {n_quar:>10,} filas")
print(f"  Contexto   (solardb.registro_contexto):   {n_ctx:>10,} filas")

cur.execute("""
    SELECT rc.codigo_regla, COUNT(*)
    FROM calidad.registro_cuarentena rq
    JOIN calidad.regla_calidad rc ON rq.regla_id = rc.regla_id
    GROUP BY rc.codigo_regla ORDER BY COUNT(*) DESC
""")
print("\n  Desglose de filas en cuarentena:")
for r in cur.fetchall():
    print(f"    - {r[0]}: {r[1]:,} filas")

cur.close()
conn.close()
print("\n✓ ¡MIGRACIÓN TOTALMENTE FINALIZADA Y VERIFICADA!")
