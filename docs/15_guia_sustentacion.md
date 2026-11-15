# Guía de Sustentación — SolarDB

| | |
|---|---|
| **Proyecto** | Taller 6 — Bases de Datos I. SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL |
| **Institución / grupo** | Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II |
| **Docente** | Ramiro Grisales Montoya |
| **Integrante responsable** | Jose Miguel Sosa Cartagena (diccionario de datos, diseño físico, privacidad y documento final) |
| **Fecha** | 15 de noviembre de 2026 |
| **Dataset** | OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223) |
| **Documentos relacionados** | `08_diccionario_datos.md`, `09_diseno_fisico.md`, `14_seguridad_y_privacidad.md` |

## Cómo usar esta guía

1. Cada pregunta trae una **respuesta corta** (lo que se dice en voz alta, en pocas frases) y un **detalle técnico** por si el profesor profundiza.
2. Cada pregunta indica **quién responde** según el rol: **JS** = Juan Sebastian Raigosa Gil (arquitectura, migración, DDL), **JM** = Jose Miguel Sosa Cartagena (diccionario, diseño físico, privacidad), **DE** = Deysi Carolina Echavarria Soto (modelo conceptual y lógico, 3FN, consultas de negocio). Todos deben poder responder todas las preguntas.
3. Las cifras que aparecen son las **verificadas por el coordinador** en las Fases 0 y 1. Lo que depende de la implementación final está marcado como **«pendiente de confirmación»**: **no se debe afirmar en la sustentación hasta tener el dato real**.
4. Regla de oro: si no se sabe una cifra, se dice cómo se obtiene (la consulta o la tabla donde está), no se improvisa.

---

## A. Preguntas difíciles y cómo responderlas

### A.1 Sobre el dataset

**1. ¿Qué es OpenCEM y de dónde vienen los datos?** *(JS / JM)*
- **Respuesta corta:** OpenCEM v1.0.0 es un dataset público de una microrred híbrida (paneles solares, baterías de litio e inversores conectados a la red eléctrica) de un campus universitario en Shenzhen, China (CUHK-Shenzhen). Está publicado en Zenodo (DOI 10.5281/zenodo.21436223) por Bartels et al. (2026).
- **Detalle técnico:** son 2 subsistemas independientes. Cada uno tiene 26 paneles de 480 W, un banco de baterías LiFePO4 de ~200 Ah (51,2 V nominales), un inversor híbrido y conexión a la red (220/230 V, 50 Hz). El inversor 1 alimenta estaciones de cómputo de investigación (GPU/CPU) y el inversor 2, sistemas de climatización (HVAC). Se muestrea cada ~12,6 segundos por Modbus/RS485.

**2. ¿Qué representa exactamente una lectura?** *(JS / DE)*
- **Respuesta corta:** una fila de `analog_measurements` es una «fotografía» de un inversor en un instante: voltajes, corrientes, potencias, temperaturas y porcentajes medidos al mismo tiempo.
- **Detalle técnico:** se identifica por el inversor (1 o 2) y el instante (`read_ts`, un timestamp Unix fraccionario en UTC). La tabla original tiene 44 columnas; SolarDB usa 30 variables físicas (véase el diccionario de datos).

**3. ¿Cuántas lecturas hay y cómo verificaron que son reales?** *(JS)*
- **Respuesta corta:** hay **2.989.759** filas en `analog_measurements`. Se contaron directamente sobre la base SQLite descomprimida (4,13 GB) y las unidades se contrastaron con el `column_dictionary.json` de los autores.
- **Detalle técnico:** el repositorio incluye un manifiesto oficial de sumas de verificación SHA-256 del dataset, que permite comprobar que los archivos no se alteraron. Los conteos de las demás tablas (por ejemplo, `context` con 25.178 filas) también son verificados.

**4. ¿Qué problemas de calidad encontraron?** *(JS / DE)*
- **Respuesta corta:** cuatro hallazgos.

| Hallazgo | Filas | Interpretación |
|---|---:|---|
| Valores nulos por *timeouts* de Modbus | ≈ 58.000–60.000 (~2 %) | Dato faltante legítimo: se acepta como `NULL`. |
| `temper1 = -20,3 °C` | 38 | Error de sensor: se envía a cuarentena. |
| Potencia activa P mayor que la aparente S | 3.811 | Violación de la ley de potencia en CA: se envía a cuarentena. |
| Frecuencia = 0 Hz | 342.592 | **No es un error:** es modo isla legítimo. |

