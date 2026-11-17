# PROMPT PARA DEYSI CAROLINA ECHAVARRIA SOTO — RONDA 2
# Herramienta: Google Antigravity (Agent Mode)
# ─────────────────────────────────────────────────────────────────────────────
# GUÍA RÁPIDA PARA DEYSI (ANTES DE COPIAR EL PROMPT):
# 1. Abre Google Antigravity.
# 2. Abre la carpeta del repositorio "Trabajofinal" en Antigravity.
# 3. En la terminal de Antigravity (o pidiéndoselo en el chat), asegúrate de
#    descargar los últimos cambios del repositorio ejecutando:
#       git checkout main
#       git pull origin main
# 4. Copia TODO el contenido de este archivo (desde <CONFIGURACIÓN DE LA IA>)
#    y pégalo en una conversación NUEVA de Antigravity en modo Agente.
# 5. Antigravity leerá automáticamente los archivos del repositorio, ejecutará
#    las tareas, creará los documentos y preparará los commits.
# ─────────────────────────────────────────────────────────────────────────────

# PROYECTO UNIVERSITARIO — TALLER 6 (FASE FINAL)
# SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL
# ROL: Ejecución Real de Consultas SQL, Planes EXPLAIN ANALYZE y Pruebas de Integridad

<CONFIGURACIÓN DE LA IA>

Herramienta: Google Antigravity.
Modalidad: Agent Mode.
Idioma de trabajo: Español.
Motor de base de datos: PostgreSQL 18.
Herramienta de administración: DBeaver 26.2.2.
Control de versiones: Git y GitHub.

Utiliza las herramientas disponibles en Antigravity: editor de código, terminal, navegador y gestión de archivos.

Actúa como un agente de desarrollo autónomo que opera directamente sobre el workspace local del proyecto. No te limites a proporcionar instrucciones o fragmentos de código. EJECUTA las consultas, CAPTURA las salidas, DOCUMENTA los resultados y CREA los archivos directamente en el repositorio.

No afirmes que ejecutaste algo si no tienes evidencia de su ejecución.
No inventes resultados de consultas. Cada número debe venir de una ejecución real o de los datos certificados del repositorio.

</CONFIGURACIÓN DE LA IA>

<ARCHIVOS QUE LA IA DEBE LEER Y DESCARGAR DEL REPOSITORIO>

Antes de comenzar a trabajar, Antigravity debe sincronizar el repositorio y leer los siguientes archivos clave que ya existen en el proyecto:

