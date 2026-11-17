"""Crear la base de datos solardb en PostgreSQL."""
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

conn = psycopg2.connect(
    host='localhost', port=5432, dbname='postgres',
    user='postgres', password='postgres'
)
conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
cur = conn.cursor()

cur.execute("SELECT 1 FROM pg_database WHERE datname = 'solardb'")
if cur.fetchone():
    print('Base de datos solardb ya existe. Eliminando para recrear...')
    # Terminar conexiones activas
    cur.execute("""
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = 'solardb' AND pid <> pg_backend_pid()
    """)
    cur.execute('DROP DATABASE solardb')

cur.execute("CREATE DATABASE solardb ENCODING 'UTF8'")
print('Base de datos solardb creada exitosamente.')
cur.close()
conn.close()