- **Detalle técnico:** lo importante es distinguir un **error** de un **dato inusual pero legítimo**. Rechazar los 342.592 registros de 0 Hz habría sido un error de diseño.

### A.2 Sobre el modelo

**5. ¿Por qué eligieron formato ancho/largo para las lecturas?** *(DE / JS)*
- **Respuesta corta:** el diseño propuesto usa **formato ancho** (una columna por variable), igual que el origen. **Pendiente de confirmación por el coordinador.**
- **Detalle técnico:**
  - *Ancho:* una fila por instante e inversor; las consultas que comparan varias variables (por ejemplo, P y S) son sencillas y no requieren uniones; es el formato del origen, lo que simplifica la migración y la verificación de conteos. Cada columna puede tener su propio tipo y su propio dominio con CHECK.
  - *Largo* (`lectura_id, variable_id, valor`): agregar una variable no cambia la estructura, pero multiplica las filas por ~30 (≈ 90 millones), y todos los valores comparten el mismo tipo, lo que impide usar dominios específicos por magnitud.
  - El formato ancho se apoya en que las variables son **fijas y conocidas** (30).

**6. ¿Cuáles son las entidades principales y cómo se relacionan?** *(DE)*
- **Respuesta corta:** un sitio tiene subsistemas; cada subsistema tiene un inversor; cada inversor genera lecturas. Las variables físicas y las unidades están en catálogos, y las lecturas se auditan por lote de carga.
- **Detalle técnico (cardinalidades propuestas, pendientes de confirmación):**
  - `dim_sitio` 1 — N `dim_subsistema`.
  - `dim_subsistema` 1 — 1 `dim_inversor`.
  - `dim_inversor` 1 — N `lectura_telemetria`.
  - `cat_unidad_medida` 1 — N `cat_variable_fisica`.
  - `lote_carga` 1 — N `lectura_telemetria`, `registro_contexto` y `registro_cuarentena`.
  - `regla_calidad` 1 — N `registro_cuarentena`.

**7. ¿Qué dependencias funcionales identificaron?** *(DE)*
- **Respuesta corta:** las principales son estas (propuestas, pendientes de confirmación por DE):
  - `inversor_id → subsistema_id`
  - `subsistema_id → sitio_id, carga_alimentada, num_paneles, potencia_panel_w, ...`
  - `variable_id → nombre_columna, unidad_id`
  - `(inversor_id, ts_lectura) → todas las variables medidas`
- **Detalle técnico:** de ahí que las características del subsistema vivan en `dim_subsistema` y no se repitan en cada lectura.

**8. ¿Cómo demuestran que el diseño está en 3FN?** *(DE)*
- **Respuesta corta:** una tabla está en 3FN si es 1FN (valores atómicos), 2FN (ningún atributo depende de solo una parte de la clave) y 3FN (ningún atributo depende de otro atributo que no sea clave).
- **Detalle técnico:** en `lectura_telemetria` cada medición depende de la lectura completa (inversor + instante). Los atributos del inversor, del subsistema y del sitio, que dependerían de `inversor_id` (dependencia transitiva), se sacaron a tablas aparte. **La demostración formal con la lista de dependencias es del modelo lógico de DE; se debe revisar su documento antes de sustentar.**

**9. ¿Hay alguna desnormalización intencional? ¿Por qué?** *(DE / JM)*
- **Respuesta corta:** posiblemente dos decisiones, **pendientes de confirmación**:
  1. El **formato ancho** de la tabla de lecturas (pregunta 5). No viola la 1FN porque los valores son atómicos.
  2. La columna `fuente_contexto` de `registro_contexto`, que **repite** el dato `valor->>'source'` del JSON. Es un dato derivado guardado de forma explícita para filtrar rápido con un índice B-tree y facilitar las consultas.
- **Detalle técnico:** toda desnormalización debe justificarse por rendimiento o simplicidad y declararse. Si ninguna se aplicó realmente, la respuesta honesta es «no hay desnormalización más allá del formato ancho».

