# PROMPT PARA JOSE MIGUEL SOSA CARTAGENA — RONDA 2
# Herramienta: ChatGPT, Claude, Gemini Web u otra IA conversacional
# ─────────────────────────────────────────────────────────────────────────────
# GUÍA RÁPIDA PARA JOSE MIGUEL (PASO A PASO ANTES DE USAR LA IA):
#
# PASO 1: Descargar los archivos más actualizados del repositorio
#   • Si usas Git: abre la terminal en tu carpeta y ejecuta:
#         git checkout main
#         git pull origin main
#   • Si NO tienes Git todavía: entra a https://github.com/desarrollosebas/Trabajofinal
#     haz clic en el botón verde "<> Code" y luego en "Download ZIP". Descomprímelo
#     en tu computador.
#
# PASO 2: ¿QUÉ ARCHIVOS DEBES SUBIR O ADJUNTAR A LA IA?
#   En la ventana del chat (ChatGPT Plus / Claude / Gemini Advanced), haz clic en el
#   icono de adjuntar archivo (+) y SUBE estos 5 archivos que están en la carpeta docs/:
#     1. docs/11_resultados_migracion.md  <-- ¡EL MÁS IMPORTANTE! (Tiene los números reales)
#     2. docs/08_diccionario_datos.md      <-- (Para que la IA lo actualice)
#     3. docs/09_diseno_fisico.md          <-- (Para que la IA lo actualice)
#     4. docs/14_seguridad_y_privacidad.md <-- (Para que la IA lo actualice)
#     5. docs/15_guia_sustentacion.md      <-- (Para que la IA lo actualice)
#
# PASO 3: Copia TODO el contenido de este archivo (desde <CONFIGURACIÓN>) y pégalo
#   como primer mensaje en la conversación con la IA.
#
# PASO 4: La IA irá entregando cada documento completo uno a uno. Tú solo debes
#   copiar el texto que te dé, guardarlo reemplazando el archivo .md correspondiente
#   en la carpeta docs/, y decirle "continúa" para que genere el siguiente.
#
# PASO 5: Al final, la IA te indicará la estructura para compilar el PDF final
#   en la carpeta report/ y los comandos de Git para subir tu trabajo.
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

Vas a trabajar JUNTO con Jose Miguel (el usuario humano). Él no tiene un agente automatizado como Antigravity; él interactúa contigo a través de esta ventana de chat y copiará tus respuestas a los archivos correspondientes en su computador.

Por lo tanto:
- El usuario humano ya te ha adjuntado o te proporcionará los archivos base del proyecto:
  * `docs/11_resultados_migracion.md` (Resultados certificados de la migración).
  * `docs/08_diccionario_datos.md` (Diccionario base de Ronda 1).
  * `docs/09_diseno_fisico.md` (Diseño físico base de Ronda 1).
  * `docs/14_seguridad_y_privacidad.md` (Análisis legal base de Ronda 1).
  * `docs/15_guia_sustentacion.md` (Guía de sustentación base de Ronda 1).
- Genera CADA archivo completo de principio a fin, listo para guardar como `.md`.
- NO generes resúmenes, esquemas incompletos ni instrucciones para que él redacte. Genera TÚ el contenido completo con calidad profesional.
- Entrega UN archivo por respuesta. Al terminar cada archivo, indícale exactamente:
  "Guarda este archivo como `docs/NOMBRE.md` en tu carpeta del proyecto. Cuando lo hayas guardado, dime 'continúa' para entregarte el siguiente."
- Si un archivo es muy extenso y se corta por el límite de tokens, divídelo y di "continúo en el siguiente mensaje".

</CONFIGURACIÓN>

<ARCHIVOS QUE LA IA DEBE LEER Y PROCESAR>

La IA debe basar toda su redacción en:
1. **Archivo de métricas reales:** `docs/11_resultados_migracion.md` (adjunto por el usuario o citado textualmente en este prompt).
2. **Archivos a actualizar y reemplazar:**
   - `docs/08_diccionario_datos.md`
   - `docs/09_diseno_fisico.md`
   - `docs/14_seguridad_y_privacidad.md`
   - `docs/15_guia_sustentacion.md`
3. **Archivo nuevo a generar:**
   - `docs/16_estructura_informe_final.md` (Estructura y contenido capítulo a capítulo para el informe final PDF).
4. **Producto final que Jose Miguel compilará:**
   - `report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`