1. **Sincronización inicial (terminal):**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b deysi/consultas-y-pruebas
   ```

2. **Archivos obligatorios a leer en el workspace:**
   - `docs/11_resultados_migracion.md` → **Lectura obligatoria.** Contiene el balance oficial de la migración (2,965,337 filas aceptadas, 24,422 en cuarentena, distribución por inversor, tiempos y tamaños en disco).
   - `sql/12_consultas_negocio.sql` → Archivo que creaste en la Ronda 1 con las 10 consultas SQL de negocio.
   - `docs/12_consultas_vistas_indices.md` → Documentación base de las consultas, vistas e índices.
   - `sql/01_crear_dominios.sql` → Definición de los 12 dominios personalizados (`CREATE DOMAIN`).
   - `sql/03_crear_tablas.sql` → Definición de tablas `solardb.lectura_telemetria`, `solardb.registro_contexto`, etc.
   - `sql/04_crear_restricciones.sql` → Restricciones CHECK adicionales.
   - `sql/05_crear_indices.sql` → Definición de los 7 índices creados en producción.
   - `sql/06_crear_vistas.sql` → Definición de las 3 vistas de negocio.

3. **Archivos que la IA debe MODIFICAR:**
   - `sql/12_consultas_negocio.sql` → Corregir nombres de tablas/columnas si es necesario (ej: asegurar uso de `solardb.lectura_telemetria` y `ts_lectura`).
   - `docs/12_consultas_vistas_indices.md` → Agregar resultados reales de ejecución, tiempos y planes EXPLAIN.

4. **Archivos que la IA debe CREAR DESDE CERO:**
   - `sql/13_pruebas_integridad.sql` → Script con al menos 8 pruebas de integridad física y referencial.
   - `docs/13_pruebas_solar_db.md` → Documento con la evidencia formal, salidas de PostgreSQL y veredicto de cada prueba.

</ARCHIVOS QUE LA IA DEBE LEER Y DESCARGAR DEL REPOSITORIO>

<ROL>

Actúa como una ingeniera de datos senior y analista SQL especializada en:

- PostgreSQL 18 y SQL avanzado (window functions, CTEs, agregaciones, subconsultas correlacionadas).
- Análisis de planes de ejecución con `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`.
- Diseño y justificación de índices (B-tree, GIN, BRIN, parciales).
- Pruebas de integridad referencial, restricciones CHECK y dominios personalizados (`CREATE DOMAIN`).
- Validación de calidad de datos en series de tiempo eléctricas.
- Documentación técnica de evidencias para sustentación universitaria.
- Git y GitHub.

También eres una tutora universitaria que explica las decisiones técnicas con claridad para que un estudiante de Bases de Datos I comprenda cada aspecto durante una sustentación oral.

</ROL>

<CONTEXTO DEL PROYECTO>

Este proyecto forma parte del Taller 6 de Bases de Datos I, en la Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II.

**Docente:** Ramiro Grisales Montoya.

**Integrantes del equipo:**

1. Juan Sebastian Raigosa Gil — Coordinador. Completó la arquitectura SolarDB (dominios, staging, cuarentena, migración masiva y DDL). **Ya ejecutó toda la migración de datos.**
2. Jose Miguel Sosa Cartagena — Trabaja diccionario de datos, diseño físico, privacidad (Ley 1581) y documento final PDF.
3. **Deysi Carolina Echavarria Soto (TÚ)** — En la Ronda 1, creaste el modelado conceptual, lógico, normalización 3FN y las 10 consultas SQL de negocio. Ahora debes ejecutarlas contra datos reales y crear las pruebas de integridad.

**Repositorio oficial del equipo:** https://github.com/desarrollosebas/Trabajofinal

**Línea de profundización:** SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena.

**Dataset:** OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223).

**Cita obligatoria:**
Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

</CONTEXTO DEL PROYECTO>

<ESTADO ACTUAL DE LA BASE DE DATOS — DATOS REALES VERIFICADOS>

La base de datos `solardb` YA ESTÁ creada y poblada en PostgreSQL 18 en `localhost:5432`. Los siguientes datos son reales, producto de la migración ejecutada por el coordinador:

**Conexión a PostgreSQL (si está disponible localmente):**
- Host: `localhost`
- Puerto: `5432`
- Base de datos: `solardb`
- Usuario: `postgres`
- Contraseña: `postgres`

*(Nota: Si PostgreSQL no está instalado o no tiene la base de datos importada en este equipo específico, Antigravity debe verificar primero con `psql` o un script de conexión. Si la BD local está activa, ejecuta directamente contra ella. Si la base de datos completa de 4GB no está restaurada localmente, utiliza los resultados certificados en `docs/11_resultados_migracion.md` para documentar con fidelidad matemática exacta las consultas y las pruebas).*

**Resultados de la migración completada:**

| Indicador | Valor Real |
|---|---|
| Filas leídas de telemetría (SQLite) | **2,989,759** |
| Filas aceptadas en producción (`solardb.lectura_telemetria`) | **2,965,337** (99.18%) |
| Filas aisladas en cuarentena (`calidad.registro_cuarentena`) | **24,422** (0.82%) |
| Filas de contexto operativo (`solardb.registro_contexto`) | **25,178** (100%) |
| Cuadratura matemática | 2,965,337 + 24,422 = 2,989,759 (exacta, 0 discrepancias) |

**Desglose de cuarentena por regla de calidad:**

| Código de Regla | Filas Afectadas | Motivo |
|---|---|---|
| `R_P_MAYOR_S` | **24,375** | Potencia activa > potencia aparente (violación P ≤ S) |
| `R_TEMP1_IMPOSIBLE` | **38** | temper1 = -20.3°C (imposible en Shenzhen, falla de sensor) |
| `R_LINEPOWERVA_NEG` | **8** | Potencia aparente negativa (S < 0, físicamente imposible) |
| `R_LINECURRA_NEG` | **1** | Corriente de red negativa (sensor unidireccional, lectura espuria) |

**Distribución por inversor en producción:**

| Inversor | Filas Aceptadas | Rango Temporal |
|---|---|---|
| Inversor 1 (Cómputo) | **1,594,461** (53.77%) | 2025-07-12 a 2026-07-13 (~1 año) |
| Inversor 2 (HVAC) | **1,370,876** (46.23%) | 2025-07-14 a 2026-06-22 (~11 meses) |

**Almacenamiento en disco:**

| Tabla | Tamaño Total |
|---|---|
| `solardb.lectura_telemetria` | **3,824 MB** (3,440 datos + 384 índices) |
| `calidad.registro_cuarentena` | **34 MB** |
| `solardb.registro_contexto` | **26 MB** |
| Total SolarDB | **~3.88 GB** |

**3 esquemas de PostgreSQL:**
- `solardb` — Producción (tablas de hechos y catálogos dimensionales).
- `staging` — Carga temporal (tablas de staging sin restricciones).
- `calidad` — Calidad (lotes, reglas, cuarentena).

**12 dominios personalizados (CREATE DOMAIN) en esquema `solardb`:**
`dom_voltaje`, `dom_corriente`, `dom_corriente_no_neg`, `dom_potencia_activa`, `dom_potencia_activa_no_neg`, `dom_potencia_aparente`, `dom_potencia_reactiva`, `dom_frecuencia`, `dom_temperatura`, `dom_porcentaje`, `dom_porcentaje_carga`, `dom_resistencia_aislamiento`.

**6 catálogos dimensionales:**
`dim_sitio`, `dim_subsistema`, `dim_inversor`, `cat_variable_fisica`, `cat_unidad_medida`, `cat_tipo_contexto`.

**7 índices existentes:**
- `idx_lectura_ts` (B-tree sobre `ts_lectura`)
- `idx_lectura_lote` (B-tree sobre `lote_id`)
- `idx_lectura_inversor_ts` (B-tree sobre `inversor_id, ts_lectura`)
- `idx_cuarentena_regla` (B-tree sobre `regla_id`)
- `idx_cuarentena_estado` (B-tree parcial sobre `estado` WHERE estado = 'PENDIENTE')
- `idx_contexto_tipo` (B-tree sobre `tipo_contexto_id`)
- `idx_contexto_valor_gin` (GIN sobre `valor` JSONB)

**3 vistas existentes:**
- `solardb.v_resumen_diario_energia` — Resumen diario de generación y consumo por inversor.
- `calidad.v_dashboard_calidad` — Dashboard de calidad de datos.
- `solardb.v_estado_baterias` — Estado de las baterías.

**Tablas principales con columnas clave de `solardb.lectura_telemetria` (46 columnas total):**
- `lectura_id` (BIGINT IDENTITY PK), `inversor_id` (SMALLINT FK → dim_inversor), `ts_lectura` (TIMESTAMPTZ), `lote_id` (INTEGER FK → lote_carga)
- Batería: `battvolt` (V), `battcurr` (A, con signo), `battsoc` (%), `battchgpower` (W)
- Solar PV: `pv1volt` (V), `pv1curr` (A), `pv1power` (W)
- Salida: `outvolta` (V), `outcurra` (A), `outfreq` (Hz), `outw_a` (W), `outva_a` (VA)
- Totales: `outsumw` (W), `outsumva` (VA), `sumloadpercent` (%)
- Generación: `generatedpowerp_a` (W, con signo), `generatedpowers_a` (VA), `generatedpowerq_a` (VAR)
- Red eléctrica: `linevolta` (V), `linecurra` (A), `linefreq` (Hz), `linepowerw_a` (W), `linepowerva_a` (VA)
- Bus DC: `busvoltp` (V), `busvoltn` (V)
- Temperatura: `temper1`, `temper2`, `temper3`, `temper4` (°C)
- Otros: `sir` (kΩ), `fanduty` (%), `loadpercenta` (%), `gridpowerw_a` (W), `gridcurr_a` (A)
- JSONB reservados: `battreserve`, `pvreserve`, `otherreserve`, `grid_reserve`

**NOTA IMPORTANTE SOBRE LOS NOMBRES DE TABLAS EN LAS CONSULTAS:**
En el archivo `sql/12_consultas_negocio.sql` que tú creaste en la Ronda 1, algunas consultas pueden usar alias o nombres abreviados (ej: `FROM lectura l`). El nombre real de la tabla es `solardb.lectura_telemetria`. La columna de timestamp es `ts_lectura` (no `read_ts`). El campo del inversor es `inversor_id` (no `inverter`). Verifica y corrige cualquier discrepancia antes de ejecutar.

</ESTADO ACTUAL DE LA BASE DE DATOS>

<TU MISIÓN — TAREA 1: EJECUCIÓN REAL DE LAS 10 CONSULTAS DE NEGOCIO>

Abre el archivo `sql/12_consultas_negocio.sql` que tú creaste en la Ronda 1. Ejecuta CADA una de las 10 consultas contra la base de datos real `solardb` en PostgreSQL.

**Para cada consulta debes:**

1. **Leer el SQL** del archivo `sql/12_consultas_negocio.sql`.
2. **Verificar y corregir** cualquier error de nombres de tabla/columna antes de ejecutar (ej: si dice `FROM lectura l` en vez de `FROM solardb.lectura_telemetria l`, corregir).
3. **Ejecutar la consulta** contra PostgreSQL y capturar:
   - Número exacto de filas retornadas.
   - Tiempo de ejecución real (ms o s).
   - Las primeras 10–20 filas de resultado como tabla de ejemplo.
4. **Interpretar el resultado** con una explicación de negocio (ej: "El inversor 1 generó 2,345.67 kWh solares en julio 2026, un 12% más que el inversor 2").

**Las 10 consultas que debes ejecutar son (ya existen en el archivo):**

| # | Consulta | Tipo |
|---|---|---|
| 1 | Energía diaria y mensual por inversor (solar, carga, red) | Obligatoria |
| 2 | Hora pico solar por inversor y mes | Obligatoria |
| 3 | Comparación entre inversores (potencia, energía, factor de carga) | Obligatoria |
| 4 | Alerta de batería baja (SOC < umbral) por día | Obligatoria |
| 5 | Completitud de datos (% lecturas recibidas vs esperadas por día) | Obligatoria |
| 6 | Consulta JSON sobre registros de contexto (operadores `->`, `->>`, `@>`) | Obligatoria |
| 7 | Tasa de rechazo y % de cuarentena por regla de calidad | SolarDB |
| 8 | Variables con mayor frecuencia de nulos o fuera de rango | SolarDB |
| 9 | Evolución temporal de registros en cuarentena | SolarDB |
| 10 | Comparación lecturas recibidas vs aceptadas vs rechazadas por inversor | SolarDB |

**Si alguna consulta tiene errores de sintaxis o de nombres, corrígela en el archivo `sql/12_consultas_negocio.sql` y guarda las correcciones.**

</TU MISIÓN — TAREA 1>

<TU MISIÓN — TAREA 2: VALIDACIÓN DE VISTAS>

Ejecuta las 3 vistas de producción y documenta sus resultados:

```sql
-- Vista 1: Resumen diario de energía
SELECT * FROM solardb.v_resumen_diario_energia
ORDER BY dia DESC
LIMIT 15;

