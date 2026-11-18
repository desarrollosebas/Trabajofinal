**INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO**
**Bases de Datos I — Grupo 811 — Semestre 2026-II**
**Docente:** Ramiro Grisales Montoya
**Proyecto:** Taller 6 (Fase Final) — SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL

| Campo | Detalle |
|---|---|
| **Documento** | `docs/15_guia_sustentacion.md` |
| **Título** | Guía de sustentación oral con métricas reales post-migración |
| **Versión** | Ronda 2 — actualizada con datos verificados |
| **Autor** | Jose Miguel Sosa Cartagena |
| **Equipo** | Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto |
| **Motor / herramienta** | PostgreSQL 18 / DBeaver 26.2.2 |
| **Repositorio** | https://github.com/desarrollosebas/Trabajofinal |
| **Fecha** | 17 de noviembre de 2026 |

---

# 15. Guía de sustentación

## 15.1 Cómo usar esta guía

1. Memoriza la **hoja de cifras** (15.2) y el **discurso de apertura** (15.3).
2. Practica el **guion de demostración en DBeaver** (15.5) al menos dos veces con la conexión real.
3. Estudia las **32 preguntas difíciles** (15.4). No memorices las respuestas palabra por palabra; entiende el argumento de cada una.
4. Revisa la **estructura del PDF final** (15.6) para saber en qué capítulo está cada tema.

Regla de oro: si no sabes algo, dilo con honestidad y explica cómo lo verificarías. Inventar una respuesta es peor que reconocer un límite.

## 15.2 Hoja de cifras (memorizar)

| Indicador | Valor |
|---|---|
| Filas leídas de telemetría (SQLite, tabla `analog_measurements`) | **2,989,759** |
| Aceptadas en producción (`solardb.lectura_telemetria`) | **2,965,337** (99.18%) |
| En cuarentena (`calidad.registro_cuarentena`) | **24,422** (0.82%) |
| Cuadratura | 2,965,337 + 24,422 = **2,989,759** exacta |
| Meta del profesor | ≥ 1,000,000 lecturas → superada (**298.9%**) |
| Contexto operativo (`solardb.registro_contexto`) | **25,178** (100%, 0 rechazadas) |
| Cuarentena `R_P_MAYOR_S` | **24,375** |
| Cuarentena `R_TEMP1_IMPOSIBLE` | **38** (temper1 = -20.3 °C) |
| Cuarentena `R_LINEPOWERVA_NEG` | **8** |
| Cuarentena `R_LINECURRA_NEG` | **1** |
| Inversor 1 (Cómputo) | **1,594,461** filas (53.77%), ~1 año |
| Inversor 2 (HVAC) | **1,370,876** filas (46.23%), ~11 meses |
| Cadencia mediana de muestreo | **12.58 s** |
| Tamaño `lectura_telemetria` | **3,824 MB** (3,440 datos + 384 índices) |
| Tamaño `registro_cuarentena` | **34 MB** |
| Tamaño `registro_contexto` | **26 MB** |
| Total SolarDB | **~3.88 GB** |
| Esquemas | 3: `solardb`, `staging`, `calidad` |
| Dominios personalizados | **12** |
| Columnas de `lectura_telemetria` | **46** (38 de medición + 4 JSONB reservadas) |
| Reglas de calidad activas | **6** |
| Lotes auditados | 2: lote 4 (telemetría) y lote 6 (contexto) |
| Registros con datos personales críticos | **204** (`wsl_bash_history`) |
| Dataset | OpenCEM v1.0.0 (DOI 10.5281/zenodo.21436223) |

Truco de memoria: **2.99 M leídas = 2.97 M buenas + 24 mil aisladas; casi todo (24,375) es una sola regla: P > S.**

## 15.3 Discurso de apertura (≈ 90 segundos)

