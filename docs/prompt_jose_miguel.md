# PROMPT PARA JOSE MIGUEL SOSA CARTAGENA
# Herramienta: ChatGPT, Claude, Gemini Web u otra IA conversacional
# Copiar TODO el contenido de este archivo y pegarlo como primer mensaje en una conversación nueva.
# ─────────────────────────────────────────────────────────────────────────────

# PROYECTO UNIVERSITARIO — TALLER 6
# SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL
# ROL: Diccionario de Datos, Diseño Físico, Privacidad (Ley 1581) y Documento Final

<CONFIGURACIÓN>

Idioma de trabajo: Español.
Motor de base de datos: PostgreSQL.
Herramienta de administración: DBeaver.
Control de versiones: Git y GitHub.
Formato de entrega: Archivos Markdown (.md) listos para incorporar a un repositorio GitHub.

</CONFIGURACIÓN>

<ROL>

Actúa simultáneamente como:

1. **Ingeniero de datos senior** especializado en PostgreSQL, tipos de datos, diseño físico de bases de datos y documentación técnica de diccionarios de datos.
2. **Abogado especialista en protección de datos personales** con dominio de la Ley Estatutaria 1581 de 2012 de Colombia (Régimen General de Protección de Datos Personales) y la Ley 1266 de 2008 (Habeas Data).
3. **Tutor universitario** que explica las decisiones técnicas con claridad para que un estudiante de Bases de Datos I pueda comprender y defender cada aspecto durante una sustentación oral.

Debes tener dominio de:
- Tipos de datos de PostgreSQL (NUMERIC, DOUBLE PRECISION, BIGINT, INTEGER, SMALLINT, BOOLEAN, TEXT, VARCHAR, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITHOUT TIME ZONE, JSON, JSONB, BYTEA).
- Restricciones declarativas (PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, NOT NULL, DEFAULT).
- Dominios personalizados (CREATE DOMAIN).
- Índices (B-tree, GIN, BRIN).
- Ley 1581 de 2012 de Colombia y sus decretos reglamentarios.
- Principios de minimización, finalidad, necesidad y confidencialidad del tratamiento de datos personales.
- Redacción académica y técnica.

</ROL>

<CONTEXTO DEL PROYECTO>

Este proyecto forma parte del Taller 6 de Bases de Datos I, en la Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II.

**Docente:** Ramiro Grisales Montoya.

**Integrantes del equipo:**

1. Juan Sebastian Raigosa Gil — Coordinador. Trabaja la arquitectura SolarDB (dominios, staging, cuarentena, migración masiva y scripts DDL).
2. **Jose Miguel Sosa Cartagena (TÚ)** — Trabajas el diccionario de datos, diseño físico, análisis de privacidad (Ley 1581 de 2012) y la estructuración del documento final.
3. Deysi Carolina Echavarria Soto — Trabaja el modelado conceptual, lógico, normalización 3FN y consultas SQL de negocio.

**Repositorio oficial del equipo:** https://github.com/desarrollosebas/Trabajofinal

**Línea de profundización:** SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena.

**Dataset:** OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223).

**Cita obligatoria:**
Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

</CONTEXTO DEL PROYECTO>

<CONTEXTO TÉCNICO DEL DATASET — LO QUE YA SABEMOS>

Nuestro coordinador (Juan Sebastian) ya completó las Fases 0 y 1 del proyecto. Los siguientes datos son reales y verificados empíricamente sobre la base SQLite descomprimida (4.13 GB):

**Sistema físico:**
- Campus universitario en Shenzhen, China (CUHK-Shenzhen).
- 2 subsistemas independientes de microrred híbrida.
- Cada uno tiene: arreglo de paneles solares (26 paneles × 480 W), banco de baterías de litio LiFePO4 (~200 Ah, 51.2 V nominal), inversor híbrido y conexión a la red eléctrica pública (220V/230V CA, 50 Hz).
- Inversor 1 (ID: 1): alimenta estaciones de cómputo de investigación (GPU/CPU).
- Inversor 2 (ID: 2): alimenta sistemas de climatización (HVAC).
- Muestreo cada ~12.6 segundos via Modbus/RS485.

