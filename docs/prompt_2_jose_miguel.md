# PROMPT PARA JOSE MIGUEL SOSA CARTAGENA — RONDA 2
# Herramienta: ChatGPT, Claude, Gemini Web u otra IA conversacional
# Copiar TODO el contenido de este archivo y pegarlo como primer mensaje en una conversación nueva.
# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANTE PARA JOSE MIGUEL: Después de pegar este prompt en la IA, ella
# te generará cada archivo uno por uno. Tú debes COPIAR el contenido que
# la IA genere, GUARDARLO como archivo .md en la carpeta correspondiente
# del proyecto, y luego decirle "continúa" para el siguiente archivo.
# Al final, subirás todo a GitHub con los comandos de Git que se indican abajo.
# ─────────────────────────────────────────────────────────────────────────────

# PROYECTO UNIVERSITARIO — TALLER 6 (FASE FINAL)
# SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL
# ROL: Actualización de Documentación con Métricas Reales e Informe Final PDF

<CONFIGURACIÓN>

Idioma de trabajo: Español.
Motor de base de datos: PostgreSQL 18.
Herramienta de administración: DBeaver 26.2.2.
Control de versiones: Git y GitHub.
Formato de entrega: Archivos Markdown (.md) listos para incorporar a un repositorio GitHub, y un informe final en PDF.

Vas a trabajar JUNTO con Jose Miguel (el usuario humano). Él no tiene un agente automatizado como Antigravity; él debe copiar tus respuestas manualmente a archivos y subirlos a Git.

Por lo tanto:
- Genera CADA archivo completo de principio a fin, listo para guardar como `.md`.
- NO generes fragmentos sueltos ni instrucciones para que él redacte. Genera TÚ el contenido completo.
- Entrega UN archivo por respuesta. Al terminar cada archivo, dile "Guarda este archivo como `docs/NOMBRE.md` y dime 'continúa' cuando estés listo para el siguiente."
- Si un archivo es muy largo, divídelo en partes y dile "continúo en el siguiente mensaje".

</CONFIGURACIÓN>

<ROL>

Actúa simultáneamente como:

1. **Ingeniero de datos senior** especializado en PostgreSQL 18, tipos de datos, diseño físico de bases de datos, documentación técnica de diccionarios de datos y estimación de almacenamiento.
2. **Abogado especialista en protección de datos personales** con dominio de la Ley Estatutaria 1581 de 2012 de Colombia (Régimen General de Protección de Datos Personales), sus decretos reglamentarios (1377/2013) y la Ley 1266 de 2008 (Habeas Data).
3. **Redactor técnico-académico** capaz de compilar un informe final universitario con portada institucional, tabla de contenidos numerada, figuras referenciadas y formato APA para citas.
4. **Tutor universitario** que explica las decisiones técnicas con claridad para que un estudiante de Bases de Datos I pueda comprender y defender cada aspecto durante una sustentación oral.

Debes tener dominio de:
- Tipos de datos de PostgreSQL (NUMERIC, DOUBLE PRECISION, BIGINT, INTEGER, SMALLINT, BOOLEAN, TEXT, VARCHAR, TIMESTAMP WITH TIME ZONE, JSONB).
- Restricciones declarativas (PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, NOT NULL, DEFAULT).
- Dominios personalizados (CREATE DOMAIN).
- Índices (B-tree, GIN, BRIN, parciales).
- Ley 1581 de 2012 de Colombia: artículos específicos (3, 4, 5, 7, 8, 9, 10, 12, 13, 15, 17, 18).
- Principios de minimización, finalidad, necesidad y confidencialidad del tratamiento de datos personales.
- Redacción académica y técnica en español.

</ROL>

<CONTEXTO DEL PROYECTO>

Este proyecto forma parte del Taller 6 de Bases de Datos I, en la Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II.

**Docente:** Ramiro Grisales Montoya.

**Integrantes del equipo:**

1. Juan Sebastian Raigosa Gil — Coordinador. Completó la arquitectura SolarDB (dominios, staging, cuarentena, migración masiva y DDL).
2. **Jose Miguel Sosa Cartagena (TÚ estás generando archivos PARA él)** — En la Ronda 1, creó el diccionario de datos, diseño físico, análisis de privacidad y guía de sustentación. Ahora debe ACTUALIZARLOS con las métricas reales post-migración y compilar el informe final PDF.
3. Deysi Carolina Echavarria Soto — Creó el modelado conceptual, lógico, normalización 3FN y consultas SQL de negocio.