> "SolarDB es una base de datos en PostgreSQL 18 para la telemetría de una microrred híbrida, a partir del dataset OpenCEM. Nuestra línea de profundización es la **integridad y calidad de datos con restricciones, dominios y tablas de cuarentena**.
>
> Leímos **2,989,759** lecturas de dos inversores. **2,965,337** (99.18%) pasaron todas las reglas y están en producción; **24,422** (0.82%) violaban alguna regla física y se aislaron en una tabla de cuarentena, sin perderlas: se guardan completas en JSONB con estado PENDIENTE. La suma cuadra exactamente.
>
> Usamos **tres esquemas**: `staging` para la carga temporal, `calidad` para reglas, lotes y cuarentena, y `solardb` para producción. Declaramos **12 dominios** con `CREATE DOMAIN` para que cada magnitud física, como voltaje, porcentaje o frecuencia, lleve su restricción dentro del tipo.
>
> Además migramos **25,178** registros de contexto operativo y marcamos con `contiene_datos_personales` los que pueden tener datos personales, en cumplimiento de la Ley 1581 de 2012. Todo ocupa unos **3.88 GB**."

## 15.4 Preguntas difíciles del profesor y respuestas

### A. Arquitectura y diseño

**1. ¿Por qué usar tres esquemas y no todo en `public`?**
Cada esquema tiene una responsabilidad distinta: `staging` recibe datos crudos y desechables, `calidad` guarda reglas, auditoría de lotes y cuarentena, y `solardb` contiene solo datos que ya pasaron las reglas. Esto permite dar permisos distintos por esquema (por ejemplo, que un analista lea `solardb` pero no `staging`), evita mezclar datos validados con no validados y hace que el nombre de cada objeto indique su confiabilidad.

**2. ¿Por qué dominios (`CREATE DOMAIN`) y no simples CHECK en cada columna?**
Porque una regla física se define una vez y se reutiliza. `dom_voltaje` (`VALUE >= 0`) se aplica a seis columnas (battvolt, pv1volt, outvolta, linevolta, busvoltp, busvoltn). Si la regla cambia, se modifica en un solo lugar en vez de en seis CHECK repetidos. Además, el dominio documenta la intención ("esto es un voltaje") y evita errores de copiar y pegar. Un CHECK por columna funciona, pero escala mal y es fácil que quede inconsistente.

**3. ¿Por qué 12 dominios? ¿Por qué algunos no tienen CHECK?**
Se separan por semántica física. Los dominios con signo no pueden restringirse a ≥ 0: `dom_corriente` (battcurr, positiva al cargar y negativa al descargar la batería), `dom_potencia_activa`, `dom_potencia_reactiva` (la reactiva puede ser inductiva o capacitiva) y `dom_temperatura`. Los demás tienen CHECK: ≥ 0 para voltaje, corriente no negativa, potencia aparente, frecuencia y resistencia de aislamiento; 0 a 100 para porcentaje; 0 a 110 para porcentaje de carga (permite sobrecarga transitoria). Son 8 con CHECK y 4 sin CHECK.

**4. ¿Por qué `dom_corriente_no_neg` y `dom_corriente` son dos dominios distintos?**
Porque la corriente de batería es bidireccional, pero las corrientes de red, del inversor y de salida del cargador que listamos se definen como magnitudes no negativas en este sensor. Mezclarlas en un solo dominio obligaría a eliminar el CHECK y perder protección en siete columnas.

**5. ¿Por qué `lectura_id` es BIGINT identity si hay una clave natural `(inversor_id, ts_lectura)`?**
La clave natural es única y se declara con UNIQUE para impedir duplicados, pero usarla como PK obligaría a que cualquier tabla que la referencie repita dos columnas. Una clave sustituta `BIGINT GENERATED ALWAYS AS IDENTITY` es compacta y estable. Elegimos BIGINT en lugar de INTEGER aunque hoy hay 2,965,337 filas (cabrían en INTEGER) porque telemetría crece continuamente con cadencia de ~12.58 s; el costo adicional es de 4 bytes por fila, del orden de 12 MB en total, un precio bajo frente a una migración de tipo futura.

**6. ¿Por qué DOUBLE PRECISION y no NUMERIC en voltajes, corrientes y temperaturas?**
NUMERIC es de precisión exacta y se justifica en dinero o cuando se exige exactitud decimal. Una medida de sensor ya es una aproximación con error de medición; el exceso de precisión de NUMERIC no aporta exactitud real, ocupa más espacio y es más lento en cálculos. DOUBLE PRECISION (8 bytes, punto flotante) es el tipo natural para magnitudes físicas medidas. Para potencias en vatios enteros usamos INTEGER, y para porcentajes SMALLINT.