**Tablas en el SQLite original y conteos exactos:**

| Tabla | Columnas | Filas | Descripción |
|-------|----------|-------|-------------|
| `analog_measurements` | 44 | **2,989,759** | Telemetría analógica principal. |
| `context` | 5 | 25,178 | Anotaciones de contexto en JSON. |
| `status` | 20 | 2,240,052 | Estados de operación del inversor. |
| `totals` | 21 | 2,279,918 | Potencias acumuladas y subtotales del BMS. |
| `settings` | 176 | 2,284,775 | Parámetros de configuración (176 columnas estáticas redundantes). |
| `specs` | 16 | 1,333,174 | Especificaciones de hardware (redundancia masiva). |
| `statistics` | 31 | 2,285,904 | Contadores de energía histórica. |
| `fault_history` | 66 | 2,129,517 | Registros históricos de fallas. |

**Variables principales de `analog_measurements` con unidades oficiales verificadas contra el `column_dictionary.json` de los autores de OpenCEM:**

| Variable | Tipo SQLite | Unidad | Rango Observado | Descripción |
|----------|-------------|--------|-----------------|-------------|
| `read_ts` | REAL | s (Unix UTC) | [1.75e9, 1.78e9] | Timestamp fraccionario Unix. |
| `inverter` | INTEGER | adimensional | [1, 2] | ID del inversor. |
| `battvolt` | REAL | V | [0.0, 57.60] | Voltaje de batería. |
| `battcurr` | REAL | A | [-66.30, 54.00] | Corriente de batería (+ carga, - descarga). |
| `battsoc` | INTEGER | % | [6, 100] | Estado de carga (SOC). |
| `battchgpower` | INTEGER | W | [-3400, 2800] | Potencia de carga/descarga. |
| `linechgcurr` | REAL | A | [0.0, 50.0] | Corriente de carga desde red. |
| `pvchgcurr` | REAL | A | [0.0, 60.0] | Corriente de carga desde solar. |
| `pv1volt` | REAL | V | [0.0, 492.60] | Voltaje del arreglo fotovoltaico. |
| `pv1curr` | REAL | A | [0.0, 10.60] | Corriente del arreglo fotovoltaico. |
| `pv1power` | INTEGER | W | [0, 3933] | Potencia activa solar generada. |
| `outvolta` | REAL | V | [0.0, 245.80] | Voltaje de salida CA a cargas. |
| `outcurra` | REAL | A | [0.0, 26.80] | Corriente de salida a cargas. |
| `outfreq` | REAL | Hz | [0.0, 50.10] | Frecuencia de salida. |
| `outw_a` | INTEGER | W | [0, 5502] | Potencia activa entregada a la carga. |
| `outva_a` | INTEGER | VA | [0, 5630] | Potencia aparente a la carga. |
| `outsumw` | INTEGER | W | [0, 5502] | Potencia activa total a la microrred. |
| `outsumva` | INTEGER | VA | [0, 5630] | Potencia aparente total. |
| `linevolta` | REAL | V | [0.0, 306.20] | Voltaje de la red eléctrica pública. |
| `linecurra` | REAL | A | [0.0, 35.40] | Corriente tomada de la red. |
| `linefreq` | REAL | Hz | [0.0, 50.07] | Frecuencia de la red (nominal 50 Hz). |
| `linepowerw_a` | INTEGER | W | [-5500, 5500] | Potencia activa con la red. |
| `gridpowerw_a` | INTEGER | W | [-5500, 5500] | Potencia neta de red en acometida. |
| `gridcurr_a` | REAL | A | [0.0, 35.40] | Corriente neta de red. |
| `busvoltp` | REAL | V | [0.0, 480.00] | Voltaje bus DC positivo. |
| `busvoltn` | REAL | V | [0.0, 480.00] | Voltaje bus DC negativo. |
| `temper1` | REAL | °C | [-20.30, 49.30] | Temperatura sensor 1. |
| `temper2` | REAL | °C | [0.0, 58.00] | Temperatura sensor 2. |
| `sir` | INTEGER | kΩ | [0, 9999] | Resistencia de aislamiento solar. |
| `fanduty` | INTEGER | % | [0, 100] | Ciclo de trabajo del ventilador. |
| `loadpercenta` | INTEGER | % | [0, 110] | Porcentaje de carga sobre capacidad nominal. |
| `sumloadpercent` | INTEGER | % | [0, 110] | Porcentaje total de carga. |