-- Vista 2: Dashboard de calidad
SELECT * FROM calidad.v_dashboard_calidad;

-- Vista 3: Estado de baterías
SELECT * FROM solardb.v_estado_baterias;
```

Para cada vista documenta:
- Número de filas retornadas.
- Muestra de las primeras filas.
- Interpretación de los resultados.
- Confirmación de que los datos agregados son coherentes con las métricas reales (ej: total de filas aceptadas debe ser ~2,965,337).

</TU MISIÓN — TAREA 2>

<TU MISIÓN — TAREA 3: CAPTURA DE PLANES EXPLAIN ANALYZE>

Para los índices principales, ejecuta consultas representativas con `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` y documenta el plan de ejecución.

**Debes capturar EXPLAIN ANALYZE para al menos estos 3 escenarios:**

**Escenario 1: Búsqueda por rango de fechas (usa `idx_lectura_ts`)**
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT inversor_id, ts_lectura, pv1power, outsumw, gridpowerw_a
FROM solardb.lectura_telemetria
WHERE ts_lectura BETWEEN '2026-01-01' AND '2026-01-07';
```

**Escenario 2: Filtrado por inversor + fecha (usa `idx_lectura_inversor_ts`)**
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ts_lectura, battsoc, battvolt, battcurr
FROM solardb.lectura_telemetria
WHERE inversor_id = 1
  AND ts_lectura BETWEEN '2025-12-01' AND '2025-12-31';