**7. ¿Por qué TIMESTAMP WITH TIME ZONE y no sin zona horaria?**
Los datos vienen de un sitio en Shenzhen y el equipo trabaja en otra zona. TIMESTAMPTZ almacena el instante en UTC y lo presenta según la zona de la sesión, lo que evita ambigüedades al comparar o cambiar de zona. Ocupa lo mismo que TIMESTAMP (8 bytes), así que no hay penalización de espacio.

**8. ¿Por qué JSONB y no JSON?**
JSONB se guarda en formato binario descompuesto, admite índices GIN (usamos `idx_contexto_valor_gin`), permite operadores de contención y consulta eficiente, y no conserva claves duplicadas. JSON guarda el texto tal cual y obliga a reanalizarlo en cada consulta. Perder el orden de las claves no importa para nuestro caso.

**9. ¿Por qué `lectura_telemetria` tiene 46 columnas? ¿Eso respeta la normalización?**
Las 38 variables de medición describen un mismo hecho: una lectura de un inversor en un instante. Todas dependen de `(inversor_id, ts_lectura)` y de nada más, por lo que no hay dependencias parciales ni transitivas entre ellas. Una alternativa EAV (una fila por variable) multiplicaría las filas por unas 38 y complicaría las consultas. Las 4 columnas JSONB (battreserve, pvreserve, otherreserve, grid_reserve) guardan campos reservados sin esquema fijo.

**10. ¿Para qué sirven los 6 catálogos dimensionales?**
Evitan texto repetido y garantizan integridad referencial: `dim_sitio` (1 fila), `dim_subsistema` (2), `dim_inversor` (2), `cat_variable_fisica` (38+), `cat_unidad_medida` (V, A, W, VA, Hz, °C, %, kΩ) y `cat_tipo_contexto` (7 fuentes). La tabla de hechos referencia el inversor por clave foránea.

### B. Calidad de datos y cuarentena

**11. ¿Por qué la temperatura de -20.3 °C fue a cuarentena y no se bloqueó con un CHECK?**
Porque no es un valor imposible por definición matemática, sino por contexto físico: en Celsius hay temperaturas negativas válidas, así que `dom_temperatura` no puede prohibirlas. Es imposible *en Shenzhen* (mínima histórica cercana a 0 °C) y apunta a falla de sensor o circuito abierto. Eso es una regla de calidad (`R_TEMP1_IMPOSIBLE`, 38 filas), no una restricción de tipo. Un CHECK habría abortado la carga completa; la cuarentena aísla la fila y conserva la evidencia.

**12. ¿Por qué hay 24,375 filas en cuarentena por P > S?**
La potencia activa nunca puede superar a la aparente (P ≤ S = |V|·|I| en corriente alterna). Como son 24,375 de 24,422 (99.81% de la cuarentena, cálculo propio), no es ruido aleatorio sino un patrón sistemático: el desfase temporal del muestreo Modbus, donde P y S no se leen en el mismo instante, y pueden quedar levemente desfasadas. Es una limitación de adquisición, no un error de nuestra migración. Lo importante es que la regla lo detectó y lo aisló.

**13. ¿No es un porcentaje muy alto de la cuarentena para una sola regla? ¿La regla es demasiado estricta?**
Representa el 0.82% del total leído en conjunto, y la regla es una desigualdad física exacta. Una alternativa sería agregar una tolerancia (por ejemplo, aceptar P ≤ S + ε) para absorber el desfase de muestreo; lo dejamos como mejora futura. Mantener la regla estricta y revisar la cuarentena es más seguro que dejar pasar datos físicamente inconsistentes.

**14. ¿Perdieron datos al rechazar 24,422 filas?**
No. Las filas aisladas se guardan completas como JSONB en `calidad.registro_cuarentena` con estado PENDIENTE. Solo están separadas de producción. La cuadratura (2,965,337 + 24,422 = 2,989,759) demuestra que cada fila leída tiene destino y que ninguna desapareció.

**15. Si el dominio ya prohíbe potencia aparente negativa, ¿por qué `R_LINEPOWERVA_NEG` envía 8 filas a cuarentena en lugar de fallar?**
Son dos capas. Las reglas de `calidad` se evalúan antes de insertar en producción y desvían la fila a cuarentena. El dominio es la última barrera: garantiza que, aunque algo se escape de las reglas, ninguna fila inválida entra en `solardb`. Si solo existiera el dominio, un valor malo haría fallar la inserción del lote completo.

