import sqlite3
import json

db_path = r"c:\Users\Sebas\Desktop\Bases datos 1\ULTIMOWORK\data\opencem-v1.0.0.sqlite"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("=== 1. DIAGNÓSTICO DE NULOS EN ANALOG_MEASUREMENTS ===")
cursor.execute("SELECT COUNT(*) FROM analog_measurements;")
total_meas = cursor.fetchone()[0]

cursor.execute("PRAGMA table_info(analog_measurements);")
cols = [r[1] for r in cursor.fetchall()]

null_counts = {}
for col in cols:
    cursor.execute(f"SELECT COUNT(*) FROM analog_measurements WHERE {col} IS NULL;")
    nc = cursor.fetchone()[0]
    if nc > 0:
        null_counts[col] = (nc, (nc / total_meas) * 100)

print(f"Total registros: {total_meas:,}")
print("Columnas con nulos (Top 20 por tasa):")
for col, (nc, pct) in sorted(null_counts.items(), key=lambda x: x[1][0], reverse=True)[:20]:
    print(f"  {col:<20}: {nc:,} nulos ({pct:.2f}%)")

print("\n=== 2. DIAGNÓSTICO DE DUPLICADOS EN ANALOG_MEASUREMENTS ===")
cursor.execute("""
    SELECT read_ts, inverter, COUNT(*) 
    FROM analog_measurements 
    GROUP BY read_ts, inverter 
    HAVING COUNT(*) > 1;
""")
dups = cursor.fetchall()
print(f"Claves duplicadas (read_ts, inverter): {len(dups)}")

print("\n=== 3. RANGOS FÍSICOS Y VALORES FUERA DE RANGO / IMPOSIBLES ===")
checks = [
    ("battsoc", "battsoc < 0 OR battsoc > 100", "SOC fuera de [0, 100]%"),
    ("battvolt", "battvolt < 0", "Voltaje batería negativo"),
    ("battvolt", "battvolt > 70", "Voltaje batería excesivo (> 70V en banco 51.2V)"),
    ("pv1volt", "pv1volt < 0", "Voltaje PV1 negativo"),
    ("pv1power", "pv1power < 0", "Potencia PV1 negativa"),
    ("outsumw", "outsumw < 0", "Potencia activa de salida negativa"),
    ("linefreq", "linefreq < 45.0 OR linefreq > 55.0", "Frecuencia de red fuera de [45, 55] Hz"),
    ("outfreq", "outfreq < 45.0 OR outfreq > 55.0", "Frecuencia de salida fuera de [45, 55] Hz"),
    ("temper1", "temper1 < -10 OR temper1 > 100", "Temperatura 1 fuera de [-10, 100] °C"),
    ("temper2", "temper2 < -10 OR temper2 > 100", "Temperatura 2 fuera de [-10, 100] °C"),
]

for col, condition, desc in checks:
    cursor.execute(f"SELECT COUNT(*), MIN({col}), MAX({col}), AVG({col}) FROM analog_measurements WHERE {condition};")
    cnt, min_v, max_v, avg_v = cursor.fetchone()
    print(f"  {desc:<45}: {cnt:,} filas afectadas | Min: {min_v}, Max: {max_v}")

print("\n=== 4. ESTADÍSTICAS BÁSICAS DE VARIABLES ELÉCTRICAS PRINCIPALES ===")
vars_to_stat = ["battvolt", "battcurr", "battsoc", "pv1volt", "pv1curr", "pv1power", "outsumw", "linevolta", "linefreq", "temper1"]
for v in vars_to_stat:
    cursor.execute(f"SELECT MIN({v}), MAX({v}), AVG({v}) FROM analog_measurements WHERE {v} IS NOT NULL;")
    min_v, max_v, avg_v = cursor.fetchone()
    print(f"  {v:<15}: Min = {min_v:10.2f} | Max = {max_v:10.2f} | Prom = {avg_v:10.2f}")

print("\n=== 5. ANÁLISIS DE FUENTES EN CONTEXT ===")
cursor.execute("SELECT json_extract(value, '$.source'), COUNT(*) FROM context GROUP BY json_extract(value, '$.source');")
sources = cursor.fetchall()
for src, cnt in sources:
    print(f"  Fuente context '{src}': {cnt:,} registros")

conn.close()