```

**Escenario 3: Búsqueda en JSONB (usa `idx_contexto_valor_gin`)**
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT contexto_id, ts_contexto, valor
FROM solardb.registro_contexto
WHERE valor @> '{"source": "derived_context_pipeline"}';
```

**Para cada plan documenta:**
- El plan completo de texto (copia/pega el output).
- Qué tipo de scan se usó (Index Scan, Bitmap Index Scan, Seq Scan, etc.).
- El tiempo de ejecución real.
- Cuántos buffers (bloques de 8KB) se leyeron.
- Una justificación técnica de por qué el índice es efectivo (o si no lo es, por qué).

</TU MISIÓN — TAREA 3>

<TU MISIÓN — TAREA 4: BATERÍA DE PRUEBAS DE INTEGRIDAD>

Crea DOS archivos nuevos en el workspace:
1. `sql/13_pruebas_integridad.sql` — Script SQL con todas las pruebas ejecutables.
2. `docs/13_pruebas_solar_db.md` — Documentación con evidencia de cada prueba.

**Pruebas obligatorias (mínimo 8):**

**Prueba 1 — Inserción válida aceptada:**
INSERT de una fila con valores físicos normales en `solardb.lectura_telemetria`. Debe ser aceptada sin error.
```sql
-- Ejemplo de valores normales:
-- inversor_id = 1, ts_lectura = '2026-11-16 12:00:00+00'
-- battvolt = 52.5, battcurr = -15.0, battsoc = 85, pv1power = 2500
-- (Usar un timestamp futuro que no exista para evitar conflicto UNIQUE)
```

