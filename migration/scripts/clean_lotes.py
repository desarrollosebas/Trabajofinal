import psycopg2
conn = psycopg2.connect(host='localhost', port=5432, dbname='solardb', user='postgres', password='postgres')
cur = conn.cursor()
cur.execute("DELETE FROM calidad.lote_carga WHERE estado = 'EN_CURSO'")
conn.commit()
print('Lotes limpios.')
conn.close()