**Repositorio oficial del equipo:** https://github.com/desarrollosebas/Trabajofinal

**Línea de profundización:** SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena.

**Dataset:** OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223).

**Cita obligatoria (formato APA 7ª ed.):**
Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

</CONTEXTO DEL PROYECTO>

<MÉTRICAS REALES POST-MIGRACIÓN — DATOS VERIFICADOS>

La migración de datos fue ejecutada exitosamente por el coordinador. Todos los números que aparecen a continuación son REALES y VERIFICADOS. Debes usarlos exactamente así en la documentación, SIN redondear y SIN inventar otros.

**Balance general de migración:**

| Indicador | Valor Real Verificado |
|---|---|
| Filas leídas de telemetría (SQLite) | **2,989,759** |
| Filas aceptadas en producción (`solardb.lectura_telemetria`) | **2,965,337** (99.18%) |
| Filas aisladas en cuarentena (`calidad.registro_cuarentena`) | **24,422** (0.82%) |
| Filas de contexto operativo (`solardb.registro_contexto`) | **25,178** (100%) |
| Cuadratura matemática | 2,965,337 + 24,422 = 2,989,759 exacta |
| Meta del profesor | ≥ 1,000,000 lecturas → **Superado (298.9%)** |

**Desglose de cuarentena por regla de calidad:**

| Código | Filas | Motivo Técnico |
|---|---|---|
| `R_P_MAYOR_S` | **24,375** | Potencia activa > potencia aparente. Violación P ≤ S = |V|·|I| en CA. Desfase temporal en muestreo Modbus. |
| `R_TEMP1_IMPOSIBLE` | **38** | temper1 = -20.3°C. Imposible en Shenzhen (mínima histórica ~0°C). Falla de sensor / circuito abierto. |
| `R_LINEPOWERVA_NEG` | **8** | Potencia aparente negativa (S < 0). Magnitud escalar no negativa por definición. Falla de muestreo. |
| `R_LINECURRA_NEG` | **1** | Corriente de red negativa. Sensor monofásico unidireccional con lectura espuria aislada. |
| **Total** | **24,422** | Almacenadas en `calidad.registro_cuarentena` como JSONB con estado PENDIENTE. |

**Distribución por inversor en producción:**

| Inversor | Función | Filas Aceptadas | % | Rango Temporal |
|---|---|---|---|---|
| Inversor 1 | Cómputo (GPU/CPU) | **1,594,461** | 53.77% | 2025-07-12 13:31:35 → 2026-07-13 05:13:53 (~1 año) |
| Inversor 2 | HVAC (climatización) | **1,370,876** | 46.23% | 2025-07-14 05:53:32 → 2026-06-22 05:35:24 (~11 meses) |
| **Total** | | **2,965,337** | 100% | Cadencia mediana: 12.58 s |

**Almacenamiento físico en disco (PostgreSQL 18):**

| Tabla | Total | Datos | Índices |
|---|---|---|---|
| `solardb.lectura_telemetria` | **3,824 MB** (3.73 GB) | 3,440 MB | 384 MB |
| `calidad.registro_cuarentena` | **34 MB** | 32 MB | 2.2 MB |
| `solardb.registro_contexto` | **26 MB** | 17 MB | 9.3 MB |
| Catálogos dimensionales + reglas | **< 1 MB** | < 100 KB | < 200 KB |
| **Total SolarDB** | **~3.88 GB** | | |

**Lotes de carga auditados:**

| lote_id | tabla_origen | estado | filas_leidas | filas_aceptadas | filas_rechazadas |
|---|---|---|---|---|---|
| 4 | analog_measurements | COMPLETADO | 2,989,759 | 2,965,337 | 24,422 |
| 6 | context | COMPLETADO | 25,178 | 25,178 | 0 |

**Esquemas PostgreSQL:** `solardb` (producción), `staging` (carga temporal), `calidad` (cuarentena y auditoría).

**12 dominios personalizados (CREATE DOMAIN) en esquema `solardb`:**

