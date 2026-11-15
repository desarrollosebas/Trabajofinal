# Seguridad y Privacidad — SolarDB (Ley 1581 de 2012)

| | |
|---|---|
| **Proyecto** | Taller 6 — Bases de Datos I. SolarDB: integridad y calidad de datos en una microrred híbrida mediante PostgreSQL |
| **Institución / grupo** | Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II |
| **Docente** | Ramiro Grisales Montoya |
| **Integrante responsable** | Jose Miguel Sosa Cartagena (diccionario de datos, diseño físico, privacidad y documento final) |
| **Fecha** | 15 de noviembre de 2026 |
| **Dataset** | OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223) |
| **Documentos relacionados** | `docs/08_diccionario_datos.md`, `docs/09_diseno_fisico.md` |

> **Alcance y límites de este documento.** Es un análisis académico elaborado por estudiantes de Ingeniería de Software; **no constituye asesoría jurídica**. Las conclusiones son **provisionales** porque el equipo todavía no ha inspeccionado el contenido real de los 204 registros `wsl_bash_history` ni de los registros de Windows. El contexto del proyecto indica que estos registros **pueden** contener usuarios, rutas, IP y nombres de scripts, pero eso debe **verificarse** (sección 2.3). Donde algo no está confirmado se indica como **«pendiente de confirmación»**.

**Normas citadas:**
- **Ley Estatutaria 1581 de 2012** (Régimen General de Protección de Datos Personales).
- **Decreto 1377 de 2013**, que reglamenta parcialmente la Ley 1581 (hoy compilado en el Decreto Único Reglamentario 1074 de 2015, Libro 2, Parte 2, Título 2, Capítulo 25).
- **Ley 1266 de 2008** (Hábeas Data), para la clasificación de los datos públicos, semiprivados y privados.

---

## 1. Datos potencialmente sensibles identificados

Según el contexto del proyecto, la tabla `context` de OpenCEM (25.178 registros) incluye fuentes con posible información de personas:

| Fuente (`$.source`) | Registros | Qué podría contener (según el contexto del proyecto) | Riesgo preliminar |
|---|---:|---|---|
| `wsl_bash_history` | 204 | Comandos de terminal Linux ejecutados por investigadores: nombres de usuario, rutas de carpetas personales (`/home/usuario/...`), nombres de scripts, direcciones IP internas y parámetros de configuración. | **Alto** |
| `windows_event_log` | 6.271 | Eventos de Windows: inicios de sesión, nombres de usuarios del sistema, servicios iniciados, rutas de archivos del sistema. | **Alto** |
| `workstation1_log` | 6.028 | Tareas de cómputo ejecutadas, GPU utilizadas, procesos y duración. | **Medio** (pendiente de inspección) |
| `workstation2_log` | 8.902 | Igual que el anterior. | **Medio** (pendiente de inspección) |
| `derived_context_pipeline` | 3.708 | Eventos climáticos y solares derivados. | **Bajo** (no describe personas) |
| `manual entry` | 60 | Calendario institucional (festivos, exámenes). | **Bajo** |
| `manual_workload_entry` | 5 | Pruebas de carga programadas. | **Bajo** |

Los datos de **telemetría eléctrica** (`analog_measurements`: voltajes, corrientes, potencias, temperaturas) describen equipos, no personas, y no son datos personales.

---

## 2. Análisis legal

### 2.1 ¿Es aplicable la Ley 1581 de 2012?

- **Art. 2 (ámbito de aplicación):** la ley rige el tratamiento de datos personales efectuado en territorio colombiano. El equipo descarga, almacena y procesa el dataset en Colombia (PostgreSQL local de cada integrante y repositorio de trabajo), por lo que, **si el dataset contiene datos personales**, el tratamiento que hace el equipo queda dentro del ámbito de la ley. Esto no excluye que el país de origen de los datos (China) tenga su propia normativa; su análisis queda **fuera del alcance** de este documento.
- **Art. 3, literal c (definición de dato personal):** es cualquier información vinculada o que pueda asociarse a una o varias personas naturales determinadas o determinables. Un nombre de usuario, una ruta como `/home/<usuario>/` o una IP que identifique el equipo de una persona **puede** asociarse a un investigador determinable, aunque no aparezca su nombre completo.
- **Art. 3, literal g (definición de Tratamiento):** cualquier operación sobre datos personales, como recolección, almacenamiento, uso, circulación o supresión. Cargar los registros en PostgreSQL, consultarlos y publicarlos en un repositorio son operaciones de Tratamiento.