### A.3 Sobre SolarDB (línea de profundización)

**10. ¿Qué es un `CREATE DOMAIN` y para qué lo usan?** *(JS / JM)*
- **Respuesta corta:** es un tipo de dato personalizado, basado en un tipo existente, con restricciones incluidas. Lo usamos para definir **una vez** las reglas de una magnitud física y reutilizarlas en muchas columnas.
- **Detalle técnico:** por ejemplo, `dom_voltaje` (tipo `DOUBLE PRECISION` con `CHECK (VALUE >= 0)`) se aplica a `battvolt`, `pv1volt`, `outvolta`, `linevolta`, `busvoltp` y `busvoltn`. Si la regla cambia, se modifica en un solo lugar.

**11. ¿Cuál es la diferencia entre un CHECK a nivel de columna y un DOMAIN?** *(JM)*
- **Respuesta corta:** el CHECK de columna vale solo para esa columna de esa tabla. El dominio es un objeto reutilizable que lleva su regla a todas las columnas que lo usen.
- **Detalle técnico:** ventajas del dominio: no se repite la regla (menos errores), se cambia con `ALTER DOMAIN` y documenta el significado de la magnitud. Ventaja del CHECK de columna: puede comparar **varias columnas** de la misma fila (por ejemplo, `outw_a <= outva_a`), cosa que un dominio no puede hacer porque solo ve su propio valor. Por eso la regla P ≤ S no es un dominio.

**12. ¿Qué es una tabla de staging y por qué se necesita?** *(JS)*
- **Respuesta corta:** es una tabla de paso, sin restricciones, donde se cargan los datos crudos antes de pasar a las tablas definitivas. Se necesita porque, si se insertara directo en la tabla con restricciones, **una sola fila inválida detendría o rechazaría la carga** sin dejar rastro de cuál fue ni por qué.
- **Detalle técnico:** `staging.staging_telemetria` guarda todo como `DOUBLE PRECISION` sin dominios. Ahí se valida cada fila y se clasifica (`estado_validacion`: `PENDIENTE`, `VALIDA`, `RECHAZADA`).

**13. ¿Qué es una tabla de cuarentena?** *(JS / DE)*
- **Respuesta corta:** es el lugar donde se guardan las filas rechazadas, con su valor original, la regla que incumplieron y su estado de revisión, para que no se pierdan ni se mezclen con los datos válidos.
- **Detalle técnico:** `calidad.registro_cuarentena` conserva la fila completa en `JSONB`, el lote, la regla y el estado (`PENDIENTE`, `CORREGIDO`, `DESCARTADO`, `REPROCESADO`).

**14. ¿Cómo llega un registro a cuarentena?** *(JS)*
- **Respuesta corta:** **PostgreSQL no envía automáticamente a cuarentena** las filas que rechaza. Es el **proceso de staging el que las clasifica ANTES de intentar insertar**: las que incumplen una regla se copian a cuarentena y las válidas pasan a la tabla definitiva.
- **Detalle técnico:** si se intentara un `INSERT` directo con un valor inválido, PostgreSQL lanzaría un error y no guardaría la fila en ninguna parte. La cuarentena es una **decisión de diseño** del proceso de carga.
- **Cuidado en la sustentación:** el profesor puede sugerir que el motor lo hace solo. Hay que corregirlo con respeto y con este argumento.

**15. ¿Qué pasa si intento insertar un voltaje de -500 V?** *(JM / JS)*
- **Respuesta corta:** depende del camino.
  1. **Directo en `lectura_telemetria`:** PostgreSQL lo rechaza con un error de restricción (`check_violation`, código `23514`), porque `dom_voltaje` exige `VALUE >= 0`. No se guarda nada.
  2. **Por el flujo de carga (staging):** la fila entra a staging, la regla de calidad la marca como inválida y se registra en cuarentena con su valor original.
- **Detalle técnico:** el mensaje de PostgreSQL sigue el patrón `value for domain ... violates check constraint ...`. Esto es lo que se muestra en la demostración (paso 8 de la sección B).