**16. Hay 6 reglas activas, pero el desglose muestra 4 con filas. ¿Qué pasa con las otras?**
`R_NULOS_MODBUS` y `R_FREQ_CERO` no aparecen con filas en el desglose de cuarentena, es decir, no aislaron registros en este conjunto. Siguen activas como controles preventivos para cargas futuras.

**17. ¿Qué significa el estado PENDIENTE y qué sigue después?**
Indica que la fila aún no ha sido revisada. El ciclo previsto es revisarla, corregirla o descartarla de manera documentada, y reprocesarla si se corrige. Es la base para un flujo de calidad de datos auditable.

**18. ¿Cuál es la diferencia entre integridad y calidad de datos en su proyecto?**
Integridad es lo que la base impide por construcción: tipos, dominios, claves primarias, foráneas, UNIQUE y NOT NULL. Calidad es lo que valida si el dato es plausible físicamente y no se puede expresar siempre como una restricción: temperatura imposible para el sitio, P > S, etc. Nuestro diseño combina ambas.

### C. Migración

**19. ¿Qué pasa si ejecuto la migración dos veces?**
En producción existe `UNIQUE (inversor_id, ts_lectura)`, por lo que una segunda ejecución no puede duplicar lecturas ya cargadas: la base rechazaría o ignoraría los duplicados según cómo esté escrita la inserción. Además, `calidad.lote_carga` registra cada ejecución como un lote con estado y contadores, lo que permite detectarla. *Confirma con Juan Sebastian cuál es el comportamiento exacto de su script (si usa `ON CONFLICT`, si limpia `staging` o si valida el lote antes), para no afirmar algo que no hace.*

**20. ¿Cómo comprueban que no se perdió ninguna fila?**
Con la cuadratura: leídas = aceptadas + rechazadas (2,989,759 = 2,965,337 + 24,422) y con los lotes auditados. El lote 4 (`analog_measurements`) lo registra: 2,989,759 leídas, 2,965,337 aceptadas, 24,422 rechazadas; el lote 6 (`context`): 25,178 leídas, 25,178 aceptadas, 0 rechazadas. Ambos con estado COMPLETADO.

**21. ¿Por qué los dos inversores tienen rangos de fechas distintos?**
Son datos reales de campo. El Inversor 1 (Cómputo) cubre del 2025-07-12 al 2026-07-13 (~1 año) y el Inversor 2 (HVAC) del 2025-07-14 al 2026-06-22 (~11 meses). Que los rangos no coincidan es una característica del dataset, no un defecto de la migración.

**22. ¿Cómo cumplieron la meta de 1,000,000 de lecturas?**
La superamos: 2,965,337 filas en producción equivalen al 296.5% de la meta; contando todas las filas leídas (2,989,759) es el 298.9%.

### D. Rendimiento y almacenamiento

**23. ¿Por qué no particionaron `lectura_telemetria`?**
Con ~3 millones de filas (3.7 GB) una tabla única con índices B-tree adecuados responde bien, y el particionamiento añade complejidad (claves de partición en PK y UNIQUE, mantenimiento de particiones). Se justificaría a partir de decenas de millones de filas (referencia de >50 M) o cuando se necesite borrar o archivar por rango de fechas, y entonces se particionaría por rango de `ts_lectura`.

**24. ¿Cuánto ocupa la base y cómo se compara con lo estimado en el diseño?**
Ocupa ~3.88 GB: 3,824 MB la tabla de telemetría (3,440 datos + 384 índices), 34 MB la cuarentena, 26 MB el contexto y menos de 1 MB los catálogos. Los índices son ~10% de la tabla principal (384 de 3,824 MB). La comparación detallada con la estimación está en el documento 09.

**25. ¿Qué índices tienen y por qué?**
Siete: `idx_lectura_ts`, `idx_lectura_lote`, `idx_lectura_inversor_ts`, `idx_cuarentena_regla`, `idx_cuarentena_estado`, `idx_contexto_tipo` e `idx_contexto_valor_gin`. Cubren las consultas típicas: por tiempo, por lote, por inversor en un rango, cuarentena por regla o estado, contexto por tipo y búsqueda dentro del JSONB (GIN). Cada índice acelera lecturas pero encarece las escrituras y ocupa espacio, por eso no indexamos las 38 columnas.