### 2.2 Clasificación de los datos personales

Las categorías público, semiprivado y privado provienen de la **Ley 1266 de 2008, art. 3** (literales f, g y h) y el **Decreto 1377 de 2013, art. 3** define dato público y dato sensible. La Ley 1581 define el **dato sensible** en su **art. 5**.

| Categoría | Definición resumida | ¿Aplica a SolarDB? |
|---|---|---|
| **Dato público** | El que no es semiprivado, privado o sensible (por ejemplo, los relativos al estado civil, la profesión o la calidad de comerciante). | **No** como regla general. Que el dataset esté publicado en Zenodo **no convierte automáticamente** en «dato público» (en el sentido legal) los comandos o usuarios que contiene. |
| **Dato semiprivado** | Dato que no tiene naturaleza íntima, reservada ni pública, y cuyo conocimiento interesa a su titular y a cierto sector o a la sociedad. | **Posible**: usuarios del sistema, nombres de equipos, tareas de cómputo asociadas a una persona. |
| **Dato privado** | Dato de naturaleza íntima o reservada, relevante solo para el titular. | **Posible**: historial de comandos personales (`wsl_bash_history`), rutas de carpetas personales. |
| **Dato sensible** (Ley 1581, art. 5) | Afecta la intimidad del Titular o su uso indebido puede generar discriminación (origen racial o étnico, orientación política, convicciones religiosas, pertenencia a sindicatos, salud, vida sexual, datos biométricos). | **No se ha identificado ninguno**, y el equipo **no debe inferirlos**. Si durante la inspección apareciera uno, se aplica el **art. 6** (el Tratamiento de datos sensibles está prohibido salvo excepciones) y se elimina del repositorio. |

> **Conclusión provisional:** los registros `wsl_bash_history` y `windows_event_log` deben tratarse, por precaución, como **datos personales privados o semiprivados**. Los demás registros y toda la telemetría eléctrica no se consideran datos personales, **salvo que la inspección demuestre lo contrario**.

### 2.3 Auditoría necesaria antes de concluir (pendiente)

Para sustentar la clasificación con evidencia, el equipo debe revisar el contenido real. Consultas sugeridas, una vez cargado `registro_contexto`:

```sql
-- ¿Qué claves tiene el JSON en cada fuente?
SELECT fuente_contexto, k, count(*)
FROM solardb.registro_contexto,
     LATERAL jsonb_object_keys(valor) AS k
GROUP BY fuente_contexto, k
ORDER BY fuente_contexto, count(*) DESC;

-- ¿Aparecen rutas de usuario en los comandos de terminal?
SELECT count(*)
FROM solardb.registro_contexto
WHERE fuente_contexto = 'wsl_bash_history'
  AND valor::text ~ '/home/[^/"[:space:]]+';

-- ¿Aparecen direcciones IPv4?
SELECT fuente_contexto, count(*)
FROM solardb.registro_contexto
WHERE valor::text ~ '\m(\d{1,3}\.){3}\d{1,3}\M'
GROUP BY fuente_contexto;
```

> El resultado de estas consultas permite pasar la tabla de la sección 1 de «posible» a «confirmado». Se recomienda hacerlas **solo en el computador local** y sin copiar resultados con datos reales al repositorio.

### 2.4 Roles según la Ley 1581 (art. 3)

| Rol | Definición legal (resumida) | Quién es en SolarDB | Observación |
|---|---|---|---|
| **Titular** (art. 3, literal f) | Persona natural cuyos datos son objeto de Tratamiento. | Las personas (investigadores o usuarios de las estaciones de trabajo y sistemas) cuya actividad quedó registrada en `wsl_bash_history`, `windows_event_log` y los logs de estaciones. | Cantidad e identidad **desconocidas** para el equipo. |
| **Responsable del Tratamiento** (art. 3, literal e) | Persona que por sí misma o con otros decide sobre la base de datos y el Tratamiento. | **(a)** Los autores y la institución que recolectaron y publicaron OpenCEM (responsables del dataset original). **(b)** El **equipo del Taller 6** (Raigosa Gil, Sosa Cartagena y Echavarria Soto), que decide para qué y cómo se procesa **su copia** en SolarDB. | La responsabilidad de (b) es limitada a su propio tratamiento académico. **Pendiente de confirmar con el docente** si la institución universitaria se considera la responsable. |
| **Encargado del Tratamiento** (art. 3, literal d) | Persona que realiza el Tratamiento **por cuenta del Responsable**. | **Ninguno formal** mientras la base de datos corra en los equipos locales de los integrantes. Si se usara un servicio de terceros que procese los datos por cuenta del equipo (por ejemplo, un PostgreSQL alojado en la nube), ese proveedor sería Encargado. | GitHub almacena el código del repositorio; por eso **no deben subirse datos crudos** (sección 5). |

