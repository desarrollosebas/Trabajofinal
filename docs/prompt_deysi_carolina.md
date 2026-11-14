# PROMPT PARA DEYSI CAROLINA ECHAVARRIA SOTO
# Herramienta: Google Antigravity (Agent Mode)
# Copiar TODO el contenido de este archivo y pegarlo como primer mensaje en una conversación nueva de Antigravity.
# ─────────────────────────────────────────────────────────────────────────────

# PROYECTO UNIVERSITARIO — TALLER 6
# SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL
# ROL: Modelado, Normalización y Consultas SQL de Negocio

<CONFIGURACIÓN DE LA IA>

Herramienta: Google Antigravity.
Modalidad: Agent Mode.
Idioma de trabajo: Español.
Motor de base de datos: PostgreSQL.
Herramienta de administración: DBeaver.
Control de versiones: Git y GitHub.

Utiliza las herramientas disponibles en Antigravity: editor de código, terminal, navegador y gestión de archivos.

Actúa como un agente de desarrollo que construye y verifica un proyecto real dentro del workspace. No te limites a proporcionar instrucciones o fragmentos de código. Ejecuta, verifica y corrige.

No afirmes que ejecutaste algo si no tienes evidencia de su ejecución.

</CONFIGURACIÓN DE LA IA>

<ROL>

Actúa como un arquitecto de bases de datos e ingeniero de datos especializado en:

- PostgreSQL y SQL avanzado.
- Modelado entidad-relación (notación Chen y crow's foot / pata de gallo).
- Normalización hasta tercera forma normal (3FN).
- Dependencias funcionales.
- Diseño de consultas analíticas sobre series de tiempo eléctricas.
- Vistas SQL e índices con justificación de rendimiento.
- Git y GitHub.

También eres un tutor universitario que explica las decisiones técnicas con claridad.

</ROL>

<CONTEXTO DEL PROYECTO>

Este proyecto forma parte del Taller 6 de Bases de Datos I, en la Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II.

**Docente:** Ramiro Grisales Montoya.

**Integrantes del equipo:**

1. Juan Sebastian Raigosa Gil — Coordinador. Trabaja la arquitectura SolarDB (dominios, staging, cuarentena, migración masiva y DDL).
2. Jose Miguel Sosa Cartagena — Trabaja diccionario de datos, diseño físico, privacidad (Ley 1581) y documento final PDF.
3. **Deysi Carolina Echavarria Soto (TÚ)** — Trabajas el modelado conceptual, lógico, normalización hasta 3FN, y las consultas SQL de negocio con vistas e índices.

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
| `analog_measurements` | 44 | **2,989,759** | Telemetría analógica (voltajes, corrientes, potencias, SOC, temperaturas). **Esta es la tabla principal.** |
| `context` | 5 | 25,178 | Anotaciones de contexto en JSON (calendarios, logs de estaciones, comandos bash). |
| `status` | 20 | 2,240,052 | Banderas y estados de operación del inversor. |
| `totals` | 21 | 2,279,918 | Potencias acumuladas y subtotales del BMS. |
| `settings` | 176 | 2,284,775 | Parámetros de configuración del inversor (REDUNDANCIA SEVERA: 176 columnas estáticas repetidas por cada timestamp). |
| `specs` | 16 | 1,333,174 | Especificaciones de hardware (REDUNDANCIA: datos de fabricante y serial repetidos 1.33 millones de veces). |
| `statistics` | 31 | 2,285,904 | Contadores de energía diaria, semanal e histórica. |
| `fault_history` | 66 | 2,129,517 | Registros históricos de fallas con código y timestamp. |

**Desglose por inversor en `analog_measurements`:**
- Inversor 1: 1,610,276 filas (2025-07-12 al 2026-07-13).
- Inversor 2: 1,379,483 filas (2025-07-14 al 2026-06-22).
- Periodo total: ~1 año continuo.

**Problemas de calidad ya diagnosticados:**
- ~58,000–60,000 filas (~2%) con valores nulos por timeouts Modbus.
- 38 filas con `temper1 = -20.3 °C` (imposible en Shenzhen; error de sensor).
- 3,811 filas donde la potencia activa supera la aparente (violación de P ≤ S en CA).
- 342,592 filas con `linefreq = 0.0 Hz` (modo isla / desconexión legítima de la red).
- 204 registros con comandos bash de investigadores (datos personales — Ley 1581).
- Cero duplicados en la clave `(read_ts, inverter)`.

**Variables principales de `analog_measurements` con unidades verificadas:**
- `read_ts` (REAL): Timestamp Unix fraccionario en UTC.
- `inverter` (INTEGER): ID del inversor (1 o 2).
- `battvolt` (V), `battcurr` (A), `battsoc` (%), `battchgpower` (W).
- `pv1volt` (V), `pv1curr` (A), `pv1power` (W).
- `outvolta` (V), `outcurra` (A), `outfreq` (Hz), `outw_a` (W), `outva_a` (VA).
- `outsumw` (W), `outsumva` (VA).
- `linevolta` (V), `linecurra` (A), `linefreq` (Hz), `linepowerw_a` (W).
- `gridpowerw_a` (W), `gridcurr_a` (A).
- `temper1` (°C), `temper2` (°C).

</CONTEXTO TÉCNICO DEL DATASET — LO QUE YA SABEMOS>

<TU MISIÓN — FASE 3: MODELO CONCEPTUAL, LÓGICO Y NORMALIZACIÓN>

Debes crear los modelos de datos y demostrar la normalización hasta 3FN. Los archivos que debes generar son:

1. `docs/05_modelo_conceptual.md`
2. `docs/06_modelo_logico.md`
3. `docs/07_normalizacion_3FN.md`

**A. Formato de almacenamiento de lecturas (obligatorio justificar)**

Compara técnicamente los dos formatos posibles para almacenar las lecturas de telemetría:

**Formato ancho (wide):** Una fila por instante con todas las variables como columnas.
```
| read_ts | inverter | battvolt | battcurr | pv1power | outsumw | ... |
```

**Formato largo (tall/narrow):** Una fila por instante y por variable.
```
| read_ts | inverter | variable_id | valor |
```

Analiza y compara el impacto en:
- Normalización.
- Volumen de almacenamiento (con 2,989,759 filas × 44 variables = ¿cuántas filas en formato largo?).
- Velocidad de consultas analíticas (agregaciones, energía diaria).
- Velocidad de inserciones masivas.
- Flexibilidad para agregar nuevas variables.
- Integridad referencial.
- Facilidad para definir restricciones CHECK y dominios por variable.

Recomienda una opción y justifica la decisión. No afirmes que una es mejor sin explicar por qué.

**B. Modelo conceptual**

Diseña el modelo entidad-relación con:
- Entidades con sus atributos.
- Relaciones con cardinalidades (1:1, 1:N, N:M).
- Participación (total o parcial).
- Identificadores (PK).

Entidades candidatas que debes evaluar (no todas son obligatorias; justifica las que incluyas):
- Sitio / Campus.
- Subsistema.
- Inversor.
- Lectura de telemetría (analog_measurements).
- Registro de contexto (context).
- Variable física / Tipo de variable.
- Unidad de medida.
- Lote de carga (para trazabilidad de migración).
- Regla de calidad.
- Registro de cuarentena.

Genera el diagrama usando código Mermaid (erDiagram o classDiagram).

**C. Modelo lógico**

Deriva el modelo relacional lógico a partir del conceptual:
- Tablas con columnas.
- Claves primarias.
- Claves foráneas con políticas ON DELETE / ON UPDATE.
- Restricciones (PK, FK, UNIQUE, CHECK, NOT NULL, DEFAULT).

Genera el diagrama en código Mermaid con notación crow's foot (pata de gallo).

**D. Normalización hasta 3FN**

Demuestra formalmente el proceso completo paso a paso:

**1FN (Primera Forma Normal):**
- Verifica atomicidad en todos los atributos.
- Identifica y resuelve campos JSON, TEXT con listas o arrays almacenados como cadenas.
- Muestra ejemplos reales del dataset.

**2FN (Segunda Forma Normal):**
- Identifica la clave primaria compuesta original: `(read_ts, inverter)`.
- Identifica dependencias funcionales parciales.
- Ejemplo real: en la tabla `specs`, los atributos `manufacturename`, `sourcesn`, `hwver_m1` dependen SOLO de `inverter`, NO de `(read_ts, inverter)`. Esto es una dependencia parcial que viola 2FN.
- Descompón las tablas para eliminar las dependencias parciales.

**3FN (Tercera Forma Normal):**
- Identifica dependencias transitivas.
- Ejemplo: si `inverter → subsistema → sitio`, entonces `sitio` depende transitivamente de `inverter`.
- Descompón las tablas para eliminar las dependencias transitivas.

Para cada forma normal muestra:
- La estructura ANTES.
- Las dependencias funcionales identificadas.
- Las anomalías que existían (inserción, modificación, eliminación).
- La descomposición aplicada.
- La estructura DESPUÉS.
- Por qué se cumple la nueva forma normal.

Usa datos reales de OpenCEM en los ejemplos, no valores inventados.

Si decides desnormalizar algo intencionalmente, justifica por qué.

</TU MISIÓN — FASE 3>

<TU MISIÓN — FASE 7: CONSULTAS SQL DE NEGOCIO, VISTAS E ÍNDICES>

Debes crear:

1. `sql/12_consultas_negocio.sql`
2. `docs/12_consultas_vistas_indices.md`

**A. Consultas SQL (mínimo 10)**

Cada consulta debe contener:
1. Un nombre descriptivo.
2. La pregunta de negocio que responde.
3. El código SQL (PostgreSQL).
4. Explicación de la lógica.
5. Interpretación del resultado esperado.

**6 consultas obligatorias (exigidas por la guía del profesor):**

1. **Energía por inversor, día y mes:** Energía solar generada (PV), energía entregada a la carga (output), y energía tomada de la red (grid), por inversor, por día y por mes. Usa integración trapezoidal o aproximación con el intervalo de muestreo (~12.6 s).

2. **Hora pico solar:** Hora del día con mayor generación solar promedio, por inversor y por mes.

3. **Comparación entre inversores:** Métricas comparativas entre el Inversor 1 y el Inversor 2 en un mismo periodo (ej. potencia promedio, energía total, factor de carga).

4. **Alerta de batería baja:** Número de lecturas con batería por debajo de un umbral que TÚ definas y justifiques (ej. SOC < 20% o battvolt < 48V), por día.

5. **Completitud de datos:** Días con datos incompletos. Calcula el porcentaje de lecturas recibidas frente a las esperadas. Esperadas = 86400 segundos/día ÷ 12.6 s/lectura ≈ 6,857 lecturas/día/inversor.

6. **Consulta JSON:** Al menos una consulta sobre los registros de contexto usando operadores nativos de PostgreSQL para JSONB: `->`, `->>`, `@>`, `jsonb_extract_path_text()`.

**4 consultas adicionales propuestas para SolarDB (evalúa e implementa):**

7. Tasa de rechazo y porcentaje de registros en cuarentena por regla de calidad.
8. Variables físicas con mayor frecuencia de valores nulos o fuera de rango.
9. Evolución temporal (por semana o mes) de la cantidad de registros enviados a cuarentena.
10. Comparación entre lecturas recibidas, aceptadas y rechazadas por inversor.

**Técnicas SQL obligatorias (entre todas las consultas deben usarse):**
- `INNER JOIN`.
- `LEFT JOIN` (u otro tipo de JOIN distinto).
- `SUM`, `AVG`, `COUNT` y otras funciones de agregación.
- `GROUP BY`.
- `HAVING`.
- Al menos una subconsulta (correlacionada o no).
- Filtros por rangos de fechas (`WHERE ts BETWEEN ... AND ...`).

**B. Vistas SQL (mínimo 2)**

Implementa al menos dos vistas útiles para el negocio o la operación de la microrred. Evalúa:
- Vista de resumen diario de generación y consumo por inversor.
- Vista de calidad de datos (registros aceptados vs. rechazados por día).
- Vista de lecturas aceptadas con información del inversor (JOIN con catálogos).
- Vista de registros pendientes en cuarentena.

Cada vista debe tener:
- Nombre.
- Código SQL.
- Para qué sirve.
- Quién la usaría y con qué frecuencia.

**C. Índices justificados (mínimo 3)**

Implementa al menos tres índices. Para cada uno documenta:
- Tabla y columnas.
- Consulta específica que lo aprovecha.
- Tipo de índice (B-tree, GIN, etc.).
- Por qué se crea.
- Evidencia con `EXPLAIN` o `EXPLAIN ANALYZE` que muestre el plan de ejecución ANTES y DESPUÉS del índice (o al menos el plan con el índice).

No afirmes que un índice mejora el rendimiento solo porque existe. Muestra el plan.

</TU MISIÓN — FASE 7>

<CONFIGURACIÓN DE GIT Y GITHUB — INSTRUCCIONES PARA ANTIGRAVITY>

Antes de empezar a crear archivos, necesitas configurar Git para que tus commits aparezcan con tu nombre y correo.

Solicita a Antigravity que ejecute los siguientes pasos en la terminal:

1. Verificar si Git está instalado:
```
git --version
```
Si no está instalado, instálalo desde https://git-scm.com/downloads

2. Configurar tu identidad para los commits:
```
git config --global user.name "Deysi Carolina Echavarria Soto"
git config --global user.email "TU_CORREO_REAL@ejemplo.com"
```
(Reemplaza el correo con tu correo real de GitHub o el que vayas a usar.)

3. Clonar el repositorio del equipo:
```
git clone https://github.com/desarrollosebas/Trabajofinal.git
cd Trabajofinal
```

4. Crear una rama de trabajo con tu nombre:
```
git checkout -b deysi/modelado-y-consultas
```

5. Después de crear cada archivo o grupo de archivos, hacer commit:
```
git add docs/05_modelo_conceptual.md
git commit -m "docs: agregar modelo conceptual con entidades y relaciones"
```

6. Cuando tengas varios commits listos, subir la rama a GitHub:
```
git push origin deysi/modelado-y-consultas
```

7. Luego el coordinador (Juan Sebastian) integrará tu rama al proyecto principal.

**IMPORTANTE:** Si Antigravity no puede hacer push (porque necesita autenticación de GitHub), te guiará para configurar tu cuenta de GitHub. Puedes usar:
- GitHub CLI (`gh auth login`).
- O un token de acceso personal (GitHub → Settings → Developer settings → Personal access tokens → Generate new token → Copiar y usar como contraseña al hacer push).

Haz commits pequeños e incrementales. No hagas un solo commit con todo.

</CONFIGURACIÓN DE GIT Y GITHUB>

<RESTRICCIONES OBLIGATORIAS>

1. No inventes datos, columnas, unidades de medida ni rangos físicos que no estén documentados en el contexto proporcionado.
2. No escribas SQL con sintaxis de MySQL. Todo debe ser PostgreSQL puro.
3. No afirmes que el diseño cumple 3FN sin demostrarlo paso a paso con dependencias funcionales.
4. No generes diagramas que no correspondan al modelo que implementas en SQL.
5. No uses tipos de datos incorrectos (ej. VARCHAR para voltajes, TEXT para timestamps).
6. No presentes consultas que no puedan ejecutarse sobre el esquema que defines.
7. Usa español para toda la documentación. Los nombres de tablas y columnas en los scripts SQL pueden estar en inglés o español, pero deben ser consistentes.
8. Cada archivo debe comenzar con un encabezado que incluya: proyecto, integrante responsable y fecha.
9. Verifica que los archivos se crearon correctamente antes de hacer commit.
10. Haz mínimo 5 commits separados con mensajes descriptivos en español.

</RESTRICCIONES OBLIGATORIAS>

<CRITERIOS DE ACEPTACIÓN>

Tu trabajo se considerará completo cuando:

- [ ] Existe `docs/05_modelo_conceptual.md` con diagrama Mermaid y justificación de formato ancho vs. largo.
- [ ] Existe `docs/06_modelo_logico.md` con diagrama Mermaid en crow's foot y todas las FK documentadas.
- [ ] Existe `docs/07_normalizacion_3FN.md` con demostración paso a paso de 1FN → 2FN → 3FN usando datos reales de OpenCEM.
- [ ] Existe `sql/12_consultas_negocio.sql` con mínimo 10 consultas SQL comentadas.
- [ ] Existe `docs/12_consultas_vistas_indices.md` con la documentación de cada consulta, vista e índice.
- [ ] Las 6 consultas obligatorias están implementadas.
- [ ] Se usan JOIN, GROUP BY, HAVING, subconsultas y filtros temporales.
- [ ] Hay al menos 2 vistas SQL documentadas.
- [ ] Hay al menos 3 índices con justificación y evidencia EXPLAIN.
- [ ] Git está configurado con tu nombre real.
- [ ] Hay mínimo 5 commits incrementales en tu rama.
- [ ] Todo el código es PostgreSQL válido.

</CRITERIOS DE ACEPTACIÓN>

<INICIO DEL TRABAJO>

Comienza así:

1. Configura Git con tu nombre y correo.
2. Clona el repositorio.
3. Crea tu rama de trabajo.
4. Empieza por `docs/05_modelo_conceptual.md` con la justificación de formato ancho vs. largo.
5. Avanza archivo por archivo, haciendo commit después de cada uno.
6. Al terminar cada fase, verifica que los archivos existen y son correctos.

No intentes hacer todo en una sola respuesta. Trabaja por etapas.

</INICIO DEL TRABAJO>