**Registros de contexto (`context`) — distribución por fuente:**

| Fuente (JSON `$.source`) | Cantidad | Contenido |
|--------------------------|----------|-----------|
| `workstation2_log` | 8,902 | Logs de GPU/CPU en estación 2. |
| `windows_event_log` | 6,271 | Eventos del sistema operativo Windows. |
| `workstation1_log` | 6,028 | Logs de tareas en estación 1. |
| `derived_context_pipeline` | 3,708 | Eventos climáticos y solares derivados. |
| `wsl_bash_history` | 204 | **Comandos de terminal Linux ejecutados por investigadores (DATOS PERSONALES).** |
| `manual entry` | 60 | Calendario institucional (festivos, exámenes). |
| `manual_workload_entry` | 5 | Pruebas de carga programadas. |

**Problemas de calidad diagnosticados:**
- ~58,000–60,000 filas (~2%) con valores nulos por timeouts Modbus.
- 38 filas con `temper1 = -20.3 °C` (imposible; error de sensor).
- 3,811 filas donde P > S (violación de ley de potencia en CA).
- 342,592 filas con frecuencia = 0 Hz (modo isla legítimo).

**Modelo SolarDB propuesto (pendiente de implementación):**
El modelo incluirá tablas de catálogo (`dim_sitio`, `dim_subsistema`, `dim_inversor`, `cat_variable_fisica`, `cat_unidad_medida`), tablas de hechos (`lectura_telemetria`, `registro_contexto`), tablas de calidad (`lote_carga`, `regla_calidad`, `registro_cuarentena`) y tablas de staging.

</CONTEXTO TÉCNICO DEL DATASET — LO QUE YA SABEMOS>

<TU MISIÓN — TAREA 1: DICCIONARIO DE DATOS>

Genera el archivo `docs/08_diccionario_datos.md`.

Para CADA tabla del modelo normalizado de SolarDB, documenta:

**Encabezado de tabla:**
- Nombre de la tabla.
- Esquema PostgreSQL al que pertenece (ej. `solardb`, `staging`, `calidad`).
- Propósito / descripción funcional.
- Cantidad esperada de filas.

**Por cada columna de la tabla:**

| Campo | Contenido |
|-------|-----------|
| Nombre | Nombre de la columna en PostgreSQL |
| Tipo de dato | Tipo PostgreSQL exacto (ej. `NUMERIC(8,2)`, `DOUBLE PRECISION`, `BIGINT`, `timestamptz`) |
| Dominio asociado | Si usa un CREATE DOMAIN personalizado (ej. `dom_voltaje`, `dom_porcentaje`) |
| Longitud / Precisión | Precisión y escala para NUMERIC, longitud para VARCHAR |
| Nulabilidad | `NOT NULL` o `NULL` |
| Valor por defecto | DEFAULT si aplica |
| PK | ✅ si es clave primaria |
| FK | Tabla y columna referenciada (ej. `→ dim_inversor.inversor_id`) |
| UNIQUE | ✅ si tiene restricción UNIQUE |
| CHECK | Expresión CHECK si aplica |
| Unidad de medida | Para variables físicas: V, A, W, VA, Hz, °C, %, kΩ, etc. |
| Evidencia de la unidad | Cita exacta de la fuente (ej. "column_dictionary.json, campo unit del registro battvolt") |
| Descripción funcional | Qué significa esta columna en el contexto del negocio de la microrred |

**Justificaciones técnicas obligatorias de tipos de datos:**

Incluye una sección especial que explique y justifique:

1. **NUMERIC vs DOUBLE PRECISION:**
   - NUMERIC es decimal exacto con precisión arbitraria. Es ideal para acumuladores de energía (kWh) donde el redondeo binario IEEE 754 puede acumular errores significativos.
   - DOUBLE PRECISION es punto flotante binario de 64 bits. Es más rápido para cálculos intensivos y suficiente para telemetría instantánea donde la precisión del sensor (ej. ±0.1V) ya limita la exactitud.
   - Explica cuándo usar cada uno en el contexto de SolarDB.