**26. ¿Por qué un índice GIN en `registro_contexto` y no B-tree?**
Porque `valor` es JSONB y las consultas buscan claves o contenido dentro del documento (por ejemplo, `valor->>'source'` o contención con `@>`). Un B-tree no sirve para ese tipo de búsqueda; GIN sí.

**27. ¿Por qué no usaron BRIN para el tiempo?**
BRIN es muy compacto y funciona bien con datos insertados en orden temporal, pero con 3 M de filas el B-tree es asumible (384 MB en índices) y más flexible para búsquedas puntuales por `(inversor_id, ts_lectura)`. Con cientos de millones de filas, BRIN sería una opción que valdría la pena evaluar.

### E. Privacidad y Ley 1581 de 2012

**28. ¿Cómo manejan la Ley 1581 de 2012?**
Clasificamos los datos: la telemetría (2,965,337 + 24,422 filas) no es dato personal; el contexto (25,178 registros) sí puede serlo. Marcamos con `contiene_datos_personales BOOLEAN NOT NULL DEFAULT FALSE`, y 204 registros de `wsl_bash_history` (usuarios, rutas, IPs) son los más críticos. Analizamos los artículos 3, 4, 5, 7, 8, 9, 10, 12, 13, 15, 17 y 18, definimos roles y redactamos un aviso de privacidad. Ver documento 14.

**29. ¿Por qué `DEFAULT FALSE` y no `DEFAULT TRUE`? ¿No es riesgoso?**
Es un riesgo conocido: si una carga olvida marcar, un registro con datos personales parecería inocuo. Por eso el proceso debe marcar explícitamente las fuentes sensibles, y hay una consulta de auditoría para verificar que `wsl_bash_history` tenga 204 registros marcados. Un DEFAULT TRUE marcaría de más y reduciría la utilidad del filtro. La medida compensatoria es la auditoría.

**30. ¿Tienen autorización de los titulares (art. 9)?**
No hay evidencia de una autorización individual. Lo reconocemos. La estrategia es de minimización: uso exclusivamente académico (finalidad, art. 4), no publicar ni compartir los registros marcados (arts. 4 y 13) y, si procede, seudonimizar o suprimir los 204 críticos. El dataset es público en Zenodo, pero eso no elimina por sí solo la obligación de analizar cada caso.

**31. ¿Son datos sensibles según el artículo 5?**
No. Los nombres de usuario, rutas e IPs no revelan origen racial, salud, orientación política u otros datos del artículo 5; son datos personales de carácter común. Si apareciera uno de esa categoría, el régimen sería más estricto.

### F. Proyecto y equipo

**32. ¿Qué limitaciones tiene SolarDB y qué harían distinto?**
(1) La regla P > S podría tener una tolerancia por el desfase de muestreo. (2) La cuarentena está en PENDIENTE; falta un flujo formal de revisión y reproceso. (3) Faltan roles y vistas que restrinjan el acceso al contexto con datos personales. (4) No hay particionamiento porque el volumen actual no lo requiere. Reconocer estas limitaciones muestra criterio.

### Preguntas cortas de respaldo

- **¿Cuál es el dataset y de dónde viene?** OpenCEM v1.0.0, Bartels et al. (2026), DOI 10.5281/zenodo.21436223.
- **¿Qué motor y herramienta usan?** PostgreSQL 18 y DBeaver 26.2.2.
- **¿Quién hizo qué?** Juan Sebastian: arquitectura SolarDB, staging, cuarentena, migración y DDL. Deysi: modelado conceptual y lógico, 3FN y consultas de negocio. Jose Miguel: diccionario de datos, diseño físico, privacidad y esta guía.
- **¿Cómo se reproduce el proyecto?** Clonando el repositorio y ejecutando los scripts en el orden documentado en `docs/`.

## 15.5 Guion de demostración en vivo en DBeaver

**Duración estimada:** 8 a 10 minutos. **Antes de empezar:** conexión activa a PostgreSQL 18, editor SQL abierto, sin credenciales visibles en pantalla, fuente grande.

### Paso 1 — Mostrar la arquitectura (1 min)

```sql
SELECT schema_name
FROM   information_schema.schemata
WHERE  schema_name IN ('solardb', 'staging', 'calidad')
ORDER  BY schema_name;
```
*Esperado:* tres filas. Di: "producción, carga temporal y calidad".

### Paso 2 — Conteos reales (1 min)

