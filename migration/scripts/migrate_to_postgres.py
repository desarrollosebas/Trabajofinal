"""
SolarDB — Script de Migración: SQLite → PostgreSQL
====================================================
Extrae datos de analog_measurements (2,989,759 filas) y context (25,178 filas)
del SQLite de OpenCEM y los carga en PostgreSQL a través del pipeline de staging.

Pipeline:
  1. Crear lote de carga en calidad.lote_carga
  2. Extraer del SQLite en lotes de 50,000 filas
  3. Insertar en staging.staging_telemetria via COPY (CSV)
  4. Ejecutar fn_ejecutar_pipeline_telemetria() para validar y mover
  5. Limpiar staging

Uso:
  python migrate_to_postgres.py

Requisitos:
  pip install psycopg2-binary
  (sqlite3 incluido en Python estándar)
"""

import sqlite3
import psycopg2
import psycopg2.extras
import os
import sys
import time
import csv
import io

# ── Configuración ──────────────────────────────────────────────────────────
SQLITE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'data', 'opencem-v1.0.0.sqlite'
)

PG_CONFIG = dict(
    host='localhost', port=5432, dbname='solardb',
    user='postgres', password='postgres'
)

BATCH_SIZE = 50_000  # filas por lote de COPY

# Columnas de analog_measurements en el orden exacto del SQLite
SQLITE_COLS = [
    'read_ts', 'inverter',
    'battvolt', 'battcurr', 'battsoc', 'battchgpower', 'battreserve',
    'linechgcurr', 'pvchgcurr',
    'pv1volt', 'pv1curr', 'pv1power', 'pvreserve',
    'outvolta', 'outcurra', 'outfreq', 'invcurra',
    'outw_a', 'outva_a', 'loadpercenta', 'normalloadw_a',
    'outsumw', 'outsumva', 'sumloadpercent',
    'generatedpowerp_a', 'generatedpowers_a', 'generatedpowerq_a',
    'linevolta', 'linecurra', 'linefreq', 'linepowerva_a', 'linepowerw_a',
    'busvoltp', 'busvoltn',
    'temper1', 'temper2', 'temper3', 'temper4',
    'sir', 'fanduty', 'otherreserve',
    'gridpowerw_a', 'gridcurr_a', 'grid_reserve',
]

# Columnas de staging (mismas que SQLite + lote_id al inicio)
STAGING_COLS = ['lote_id'] + SQLITE_COLS


