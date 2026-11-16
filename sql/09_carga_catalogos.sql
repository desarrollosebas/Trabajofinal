/*
 * ============================================================================
 *  SolarDB — Script 09: Carga de Datos en Catálogos
 * ============================================================================
 *  Proyecto  : SolarDB – Integridad y calidad de datos con restricciones,
 *              dominios y tablas de cuarentena
 *  Materia   : Bases de Datos I – Taller 6
 *
 *  Descripción:
 *      Inserta los datos de referencia en las tablas de catálogo:
 *        • dim_sitio           — 1 sitio (CUHK-Shenzhen)
 *        • dim_subsistema      — 2 subsistemas
 *        • dim_inversor        — 2 inversores
 *        • cat_tipo_contexto   — 7 fuentes de contexto
 *        • cat_unidad_medida   — 9 unidades SI
 *        • cat_variable_fisica — 38 variables de medición
 *        • regla_calidad       — 4 reglas de validación
 *
 *  Prerequisito : Scripts 00–04 (esquemas, dominios, catálogos, tablas).
 *  Idempotente  : Sí (ON CONFLICT DO NOTHING donde aplica).
 *
 *  Fuentes de datos:
 *      • column_dictionary.json (OpenCEM v1.0.0)
 *      • database_export_report.json
 *      • docs/02_diagnostico_calidad.md (análisis empírico)
 *      • Referencia del campus: Bartels et al. (2026), OpenCEM v1.0.0
 * ============================================================================
 */

BEGIN;  -- Transacción atómica

-- ═══════════════════════════════════════════════════════════════════════════
--  1. dim_sitio — Campus CUHK-Shenzhen
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO solardb.dim_sitio (nombre_sitio, ciudad, pais, zona_horaria)
VALUES (
    'Campus CUHK-Shenzhen',
    'Shenzhen',
    'China',
    'Asia/Shanghai'
)
ON CONFLICT (nombre_sitio) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
--  2. dim_subsistema — 2 subsistemas de microrred
-- ═══════════════════════════════════════════════════════════════════════════
-- Datos extraídos de la documentación OpenCEM y la tabla specs del SQLite.
-- Subsistema 1: alimenta estaciones de trabajo (Cómputo)
-- Subsistema 2: alimenta sistema HVAC (climatización)

INSERT INTO solardb.dim_subsistema
    (sitio_id, nombre_subsistema, carga_alimentada,
     num_paneles, potencia_panel_w, quimica_bateria,
     capacidad_bateria_ah, voltaje_nominal_bateria_v)
VALUES
    (
        (SELECT sitio_id FROM solardb.dim_sitio WHERE nombre_sitio = 'Campus CUHK-Shenzhen'),
        'Microrred Solar - Cómputo',
        'Estaciones de trabajo y equipos de cómputo del laboratorio',
        6, 450, 'LiFePO4',
        200.0, 48.0
    ),
    (
        (SELECT sitio_id FROM solardb.dim_sitio WHERE nombre_sitio = 'Campus CUHK-Shenzhen'),
        'Microrred Solar - HVAC',
        'Sistema de climatización y ventilación del laboratorio',
        6, 450, 'LiFePO4',
        200.0, 48.0
    )
ON CONFLICT (nombre_subsistema) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
--  3. dim_inversor — 2 inversores solares híbridos
-- ═══════════════════════════════════════════════════════════════════════════
-- inversor_id = 1 y 2, coincide directamente con el campo "inverter"
-- del dataset SQLite.

INSERT INTO solardb.dim_inversor
    (inversor_id, subsistema_id, modelo, fabricante,
     potencia_nominal_w, frecuencia_nominal_hz, tension_nominal_red_v)
VALUES
    (
        1,
        (SELECT subsistema_id FROM solardb.dim_subsistema
         WHERE nombre_subsistema = 'Microrred Solar - Cómputo'),
        'Inversor Híbrido Solar',
        'No especificado en dataset',
        6000, 50, '220'
    ),
    (
        2,
        (SELECT subsistema_id FROM solardb.dim_subsistema
         WHERE nombre_subsistema = 'Microrred Solar - HVAC'),
        'Inversor Híbrido Solar',
        'No especificado en dataset',
        6000, 50, '220'
    )
ON CONFLICT (inversor_id) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
--  4. cat_tipo_contexto — 7 fuentes de contexto operativo
-- ═══════════════════════════════════════════════════════════════════════════
-- Fuentes observadas empíricamente en la tabla "context" del SQLite.
-- Conteos: workstation2_log(8902), windows_event_log(6271),
--          workstation1_log(6028), derived_context_pipeline(3708),
--          wsl_bash_history(204), manual_entry(60), manual_workload_entry(5)