### 2.5 Principios del Tratamiento (art. 4) — evaluación

| Principio (art. 4) | Qué exige | Evaluación del proyecto | Medida |
|---|---|---|---|
| **a) Legalidad** | El Tratamiento es una actividad reglada, sujeta a la ley. | **Parcial.** El equipo aplica la ley como marco de trabajo; no hay verificación de que el origen de los datos cumpla la normativa de su país. | Documentar el análisis (este archivo) y citar la fuente del dataset. |
| **b) Finalidad** | El Tratamiento debe obedecer a una finalidad legítima, informada al Titular. | **Cumple en lo académico**: la finalidad es un trabajo universitario sobre integridad y calidad de datos, no la identificación de personas. | Declarar la finalidad en el aviso de privacidad (sección 4) y no usar los datos para ningún otro propósito. |
| **c) Libertad** | El Tratamiento solo puede ejercerse con el consentimiento previo, expreso e informado del Titular, salvo excepciones legales. | **En riesgo / pendiente.** El equipo no obtuvo consentimiento de los Titulares. Dos normas pueden ser relevantes: el **art. 10, literal d** (no se requiere autorización para tratamiento autorizado por la ley con fines históricos, estadísticos o científicos) y el **art. 6, literal e** (para datos sensibles con finalidad histórica, estadística o científica, se deben adoptar medidas que supriman la identidad de los Titulares). **Su aplicación al caso es una interpretación a confirmar** con el docente o un asesor. | Aplicar la **supresión de identidad** (anonimización) antes de cualquier análisis o publicación. |
| **d) Veracidad o calidad** | La información debe ser veraz, completa, exacta, actualizada, comprobable y comprensible. | **Cumple.** Es el eje de SolarDB: reglas de calidad, cuarentena y trazabilidad por lote (`calidad.lote_carga`). | Conservar los valores originales en la cuarentena y no alterar el significado de los datos. |
| **e) Transparencia** | Se debe garantizar al Titular el derecho a obtener información sobre sus datos. | **Parcial.** Los Titulares no tienen canal de contacto con el equipo. | Aviso de privacidad con un contacto del equipo (sección 4). |
| **f) Acceso y circulación restringida** | Los datos personales no se publican en Internet ni medios masivos, salvo que el acceso sea controlado. | **En riesgo** si se suben datos al repositorio de GitHub. | No subir datos crudos; restringir el acceso por esquemas, roles y vistas (sección 3). |
| **g) Seguridad** | La información se maneja con medidas técnicas, humanas y administrativas para evitar adulteración, pérdida, consulta o acceso no autorizado. | **Parcial**, depende de las medidas aplicadas. | Roles, vistas, `.gitignore`, sin credenciales en el repositorio (secciones 3 y 5). |
| **h) Confidencialidad** | Quienes intervengan en el Tratamiento deben garantizar la reserva de la información. | **Parcial.** | Los tres integrantes se comprometen a no compartir los registros con datos personales fuera del trabajo. |

**Deberes asociados.** Si el equipo se considera Responsable, el **art. 17** le exige, entre otros, garantizar el hábeas data, conservar la información bajo condiciones de seguridad que impidan su adulteración, pérdida o acceso no autorizado, e informar al Titular la finalidad. Si participara un Encargado, el **art. 18** fija deberes equivalentes. El **art. 12** establece el deber de informar al Titular, como mínimo, la finalidad del Tratamiento y sus derechos, y el **art. 9** exige autorización previa e informada, salvo las excepciones del **art. 10**.

**Derechos de los Titulares (art. 8):** conocer, actualizar y rectificar sus datos; pedir prueba de la autorización; ser informados del uso; presentar quejas ante la Superintendencia de Industria y Comercio (autoridad de protección de datos, **art. 19**); **revocar la autorización o solicitar la supresión** del dato (literal e); y acceder gratuitamente a sus datos.