| Dominio | Tipo Base | Restricción CHECK | Columnas que lo usan |
|---|---|---|---|
| `dom_voltaje` | DOUBLE PRECISION | `VALUE >= 0` | battvolt, pv1volt, outvolta, linevolta, busvoltp, busvoltn |
| `dom_corriente` | DOUBLE PRECISION | Sin CHECK (con signo) | battcurr |
| `dom_corriente_no_neg` | DOUBLE PRECISION | `VALUE >= 0` | linechgcurr, pvchgcurr, pv1curr, outcurra, invcurra, linecurra, gridcurr_a |
| `dom_potencia_activa` | INTEGER | Sin CHECK (con signo) | battchgpower, linepowerw_a, gridpowerw_a, generatedpowerp_a |
| `dom_potencia_activa_no_neg` | INTEGER | `VALUE >= 0` | pv1power, outw_a, normalloadw_a, outsumw |
| `dom_potencia_aparente` | INTEGER | `VALUE >= 0` | outva_a, outsumva, linepowerva_a, generatedpowers_a |
| `dom_potencia_reactiva` | INTEGER | Sin CHECK (con signo) | generatedpowerq_a |
| `dom_frecuencia` | DOUBLE PRECISION | `VALUE >= 0` | outfreq, linefreq |
| `dom_temperatura` | DOUBLE PRECISION | Sin CHECK (anomalías → cuarentena) | temper1, temper2, temper3, temper4 |
| `dom_porcentaje` | SMALLINT | `VALUE BETWEEN 0 AND 100` | battsoc, fanduty |
| `dom_porcentaje_carga` | SMALLINT | `VALUE BETWEEN 0 AND 110` | loadpercenta, sumloadpercent |
| `dom_resistencia_aislamiento` | INTEGER | `VALUE >= 0` | sir |

**6 catálogos dimensionales:**
- `solardb.dim_sitio` — Sitio/campus (1 fila: CUHK-Shenzhen).
- `solardb.dim_subsistema` — Subsistemas de microrred (2 filas: Cómputo, HVAC).
- `solardb.dim_inversor` — Inversores (2 filas: Inv1, Inv2).
- `solardb.cat_variable_fisica` — Variables de telemetría (38+ filas).
- `solardb.cat_unidad_medida` — Unidades de medida (V, A, W, VA, Hz, °C, %, kΩ).
- `solardb.cat_tipo_contexto` — Tipos de contexto (7 fuentes: workstation1_log, etc.).

**Tabla principal `solardb.lectura_telemetria` (46 columnas):**
- PK: `lectura_id BIGINT GENERATED ALWAYS AS IDENTITY`
- UNIQUE natural: `(inversor_id, ts_lectura)`
- FK: `inversor_id → dim_inversor(inversor_id)`, `lote_id → calidad.lote_carga(lote_id)`
- 38 columnas numéricas de medición con dominios personalizados
- 4 columnas JSONB reservadas (battreserve, pvreserve, otherreserve, grid_reserve)

**Tabla `solardb.registro_contexto` (6 columnas):**
- PK: `contexto_id BIGINT GENERATED ALWAYS AS IDENTITY`
- FK: `tipo_contexto_id → cat_tipo_contexto`, `lote_id → calidad.lote_carga`
- `valor JSONB NOT NULL CHECK (jsonb_typeof(valor) = 'object')`
- `contiene_datos_personales BOOLEAN NOT NULL DEFAULT FALSE` — Flag de Ley 1581/2012.

**Registros de contexto por fuente (campo `source` dentro del JSONB `valor`):**

| Fuente | Cantidad | Contenido | ¿Datos personales? |
|---|---|---|---|
| `workstation2_log` | 8,902 | Logs GPU/CPU estación 2 | Posible (nombres de tareas) |
| `windows_event_log` | 6,271 | Eventos Windows | Sí (nombres de usuario) |
| `workstation1_log` | 6,028 | Logs tareas estación 1 | Posible |
| `derived_context_pipeline` | 3,708 | Eventos climáticos/solares | No |
| `wsl_bash_history` | **204** | **Comandos de terminal Linux** | **SÍ (nombres de usuario, rutas, IPs)** |
| `manual entry` | 60 | Calendario institucional | No |
| `manual_workload_entry` | 5 | Pruebas de carga | No |

</MÉTRICAS REALES POST-MIGRACIÓN>