def migrate_telemetria():
    """Migrar analog_measurements: SQLite → staging → producción."""
    print('=' * 70)
    print('  SolarDB — Migración de Telemetría')
    print('=' * 70)

    # Verificar SQLite
    if not os.path.exists(SQLITE_PATH):
        print(f'ERROR: No se encontró {SQLITE_PATH}')
        sys.exit(1)
    print(f'SQLite: {SQLITE_PATH}')
    print(f'  Tamaño: {os.path.getsize(SQLITE_PATH) / (1024**3):.2f} GB')

    # Conexiones
    sqlite_conn = sqlite3.connect(SQLITE_PATH)
    sqlite_conn.row_factory = sqlite3.Row
    pg_conn = psycopg2.connect(**PG_CONFIG)
    pg_conn.autocommit = False

    try:
        pg_cur = pg_conn.cursor()
        pg_cur.execute("SET search_path TO staging, solardb, calidad, public")

        # Limpiar datos previos para re-ejecución limpia
        pg_cur.execute("DELETE FROM calidad.registro_cuarentena")
        pg_cur.execute("DELETE FROM solardb.lectura_telemetria")
        pg_cur.execute("DELETE FROM solardb.registro_contexto")
        pg_cur.execute("TRUNCATE staging.staging_telemetria")
        pg_cur.execute("DELETE FROM calidad.lote_carga")
        pg_conn.commit()
        print('Datos previos limpiados.')

        # ── Paso 1: Crear lote de carga ──
        pg_cur.execute("""
            INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
            VALUES ('analog_measurements', 'Migración completa desde OpenCEM v1.0.0 SQLite')
            RETURNING lote_id
        """)
        lote_id = pg_cur.fetchone()[0]
        pg_conn.commit()
        print(f'\nLote de carga creado: lote_id = {lote_id}')

        # ── Paso 2: Contar filas en SQLite ──
        sqlite_cur = sqlite_conn.cursor()
        sqlite_cur.execute('SELECT COUNT(*) FROM analog_measurements')
        total_rows = sqlite_cur.fetchone()[0]
        print(f'Filas en SQLite: {total_rows:,}')

        # ── Paso 3: Extraer y cargar en staging por lotes ──
        print(f'\nCargando en staging (lotes de {BATCH_SIZE:,})...')
        t_start = time.time()
        loaded = 0

        cols_str = ', '.join(SQLITE_COLS)
        staging_cols_str = ', '.join(STAGING_COLS)
        query = f'SELECT {cols_str} FROM analog_measurements ORDER BY read_ts, inverter'

        sqlite_cur.execute(query)

        while True:
            rows = sqlite_cur.fetchmany(BATCH_SIZE)
            if not rows:
                break

            # Construir CSV en memoria para COPY
            buf = io.StringIO()
            writer = csv.writer(buf, delimiter='\t', lineterminator='\n')
            for row in rows:
                # Prepend lote_id, convert None to \N for COPY
                values = [lote_id]
                for val in row:
                    if val is None:
                        values.append(r'\N')
                    else:
                        values.append(val)
                writer.writerow(values)

            buf.seek(0)
            pg_cur.copy_from(
                buf,
                'staging_telemetria',
                sep='\t',
                null=r'\N',
                columns=STAGING_COLS
            )
            pg_conn.commit()

            loaded += len(rows)
            elapsed = time.time() - t_start
            rate = loaded / elapsed if elapsed > 0 else 0
            pct = (loaded / total_rows) * 100
            print(f'  {loaded:>10,} / {total_rows:,} ({pct:5.1f}%) '
                  f'  {rate:,.0f} filas/s  '
                  f'  {elapsed:.0f}s transcurridos', end='\r')

        print()  # newline after progress
        t_load = time.time() - t_start
        print(f'Carga en staging completada: {loaded:,} filas en {t_load:.1f}s '
              f'({loaded/t_load:,.0f} filas/s)')

        # ── Paso 4: Ejecutar pipeline de validación ──
        print('\nEjecutando pipeline de validación...')
        t_pipeline = time.time()

        pg_cur.execute(
            'SELECT * FROM staging.fn_ejecutar_pipeline_telemetria(%s)',
            (lote_id,)
        )
        result = pg_cur.fetchone()
        pg_conn.commit()

        # Capturar notices
        for notice in pg_conn.notices:
            if 'NOTICE' in notice:
                msg = notice.replace('NOTICE:', '').replace('NOTICE', '').strip()
                if msg:
                    print(f'  {msg}')
        pg_conn.notices.clear()

        t_pipeline_elapsed = time.time() - t_pipeline
        print(f'\nPipeline completado en {t_pipeline_elapsed:.1f}s')
        print(f'  Filas validadas:  {result[0]:,}')
        print(f'  Filas rechazadas: {result[1]:,}')
        print(f'  Filas insertadas: {result[2]:,}')
        print(f'  Filas cuarentena: {result[3]:,}')

        # ── Paso 5: Verificación post-migración ──
        print('\n' + '=' * 70)
        print('  Verificación Post-Migración')
        print('=' * 70)

        pg_cur.execute('SELECT COUNT(*) FROM solardb.lectura_telemetria')
        prod_count = pg_cur.fetchone()[0]

        pg_cur.execute('SELECT COUNT(*) FROM calidad.registro_cuarentena WHERE lote_id = %s', (lote_id,))
        quarantine_count = pg_cur.fetchone()[0]

        pg_cur.execute("""
            SELECT estado, filas_leidas, filas_aceptadas, filas_rechazadas
            FROM calidad.lote_carga WHERE lote_id = %s
        """, (lote_id,))
        lote = pg_cur.fetchone()

        pg_cur.execute("""
            SELECT rc.codigo_regla, COUNT(*) as n
            FROM calidad.registro_cuarentena rq
            JOIN calidad.regla_calidad rc ON rq.regla_id = rc.regla_id
            WHERE rq.lote_id = %s
            GROUP BY rc.codigo_regla
            ORDER BY n DESC
        """, (lote_id,))
        regla_counts = pg_cur.fetchall()

        pg_cur.execute("""
            SELECT inversor_id, COUNT(*), MIN(ts_lectura), MAX(ts_lectura)
            FROM solardb.lectura_telemetria
            GROUP BY inversor_id ORDER BY inversor_id
        """)
        inv_stats = pg_cur.fetchall()

        print(f'  Lote {lote_id}: estado={lote[0]}, '
              f'leídas={lote[1]:,}, aceptadas={lote[2]:,}, rechazadas={lote[3]:,}')
        print(f'  Filas en producción: {prod_count:,}')
        print(f'  Filas en cuarentena: {quarantine_count:,}')

        if regla_counts:
            print(f'  Desglose de cuarentena:')
            for regla, n in regla_counts:
                print(f'    {regla}: {n:,} filas')

        if inv_stats:
            print(f'  Por inversor:')
            for inv_id, count, ts_min, ts_max in inv_stats:
                print(f'    Inversor {inv_id}: {count:,} filas, '
                      f'{ts_min} → {ts_max}')

        # ── Paso 6: Limpiar staging ──
        print('\nLimpiando staging...')
        pg_cur.execute('TRUNCATE staging.staging_telemetria')
        pg_conn.commit()
        print('Staging truncado.')

        # ── Paso 7: ANALYZE para actualizar estadísticas ──
        print('Ejecutando ANALYZE...')
        pg_conn.autocommit = True
        pg_cur.execute('ANALYZE solardb.lectura_telemetria')
        pg_cur.execute('ANALYZE calidad.registro_cuarentena')
        pg_cur.execute('ANALYZE calidad.lote_carga')
        print('ANALYZE completado.')

        t_total = time.time() - t_start
        print(f'\n{"=" * 70}')
        print(f'  MIGRACIÓN COMPLETADA')
        print(f'  Tiempo total: {t_total:.1f}s ({t_total/60:.1f} min)')
        print(f'  Filas en producción: {prod_count:,}')
        print(f'  Filas en cuarentena: {quarantine_count:,}')
        print(f'{"=" * 70}')

    except Exception as e:
        pg_conn.rollback()
        print(f'\nERROR FATAL: {e}')
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        sqlite_conn.close()
        pg_conn.close()