**Transferencias (art. 26):** la ley prohíbe transferir datos personales a países que no ofrezcan niveles adecuados de protección. Publicar datos personales en un repositorio alojado en servidores en el exterior podría equivaler a una transferencia, razón adicional para **no subir datos crudos**.

---

## 3. Medidas técnicas propuestas

Las medidas buscan la **minimización**: tratar solo los datos necesarios para la finalidad. Para el análisis de calidad de la telemetría no se necesita saber quién escribió un comando, solo que el evento existió y cuándo.

> **Importante:** los scripts de esta sección son ejemplos de diseño, **no han sido ejecutados contra los datos reales**. Los patrones deben probarse sobre una muestra local antes de usarse. **Pendiente de confirmación por el coordinador** su integración en el script de migración.

### 3.1 Anonimización de usuarios y rutas

**Reemplazo de rutas personales** (`/home/<usuario>/...`):

```sql
-- Sustituye el nombre de usuario en rutas Linux por un valor genérico
SELECT regexp_replace(valor::text, '/home/[^/"[:space:]]+', '/home/usuario_anonimo', 'g')::jsonb
FROM staging.staging_contexto;   -- tabla de aterrizaje (pendiente de confirmación)
```

**Seudonimización de usuarios** (para poder contar «usuarios distintos» sin saber quiénes son), con la extensión `pgcrypto` y una **sal** que se entrega por variable de `psql` y **nunca se escribe en un archivo del repositorio**:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- La sal se pasa al iniciar psql con:  -v sal='...'   (valor que NO se guarda en el repositorio)
SELECT encode(hmac('<nombre_de_usuario>', :'sal', 'sha256'), 'hex');
```

> Una seudonimización con sal **no es anonimización total**: quien posea la sal podría reidentificar. Por eso la sal no se comparte ni se versiona. Los nombres de usuario de Windows están dentro de claves JSON que **aún no se conocen** (auditoría de la sección 2.3); el patrón se define después de inspeccionarlas.

### 3.2 Enmascaramiento de IP y nombres de equipo

```sql
-- Enmascara los dos últimos octetos de IPv4: 10.1.23.45  ->  10.1.x.x
SELECT regexp_replace(valor::text,
       '\m(\d{1,3})\.(\d{1,3})\.\d{1,3}\.\d{1,3}\M', '\1.\2.x.x', 'g')::jsonb
FROM staging.staging_contexto;
```

- El patrón puede afectar cadenas con forma de IP que sean versiones de software (por ejemplo, `1.2.3.4`). Se acepta el falso positivo, porque es preferible enmascarar de más.
- Los nombres de equipo (hostnames) se reemplazan por alias genéricos (`equipo_01`, `equipo_02`) mediante una tabla de equivalencias que se guarda **solo en el equipo local**, no en el repositorio. Los hostnames reales **no se conocen** todavía (pendiente de auditoría).

### 3.3 Separación en esquemas y roles de acceso restringido

Aprovecha la separación de esquemas definida en `docs/09_diseno_fisico.md`:

```sql
-- Rol sin inicio de sesión: agrupa permisos (no tiene contraseña)
CREATE ROLE rol_analista NOLOGIN;

GRANT USAGE ON SCHEMA solardb TO rol_analista;

-- El analista NO puede leer la tabla con el JSON completo...
REVOKE ALL ON solardb.registro_contexto FROM rol_analista;

-- ...solo la vista sin datos personales (sección 3.5)
GRANT SELECT ON solardb.v_contexto_sin_personales TO rol_analista;