2. **TIMESTAMP WITH TIME ZONE vs TIMESTAMP WITHOUT TIME ZONE:**
   - Los datos originales son Unix timestamps fraccionarios en UTC.
   - PostgreSQL almacena `timestamptz` internamente siempre en UTC y lo convierte a la zona del cliente al mostrarlo.
   - `timestamp` (sin TZ) almacena el valor literal sin conciencia de zona horaria.
   - Justifica por qué `timestamptz` es la opción correcta para datos de telemetría global.

3. **JSONB vs JSON:**
   - `JSON` almacena texto tal cual y lo parsea cada vez que se consulta.
   - `JSONB` almacena una representación binaria descompuesta, permite indexación GIN sobre claves internas, soporta operadores de contención (`@>`, `?`, `?&`), y es significativamente más rápido en consultas.
   - Para los registros de contexto de OpenCEM (campo `value`), justifica por qué JSONB es superior.

4. **BIGINT vs INTEGER:**
   - INTEGER: 4 bytes, rango hasta ~2.1 × 10⁹.
   - BIGINT: 8 bytes, rango hasta ~9.2 × 10¹⁸.
   - Con casi 3 millones de lecturas de telemetría y posibilidad de crecimiento, ¿se justifica BIGINT para las llaves subrogadas? ¿Y para contadores acumulativos de energía?

</TU MISIÓN — TAREA 1>

<TU MISIÓN — TAREA 2: DISEÑO FÍSICO>

Genera el archivo `docs/09_diseno_fisico.md`.

Documenta las decisiones de diseño físico de PostgreSQL:

1. **Esquemas (schemas):** ¿Se usarán esquemas separados? (ej. `solardb` para producción, `staging` para carga temporal, `calidad` para cuarentena). Justifica.

2. **Tablespaces:** ¿Se justifica usar tablespaces separados para telemetría vs. catálogos? (Para este proyecto académico probablemente no, pero discútelo).

3. **Particionamiento:** ¿Conviene particionar la tabla de lecturas por rango de fecha (`PARTITION BY RANGE (read_ts)`)? Discute ventajas y desventajas para un dataset de 3 millones de filas.

4. **Estrategia de índices:** Documenta los tipos de índice disponibles en PostgreSQL (B-tree, Hash, GIN, GiST, BRIN) y recomienda cuáles usar para:
   - Búsqueda por timestamp.
   - Filtrado por inversor.
   - Consultas sobre contenido JSON.
   - Búsqueda de registros en cuarentena por estado.

5. **Estimación de almacenamiento:** Calcula el tamaño esperado en disco de las tablas principales después de la migración.

</TU MISIÓN — TAREA 2>

<TU MISIÓN — TAREA 3: MANEJO RESPONSABLE DE INFORMACIÓN — LEY 1581 DE 2012>

Genera el archivo `docs/14_seguridad_y_privacidad.md`.

Analiza la situación de privacidad del dataset OpenCEM:

**Datos potencialmente sensibles identificados:**

1. **204 registros `wsl_bash_history`:** Contienen comandos reales de terminal Linux ejecutados por investigadores. Pueden incluir nombres de usuario, rutas de carpetas personales (`/home/username/...`), nombres de scripts, direcciones IP internas y parámetros de configuración.

2. **6,271 registros `windows_event_log`:** Contienen eventos del sistema operativo Windows como inicios de sesión, nombres de usuarios del sistema, servicios iniciados y rutas de archivos de sistema.

3. **6,028 + 8,902 registros de workstation logs:** Contienen información sobre tareas de cómputo ejecutadas, GPU utilizadas, procesos y duración.

**Análisis legal obligatorio:**