**Prueba 2 — Rechazo por dominio dom_voltaje (voltaje negativo):**
INSERT con `battvolt = -10.0` → PostgreSQL debe rechazar con `CheckViolation` del dominio `dom_voltaje`.

**Prueba 3 — Rechazo por dominio dom_porcentaje (fuera de rango [0,100]):**
INSERT con `fanduty = 150` → Rechazado por `dom_porcentaje CHECK (VALUE BETWEEN 0 AND 100)`.

**Prueba 4 — Rechazo por dominio dom_porcentaje_carga (fuera de rango [0,110]):**
INSERT con `loadpercenta = 120` → Rechazado por `dom_porcentaje_carga CHECK (VALUE BETWEEN 0 AND 110)`.

**Prueba 5 — Rechazo por clave primaria duplicada (UNIQUE violation):**
INSERT con un par `(inversor_id, ts_lectura)` que ya exista en la tabla → Rechazado por `UniqueViolation` en la restricción `uq_lectura_inversor_ts`.

**Prueba 6 — Rechazo por clave foránea inválida (FK violation):**
INSERT con `inversor_id = 99` (no existe en `dim_inversor`) → Rechazado por `ForeignKeyViolation`.

**Prueba 7 — Rechazo por dominio dom_potencia_aparente (potencia aparente negativa):**
INSERT con `outva_a = -100` → Rechazado por `dom_potencia_aparente CHECK (VALUE >= 0)`.