**16. ¿Pueden reprocesar un registro de cuarentena?** *(JS)*
- **Respuesta corta:** sí. Como la cuarentena guarda la fila original completa y un campo `estado`, se puede corregir el dato (o la regla), volver a insertar en la tabla definitiva y marcar el registro como `REPROCESADO`.
- **Detalle técnico:** el flujo es: revisar los `PENDIENTE`, decidir (corregir o descartar), reinsertar solo los corregidos y actualizar `estado` y `fecha_resolucion`. Quedan trazados por `lote_id`. **El procedimiento exacto es del coordinador (pendiente de confirmación).**

### A.4 Sobre la migración

**17. ¿Cómo cargaron un millón de lecturas?** *(JS)*
- **Respuesta corta:** **pendiente de confirmación por el coordinador.** El esquema recomendado es: cargar los datos crudos del SQLite a `staging` en bloque (por ejemplo, con `COPY`), validarlos allí y luego insertarlos en `solardb` con un `INSERT ... SELECT` por lotes, registrando cada lote en `calidad.lote_carga`.
- **Detalle técnico:** la carga masiva es mucho más rápida que insertar fila por fila. Para acelerarla se recomienda crear los índices secundarios después de cargar y ejecutar `ANALYZE` al final (véase `09_diseno_fisico.md`). **Debe explicarse el método real que usó JS, no este.**

**18. ¿Cuánto tiempo tardó la migración?** *(JS)*
- **Respuesta corta:** **dato por medir.** No hay una cifra confirmada. Se obtiene de `calidad.lote_carga` (`fecha_fin - fecha_inicio`).
- **Detalle técnico:** si el equipo no registra el tiempo, se puede medir ejecutando la migración con `\timing` activado en `psql` (o con el tiempo de ejecución que muestra DBeaver).

**19. ¿Qué pasa si ejecutan la migración dos veces?** *(JS / JM)*
- **Respuesta corta:** si se diseña bien, **no se duplican las lecturas**: la restricción `UNIQUE (inversor_id, ts_lectura)` lo impide, y la inserción usa `ON CONFLICT DO NOTHING` (o se verifica antes con `lote_carga`). **Pendiente de confirmación:** que no existan duplicados en el origen y que el script lo implemente así.
- **Detalle técnico:** una migración con esta propiedad se llama **idempotente**: ejecutarla varias veces deja el mismo resultado que ejecutarla una.

**20. ¿Cuántos registros fueron rechazados y por qué?** *(JS)*
- **Respuesta corta:** el **dato real sale de `calidad.lote_carga`** (`filas_rechazadas`) y de `registro_cuarentena`. Con las dos reglas diagnosticadas, el máximo esperado sería de **38 + 3.811 = 3.849** filas, **sin contar** las demás reglas que se definan.
- **Detalle técnico:** una misma fila podría incumplir ambas reglas, por lo que el total de filas únicas podría ser **menor** a 3.849. Los ~58.000 a 60.000 nulos **no** se rechazan (son datos faltantes legítimos) y los 342.592 registros de 0 Hz **tampoco** (modo isla). Para el desglose por regla:
```sql
SELECT r.codigo_regla, count(*) AS filas
FROM calidad.registro_cuarentena q
JOIN calidad.regla_calidad r USING (regla_id)
GROUP BY r.codigo_regla
ORDER BY filas DESC;
```

### A.5 Sobre las consultas

**21. ¿Cómo calculan la energía diaria si el muestreo no es uniforme?** *(DE)*
- **Respuesta corta:** la energía es la **integral de la potencia en el tiempo**. Como las lecturas no están separadas por un intervalo exacto (~12,6 s en promedio, con huecos por *timeouts*), no se multiplica por un intervalo fijo: se usa el **tiempo real entre lecturas consecutivas** (método del trapecio).
- **Detalle técnico:** energía = suma de `(P_anterior + P_actual) / 2 × Δt`. Se convierte de W·s a kWh dividiendo por 3.600.000. Los huecos largos se descartan para no inventar energía donde no hubo medición. Ejemplo de referencia (**la consulta final es de DE; el umbral de huecos está pendiente de confirmación**):
```sql
WITH muestras AS (
  SELECT ts_lectura, outsumw,
         LAG(outsumw) OVER w AS w_ant,
         EXTRACT(EPOCH FROM ts_lectura - LAG(ts_lectura) OVER w) AS dt_s
  FROM solardb.lectura_telemetria
  WHERE inversor_id = 1
  WINDOW w AS (PARTITION BY inversor_id ORDER BY ts_lectura)
)
SELECT date_trunc('day', ts_lectura) AS dia,
       round((SUM((outsumw + w_ant) / 2.0 * dt_s) / 3600000.0)::numeric, 3) AS kwh
FROM muestras
WHERE dt_s IS NOT NULL AND outsumw IS NOT NULL AND w_ant IS NOT NULL
  AND dt_s <= 60            -- umbral de hueco: a confirmar
GROUP BY 1
ORDER BY 1;
```
- Notas: `outsumw` es la potencia activa total a la microrred (W). El día de `date_trunc` depende de la zona horaria de la sesión; hay que acordar si se usa la del sitio (Shenzhen) o UTC. El resultado se convierte a `NUMERIC` para presentar totales estables (véase la justificación en `08_diccionario_datos.md`).