```sql
SELECT 'solardb.lectura_telemetria' AS tabla, COUNT(*) AS filas FROM solardb.lectura_telemetria
UNION ALL
SELECT 'calidad.registro_cuarentena', COUNT(*) FROM calidad.registro_cuarentena
UNION ALL
SELECT 'solardb.registro_contexto', COUNT(*) FROM solardb.registro_contexto;
```
*Esperado:* **2,965,337**, **24,422** y **25,178**.

### Paso 3 — Cuadratura (30 s)

```sql
SELECT (SELECT COUNT(*) FROM solardb.lectura_telemetria)
     + (SELECT COUNT(*) FROM calidad.registro_cuarentena) AS total_leidas;
```
*Esperado:* **2,989,759**.

### Paso 4 — Lotes auditados (30 s)

```sql
SELECT * FROM calidad.lote_carga ORDER BY lote_id;
```
*Esperado:* lote 4 (`analog_measurements`) con 2,989,759 / 2,965,337 / 24,422 y lote 6 (`context`) con 25,178 / 25,178 / 0, ambos COMPLETADO.

### Paso 5 — Cuarentena por regla (1 min)

Primero localiza el nombre de la columna que guarda la regla:

```sql
SELECT column_name, data_type
FROM   information_schema.columns
WHERE  table_schema = 'calidad' AND table_name = 'registro_cuarentena'
ORDER  BY ordinal_position;
```

Luego agrupa por esa columna (reemplaza `<columna_regla>` por el nombre que veas):

```sql
SELECT <columna_regla> AS regla, COUNT(*) AS filas
FROM   calidad.registro_cuarentena
GROUP  BY <columna_regla>
ORDER  BY filas DESC;
```
*Esperado:* R_P_MAYOR_S 24,375; R_TEMP1_IMPOSIBLE 38; R_LINEPOWERVA_NEG 8; R_LINECURRA_NEG 1.

> Haz estos dos pasos en tu ensayo para tener el nombre exacto de la columna y no improvisar frente al profesor.

### Paso 6 — Los dominios en acción (1.5 min)

```sql
SELECT t.typname AS dominio, pg_get_constraintdef(c.oid) AS restriccion
FROM   pg_type t
JOIN   pg_namespace n  ON n.oid = t.typnamespace
JOIN   pg_constraint c ON c.contypid = t.oid
WHERE  n.nspname = 'solardb' AND t.typtype = 'd'
ORDER  BY t.typname;
```
*Esperado:* los dominios con CHECK (8 filas); los otros 4 no tienen CHECK, y lo explicas.

Ahora la prueba de que protegen:

```sql
SELECT 150::solardb.dom_porcentaje;
```
*Esperado:* error de violación de la restricción del dominio. Di: "el tipo mismo rechaza el valor".

```sql
SELECT (-5)::solardb.dom_voltaje;
```
*Esperado:* error igual. Ya no hay que repetir el CHECK en cada columna.

### Paso 7 — Restricciones de la tabla principal (1 min)

```sql
SELECT conname, contype, pg_get_constraintdef(oid) AS definicion
FROM   pg_constraint
WHERE  conrelid = 'solardb.lectura_telemetria'::regclass;
```
*Esperado:* PK en `lectura_id`, UNIQUE `(inversor_id, ts_lectura)`, FK a `dim_inversor` y a `calidad.lote_carga`.

### Paso 8 — Distribución por inversor (1 min)

```sql
SELECT inversor_id,
       COUNT(*)         AS filas,
       MIN(ts_lectura)  AS primera,
       MAX(ts_lectura)  AS ultima
FROM   solardb.lectura_telemetria
GROUP  BY inversor_id
ORDER  BY inversor_id;
```
*Esperado:* 1,594,461 y 1,370,876 filas con los rangos de la hoja de cifras.

### Paso 9 — Tamaños en disco (1 min)

```sql
SELECT n.nspname || '.' || c.relname                                            AS tabla,
       pg_size_pretty(pg_total_relation_size(c.oid))                            AS total,
       pg_size_pretty(pg_total_relation_size(c.oid) - pg_indexes_size(c.oid))   AS datos,
       pg_size_pretty(pg_indexes_size(c.oid))                                   AS indices
FROM   pg_class c
JOIN   pg_namespace n ON n.oid = c.relnamespace
WHERE  c.relkind = 'r' AND n.nspname IN ('solardb', 'calidad')
ORDER  BY pg_total_relation_size(c.oid) DESC;
```
*Esperado:* ~3,824 MB, ~34 MB y ~26 MB para las tres tablas grandes. Pueden variar levemente si se ejecutó VACUUM o ANALYZE.