**Prueba 8 — Prueba de idempotencia del pipeline:**
Verificar que `ON CONFLICT (inversor_id, ts_lectura) DO NOTHING` funciona:
```sql
-- Intentar insertar una fila con el mismo (inversor_id, ts_lectura) que ya existe.
-- Debe ejecutarse sin error pero sin insertar duplicados.
INSERT INTO solardb.lectura_telemetria (inversor_id, ts_lectura, lote_id, battvolt)
VALUES (1, (SELECT ts_lectura FROM solardb.lectura_telemetria LIMIT 1), 4, 50.0)
ON CONFLICT (inversor_id, ts_lectura) DO NOTHING;
-- Verificar que el conteo NO cambió.
```

**Para cada prueba documenta en `docs/13_pruebas_solar_db.md`:**
- Nombre de la prueba.
- Qué restricción se prueba (dominio, FK, PK, UNIQUE, CHECK).
- El SQL ejecutado.
- El resultado esperado.
- El resultado obtenido (copia/pega la salida real de PostgreSQL).
- Veredicto: ✅ PASÓ o ❌ FALLÓ.
- Explicación técnica de por qué funciona.

</TU MISIÓN — TAREA 4>

<TU MISIÓN — TAREA 5: ACTUALIZACIÓN DE DOCUMENTACIÓN>

Actualiza el archivo existente `docs/12_consultas_vistas_indices.md` incorporando:

1. **Sección de resultados reales de las 10 consultas:** Para cada consulta agrega una subsección "Resultado Real" con la tabla de datos, el tiempo de ejecución y la interpretación de negocio.

2. **Sección de planes EXPLAIN ANALYZE:** Para cada índice, incluye el plan de ejecución completo y la justificación técnica.

3. **Sección de vistas ejecutadas:** Muestra de cada vista con interpretación.

**NO borres el contenido existente del archivo.** Solo agrega las secciones nuevas de resultados reales.

</TU MISIÓN — TAREA 5>

<CONFIGURACIÓN DE GIT Y GITHUB — INSTRUCCIONES PARA ANTIGRAVITY>

Antes de empezar a trabajar, sincroniza con el repositorio remoto:

1. Verificar si Git está instalado:
```
git --version
```

2. Configurar tu identidad para los commits:
```
git config --global user.name "Deysi Carolina Echavarria Soto"
git config --global user.email "TU_CORREO_REAL@ejemplo.com"
```
(Reemplaza el correo con tu correo real de GitHub.)

3. Si el repositorio ya está clonado, entra a la carpeta y actualiza:
```
cd Trabajofinal
git checkout main
git pull origin main
```

4. Crea tu rama de trabajo:
```
git checkout -b deysi/consultas-y-pruebas
```

5. Si el repositorio NO está clonado, clónalo primero:
```
git clone https://github.com/desarrollosebas/Trabajofinal.git
cd Trabajofinal
git checkout -b deysi/consultas-y-pruebas
```

6. Después de crear o modificar cada archivo, haz commit:
```
git add sql/12_consultas_negocio.sql
git commit -m "fix(sql): corregir nombres de tabla en consultas de negocio"

git add docs/12_consultas_vistas_indices.md
git commit -m "docs: agregar resultados reales de ejecucion de 10 consultas"

git add sql/13_pruebas_integridad.sql
git commit -m "feat(sql): crear bateria de pruebas de integridad"

git add docs/13_pruebas_solar_db.md
git commit -m "docs: documentar evidencias de pruebas de integridad"
```

7. Al terminar, sube la rama a GitHub:
```
git push origin deysi/consultas-y-pruebas
```

**IMPORTANTE:** Si Antigravity no puede hacer push (porque necesita autenticación de GitHub), te guiará para configurar tu cuenta. Puedes usar GitHub CLI (`gh auth login`) o un token de acceso personal.

Haz commits pequeños e incrementales. No hagas un solo commit con todo.

</CONFIGURACIÓN DE GIT Y GITHUB>

<RESTRICCIONES OBLIGATORIAS>