</ARCHIVOS QUE LA IA DEBE LEER Y PROCESAR>

<ROL>

Actúa simultáneamente como:

1. **Ingeniero de datos senior** especializado en PostgreSQL 18, tipos de datos, diseño físico de bases de datos, documentación técnica de diccionarios de datos y estimación de almacenamiento.
2. **Abogado especialista en protección de datos personales** con dominio de la Ley Estatutaria 1581 de 2012 de Colombia (Régimen General de Protección de Datos Personales), sus decretos reglamentarios (Decreto 1377 de 2013) y la Ley 1266 de 2008 (Habeas Data).
3. **Redactor técnico-académico** capaz de compilar un informe final universitario con portada institucional, tabla de contenidos numerada, figuras referenciadas y formato APA 7ª edición para citas.
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

Reemplaza las estimaciones teóricas de la Ronda 1 con los datos reales post-migración:

1. **Cantidad de filas por tabla:**
   - `solardb.lectura_telemetria`: 2,965,337 filas.
   - `calidad.registro_cuarentena`: 24,422 filas.
   - `solardb.registro_contexto`: 25,178 filas.
   - `calidad.lote_carga`: 2 lotes completados (IDs 4 y 6).
   - `calidad.regla_calidad`: 6 reglas activas (R_TEMP1_IMPOSIBLE, R_P_MAYOR_S, R_NULOS_MODBUS, R_FREQ_CERO, R_LINECURRA_NEG, R_LINEPOWERVA_NEG).

2. **Tamaños en disco:** Incluir los tamaños reales (3,824 MB, 34 MB, 26 MB, etc.).

3. **Columnas de `lectura_telemetria`:** Verificar que las 46 columnas están documentadas con su dominio, tipo base, CHECK, FK, unidad de medida y evidencia de la fuente.

4. **Mantener y perfeccionar las justificaciones técnicas:**
   - NUMERIC vs DOUBLE PRECISION.
   - TIMESTAMP WITH TIME ZONE vs sin TZ.
   - JSONB vs JSON.
   - BIGINT vs INTEGER.

</TU MISIÓN — TAREA 1>

<TU MISIÓN — TAREA 2: ACTUALIZAR DISEÑO FÍSICO CON MÉTRICAS REALES>

Genera el archivo actualizado `docs/09_diseno_fisico.md` COMPLETO.

1. **Estimación vs Realidad de almacenamiento:** Cuadro comparativo entre lo estimado en diseño y los 3.88 GB reales en disco.
2. **Estrategia de índices:** Documentar los 7 índices reales en producción (`idx_lectura_ts`, `idx_lectura_lote`, `idx_lectura_inversor_ts`, `idx_cuarentena_regla`, `idx_cuarentena_estado`, `idx_contexto_tipo`, `idx_contexto_valor_gin`).
3. **Particionamiento:** Justificar técnicamente por qué para ~3M de filas no se particionó, y cuándo valdría la pena hacerlo (>50M filas).
4. **Esquemas:** Justificación de la arquitectura multiesquema (`solardb`, `staging`, `calidad`).

</TU MISIÓN — TAREA 2>

<TU MISIÓN — TAREA 3: ACTUALIZAR GUÍA DE SUSTENTACIÓN CON DATOS REALES>

Genera el archivo actualizado `docs/15_guia_sustentacion.md` COMPLETO.

1. **Actualizar TODAS las respuestas** con los datos reales verificados (2,965,337 filas, 24,422 en cuarentena, 3.88 GB).
2. **Incluir al menos 25 preguntas difíciles del profesor** con respuestas sólidas sobre:
   - ¿Por qué dominios y no simples CHECKs?
   - ¿Por qué la temperatura de -20.3°C fue a cuarentena y no a un CHECK?
   - ¿Por qué hay 24,375 filas en cuarentena por P > S?
   - ¿Cómo se maneja la Ley 1581 de 2012?
   - ¿Qué pasa si ejecuto la migración dos veces?
3. **Guion de demostración en vivo en DBeaver:** Paso a paso exacto para la presentación oral ante el profesor.
4. **Estructura del PDF final:** Tabla de contenidos completa.

</TU MISIÓN — TAREA 3>

<TU MISIÓN — TAREA 4: ACTUALIZAR ANÁLISIS DE PRIVACIDAD (LEY 1581)>

Genera el archivo actualizado `docs/14_seguridad_y_privacidad.md` COMPLETO.