**22. ¿Por qué usaron ese umbral de batería baja?** *(DE)*
- **Respuesta corta:** **pendiente de confirmación por DE**: el umbral exacto no está en el contexto de este documento. La respuesta debe apoyarse en datos, no en una cifra «porque sí».
- **Detalle técnico:** la variable es `battsoc` (estado de carga, en %), con rango observado de **6 a 100**. Un umbral razonable se justifica con la distribución real de los datos (por ejemplo, con percentiles) o con las recomendaciones del fabricante de la batería. Se debe poder decir: qué porcentaje de lecturas cae bajo el umbral y por qué ese corte es útil para el negocio. Para obtener esa cifra:
```sql
SELECT count(*) FILTER (WHERE battsoc < <umbral>) AS bajo_umbral,
       count(battsoc) AS con_dato
FROM solardb.lectura_telemetria;
```

**23. ¿Qué muestra la consulta JSON?** *(DE / JM)*
- **Respuesta corta:** **pendiente de confirmación por DE** (se debe describir la consulta real). En general, una consulta JSON sobre `registro_contexto` filtra o agrupa los eventos de contexto (estaciones de trabajo, calendario, eventos climáticos) por el contenido del campo `valor`, para relacionarlos con la telemetría.
- **Detalle técnico:** se apoya en `JSONB` y en el índice GIN (operador `@>`). Ejemplo general con una fuente real del dataset:
```sql
-- Cantidad de eventos de contexto por fuente (el total debe dar 25.178)
SELECT fuente_contexto, count(*)
FROM solardb.registro_contexto
GROUP BY fuente_contexto
ORDER BY count(*) DESC;
```
- **Cuidado con la privacidad:** si la consulta toca `wsl_bash_history` o `windows_event_log`, usar la vista `solardb.v_contexto_sin_personales` y **no mostrar contenido real en pantalla** (véase `14_seguridad_y_privacidad.md`).

### A.6 Preguntas adicionales sobre diccionario de datos, diseño físico y privacidad (JM)

**24. ¿Por qué `DOUBLE PRECISION` y no `NUMERIC` en la telemetría?** *(JM)*
- **Respuesta corta:** porque son mediciones de sensor con incertidumbre propia (resolución de una décima), el origen ya es un flotante de 8 bytes (no se pierde información) y las agregaciones sobre casi 3 millones de filas son más rápidas. `NUMERIC` se reserva para datos exactos (especificaciones nominales y totales de energía).

**25. ¿Por qué `timestamptz` y no `timestamp`?** *(JM)*
- **Respuesta corta:** los datos vienen en UTC (Unix) de un sitio en Shenzhen y se analizan desde otra zona horaria. `timestamptz` guarda un **instante absoluto** y lo muestra en la zona del cliente; `timestamp` guarda un valor literal sin zona y puede interpretarse mal.

**26. ¿Por qué `JSONB` y no `JSON`?** *(JM)*
- **Respuesta corta:** `JSONB` está ya procesado (consultas más rápidas), permite el índice GIN y los operadores de contención (`@>`, `?`). `JSON` guarda el texto tal cual y lo reanaliza en cada consulta.