<TU MISIÓN — TAREA 1: ACTUALIZAR DICCIONARIO DE DATOS CON MÉTRICAS REALES>

Genera el archivo actualizado `docs/08_diccionario_datos.md` COMPLETO.

Este archivo ya existe (lo creaste en la Ronda 1 con estimaciones teóricas). Ahora debes generar la versión DEFINITIVA que reemplace las estimaciones con los datos reales post-migración.

**Cambios obligatorios respecto a la versión anterior:**

1. **Cantidad de filas por tabla:** Usar los valores reales:
   - `solardb.lectura_telemetria`: 2,965,337 filas (antes decía "hasta ~2,989,759").
   - `calidad.registro_cuarentena`: 24,422 filas (antes era una estimación).
   - `solardb.registro_contexto`: 25,178 filas.
   - `calidad.lote_carga`: 2 lotes completados (IDs 4 y 6).
   - `calidad.regla_calidad`: 6 reglas activas (R_TEMP1_IMPOSIBLE, R_P_MAYOR_S, R_NULOS_MODBUS, R_FREQ_CERO, R_LINECURRA_NEG, R_LINEPOWERVA_NEG).

2. **Tamaños en disco:** Incluir los tamaños reales (3,824 MB, 34 MB, 26 MB, etc.).

3. **Columnas de `lectura_telemetria`:** Verificar que las 46 columnas están documentadas con su dominio, tipo base, CHECK, FK, unidad de medida y evidencia de la fuente.

4. **Mantener las justificaciones técnicas:**
   - NUMERIC vs DOUBLE PRECISION.
   - TIMESTAMP WITH TIME ZONE vs sin TZ.
   - JSONB vs JSON.
   - BIGINT vs INTEGER.

**Formato del diccionario por tabla (mantener el formato de la Ronda 1):**

Encabezado de tabla: nombre, esquema, propósito, cantidad real de filas, tamaño en disco.

Por cada columna:

| Campo | Contenido |
|---|---|
| Nombre | Nombre de la columna |
| Tipo de dato | Tipo PostgreSQL exacto |
| Dominio asociado | CREATE DOMAIN si aplica |
| Nulabilidad | NOT NULL o NULL |
| Valor por defecto | DEFAULT si aplica |
| PK | ✅ si es PK |
| FK | Tabla→columna referenciada |
| UNIQUE | ✅ si aplica |
| CHECK | Expresión si aplica |
| Unidad de medida | V, A, W, VA, Hz, °C, %, kΩ |
| Evidencia de la unidad | column_dictionary.json, campo unit del registro X |
| Descripción funcional | Qué significa en el negocio |

</TU MISIÓN — TAREA 1>

<TU MISIÓN — TAREA 2: ACTUALIZAR DISEÑO FÍSICO CON MÉTRICAS REALES>

Genera el archivo actualizado `docs/09_diseno_fisico.md` COMPLETO.

**Cambios obligatorios:**

1. **Estimación de almacenamiento:** Reemplazar estimaciones teóricas con los tamaños reales post-migración.

2. **Estrategia de índices:** Actualizar con los 7 índices que realmente se crearon:
   - `idx_lectura_ts` (B-tree sobre ts_lectura) — Búsqueda por rango temporal.
   - `idx_lectura_lote` (B-tree sobre lote_id) — JOIN con lote_carga.
   - `idx_lectura_inversor_ts` (B-tree sobre inversor_id, ts_lectura) — Consultas por inversor + fecha.
   - `idx_cuarentena_regla` (B-tree sobre regla_id) — Análisis por regla de calidad.
   - `idx_cuarentena_estado` (B-tree parcial WHERE estado = 'PENDIENTE') — Solo filas pendientes de revisión.
   - `idx_contexto_tipo` (B-tree sobre tipo_contexto_id) — Filtrado por tipo de contexto.
   - `idx_contexto_valor_gin` (GIN sobre valor JSONB) — Consultas con operadores `@>`, `?`, `?&`.

3. **Particionamiento:** Mantener la discusión teórica pero agregar la decisión real: "Para el volumen actual (~3M filas) no se implementó particionamiento. Se recomienda evaluarlo si el dataset crece a > 50M filas."

4. **Esquemas:** Confirmar los 3 esquemas reales (`solardb`, `staging`, `calidad`) con su propósito.

</TU MISIÓN — TAREA 2>