1. **Métricas reales de privacidad:** 25,178 registros de contexto migrados, 204 con datos personales críticos (`wsl_bash_history`).
2. **Medida técnica en base de datos:** Explicar el uso de la columna `contiene_datos_personales BOOLEAN` en `solardb.registro_contexto` para filtrado y auditoría.
3. **Análisis legal riguroso:** Clasificación de datos según Ley 1581 de 2012 (artículos 3, 4, 5, 7, 8, 9, 10, 12, 13, 15, 17, 18), roles de tratamiento y aviso de privacidad simplificado.

</TU MISIÓN — TAREA 4>

<TU MISIÓN — TAREA 5: ESTRUCTURA DEL INFORME FINAL PDF>

Genera el archivo `docs/16_estructura_informe_final.md` con la guía completa para compilar el informe final PDF oficial:
- Portada institucional.
- Tabla de contenidos con los 16 capítulos correspondientes a todos los archivos `docs/00` a `docs/15`.
- Asignación por integrantes.
- Instrucciones de exportación a PDF (Word / Google Docs / Pandoc).
- Ubicación de guardado: `report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`.

</TU MISIÓN — TAREA 5>

<CONFIGURACIÓN DE GIT Y GITHUB — INSTRUCCIONES PASO A PASO PARA JOSE MIGUEL>

Instrucciones para cuando tengas tus archivos listos y quieras subirlos:

```bash
# 1. Configurar tu identidad en Git (solo la primera vez)
git config --global user.name "Jose Miguel Sosa Cartagena"
git config --global user.email "jose.sosa216@pascualbravo.edu.co"

# 2. Descargar últimos cambios y crear tu rama
cd "C:\ruta\a\tu\carpeta\ULTIMOWORK"
git checkout main
git pull origin main
git checkout -b jose/auditoria-e-informe-pdf

# 3. Hacer commit de cada archivo guardado
git add docs/08_diccionario_datos.md
git commit -m "docs: actualizar diccionario de datos con metricas reales post-migracion"

git add docs/09_diseno_fisico.md
git commit -m "docs: actualizar diseno fisico con tamanos reales en disco"

git add docs/14_seguridad_y_privacidad.md
git commit -m "docs: actualizar analisis Ley 1581 con metricas reales"

git add docs/15_guia_sustentacion.md
git commit -m "docs: actualizar guia de sustentacion con datos reales"

git add docs/16_estructura_informe_final.md
git commit -m "docs: agregar estructura del informe final PDF"

git add report/
git commit -m "report: agregar informe final PDF compilado"

# 4. Subir tu rama a GitHub
git push origin jose/auditoria-e-informe-pdf
```

</CONFIGURACIÓN DE GIT Y GITHUB>

<RESTRICCIONES OBLIGATORIAS>

1. No inventes datos, métricas, conteos ni tamaños. Todos los números deben coincidir EXACTAMENTE con las métricas proporcionadas (2,965,337 filas aceptadas, 24,422 en cuarentena, 3.88 GB en disco).
2. Todos los tipos de datos deben ser de PostgreSQL 18.
3. Las unidades de medida deben coincidir con las documentadas por OpenCEM.
4. Citar artículos específicos de la Ley 1581 de 2012.
5. No incluir contraseñas, tokens ni credenciales.
6. Redacción formal académica en español.
7. Encabezado institucional obligatorio en cada archivo.
8. Entregar UN archivo por mensaje, completo y sin resumir.

</RESTRICCIONES OBLIGATORIAS>

<FORMATO DE ENTREGA>

Entrégame cada archivo por separado en formato Markdown completo.

El orden de entrega debe ser:
1. Primero: `docs/08_diccionario_datos.md`
2. Segundo: `docs/09_diseno_fisico.md`
3. Tercero: `docs/14_seguridad_y_privacidad.md`
4. Cuarto: `docs/15_guia_sustentacion.md`
5. Quinto: `docs/16_estructura_informe_final.md`

Al terminar cada archivo, dime:
"Guarda este archivo como `docs/NOMBRE.md`. Luego dime 'continúa' para generar el siguiente."

</FORMATO DE ENTREGA>

<INICIO DEL TRABAJO>

Comienza entregándome el primer archivo: `docs/08_diccionario_datos.md` (versión definitiva actualizada con las métricas reales).

Genera el contenido COMPLETO de principio a fin.

Empieza ahora.

</INICIO DEL TRABAJO>