-- Telemetría y catálogos no contienen datos personales
GRANT SELECT ON solardb.lectura_telemetria TO rol_analista;
```

- Los roles con inicio de sesión (`LOGIN`) se crean **de forma local** y su contraseña se define con `\password` en `psql` o con DBeaver, **nunca en un archivo `.sql` versionado**.
- La tabla `staging.*` (datos crudos) y `calidad.registro_cuarentena` (copia completa de filas rechazadas, en JSONB) deben quedar **sin permisos para el rol de analista**.

### 3.4 Política de retención y eliminación (propuesta)

| Dato | Retención propuesta | Eliminación |
|---|---|---|
| `staging.*` (datos crudos) | Solo durante la migración y su verificación | `TRUNCATE` al cerrar el lote exitoso. |
| `registro_contexto` con `contiene_datos_personales = TRUE` | Únicamente en versión **anonimizada** | El valor original no se conserva en la base final. |
| `registro_cuarentena` | Mientras haya registros `PENDIENTE` | Eliminar o anonimizar cuando se resuelva. |
| Copias de la base de datos o del SQLite original | Solo en el equipo local de cada integrante | Borrarlas al finalizar el semestre 2026-II, una vez cerrada la evaluación del taller. **Plazo exacto pendiente de acordar con el equipo y el docente.** |

Si un Titular solicitara la supresión de sus datos (**art. 8, literal e** de la Ley 1581; **art. 9 del Decreto 1377 de 2013**), el equipo eliminará los registros asociados.

### 3.5 Vistas que excluyen campos sensibles

Se añade la marca `contiene_datos_personales` (véase `docs/08_diccionario_datos.md`, tabla `registro_contexto`). **Regla propuesta:** `TRUE` para `wsl_bash_history` y `windows_event_log`; para los logs de estaciones, **según el resultado de la auditoría** (sección 2.3).

```sql
-- Vista segura: oculta el JSON de los registros marcados con datos personales
CREATE VIEW solardb.v_contexto_sin_personales AS
SELECT contexto_id,
       fuente_contexto,
       ts_contexto,
       CASE WHEN contiene_datos_personales THEN NULL ELSE valor END AS valor
FROM solardb.registro_contexto;
```

La vista conserva el hecho de que el evento existió (fuente y fecha), útil para correlacionar con la telemetría, pero **no expone el contenido** de los registros con posibles datos personales.

---

## 4. Aviso de privacidad simplificado (proyecto académico)

El **Decreto 1377 de 2013, art. 15** exige que el aviso contenga como mínimo: el nombre y datos de contacto del Responsable, el Tratamiento y su finalidad, los derechos del Titular y los mecanismos para conocer la política de tratamiento. Propuesta de texto:

> **AVISO DE PRIVACIDAD — Proyecto SolarDB (Taller 6, Bases de Datos I)**
>
> **Responsables del tratamiento:** Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena y Deysi Carolina Echavarria Soto, estudiantes de la Institución Universitaria Pascual Bravo (grupo 811, semestre 2026-II), bajo la orientación del docente Ramiro Grisales Montoya.
> **Contacto:** [correo del equipo — por definir].
>
> **Datos tratados:** este proyecto usa el dataset público OpenCEM v1.0.0 (Bartels et al., 2026; DOI 10.5281/zenodo.21436223), compuesto principalmente por telemetría eléctrica de equipos. Una parte menor del dataset (registros de contexto) puede contener información asociada a usuarios de sistemas informáticos, como nombres de usuario, rutas de carpetas, direcciones IP o comandos.
>
> **Finalidad:** exclusivamente académica: estudiar la integridad y calidad de los datos en una base de datos PostgreSQL. **No se utilizan los datos para identificar, evaluar ni contactar a ninguna persona.**
>
> **Medidas:** los datos que puedan asociarse a personas se anonimizan o se enmascaran antes del análisis, se separan en esquemas con acceso restringido y **no se publican en el repositorio**. Los datos originales se eliminan al finalizar el semestre.
>
> **Sus derechos (Ley 1581 de 2012, art. 8):** conocer, actualizar y rectificar sus datos; solicitar prueba de la autorización; ser informado del uso de sus datos; presentar quejas ante la Superintendencia de Industria y Comercio; revocar la autorización o solicitar la supresión de sus datos; y acceder gratuitamente a ellos. Puede ejercerlos escribiendo al contacto indicado.
>
> **Política de tratamiento:** este aviso y el documento `docs/14_seguridad_y_privacidad.md` del repositorio del proyecto describen cómo se tratan los datos.

> **Pendiente:** definir un correo de contacto y confirmar con el docente si el aviso debe presentarse como trabajo individual del equipo o a nombre de la institución.

---

## 5. Protección del repositorio

### 5.1 Lo que el repositorio NO debe contener

| Elemento | Motivo |
|---|---|
| **Contraseñas** de PostgreSQL o de cualquier otro sistema | Cualquiera con acceso al repositorio podría usarlas; quedan además en el historial de Git aunque se borren después. |
| **Cadenas de conexión con credenciales** (por ejemplo, URL del tipo `postgresql://usuario:clave@servidor/base`) | Contienen la contraseña en texto claro. |
| **Tokens de acceso a GitHub** (*Personal Access Tokens*) | Dan acceso a la cuenta de quien los creó. |
| **Datos crudos del dataset** (el SQLite de 4,13 GB, CSV, volcados) | Pueden contener datos personales (arts. 4-f y 26 de la Ley 1581) y exceden el tamaño razonable de un repositorio. |
| **Archivos `.env`** con variables de entorno sensibles | Suelen guardar claves y cadenas de conexión. |
| **Archivos de configuración de clientes**, como los de DBeaver (`data-sources.json`, `credentials-config.json`) | Pueden guardar conexiones y credenciales. |
| **Tabla de equivalencias de seudónimos y la sal** de la sección 3.1 | Permitirían reidentificar a las personas. |