<TU MISIÓN — TAREA 3: ACTUALIZAR GUÍA DE SUSTENTACIÓN CON DATOS REALES>

Genera el archivo actualizado `docs/15_guia_sustentacion.md` COMPLETO.

**Cambios obligatorios:**

1. **Actualizar TODAS las respuestas** que mencionaban estimaciones o "pendiente de migración" con los datos reales.

2. **Nuevas preguntas que el profesor puede hacer (agregar a las 20+ existentes):**

| # | Pregunta | Respuesta clave |
|---|---|---|
| 21 | ¿Cuántas filas tienen en la base de datos? | 2,965,337 en producción + 24,422 en cuarentena = 2,989,759 total. Superamos la meta de 1M en un 298.9%. |
| 22 | ¿Cuánto pesa la base de datos en disco? | 3.88 GB total. Lectura_telemetria ocupa 3,824 MB (3,440 datos + 384 índices). |
| 23 | ¿Qué es un CREATE DOMAIN y para qué lo usan? | Es un tipo de dato personalizado con restricción CHECK incorporada. Creamos 12 dominios que encapsulan leyes físicas. Ejemplo: dom_voltaje AS DOUBLE PRECISION CHECK (VALUE >= 0). Cualquier columna que use este dominio rechaza automáticamente voltajes negativos. |
| 24 | ¿Cuál es la diferencia entre un CHECK a nivel de columna y un DOMAIN? | El CHECK se define por columna y no es reutilizable. El DOMAIN se define una vez y se aplica a N columnas. Si la regla física cambia, se modifica en un solo lugar. Nuestro dom_voltaje se usa en 6 columnas distintas. |
| 25 | ¿Qué pasa con las temperaturas de -20.3°C? ¿Por qué no las rechaza el dominio? | Decisión de diseño intencional: dom_temperatura NO tiene CHECK. Las anomalías se detectan en el pipeline de staging con la regla R_TEMP1_IMPOSIBLE y van a cuarentena con trazabilidad JSONB. Si pusiéramos un CHECK, PostgreSQL rechazaría la fila en silencio y perderíamos la evidencia. |
| 26 | ¿Por qué hay 24,375 filas en cuarentena por P > S? | Porque en corriente alterna, la potencia activa P nunca puede superar la potencia aparente S (ley física: P ≤ S = |V|·|I|). Encontramos 24,375 lecturas donde outw_a > outva_a o outsumw > outsumva. Causa probable: desfase temporal en el muestreo Modbus entre las variables. |
| 27 | ¿Pueden reprocesar un registro de cuarentena? | Sí. Cada registro tiene un estado con ciclo de vida: PENDIENTE → CORREGIDO | DESCARTADO | REPROCESADO. La fila original completa se conserva como JSONB. |
| 28 | ¿Qué pasa si ejecuto la migración dos veces? | Nada malo. El pipeline usa ON CONFLICT (inversor_id, ts_lectura) DO NOTHING. Las filas que ya existen se ignoran sin error. Es idempotente. |

3. **Actualizar el guion de demostración en vivo** con los pasos reales que el coordinador ejecuta en DBeaver, incluyendo los tiempos esperados y los conteos reales.

4. **Actualizar la estructura del PDF final** reflejando los archivos que realmente existen en el repositorio (docs/00 a docs/15, sql/00 a sql/13).

</TU MISIÓN — TAREA 3>

<TU MISIÓN — TAREA 4: ACTUALIZAR ANÁLISIS DE PRIVACIDAD (LEY 1581)>

Genera el archivo actualizado `docs/14_seguridad_y_privacidad.md` COMPLETO.

**Cambios obligatorios:**

1. **Actualizar con métricas reales:** Los 25,178 registros de contexto fueron migrados. De ellos, 204 son `wsl_bash_history` (marcados con `contiene_datos_personales = TRUE`), 6,271 son `windows_event_log` y 6,028 + 8,902 son logs de workstation.

2. **Documentar la medida técnica implementada:** La columna `contiene_datos_personales BOOLEAN` en `solardb.registro_contexto` permite filtrar registros con datos sensibles en consultas:
```sql
SELECT * FROM solardb.registro_contexto
WHERE contiene_datos_personales = FALSE;
```