**27. ¿Por qué `BIGINT` en `lectura_id`, si 3 millones caben en un `INTEGER`?** *(JM)*
- **Respuesta corta:** es cierto que caben (usan ~0,14 % del rango). Se eligió `BIGINT` por crecimiento: la tabla recibe datos continuamente y cambiar el tipo de una llave primaria más adelante es costoso. El sobrecosto es de 4 bytes por fila (≈ 12 MB en total).

**28. ¿Por qué no particionaron la tabla de lecturas?** *(JM)*
- **Respuesta corta:** con ~3 millones de filas (~0,7 GiB), un índice B-tree compuesto resuelve los filtros por fecha e inversor. El particionamiento añade complejidad (la PK debe incluir la clave de partición) y se documenta como trabajo futuro.

**29. ¿Qué datos personales tiene el dataset y cómo los protegieron?** *(JM)*
- **Respuesta corta:** los registros `wsl_bash_history` (204) y `windows_event_log` (6.271) **pueden** contener usuarios, rutas e IP. Se aplica **minimización**: anonimización, enmascaramiento de IP, vistas que ocultan el contenido, roles con permisos mínimos y un repositorio sin datos crudos ni credenciales. La clasificación es **provisional** hasta inspeccionar el contenido real. Normas: Ley 1581 de 2012 (arts. 3, 4, 5, 6, 8, 10, 17 y 26) y Decreto 1377 de 2013.

**30. ¿Por qué no hay contraseñas en el repositorio?** *(JM)*
- **Respuesta corta:** porque cualquiera con acceso al repositorio las vería, y quedarían en el historial de Git aunque se borraran. Las credenciales se piden al conectar y los archivos sensibles están en `.gitignore`.

---

## B. Guion para la demostración en vivo (DBeaver)

**Antes de la demostración (preparación):**
- Ensayar el guion completo al menos una vez, **con la migración ya ejecutada** en una base de prueba, y anotar el tiempo.
- Si la migración tarda mucho, no ejecutarla en vivo: mostrar la ya hecha, o ejecutarla sobre un subconjunto.
- Tener a mano los scripts DDL **en orden** y el nombre exacto de cada uno (**lo define el coordinador; no están confirmados aquí**).
- Tener capturas de pantalla de respaldo por si falla la conexión.
- **Nunca mostrar contraseñas en pantalla** (la ventana de conexión de DBeaver debe quedar cerrada o con la clave oculta) ni datos reales de `wsl_bash_history` o `windows_event_log`.

| Paso | Qué se hace | Qué se muestra / qué se dice |
|---|---|---|
| **1. Crear la base de datos desde cero** | En DBeaver, conectarse al servidor y ejecutar:<br>`CREATE DATABASE solardb_demo;`<br>Abrir una conexión nueva a esa base. | Una base vacía: «partimos desde cero, sin datos ni objetos». Se muestra el árbol de DBeaver sin tablas. |
| **2. Ejecutar los scripts DDL en orden** | Abrir y ejecutar cada script del coordinador en el orden acordado: esquemas, dominios, catálogos, tablas de hechos, tablas de calidad, tablas de staging, índices y vistas (**nombres de archivo pendientes**). | Se explica por qué ese orden: los dominios y esquemas deben existir antes de las tablas que los usan, y las tablas referenciadas antes de las que tienen llaves foráneas. Se muestran los tres esquemas: `solardb`, `staging`, `calidad`. |
| **3. Cargar catálogos** | Ejecutar el script de carga de catálogos (**pendiente de confirmación**).<br>Verificar:<br>`SELECT * FROM solardb.dim_inversor;`<br>`SELECT count(*) FROM solardb.cat_variable_fisica;` | Se ven los 2 inversores (1 y 2) y las 30 variables con sus unidades (V, A, W, VA, Hz, °C, %, kΩ). |
| **4. Ejecutar la migración de datos** | Ejecutar el script de migración del coordinador (**pendiente**) o mostrar el resultado de una ejecución previa.<br>Consultar:<br>`SELECT * FROM calidad.lote_carga;` | Cuántas filas se leyeron, se aceptaron y se rechazaron, y cuánto tardó. Se explica el flujo: staging, validación y destino. |
| **5. Mostrar que hay más de un millón de lecturas** | `SELECT count(*) FROM solardb.lectura_telemetria;` | Resultado esperado: **más de 1.000.000** (el origen tiene 2.989.759, menos las filas rechazadas; **cifra final pendiente**). |
| **6. Ejecutar una consulta de negocio** | Ejecutar la consulta de energía diaria de DE (referencia: pregunta 21). | Se explica el cálculo con tiempos reales entre lecturas, no con un intervalo fijo. |
| **7. Insertar un dato válido y mostrarlo** | Ver la nota (a) debajo de la tabla. | Se muestra la fila insertada y se explica que cumple los dominios. |
| **8. Intentar insertar un dato inválido y mostrar el rechazo** | Ver la nota (b) debajo de la tabla. | El error de PostgreSQL (`check_violation`, código 23514) indica que el valor viola el dominio `dom_voltaje`. No queda nada guardado. |
| **9. Mostrar la tabla de cuarentena** | `SELECT r.codigo_regla, q.estado, count(*)`<br>`FROM calidad.registro_cuarentena q`<br>`JOIN calidad.regla_calidad r USING (regla_id)`<br>`GROUP BY 1, 2;` | Los registros rechazados por regla y estado (por ejemplo, `temper1 = -20,3` y P > S). Se aclara que **la clasificación la hizo el proceso de staging**, no el motor automáticamente (pregunta 14). |
| **10. Mostrar las vistas** | Listar las vistas del esquema `solardb` (las de negocio del equipo y `v_contexto_sin_personales`).<br>`SELECT * FROM solardb.v_contexto_sin_personales LIMIT 10;` | Las vistas de negocio simplifican consultas. La vista de contexto **oculta el contenido** de los registros con datos personales (Ley 1581). |
| **11. Mostrar un `EXPLAIN ANALYZE` con índice** | Ver la nota (c) debajo de la tabla. | En el plan, `Index Scan` o `Bitmap Index Scan` sobre `(inversor_id, ts_lectura)`: el índice se usa y se ve el tiempo de ejecución. |

