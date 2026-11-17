import psycopg2
conn = psycopg2.connect(host='localhost', port=5432, dbname='solardb', user='postgres', password='postgres')
cur = conn.cursor()
cur.execute("""
    SELECT pid, state, now() - query_start as duration, wait_event_type, wait_event, query
    FROM pg_stat_activity
    WHERE datname = 'solardb' AND pid != pg_backend_pid()
""")
for r in cur.fetchall():
    print(f'PID {r[0]} | state: {r[1]} | duration: {r[2]} | wait: {r[3]}:{r[4]}')
    print(f'Query: {r[5][:150]}...')
conn.close()