1. Identifica qué tipos de datos personales están presentes según la clasificación de la Ley 1581 de 2012 (datos públicos, semiprivados, privados, sensibles).
2. Identifica los roles: ¿quién es el Responsable del Tratamiento? ¿Quién es el Encargado? ¿Quiénes son los Titulares?
3. Evalúa si se cumplen los principios de la ley: finalidad, libertad, veracidad, transparencia, acceso y circulación restringida, seguridad y confidencialidad.
4. Propón medidas técnicas concretas:
   - Anonimización de nombres de usuario y rutas.
   - Enmascaramiento de IPs y hostnames.
   - Separación en esquemas de acceso restringido.
   - Política de retención y eliminación.
   - Vistas que excluyan campos sensibles.
5. Redacta un aviso de privacidad simplificado para el proyecto académico.

**Protección del repositorio:**

Documenta explícitamente que el repositorio NO debe contener:
- Contraseñas de PostgreSQL ni de ningún otro sistema.
- Cadenas de conexión con credenciales.
- Tokens de acceso a GitHub.
- Datos crudos del dataset (van en `.gitignore`).
- Archivos `.env` con variables de entorno sensibles.

</TU MISIÓN — TAREA 3>

<TU MISIÓN — TAREA 4: GUÍA DE SUSTENTACIÓN>

Genera el archivo `docs/15_guia_sustentacion.md`.

Prepara una guía completa para que los tres integrantes podamos defender el proyecto ante el profesor.

**A. Preguntas difíciles que puede hacer el profesor y cómo responderlas:**

Redacta al menos 20 preguntas organizadas por tema, con respuestas claras y técnicas:

**Sobre el dataset:**
1. ¿Qué es OpenCEM y de dónde vienen los datos?
2. ¿Qué representa exactamente una lectura?
3. ¿Cuántas lecturas hay y cómo verificaron que son reales?
4. ¿Qué problemas de calidad encontraron?

**Sobre el modelo:**
5. ¿Por qué eligieron formato ancho/largo para las lecturas?
6. ¿Cuáles son las entidades principales y cómo se relacionan?
7. ¿Qué dependencias funcionales identificaron?
8. ¿Cómo demuestran que el diseño está en 3FN?
9. ¿Hay alguna desnormalización intencional? ¿Por qué?

**Sobre SolarDB (línea de profundización):**
10. ¿Qué es un CREATE DOMAIN y para qué lo usan?
11. ¿Cuál es la diferencia entre un CHECK a nivel de columna y un DOMAIN?
12. ¿Qué es una tabla de staging y por qué se necesita?
13. ¿Qué es una tabla de cuarentena?
14. ¿Cómo llega un registro a cuarentena? (El profesor puede confundir: PostgreSQL NO envía automáticamente registros rechazados a cuarentena; el proceso de staging los clasifica ANTES de intentar insertar.)
15. ¿Qué pasa si intento insertar un voltaje de -500V?
16. ¿Pueden reprocesar un registro de cuarentena?

**Sobre la migración:**
17. ¿Cómo cargaron un millón de lecturas?
18. ¿Cuánto tiempo tardó la migración?
19. ¿Qué pasa si ejecutan la migración dos veces?
20. ¿Cuántos registros fueron rechazados y por qué?

**Sobre las consultas:**
21. ¿Cómo calculan la energía diaria si el muestreo no es uniforme?
22. ¿Por qué usaron ese umbral de batería baja?
23. ¿Qué muestra la consulta JSON?

**B. Guion para la demostración en vivo (paso a paso en DBeaver):**

1. Crear la base de datos desde cero.
2. Ejecutar los scripts DDL en orden.
3. Cargar catálogos.
4. Ejecutar la migración de datos.
5. Mostrar que hay más de un millón de lecturas.
6. Ejecutar una consulta de negocio.
7. Insertar un dato válido y mostrarlo.
8. Intentar insertar un dato inválido y mostrar el rechazo.
9. Mostrar la tabla de cuarentena con registros rechazados.
10. Mostrar las vistas.
11. Mostrar un plan EXPLAIN ANALYZE con índice.

**C. Estructura del documento PDF final:**

Diseña la tabla de contenidos completa del PDF:
`BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`

</TU MISIÓN — TAREA 4>

<CONFIGURACIÓN DE GIT Y GITHUB — INSTRUCCIONES PASO A PASO PARA JOSE MIGUEL>

Como tú NO tienes Antigravity para automatizar este proceso, aquí van las instrucciones manuales completas para instalar Git, configurarlo y subir tus archivos al repositorio del equipo.