**(a) Paso 7: inserción válida.** Se usan valores de demostración dentro de los rangos observados (por ejemplo, el máximo de `battvolt` observado es 57,60 V y el de `battsoc`, 100 %). Se limpia la fila al terminar para no alterar los conteos:
```sql
INSERT INTO solardb.lectura_telemetria
  (inversor_id, ts_lectura, lote_id, battvolt, battsoc)
VALUES
  (1, now(), (SELECT max(lote_id) FROM calidad.lote_carga), 57.60, 100)
RETURNING *;

-- Limpiar la fila de demostración
DELETE FROM solardb.lectura_telemetria
WHERE inversor_id = 1 AND battvolt = 57.60 AND battsoc = 100
  AND ts_lectura >= now() - interval '10 minutes';
```
> Ajustar si el script del coordinador exige otras columnas obligatorias. Se recomienda ejecutar la limpieza **con cuidado** y comprobar con un `SELECT` antes de borrar.

**(b) Paso 8: inserción inválida (la del profesor, -500 V).**
```sql
INSERT INTO solardb.lectura_telemetria
  (inversor_id, ts_lectura, lote_id, battvolt)
VALUES
  (1, now(), (SELECT max(lote_id) FROM calidad.lote_carga), -500);
```
Resultado esperado: un error que indica que el valor viola el `CHECK` del dominio `dom_voltaje`. Si el equipo quiere mostrar también la cuarentena, la misma fila se inserta en `staging.staging_telemetria` y se ejecuta el procedimiento de clasificación del coordinador (**pendiente de confirmación**).

**(c) Paso 11: plan de ejecución.** Primero se consulta un rango real de fechas:
```sql
SELECT min(ts_lectura), max(ts_lectura) FROM solardb.lectura_telemetria;

EXPLAIN (ANALYZE, BUFFERS)
SELECT ts_lectura, battvolt, battsoc
FROM solardb.lectura_telemetria
WHERE inversor_id = 1
  AND ts_lectura >= '<fecha_inicio_real>'
  AND ts_lectura <  '<fecha_fin_real>';
```
Se sustituyen las fechas por valores reales obtenidos de la primera consulta. Si el plan muestra `Seq Scan`, puede ser correcto cuando el rango abarca gran parte de la tabla; en ese caso se elige un rango más estrecho.

---

## C. Estructura del documento PDF final

**Nombre del archivo:** `BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`

