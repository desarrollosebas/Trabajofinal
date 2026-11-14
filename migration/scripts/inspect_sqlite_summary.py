import sqlite3
import datetime
import json
import os

db_path = r"c:\Users\Sebas\Desktop\Bases datos 1\ULTIMOWORK\data\opencem-v1.0.0.sqlite"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("=== TABLAS EN OPENCEM SQLITE ===")
cursor.execute("SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') ORDER BY name;")
tables = cursor.fetchall()
for tname, ttype in tables:
    cursor.execute(f"PRAGMA table_info('{tname}');")
    cols = cursor.fetchall()
    print(f"[{ttype}] {tname}: {len(cols)} columnas")

print("\n=== CONTEO EXACTO DE FILAS POR TABLA ===")
for tname, _ in tables:
    cursor.execute(f"SELECT COUNT(*) FROM '{tname}';")
    count = cursor.fetchone()[0]
    print(f"  {tname}: {count:,} filas")

print("\n=== RANGOS TEMPORALES Y DISTRIBUCIÓN POR INVERSOR EN ANALOG_MEASUREMENTS ===")
cursor.execute("""
    SELECT 
        inverter,
        COUNT(*) as total_rows,
        MIN(read_ts) as min_ts,
        MAX(read_ts) as max_ts
    FROM analog_measurements
    GROUP BY inverter;
""")
inv_rows = cursor.fetchall()
for inv, cnt, min_t, max_t in inv_rows:
    dt_min = datetime.datetime.fromtimestamp(min_t, tz=datetime.timezone.utc)
    dt_max = datetime.datetime.fromtimestamp(max_t, tz=datetime.timezone.utc)
    print(f"  Inversor {inv}: {cnt:,} filas | Desde: {dt_min.isoformat()} | Hasta: {dt_max.isoformat()}")

print("\n=== ANÁLISIS DE CONTEXT RECORDS ===")
cursor.execute("SELECT COUNT(*), MIN(recorded), MAX(recorded), MIN(start), MAX(end) FROM context;")
cnt, min_r, max_r, min_s, max_e = cursor.fetchone()
print(f"  Total registros de contexto: {cnt:,}")
if min_r:
    print(f"  Recorded desde: {datetime.datetime.fromtimestamp(min_r, tz=datetime.timezone.utc).isoformat()} hasta {datetime.datetime.fromtimestamp(max_r, tz=datetime.timezone.utc).isoformat()}")

cursor.execute("SELECT value FROM context LIMIT 5;")
sample_ctx = cursor.fetchall()
print("  Muestras de context JSON:")
for s in sample_ctx:
    print("   ", s[0][:150])

conn.close()