**PASO 1: Instalar Git**

1. Abre tu navegador y ve a: https://git-scm.com/downloads
2. Descarga el instalador para Windows.
3. Ejecuta el instalador. En todas las pantallas puedes dejar las opciones por defecto. Solo asegúrate de que:
   - En "Adjusting your PATH environment": selecciona "Git from the command line and also from 3rd-party software".
   - En "Choosing the default editor": puedes elegir "Use Visual Studio Code as Git's default editor" o Notepad.
4. Una vez instalado, abre una terminal (PowerShell o CMD) y escribe:
```
git --version
```
Deberías ver algo como: `git version 2.47.0.windows.1`

**PASO 2: Crear una cuenta de GitHub (si no tienes)**

1. Ve a https://github.com y regístrate con tu correo personal o institucional.
2. Verifica tu correo electrónico.

**PASO 3: Configurar tu identidad en Git**

Abre PowerShell o CMD y ejecuta estos dos comandos (reemplaza con TU nombre y TU correo):
```
git config --global user.name "Jose Miguel Sosa Cartagena"
git config --global user.email "tu_correo_real@ejemplo.com"
```

**PASO 4: Clonar el repositorio del equipo**

```
cd Desktop
git clone https://github.com/desarrollosebas/Trabajofinal.git
cd Trabajofinal
```

Si te pide usuario y contraseña:
- Usuario: tu nombre de usuario de GitHub.
- Contraseña: NO uses tu contraseña de GitHub. Necesitas un **token de acceso personal**:
  1. En GitHub ve a: Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token.
  2. Dale un nombre (ej. "Taller6").
  3. Marca el permiso "repo" (acceso completo a repositorios).
  4. Clic en "Generate token".
  5. COPIA el token (solo se muestra una vez).
  6. Usa ese token como contraseña cuando Git te la pida.

**PASO 5: Crear tu rama de trabajo**

```
git checkout -b jose/diccionario-y-privacidad
```

**PASO 6: Crear tus archivos**

Crea los archivos Markdown que la IA te genera. Puedes usar:
- Notepad: abre Notepad, pega el contenido, guarda como `docs/08_diccionario_datos.md` (asegúrate de seleccionar "Todos los archivos" y que la extensión sea `.md`, no `.md.txt`).
- Visual Studio Code (recomendado): instálalo desde https://code.visualstudio.com, abre la carpeta `Trabajofinal` y crea los archivos directamente.

**PASO 7: Hacer commits**

Después de crear cada archivo, abre la terminal en la carpeta `Trabajofinal` y ejecuta:

```
git add docs/08_diccionario_datos.md
git commit -m "docs: agregar diccionario de datos completo"
```

Repite para cada archivo:
```
git add docs/09_diseno_fisico.md
git commit -m "docs: agregar diseño físico de PostgreSQL"

git add docs/14_seguridad_y_privacidad.md
git commit -m "docs: agregar análisis de privacidad Ley 1581"

git add docs/15_guia_sustentacion.md
git commit -m "docs: agregar guía de sustentación y preguntas frecuentes"
```

**PASO 8: Subir tu rama a GitHub**

```
git push origin jose/diccionario-y-privacidad
```

Si te pide credenciales de nuevo, usa tu usuario de GitHub y el token que generaste.

**PASO 9: Verificar en GitHub**

Abre https://github.com/desarrollosebas/Trabajofinal en tu navegador. Deberías ver un banner amarillo que dice: "jose/diccionario-y-privacidad had recent pushes". El coordinador (Juan Sebastian) se encargará de integrar tu rama.

**RESUMEN DE COMANDOS:**
```
git --version
git config --global user.name "Jose Miguel Sosa Cartagena"
git config --global user.email "tu_correo@ejemplo.com"
cd Desktop
git clone https://github.com/desarrollosebas/Trabajofinal.git
cd Trabajofinal
git checkout -b jose/diccionario-y-privacidad
# ... crear archivos ...
git add docs/08_diccionario_datos.md
git commit -m "docs: agregar diccionario de datos"
git add docs/09_diseno_fisico.md
git commit -m "docs: agregar diseño físico"
git add docs/14_seguridad_y_privacidad.md
git commit -m "docs: agregar análisis Ley 1581"
git add docs/15_guia_sustentacion.md
git commit -m "docs: agregar guía de sustentación"
git push origin jose/diccionario-y-privacidad
```

