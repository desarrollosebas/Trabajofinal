"""Ejecutar todos los scripts DDL de SolarDB en orden."""
import psycopg2
import os
import sys

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

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

conn = psycopg2.connect(
    host='localhost', port=5432, dbname='solardb',
    user='postgres', password='postgres'
)
conn.autocommit = False

for script_path in SCRIPTS:
    full_path = os.path.join(BASE_DIR, script_path)
    print(f'\n{"="*60}')
    print(f'Ejecutando: {script_path}')
    print(f'{"="*60}')

    with open(full_path, 'r', encoding='utf-8') as f:
        sql = f.read()

    try:
        cur = conn.cursor()
        cur.execute(sql)
        conn.commit()

        # Capturar NOTICE messages
        for notice in conn.notices:
            print(f'  {notice.strip()}')
        conn.notices.clear()

        print(f'  ✓ OK')
    except Exception as e:
        conn.rollback()
        print(f'  ✗ ERROR: {e}')
        sys.exit(1)

print(f'\n{"="*60}')
print('TODOS LOS SCRIPTS EJECUTADOS EXITOSAMENTE')
print(f'{"="*60}')

# Verificación final
cur = conn.cursor()

# Contar objetos
cur.execute("""
    SELECT schemaname, count(*)
    FROM pg_tables
    WHERE schemaname IN ('solardb','staging','calidad')
    GROUP BY schemaname ORDER BY schemaname
""")
print('\nTablas por esquema:')
for row in cur.fetchall():
    print(f'  {row[0]}: {row[1]}')

cur.execute("""
    SELECT count(*) FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'solardb' AND t.typtype = 'd'
""")
print(f'Dominios en solardb: {cur.fetchone()[0]}')

cur.execute("""
    SELECT count(*) FROM information_schema.views
    WHERE table_schema IN ('solardb','calidad')
""")
print(f'Vistas: {cur.fetchone()[0]}')

cur.execute("""
    SELECT count(*) FROM information_schema.routines
    WHERE routine_schema = 'staging' AND routine_type = 'FUNCTION'
""")
print(f'Funciones PL/pgSQL: {cur.fetchone()[0]}')

cur.close()
conn.close()