Los datos que sí pueden ir en el repositorio: scripts DDL **sin credenciales**, documentación, consultas SQL de negocio, y el manifiesto de sumas de verificación (`SHA-256`) del dataset.

### 5.2 Archivo `.gitignore` sugerido

```gitignore
# Datos crudos del dataset
*.sqlite
*.sqlite3
*.db
data/raw/
data/staging/
*.dump
*.backup

# Credenciales y variables de entorno
.env
*.env
.pgpass
pgpass.conf
*.pem
*.key
secrets/

# Configuración local de DBeaver
.dbeaver/
data-sources*.json
credentials-config.json

# Tablas de equivalencia de anonimización
*equivalencias*
```

> **Pendiente de confirmación por el coordinador:** revisar el `.gitignore` que ya exista en el repositorio y añadir solo lo que falte, para no duplicar reglas.

### 5.3 Buenas prácticas

1. **Las credenciales se piden al momento de conectarse** (DBeaver las solicita o las guarda de forma local cifrada) y no se escriben en los scripts.
2. **Antes de cada `git commit`,** revisar qué se va a subir con `git status` y `git diff --staged`.
3. **Buscar secretos por descuido** antes de subir, por ejemplo: `git diff --staged | grep -i -E "password|passwd|token|secret|postgresql://"`. Si aparece algo, no se hace el commit.
4. **El token de GitHub se trata como una contraseña:** no se pega en archivos, capturas de pantalla ni chats, y se le asigna una fecha de vencimiento corta.
5. **Si un secreto se sube por error:** (a) **revocar de inmediato** el token o cambiar la contraseña, porque borrar el archivo después **no** elimina el secreto del historial de Git; (b) avisar al coordinador para limpiar el historial si fuera necesario.
6. Los datos que se compartan entre integrantes deben ser **datos anonimizados o sintéticos**, nunca los registros originales con datos personales.

---

## 6. Resumen y pendientes

| Aspecto | Conclusión |
|---|---|
| Datos personales | Posibles en `wsl_bash_history` (204) y `windows_event_log` (6.271); pendiente de inspección en los logs de estaciones (6.028 y 8.902). |
| Clasificación | Privados o semiprivados de forma provisional; no se identificaron datos sensibles (art. 5). |
| Roles | Titulares: personas registradas en los logs. Responsable: autores de OpenCEM y el equipo respecto de su copia. Encargado: ninguno formal mientras todo sea local. |
| Principios en mayor riesgo | Libertad (art. 4-c) y acceso y circulación restringida (art. 4-f). |
| Medidas principales | Anonimización, enmascaramiento de IP, roles, vistas, retención limitada y repositorio sin datos crudos ni credenciales. |

**Pendientes para el coordinador y el docente:**
1. Inspeccionar el contenido real de los registros de contexto (sección 2.3) y ajustar la clasificación.
2. Decidir en qué punto de la migración se aplican la anonimización y el enmascaramiento.
3. Confirmar con el docente si la institución se considera Responsable y si se requiere formalizar el aviso de privacidad.
4. Verificar la licencia y los términos de uso de OpenCEM en Zenodo.
5. Definir el correo de contacto y la fecha de eliminación de las copias locales.
6. Revisar el `.gitignore` del repositorio.

---

## 7. Fuentes normativas

- Congreso de la República de Colombia. *Ley Estatutaria 1581 de 2012*, por la cual se dictan disposiciones generales para la protección de datos personales. Diario Oficial 48.587 del 18 de octubre de 2012.
- Ministerio de Comercio, Industria y Turismo. *Decreto 1377 de 2013*, por el cual se reglamenta parcialmente la Ley 1581 de 2012.
- Congreso de la República de Colombia. *Ley Estatutaria 1266 de 2008* (Hábeas Data).
- Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

Este documento no contiene contraseñas, tokens ni cadenas de conexión.