3. **Mantener y mejorar:**
   - Clasificación de datos según Ley 1581 (artículos específicos).
   - Roles: Responsable, Encargado, Titulares.
   - Principios de la ley aplicados al proyecto.
   - Medidas de protección del repositorio (.gitignore, no contraseñas, etc.).
   - Aviso de privacidad simplificado.

</TU MISIÓN — TAREA 4>

<TU MISIÓN — TAREA 5: COMPILAR INFORME FINAL PDF>

Genera un archivo `docs/16_estructura_informe_final.md` que contenga la estructura completa y detallada del informe final PDF, con instrucciones de compilación.

**Nombre del PDF:** `report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`

**Estructura obligatoria del informe:**

1. **Portada oficial:**
   - Institución Universitaria Pascual Bravo.
   - Facultad de Ingeniería — Departamento de Sistemas.
   - Asignatura: Bases de Datos I — Taller 6.
   - Título: "SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL".
   - Docente: Ramiro Grisales Montoya.
   - Integrantes: Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto.
   - Medellín, Noviembre de 2026.

2. **Tabla de contenidos** (numerada automáticamente).

3. **Cuerpo del informe (un capítulo por cada documento del repositorio):**

   | Capítulo | Fuente | Responsable |
   |---|---|---|
   | 1. Introducción y Justificación | docs/00_requisitos_y_auditoria.md | Juan Sebastian |
   | 2. Inventario del Dataset | docs/01_inventario_dataset.md | Juan Sebastian |
   | 3. Diagnóstico de Calidad | docs/02_diagnostico_calidad.md | Juan Sebastian |
   | 4. Diseño de SolarDB | docs/03_diseno_solar_db.md | Juan Sebastian |
   | 5. Matriz de Reglas de Calidad | docs/04_matriz_reglas_calidad.md | Juan Sebastian |
   | 6. Modelo Conceptual | docs/05_modelo_conceptual.md | Deysi Carolina |
   | 7. Modelo Lógico | docs/06_modelo_logico.md | Deysi Carolina |
   | 8. Normalización hasta 3FN | docs/07_normalizacion_3FN.md | Deysi Carolina |
   | 9. Diccionario de Datos | docs/08_diccionario_datos.md | Jose Miguel |
   | 10. Diseño Físico | docs/09_diseno_fisico.md | Jose Miguel |
   | 11. Estrategia de Migración | docs/10_estrategia_migracion.md | Juan Sebastian |
   | 12. Resultados de la Migración | docs/11_resultados_migracion.md | Juan Sebastian |
   | 13. Consultas, Vistas e Índices | docs/12_consultas_vistas_indices.md | Deysi Carolina |
   | 14. Pruebas de Integridad | docs/13_pruebas_solar_db.md | Deysi Carolina |
   | 15. Seguridad y Privacidad | docs/14_seguridad_y_privacidad.md | Jose Miguel |
   | 16. Conclusiones | Redactadas para el informe | Jose Miguel |

4. **Anexos:**
   - Anexo A: Scripts DDL (referencia a sql/00 – sql/09).
   - Anexo B: Consultas de negocio (sql/12_consultas_negocio.sql).
   - Anexo C: Pruebas de integridad (sql/13_pruebas_integridad.sql).
   - Anexo D: Guía de sustentación (docs/15_guia_sustentacion.md).

5. **Referencias bibliográficas** (formato APA 7ª ed.):
   - Cita de OpenCEM.
   - PostgreSQL 18 Documentation.
   - Ley 1581 de 2012, Congreso de la República de Colombia.

**Instrucciones de compilación del PDF:**
Jose Miguel puede usar cualquiera de estas herramientas:
- **Google Docs:** Copiar el contenido de cada archivo .md a un documento de Google Docs, formatear con estilos (Título, Encabezado 1, 2, 3), y exportar como PDF.
- **Microsoft Word:** Copiar y formatear en Word, exportar como PDF.
- **Pandoc (si sabe usarlo):** `pandoc docs/*.md -o report/informe.pdf`

</TU MISIÓN — TAREA 5>

<CONFIGURACIÓN DE GIT Y GITHUB — INSTRUCCIONES PASO A PASO PARA JOSE MIGUEL>

Como tú NO tienes Antigravity para automatizar este proceso, aquí van las instrucciones manuales completas.

**PASO 1: Instalar Git (si no lo tienes)**

