"""
Migración de tabla context de SQLite a solardb.registro_contexto.
"""
import sqlite3
import psycopg2
import json

PG = dict(host='localhost', port=5432, dbname='solardb', user='postgres', password='postgres')

conn_pg = psycopg2.connect(**PG)
conn_pg.autocommit = True
cur_pg = conn_pg.cursor()

# 1. Crear lote para contexto
cur_pg.execute("""
    INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
    VALUES ('context', 'Migración de contexto operativo OpenCEM v1.0.0')
    RETURNING lote_id
""")
lote_ctx = cur_pg.fetchone()[0]
print(f"Lote contexto creado: {lote_ctx}")

# 2. Mapeo de fuentes a tipo_contexto_id
cur_pg.execute("SELECT codigo_fuente, tipo_contexto_id FROM solardb.cat_tipo_contexto")
tipo_map = dict(cur_pg.fetchall())

# Si hay fuentes en SQLite con espacio o nombre distinto, asegurar que existan
conn_sqlite = sqlite3.connect('data/opencem-v1.0.0.sqlite')
cur_sqlite = conn_sqlite.cursor()
cur_sqlite.execute("SELECT id, recorded, start, end, value FROM context")

inserted = 0
skipped = 0

for row in cur_sqlite:
    cid, recorded, start_ts, end_ts, val_text = row
    val_json = {}
    try:
        val_json = json.loads(val_text)
    except:
        val_json = {"raw": val_text}
    
    source = val_json.get("source", "manual_entry")
    
    # Normalizar source si viene con espacios
    source_clean = source.replace(" ", "_")
    
    tipo_id = tipo_map.get(source_clean) or tipo_map.get(source)
    if not tipo_id:
        # Insertar fuente si no existe
        cur_pg.execute("""
            INSERT INTO solardb.cat_tipo_contexto (codigo_fuente, descripcion, contiene_pii)
            VALUES (%s, %s, %s)
            ON CONFLICT (codigo_fuente) DO UPDATE SET codigo_fuente = EXCLUDED.codigo_fuente
            RETURNING tipo_contexto_id
        """, (source_clean, f"Fuente de contexto: {source}", "bash" in source_clean.lower()))
        tipo_id = cur_pg.fetchone()[0]
        tipo_map[source_clean] = tipo_id
    
    # Agregar start y end al JSONB
    if start_ts: val_json["start_ts"] = start_ts
    if end_ts: val_json["end_ts"] = end_ts
    
    ts_ctx = start_ts if start_ts else recorded
    contiene_pii = ("bash" in source_clean.lower())
    
    cur_pg.execute("""
        INSERT INTO solardb.registro_contexto
            (tipo_contexto_id, ts_contexto, valor, contiene_datos_personales, lote_id)
        VALUES (%s, to_timestamp(%s), %s::jsonb, %s, %s)
    """, (tipo_id, ts_ctx, json.dumps(val_json, ensure_ascii=False), contiene_pii, lote_ctx))
    inserted += 1

conn_sqlite.close()

# Actualizar lote
cur_pg.execute(f"""
    UPDATE calidad.lote_carga
    SET filas_leidas = {inserted}, filas_aceptadas = {inserted}, filas_rechazadas = 0,
        fecha_fin = now(), estado = 'COMPLETADO'
    WHERE lote_id = {lote_ctx};
""")
print(f"✓ Contexto migrado: {inserted:,} filas")

# ANALYZE en todo
cur_pg.execute("ANALYZE solardb.lectura_telemetria")
cur_pg.execute("ANALYZE solardb.registro_contexto")
cur_pg.execute("ANALYZE calidad.registro_cuarentena")
cur_pg.execute("ANALYZE calidad.lote_carga")
print("✓ ANALYZE completado en todas las tablas")

conn_pg.close()
