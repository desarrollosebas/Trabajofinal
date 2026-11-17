import psycopg2
conn = psycopg2.connect(host='localhost', port=5432, dbname='solardb', user='postgres', password='postgres')
cur = conn.cursor()
cur.execute("""
    SELECT pg_cancel_backend(pid)
    FROM pg_stat_activity
    WHERE query LIKE '%SELECT COUNT(*) FROM staging.staging_telemetria%'
      AND pid != pg_backend_pid()
""")
print('Cancelled queries.')
conn.close()