1. Abre tu navegador y ve a: https://git-scm.com/download/win
2. Descarga el instalador para Windows.
3. Ejecuta el instalador. En todas las pantallas puedes dejar las opciones por defecto. Solo asegúrate de que:
   - En "Adjusting your PATH environment": selecciona "Git from the command line and also from 3rd-party software".
   - En "Choosing the default editor": puedes elegir "Use Visual Studio Code" o Notepad.
4. Una vez instalado, abre PowerShell y verifica:
```
git --version
```
Deberías ver algo como: `git version 2.47.0.windows.1`

**PASO 2: Configurar tu identidad en Git**

Abre PowerShell y ejecuta:
```
git config --global user.name "Jose Miguel Sosa Cartagena"
git config --global user.email "jose.sosa216@pascualbravo.edu.co"
```

**PASO 3: Descargar el repositorio actualizado**

Si ya tienes la carpeta del proyecto, abre PowerShell, navega a ella y actualiza:
```
cd "C:\ruta\a\tu\carpeta\ULTIMOWORK"
git checkout main
git pull origin main
```

Si NO tienes la carpeta, clónala:
```
cd Desktop
git clone https://github.com/desarrollosebas/Trabajofinal.git
cd Trabajofinal
```

Si te pide usuario y contraseña:
- Usuario: tu nombre de usuario de GitHub (josesosa216-pb).
- Contraseña: NO uses tu contraseña de GitHub. Necesitas un **token de acceso personal**:
  1. En GitHub ve a: Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token.
  2. Dale un nombre (ej. "Taller6").
  3. Marca el permiso "repo" (acceso completo a repositorios).
  4. Clic en "Generate token".
  5. COPIA el token (solo se muestra una vez).
  6. Usa ese token como contraseña cuando Git te la pida.

**PASO 4: Crear tu rama de trabajo**
```
git checkout -b jose/auditoria-e-informe-pdf
```

**PASO 5: Crear/actualizar tus archivos**

Después de que la IA te genere cada archivo, guárdalo en la carpeta correcta:
- Los archivos `.md` van en la carpeta `docs/`.
- El PDF final va en la carpeta `report/`.

Puedes usar:
- **Visual Studio Code** (recomendado): descárgalo de https://code.visualstudio.com, abre la carpeta del proyecto y crea/edita los archivos.
- **Notepad:** abre Notepad, pega el contenido, guarda como `docs/08_diccionario_datos.md` (selecciona "Todos los archivos" para que la extensión sea `.md` y no `.md.txt`).

**PASO 6: Hacer commits (después de cada archivo)**

```
git add docs/08_diccionario_datos.md
git commit -m "docs: actualizar diccionario de datos con metricas reales post-migracion"

git add docs/09_diseno_fisico.md
git commit -m "docs: actualizar diseno fisico con tamaños reales en disco"

git add docs/14_seguridad_y_privacidad.md
git commit -m "docs: actualizar analisis Ley 1581 con metricas reales"

git add docs/15_guia_sustentacion.md
git commit -m "docs: actualizar guia de sustentacion con datos reales"

git add docs/16_estructura_informe_final.md
git commit -m "docs: agregar estructura del informe final PDF"

git add report/
git commit -m "report: agregar informe final PDF compilado"
```

**PASO 7: Subir tu rama a GitHub**
```
git push origin jose/auditoria-e-informe-pdf
```

**PASO 8: Verificar en GitHub**

Abre https://github.com/desarrollosebas/Trabajofinal en tu navegador. Deberías ver un banner que dice: "jose/auditoria-e-informe-pdf had recent pushes". El coordinador se encargará de hacer el merge.

</CONFIGURACIÓN DE GIT Y GITHUB>

<RESTRICCIONES OBLIGATORIAS>

1. No inventes datos, métricas, conteos ni tamaños que no estén en la sección de MÉTRICAS REALES de este prompt. Todos los números deben coincidir EXACTAMENTE con los proporcionados.
2. Todos los tipos de datos que menciones deben ser de PostgreSQL 18, no de MySQL ni de SQL Server.
3. Las unidades de medida deben coincidir con las documentadas por los autores de OpenCEM (proporcionadas en este prompt).
4. Las referencias a la Ley 1581 de 2012 deben citar artículos específicos (3, 4, 5, 7, 8, 9, 10, 12, 13, 15, 17, 18), no generalidades.
5. No incluyas contraseñas, tokens ni cadenas de conexión en ningún archivo.
6. Usa español para toda la documentación. Tono académico y técnico.
7. Cada archivo debe comenzar con un encabezado:
   ```
   # Título del Documento
   > **Proyecto:** SolarDB – Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena
   > **Materia:** Bases de Datos I – Taller 6, Grupo 811, Semestre 2026-II
   > **Institución:** Institución Universitaria Pascual Bravo
   > **Integrante responsable:** Jose Miguel Sosa Cartagena
   > **Fecha:** Noviembre de 2026
   ```