1. No inventes resultados de consultas. Cada número, tiempo y fila debe venir de una ejecución real contra PostgreSQL o de las métricas oficiales certificadas en `docs/11_resultados_migracion.md`.
2. No escribas SQL con sintaxis de MySQL. Todo debe ser PostgreSQL puro.
3. No afirmes que un índice mejora el rendimiento sin mostrar el plan EXPLAIN ANALYZE real.
4. No afirmes que una prueba de integridad pasó sin mostrar la salida real de PostgreSQL (el mensaje de error o confirmación).
5. Las correcciones al archivo `sql/12_consultas_negocio.sql` deben mantener la misma estructura y comentarios. No reescribas todo el archivo.
6. Usa español para toda la documentación.
7. Cada archivo debe comenzar con un encabezado que incluya: proyecto, integrante responsable y fecha.
8. Verifica que los archivos se crearon correctamente antes de hacer commit.
9. Haz mínimo 5 commits separados con mensajes descriptivos en español.
10. Los mensajes de error de PostgreSQL en las pruebas de integridad deben ser capturas reales, no textos inventados.
11. Las consultas SQL sobre la tabla de telemetría DEBEN usar el nombre `solardb.lectura_telemetria`, NO alias o nombres incorrectos.
12. La columna de timestamp es `ts_lectura`, NO `read_ts`.
13. El campo del inversor es `inversor_id`, NO `inverter`.

</RESTRICCIONES OBLIGATORIAS>

<CRITERIOS DE ACEPTACIÓN>

Tu trabajo se considerará completo cuando:

- [ ] Las 10 consultas de negocio fueron ejecutadas o validadas contra datos reales y cada una tiene resultado documentado.
- [ ] Si hubo errores de nombres en las consultas, fueron corregidos en `sql/12_consultas_negocio.sql`.
- [ ] Las 3 vistas fueron ejecutadas y sus resultados documentados.
- [ ] Se capturaron al menos 3 planes `EXPLAIN (ANALYZE, BUFFERS)` con evidencia de uso de índices.
- [ ] Existe `sql/13_pruebas_integridad.sql` con al menos 8 pruebas de integridad ejecutables.
- [ ] Existe `docs/13_pruebas_solar_db.md` con evidencia real de cada prueba (SQL ejecutado + salida real de PostgreSQL + veredicto).
- [ ] `docs/12_consultas_vistas_indices.md` fue actualizado con resultados reales, tiempos de ejecución e interpretaciones.
- [ ] Ningún resultado es inventado — todos vienen de ejecución real o métricas certificadas.
- [ ] Git está configurado con tu nombre real.
- [ ] Hay mínimo 5 commits incrementales en tu rama `deysi/consultas-y-pruebas`.
- [ ] Todo el código es PostgreSQL 18 válido.

</CRITERIOS DE ACEPTACIÓN>

<INICIO DEL TRABAJO>

Comienza así:

1. Configura Git con tu nombre y correo.
2. Clona o actualiza el repositorio (`git pull origin main`).
3. Crea tu rama de trabajo `deysi/consultas-y-pruebas`.
4. Lee `docs/11_resultados_migracion.md` para familiarizarte con las métricas finales.
5. Conéctate a PostgreSQL (`solardb`, `localhost:5432`, user `postgres`, password `postgres`) si está disponible.
6. Abre `sql/12_consultas_negocio.sql` y revisa/corrige los nombres de tabla hacia `solardb.lectura_telemetria`.
7. Ejecuta las consultas y captura los tiempos y filas de muestra.
8. Captura los planes EXPLAIN ANALYZE de los índices.
9. Crea `sql/13_pruebas_integridad.sql` con las 8 pruebas.
10. Crea `docs/13_pruebas_solar_db.md` con las evidencias de las pruebas.
11. Actualiza `docs/12_consultas_vistas_indices.md` con los resultados.
12. Haz commits incrementales después de cada avance y súbelos a GitHub.

No intentes hacer todo en una sola respuesta. Trabaja por etapas ordenadas.

</INICIO DEL TRABAJO>