### Paso 10 — Un índice en acción (1 min)

```sql
EXPLAIN ANALYZE
SELECT *
FROM   solardb.lectura_telemetria
WHERE  inversor_id = 1
AND    ts_lectura BETWEEN '2025-08-01' AND '2025-08-02';
```
*Esperado:* un plan con *Index Scan* o *Bitmap Index Scan* sobre `idx_lectura_inversor_ts`. Ajusta `inversor_id` si en tu base los identificadores son distintos.

### Paso 11 — Privacidad (1 min)

```sql
SELECT valor->>'source'                                   AS fuente,
       COUNT(*)                                           AS total_registros,
       COUNT(*) FILTER (WHERE contiene_datos_personales)  AS marcados
FROM   solardb.registro_contexto
GROUP  BY valor->>'source'
ORDER  BY total_registros DESC;
```
*Esperado:* la suma de `total_registros` es **25,178**, con `wsl_bash_history` = **204**.

### Cierre de la demostración (20 s)

"Todo lo que vimos cuadra: 2,965,337 + 24,422 = 2,989,759 filas, con integridad en el motor y calidad en la cuarentena."

### Plan B si algo falla

| Problema | Solución |
|---|---|
| Se pierde la conexión | Reconectar con *Invalidate/Reconnect*; tener capturas de pantalla de cada resultado como respaldo |
| Una consulta tarda | Explicar que son ~3 M de filas y esperar; no cancelar |
| Un nombre de columna no existe | Usar la consulta de `information_schema.columns` del paso 5 |
| Un número no coincide | No inventar: decir "voy a verificar" y mostrar la fuente (`calidad.lote_carga`) |

## 15.6 Estructura del PDF final

El informe se compila como `report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`. La estructura definitiva por capítulos, la asignación por integrante y las instrucciones de exportación están en el documento 16. Resumen de la tabla de contenidos:

| Sección | Contenido | Documento |
|---|---|---|
| Portada institucional | Institución, curso, grupo, docente, integrantes, fecha | — |
| Resumen y palabras clave | Síntesis con métricas reales | — |
| Tabla de contenidos | Numerada, con figuras y tablas | — |
| Capítulos 1 a 8 | Contexto, modelado conceptual y lógico, normalización 3FN y arquitectura | `docs/00` a `docs/07` |
| Capítulo 9 | Diccionario de datos actualizado | `docs/08_diccionario_datos.md` |
| Capítulo 10 | Diseño físico actualizado | `docs/09_diseno_fisico.md` |
| Capítulos 11 a 14 | Resultados de migración, consultas y demás según tus archivos | `docs/10` a `docs/13` (el 11 contiene las métricas reales) |
| Capítulo 15 | Seguridad y privacidad (Ley 1581 de 2012) | `docs/14_seguridad_y_privacidad.md` |
| Capítulo 16 | Guía de sustentación | `docs/15_guia_sustentacion.md` |
| Referencias | APA 7.ª edición, incluida la cita de OpenCEM | — |

> Los títulos exactos de los documentos `00` a `07` y `10` a `13` deben tomarse de tus archivos; esta guía no los modifica.

## 15.7 Lista de verificación el día de la sustentación

- [ ] Conexión DBeaver probada y sin credenciales visibles.
- [ ] Hoja de cifras (15.2) memorizada.
- [ ] Guion de los pasos 1 a 11 ensayado, con el nombre de la columna de regla ya identificado.
- [ ] Capturas de pantalla de cada resultado como respaldo.
- [ ] Repositorio actualizado (`git pull origin main`) y rama `jose/auditoria-e-informe-pdf` subida.
- [ ] PDF final abierto y revisado.
- [ ] Reparto de preguntas acordado con Juan Sebastian y Deysi.
- [ ] Agua, cargador y copia del PDF en USB.

## 15.8 Referencias (APA 7.ª edición)

Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

Congreso de la República de Colombia. (2012). *Ley Estatutaria 1581 de 2012, por la cual se dictan disposiciones generales para la protección de datos personales*.