> Propuesta de tabla de contenidos, **pendiente de confirmación por el coordinador**. El orden sigue el de los documentos del repositorio; los responsables son los del reparto del Taller 6.

**Portada**
- Título: «SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL».
- Taller 6, Bases de Datos I, grupo 811, semestre 2026-II.
- Institución Universitaria Pascual Bravo.
- Docente: Ramiro Grisales Montoya.
- Integrantes: Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto.
- Fecha de entrega.

**Tabla de contenidos**

| N.º | Sección | Contenido | Responsable |
|---|---|---|---|
| — | Resumen ejecutivo | Problema, solución y resultados en una página | Todos |
| 1 | Introducción y objetivos | Contexto, justificación, objetivo general y específicos | Todos |
| 2 | Dataset OpenCEM | Descripción, sistema físico, tablas originales y conteos, cita obligatoria, verificación (SHA-256) | JS |
| 3 | Diagnóstico de calidad | Nulos, `temper1 = -20,3 °C`, P > S, frecuencia 0 Hz y su tratamiento | JS / DE |
| 4 | Modelado conceptual | Entidades, atributos, relaciones y diagrama entidad-relación | DE |
| 5 | Modelado lógico y normalización | Dependencias funcionales, 3FN, decisiones de desnormalización | DE |
| 6 | Arquitectura SolarDB | Esquemas, dominios, staging, cuarentena y reglas de calidad | JS |
| 7 | Diccionario de datos | Tablas y columnas (resumen; completo en anexo) y justificación de tipos de datos | JM |
| 8 | Diseño físico | Esquemas, tablespaces, particionamiento, índices y almacenamiento | JM |
| 9 | Migración de datos | Flujo staging a destino, lotes, idempotencia, resultados y rechazos | JS |
| 10 | Consultas de negocio | Energía diaria, batería baja, consulta JSON, vistas y su análisis | DE |
| 11 | Rendimiento | `EXPLAIN ANALYZE` e impacto de los índices | JM / DE |
| 12 | Seguridad y privacidad | Ley 1581 de 2012: datos, roles, principios, medidas y aviso de privacidad | JM |
| 13 | Protección del repositorio | Qué no debe subirse; `.gitignore` | JM |
| 14 | Resultados y análisis | Cifras finales de la migración y de la cuarentena | JS |
| 15 | Conclusiones y trabajo futuro | Aprendizajes, limitaciones y mejoras (por ejemplo, particionamiento) | Todos |
| 16 | Referencias | Cita de OpenCEM (Bartels et al., 2026) y normas (Ley 1581 de 2012, Decreto 1377 de 2013, Ley 1266 de 2008), en el formato exigido por el docente | JM |
| A | Anexo A | Diccionario de datos completo | JM |
| B | Anexo B | Scripts DDL y de migración (**sin credenciales**) | JS |
| C | Anexo C | Guion de la demostración | JM |
| D | Anexo D | Enlace al repositorio: https://github.com/desarrollosebas/Trabajofinal | Todos |

**Recomendaciones para el PDF:**
- Todas las cifras deben provenir de datos **medidos** (por ejemplo, de `lote_carga`), no de estimaciones.
- Numerar las figuras y las tablas, y citarlas en el texto.
- No incluir datos reales de los registros de contexto con posibles datos personales.
- Comprobar que el PDF no contenga contraseñas, tokens ni cadenas de conexión.
- Confirmar con el docente el formato de citas y la extensión esperada.

---

## D. Lista de verificación antes de sustentar

- [ ] Los tres integrantes pueden explicar las preguntas 10 a 16 (línea de profundización) sin leer.
- [ ] Se conocen las cifras reales: filas migradas, filas rechazadas por regla y tiempo de la migración.
- [ ] Se ensayó la demostración completa con la base de datos ya cargada.
- [ ] Se completaron los datos **pendientes de confirmación** de los documentos 08, 09, 14 y esta guía.
- [ ] El repositorio no contiene contraseñas, tokens, cadenas de conexión ni datos crudos.
- [ ] El PDF final está generado con el nombre acordado.
- [ ] Hay capturas de pantalla de respaldo de cada paso de la demostración.

Este documento no contiene contraseñas, tokens ni cadenas de conexión.