INSERT INTO solardb.cat_tipo_contexto (codigo_fuente, descripcion, contiene_pii)
VALUES
    ('workstation2_log',          'Log del sistema operativo de la estación de trabajo 2',   FALSE),
    ('windows_event_log',         'Registro de eventos de Windows del servidor',             FALSE),
    ('workstation1_log',          'Log del sistema operativo de la estación de trabajo 1',   FALSE),
    ('derived_context_pipeline',  'Contexto derivado automáticamente por el pipeline de procesamiento', FALSE),
    ('wsl_bash_history',          'Historial de comandos bash en WSL (puede contener rutas de usuario)', TRUE),
    ('manual_entry',              'Entrada manual registrada por el operador del laboratorio', FALSE),
    ('manual_workload_entry',     'Registro manual de carga de trabajo del laboratorio',     FALSE)
ON CONFLICT (codigo_fuente) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
--  5. cat_unidad_medida — Unidades del Sistema Internacional
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO solardb.cat_unidad_medida (simbolo, nombre, magnitud)
VALUES
    ('V',    'Voltio',                    'Voltaje / Tensión eléctrica'),
    ('A',    'Amperio',                   'Corriente eléctrica'),
    ('W',    'Vatio',                     'Potencia activa'),
    ('VA',   'Voltamperio',               'Potencia aparente'),
    ('VAR',  'Voltamperio reactivo',      'Potencia reactiva'),
    ('Hz',   'Hercio',                    'Frecuencia'),
    ('°C',   'Grado Celsius',             'Temperatura'),
    ('%',    'Porcentaje',                'Fracción / Proporción'),
    ('kΩ',   'Kiloohmio',                 'Resistencia eléctrica')
ON CONFLICT (simbolo) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
--  6. cat_variable_fisica — 38 variables de medición
-- ═══════════════════════════════════════════════════════════════════════════
-- Datos extraídos de column_dictionary.json del dataset OpenCEM.
-- Los rangos observados vienen del análisis empírico (02_diagnostico).

INSERT INTO solardb.cat_variable_fisica
    (nombre_columna, descripcion, unidad_id, dominio_pg)