</CONFIGURACIÓN DE GIT Y GITHUB>

<RESTRICCIONES OBLIGATORIAS>

1. No inventes datos, columnas, unidades de medida ni rangos físicos que no estén en el contexto proporcionado.
2. Todos los tipos de datos que menciones deben ser de PostgreSQL, no de MySQL ni de SQL Server.
3. Las unidades de medida deben coincidir con las documentadas por los autores de OpenCEM (proporcionadas arriba).
4. Las referencias a la Ley 1581 de 2012 deben citar artículos específicos, no generalidades.
5. No incluyas contraseñas, tokens ni cadenas de conexión en ningún archivo.
6. Usa español para toda la documentación.
7. Cada archivo debe comenzar con un encabezado: proyecto, integrante responsable y fecha.
8. No uses lenguaje informal. Mantén un tono académico y técnico.
9. Los ejemplos de datos deben ser reales (tomados del contexto proporcionado), no inventados.
10. Entrega cada archivo por separado, completo y listo para guardar como `.md`.

</RESTRICCIONES OBLIGATORIAS>

<FORMATO DE ENTREGA>

Entrégame cada archivo por separado en formato Markdown completo.

El orden de entrega debe ser:
1. Primero: `docs/08_diccionario_datos.md`
2. Segundo: `docs/09_diseno_fisico.md`
3. Tercero: `docs/14_seguridad_y_privacidad.md`
4. Cuarto: `docs/15_guia_sustentacion.md`

Si el contenido es muy extenso para una sola respuesta, divídelo y dime "continúo en el siguiente mensaje" al final de cada parte. Yo te diré "continúa" para que sigas.

No mezcles varios archivos en una sola respuesta. Uno a la vez.

</FORMATO DE ENTREGA>

<CRITERIOS DE ACEPTACIÓN>

Tu trabajo se considerará completo cuando:

- [ ] Existe `docs/08_diccionario_datos.md` con TODAS las tablas y TODAS las columnas documentadas.
- [ ] Cada variable física tiene su unidad de medida y la evidencia de la fuente.
- [ ] Se justifica NUMERIC vs DOUBLE PRECISION con argumentos técnicos reales.
- [ ] Se justifica TIMESTAMP WITH TIME ZONE vs sin TZ.
- [ ] Se justifica JSONB vs JSON.
- [ ] Se justifica BIGINT vs INTEGER.
- [ ] Existe `docs/09_diseno_fisico.md` con análisis de esquemas, particionamiento, índices y almacenamiento.
- [ ] Existe `docs/14_seguridad_y_privacidad.md` con análisis bajo Ley 1581 de 2012 citando artículos específicos.
- [ ] Existe `docs/15_guia_sustentacion.md` con al menos 20 preguntas y respuestas organizadas por tema.
- [ ] Existe la estructura del PDF final con tabla de contenidos completa.
- [ ] Existe el guion de demostración en vivo paso a paso.
- [ ] Ningún archivo contiene contraseñas, tokens ni cadenas de conexión.
- [ ] Todo está en español con tono académico y técnico.

</CRITERIOS DE ACEPTACIÓN>

<INICIO DEL TRABAJO>

Comienza generando el primer archivo: `docs/08_diccionario_datos.md`.

Si necesitas aclaraciones sobre el modelo de tablas que va a implementar el coordinador, trabaja con las tablas candidatas mencionadas en el contexto:
- Catálogos: `dim_sitio`, `dim_subsistema`, `dim_inversor`, `cat_variable_fisica`, `cat_unidad_medida`.
- Hechos: `lectura_telemetria`, `registro_contexto`.
- Calidad: `lote_carga`, `regla_calidad`, `registro_cuarentena`, `staging_telemetria`.

Si algún detalle del modelo no está confirmado, indícalo claramente como "pendiente de confirmación por el coordinador" y propón un valor razonable.

Empieza ahora.

</INICIO DEL TRABAJO>
