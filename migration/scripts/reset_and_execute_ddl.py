"""Resetear y re-ejecutar DDL de SolarDB."""
import psycopg2
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

SCRIPTS = [
    'sql/00_crear_esquemas.sql',
    'sql/01_crear_dominios.sql',
    'sql/02_crear_catalogos.sql',
    'sql/03_crear_tablas.sql',
    'sql/04_crear_restricciones.sql',
    'sql/05_crear_indices.sql',
    'sql/06_crear_vistas.sql',
    'sql/07_crear_funciones_triggers.sql',
    'sql/08_crear_staging.sql',
    'sql/09_carga_catalogos.sql',
]

conn = psycopg2.connect(
    host='localhost', port=5432, dbname='solardb',
    user='postgres', password='postgres'
)
conn.autocommit = True

cur = conn.cursor()
print('Limpiando esquemas existentes...')
cur.execute('DROP SCHEMA IF EXISTS solardb CASCADE')
cur.execute('DROP SCHEMA IF EXISTS staging CASCADE')
cur.execute('DROP SCHEMA IF EXISTS calidad CASCADE')
print('Esquemas eliminados.')

conn.autocommit = False

for script_path in SCRIPTS:
    full_path = os.path.join(BASE_DIR, script_path)
    name = os.path.basename(script_path)
    with open(full_path, 'r', encoding='utf-8') as f:
        sql = f.read()
    try:
        cur = conn.cursor()
        cur.execute(sql)
        conn.commit()
        notices = [n.strip() for n in conn.notices]
        conn.notices.clear()
        status = ' | '.join(n for n in notices if n.startswith('NOTICE'))
        print(f'  ✓ {name}  {status}')
    except Exception as e:
        conn.rollback()
        print(f'  ✗ {name}: {e}')
        sys.exit(1)

print('\n=== TODOS LOS SCRIPTS OK ===')

# Resumen
cur = conn.cursor()
queries = [
    ("Tablas", "SELECT count(*) FROM pg_tables WHERE schemaname IN ('solardb','staging','calidad')"),
    ("Dominios", "SELECT count(*) FROM pg_type t JOIN pg_namespace n ON t.typnamespace=n.oid WHERE n.nspname='solardb' AND t.typtype='d'"),
    ("Vistas", "SELECT count(*) FROM information_schema.views WHERE table_schema IN ('solardb','calidad')"),
    ("Funciones", "SELECT count(*) FROM information_schema.routines WHERE routine_schema='staging' AND routine_type='FUNCTION'"),
    ("Indices custom", "SELECT count(*) FROM pg_indexes WHERE schemaname IN ('solardb','calidad','staging') AND indexname LIKE 'idx_%'"),
    ("Reglas calidad", "SELECT count(*) FROM calidad.regla_calidad"),
    ("Inversores", "SELECT count(*) FROM solardb.dim_inversor"),
    ("Variables fisicas", "SELECT count(*) FROM solardb.cat_variable_fisica"),
]
for label, q in queries:
    cur.execute(q)
    print(f'  {label}: {cur.fetchone()[0]}')

cur.close()
conn.close()