VALUES
    -- Batería
    ('battvolt',    'Voltaje terminal de batería',                    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'V'),    'dom_voltaje'),
    ('battcurr',    'Corriente de batería con signo (+descarga/-carga)', (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente'),
    ('battsoc',     'Estado de carga de batería',                     (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '%'),    'dom_porcentaje'),
    ('battchgpower','Potencia de carga de batería',                   (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa'),

    -- Carga
    ('linechgcurr', 'Corriente de carga desde la red',                (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg'),
    ('pvchgcurr',   'Corriente de carga desde paneles PV',            (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg'),

    -- PV (Panel Solar)
    ('pv1volt',     'Voltaje del canal PV 1',                         (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'V'),    'dom_voltaje'),
    ('pv1curr',     'Corriente del canal PV 1',                       (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg'),
    ('pv1power',    'Potencia activa del canal PV 1',                 (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa_no_neg'),

    -- Salida del inversor (fase A)
    ('outvolta',    'Voltaje de salida (fase A)',                      (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'V'),    'dom_voltaje'),
    ('outcurra',    'Corriente de salida (fase A)',                    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg'),
    ('outfreq',     'Frecuencia de salida',                           (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'Hz'),   'dom_frecuencia'),
    ('invcurra',    'Corriente del inversor (fase A)',                 (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg'),
    ('outw_a',      'Potencia activa de salida (fase A)',              (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa_no_neg'),
    ('outva_a',     'Potencia aparente de salida (fase A)',            (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'VA'),   'dom_potencia_aparente'),
    ('loadpercenta','Porcentaje de carga (fase A)',                    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '%'),    'dom_porcentaje_carga'),
    ('normalloadw_a','Potencia activa de carga normal (fase A)',      (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa_no_neg'),

    -- Totales (suma de fases)
    ('outsumw',     'Suma de potencia activa de salida',              (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa_no_neg'),
    ('outsumva',    'Suma de potencia aparente de salida',            (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'VA'),   'dom_potencia_aparente'),
    ('sumloadpercent','Porcentaje de carga total',                    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '%'),    'dom_porcentaje_carga'),

    -- Potencia generada (fase A)
    ('generatedpowerp_a', 'Potencia activa generada P (fase A)',      (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa_no_neg'),
    ('generatedpowers_a', 'Potencia aparente generada S (fase A)',    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'VA'),   'dom_potencia_aparente'),
    ('generatedpowerq_a', 'Potencia reactiva generada Q (fase A)',    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'VAR'),  'dom_potencia_reactiva'),

    -- Línea / Red eléctrica (fase A)
    ('linevolta',   'Voltaje de la red eléctrica (fase A)',           (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'V'),    'dom_voltaje'),
    ('linecurra',   'Corriente de la red eléctrica (fase A)',         (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg'),
    ('linefreq',    'Frecuencia de la red eléctrica',                 (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'Hz'),   'dom_frecuencia'),
    ('linepowerva_a','Potencia aparente de la red (fase A)',           (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'VA'),   'dom_potencia_aparente'),
    ('linepowerw_a', 'Potencia activa de la red (fase A)',            (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa'),

    -- Bus DC
    ('busvoltp',    'Voltaje del bus DC positivo',                    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'V'),    'dom_voltaje'),
    ('busvoltn',    'Voltaje del bus DC negativo',                    (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'V'),    'dom_voltaje'),

    -- Temperaturas
    ('temper1',     'Temperatura del sensor 1',                       (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '°C'),   'dom_temperatura'),
    ('temper2',     'Temperatura del sensor 2',                       (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '°C'),   'dom_temperatura'),
    ('temper3',     'Temperatura del sensor 3',                       (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '°C'),   'dom_temperatura'),
    ('temper4',     'Temperatura del sensor 4',                       (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '°C'),   'dom_temperatura'),

    -- Otros
    ('sir',         'Resistencia de aislamiento SIR',                 (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'kΩ'),   'dom_resistencia_aislamiento'),
    ('fanduty',     'Ciclo de trabajo del ventilador',                (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = '%'),    'dom_porcentaje'),

    -- Grid (medición directa de red)
    ('gridpowerw_a','Potencia activa de red directa (fase A)',        (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'W'),    'dom_potencia_activa'),
    ('gridcurr_a',  'Corriente de red directa (fase A)',              (SELECT unidad_id FROM solardb.cat_unidad_medida WHERE simbolo = 'A'),    'dom_corriente_no_neg')
ON CONFLICT (nombre_columna) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
--  7. regla_calidad — Reglas de validación del pipeline
-- ═══════════════════════════════════════════════════════════════════════════
-- Basadas en el diagnóstico de calidad (docs/02_diagnostico_calidad.md).

INSERT INTO calidad.regla_calidad
    (codigo_regla, descripcion, variable_afectada, severidad, accion)
VALUES
    (
        'R_TEMP1_IMPOSIBLE',
        'Temperatura temper1 ≤ -20°C: físicamente imposible en Shenzhen '
        '(clima subtropical, mínima histórica ~0°C). Indica fallo de sensor '
        'por circuito abierto. Evidencia: 38 filas con temper1 = -20.3°C.',
        'temper1',
        'ERROR',
        'CUARENTENA'
    ),
    (
        'R_P_MAYOR_S',
        'Potencia activa P > Potencia aparente S: viola la ley física '
        'P ≤ S = |V|×|I| en circuitos AC. Evidencia: 3,811 filas '
        '(Inv1: 3,574, Inv2: 237). Causas probables: error de medición, '
        'desfase temporal entre registros P y S.',
        'outw_a, outva_a, outsumw, outsumva',
        'ERROR',
        'CUARENTENA'
    ),
    (
        'R_NULOS_MODBUS',
        'Valores NULL en columnas de medición por timeout de comunicación '
        'Modbus entre el inversor y el sistema de adquisición. '
        'Evidencia: ~58,000-60,000 filas (~2%% del total). '
        'Acción: ACEPTAR — es dato faltante legítimo, se mantiene como NULL.',
        NULL,
        'INFO',
        'ACEPTAR'
    ),
    (
        'R_FREQ_CERO',
        'Frecuencia linefreq = 0 Hz o outfreq = 0 Hz: NO es error. '
        'Indica modo isla (desconectado de red) o standby del inversor. '
        'Evidencia: 342,592 filas linefreq = 0 Hz, 149,624 outfreq = 0 Hz. '
        'Acción: ACEPTAR — estado operativo legítimo.',
        'linefreq, outfreq',
        'INFO',
        'ACEPTAR'
    )
ON CONFLICT (codigo_regla) DO NOTHING;


-- ─── Verificación de carga ──────────────────────────────────────────────────
DO $$
DECLARE
    v_sitios      INTEGER;
    v_subsistemas INTEGER;
    v_inversores  INTEGER;
    v_contextos   INTEGER;
    v_unidades    INTEGER;
    v_variables   INTEGER;
    v_reglas      INTEGER;
BEGIN
    SELECT count(*) INTO v_sitios      FROM solardb.dim_sitio;
    SELECT count(*) INTO v_subsistemas FROM solardb.dim_subsistema;
    SELECT count(*) INTO v_inversores  FROM solardb.dim_inversor;
    SELECT count(*) INTO v_contextos   FROM solardb.cat_tipo_contexto;
    SELECT count(*) INTO v_unidades    FROM solardb.cat_unidad_medida;
    SELECT count(*) INTO v_variables   FROM solardb.cat_variable_fisica;
    SELECT count(*) INTO v_reglas      FROM calidad.regla_calidad;

    RAISE NOTICE '✓ Catálogos cargados:';
    RAISE NOTICE '  dim_sitio:           % filas', v_sitios;
    RAISE NOTICE '  dim_subsistema:      % filas', v_subsistemas;
    RAISE NOTICE '  dim_inversor:        % filas', v_inversores;
    RAISE NOTICE '  cat_tipo_contexto:   % filas', v_contextos;
    RAISE NOTICE '  cat_unidad_medida:   % filas', v_unidades;
    RAISE NOTICE '  cat_variable_fisica: % filas', v_variables;
    RAISE NOTICE '  regla_calidad:       % filas', v_reglas;
END
$$;

COMMIT;