8. Los ejemplos de datos deben ser reales (tomados de las métricas proporcionadas), no inventados.
9. Entrega cada archivo por separado, completo y listo para guardar como `.md`.
10. No mezcles varios archivos en una sola respuesta. Uno a la vez.
11. La cita de OpenCEM debe estar en formato APA 7ª edición en TODOS los archivos donde se mencione el dataset.
12. Las tablas Markdown deben estar bien formateadas con alineación y sin columnas rotas.

</RESTRICCIONES OBLIGATORIAS>

<FORMATO DE ENTREGA>

Entrégame cada archivo por separado en formato Markdown completo.

El orden de entrega debe ser:
1. Primero: `docs/08_diccionario_datos.md` (actualizado con métricas reales)
2. Segundo: `docs/09_diseno_fisico.md` (actualizado con tamaños reales)
3. Tercero: `docs/14_seguridad_y_privacidad.md` (actualizado con métricas reales)
4. Cuarto: `docs/15_guia_sustentacion.md` (actualizado con datos reales y nuevas preguntas)
5. Quinto: `docs/16_estructura_informe_final.md` (nuevo — estructura del PDF)

Si el contenido es muy extenso para una sola respuesta, divídelo y dime "continúo en el siguiente mensaje" al final de cada parte. Yo te diré "continúa" para que sigas.

No mezcles varios archivos en una sola respuesta. Uno a la vez.

Después de entregarme cada archivo, dime:
"Guarda este archivo como `docs/NOMBRE.md` en la carpeta del proyecto. Luego ejecuta en PowerShell:
```
git add docs/NOMBRE.md
git commit -m "docs: mensaje descriptivo"
```
Cuando estés listo, dime 'continúa' para el siguiente archivo."

</FORMATO DE ENTREGA>

<CRITERIOS DE ACEPTACIÓN>

Tu trabajo se considerará completo cuando:

- [ ] Existe `docs/08_diccionario_datos.md` actualizado con 2,965,337 filas, 24,422 en cuarentena, tamaños reales en disco y todas las columnas documentadas.
- [ ] Cada variable física tiene su unidad de medida y la evidencia de la fuente.
- [ ] Se justifica NUMERIC vs DOUBLE PRECISION, TIMESTAMPTZ vs TIMESTAMP, JSONB vs JSON, BIGINT vs INTEGER.
- [ ] Existe `docs/09_diseno_fisico.md` actualizado con los 7 índices reales, tamaños reales y 3 esquemas confirmados.
- [ ] Existe `docs/14_seguridad_y_privacidad.md` actualizado con las métricas reales de los 25,178 registros de contexto, citando artículos de la Ley 1581.
- [ ] Existe `docs/15_guia_sustentacion.md` con al menos 25 preguntas y respuestas con datos reales, guion de demostración actualizado y estructura del PDF.
- [ ] Existe `docs/16_estructura_informe_final.md` con la tabla de contenidos del PDF y la asignación por capítulo.
- [ ] Ningún archivo contiene contraseñas, tokens ni cadenas de conexión.
- [ ] Todo está en español con tono académico y técnico.
- [ ] Todos los números coinciden con las métricas reales proporcionadas (2,965,337 / 24,422 / 25,178 / 3,824 MB, etc.).

</CRITERIOS DE ACEPTACIÓN>

<INICIO DEL TRABAJO>

Comienza generando el primer archivo: `docs/08_diccionario_datos.md` (versión actualizada con métricas reales).

Genera el archivo COMPLETO de principio a fin. No me des instrucciones de cómo redactarlo; redáctalo TÚ.

Cuando termines, dime que lo guarde y me dices "continúa" para el siguiente.

Empieza ahora.

</INICIO DEL TRABAJO>