def migrate_contexto():
    """Migrar context: SQLite → solardb.registro_contexto."""
    print(f'\n{"=" * 70}')
    print('  SolarDB — Migración de Contexto')
    print(f'{"=" * 70}')

    sqlite_conn = sqlite3.connect(SQLITE_PATH)
    pg_conn = psycopg2.connect(**PG_CONFIG)
    pg_conn.autocommit = False
    pg_cur = pg_conn.cursor()

    try:
        # Crear lote
        pg_cur.execute("""
            INSERT INTO calidad.lote_carga (tabla_origen, observaciones)
            VALUES ('context', 'Migración de contexto operativo desde OpenCEM v1.0.0')
            RETURNING lote_id
        """)
        lote_id = pg_cur.fetchone()[0]
        pg_conn.commit()
        print(f'Lote de carga: lote_id = {lote_id}')

        # Leer tipos de contexto
        pg_cur.execute('SELECT codigo_fuente, tipo_contexto_id FROM solardb.cat_tipo_contexto')
        tipo_map = dict(pg_cur.fetchall())

        # Leer contexto de SQLite
        sqlite_cur = sqlite_conn.cursor()
        sqlite_cur.execute("""
            SELECT read_ts, source, key, value, description
            FROM context ORDER BY read_ts
        """)

        inserted = 0
        skipped = 0
        for row in sqlite_cur:
            read_ts, source, key, value, description = row

            # Buscar tipo_contexto_id
            tipo_id = tipo_map.get(source)
            if tipo_id is None:
                skipped += 1
                continue

            # Construir JSONB
            import json
            valor_dict = {}
            if key:
                valor_dict['key'] = key
            if value:
                try:
                    valor_dict['value'] = json.loads(value)
                except (json.JSONDecodeError, TypeError):
                    valor_dict['value'] = value
            if description:
                valor_dict['description'] = description
            if not valor_dict:
                valor_dict = {'raw': True}

            # Determinar si contiene PII
            contiene_pii = (source == 'wsl_bash_history')

            # Convertir timestamp
            ts_contexto = None
            if read_ts is not None:
                ts_contexto = f"to_timestamp({read_ts})"

            pg_cur.execute("""
                INSERT INTO solardb.registro_contexto
                    (tipo_contexto_id, ts_contexto, valor, contiene_datos_personales, lote_id)
                VALUES (%s, to_timestamp(%s), %s::jsonb, %s, %s)
            """, (
                tipo_id,
                read_ts,
                json.dumps(valor_dict, ensure_ascii=False),
                contiene_pii,
                lote_id
            ))
            inserted += 1

            if inserted % 5000 == 0:
                pg_conn.commit()
                print(f'  {inserted:,} filas insertadas...', end='\r')

        # Actualizar lote
        pg_cur.execute("""
            UPDATE calidad.lote_carga
            SET filas_leidas = %s, filas_aceptadas = %s, filas_rechazadas = %s,
                fecha_fin = now(), estado = 'COMPLETADO'
            WHERE lote_id = %s
        """, (inserted + skipped, inserted, skipped, lote_id))
        pg_conn.commit()

        print(f'  Contexto migrado: {inserted:,} insertadas, {skipped:,} omitidas')

        # ANALYZE
        pg_conn.autocommit = True
        pg_cur.execute('ANALYZE solardb.registro_contexto')
        print('  ANALYZE completado.')

    except Exception as e:
        pg_conn.rollback()
        print(f'ERROR: {e}')
        import traceback
        traceback.print_exc()
    finally:
        sqlite_conn.close()
        pg_conn.close()


if __name__ == '__main__':
    migrate_telemetria()
    migrate_contexto()
