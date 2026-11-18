**INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO**
**Bases de Datos I — Grupo 811 — Semestre 2026-II**
**Docente:** Ramiro Grisales Montoya
**Proyecto:** Taller 6 (Fase Final) — SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL

| Campo | Detalle |
|---|---|
| **Documento** | `docs/14_seguridad_y_privacidad.md` |
| **Título** | Análisis de seguridad y privacidad de datos personales (Ley 1581 de 2012) |
| **Versión** | Ronda 2 — actualizada con métricas reales post-migración |
| **Autor** | Jose Miguel Sosa Cartagena |
| **Equipo** | Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto |
| **Motor / herramienta** | PostgreSQL 18 / DBeaver 26.2.2 |
| **Repositorio** | https://github.com/desarrollosebas/Trabajofinal |
| **Fecha** | 17 de noviembre de 2026 |

---

# 14. Seguridad y privacidad de datos personales

## 14.1 Propósito y alcance

Este documento analiza el tratamiento de datos personales dentro de SolarDB a la luz de la **Ley Estatutaria 1581 de 2012** (Régimen General de Protección de Datos Personales), el **Decreto 1377 de 2013** que la reglamenta parcialmente, y la **Ley 1266 de 2008** (Habeas Data financiero), esta última únicamente para descartar su aplicación.

Con la migración concluida, el análisis deja de ser teórico: se apoya en las cantidades reales verificadas en la base de datos, en particular los **25,178 registros de contexto operativo** migrados a `solardb.registro_contexto`, de los cuales **204 provienen de la fuente `wsl_bash_history`** (comandos de terminal Linux) y se clasifican como de **riesgo crítico** por contener nombres de usuario, rutas e IPs.

> **Nota de alcance.** Este es un análisis académico elaborado para el curso de Bases de Datos I. No constituye concepto jurídico profesional ni sustituye la revisión de un abogado habilitado.

## 14.2 Resumen ejecutivo de métricas de privacidad

| Indicador | Valor real verificado |
|---|---|
| Filas de telemetría eléctrica aceptadas (`solardb.lectura_telemetria`) | 2,965,337 |
| Filas en cuarentena (`calidad.registro_cuarentena`) | 24,422 |
| Registros de contexto migrados (`solardb.registro_contexto`) | 25,178 (100%) |
| Registros de contexto con datos personales críticos (`wsl_bash_history`) | **204** |
| Registros de contexto rechazados en la migración (lote 6) | 0 |
| Esquema donde reside el dato personal | `solardb` |
| Medida técnica de marcado | `contiene_datos_personales BOOLEAN NOT NULL DEFAULT FALSE` |
| Almacenamiento de `registro_contexto` | 26 MB (17 MB datos, 9.3 MB índices) |

**Conclusión principal:** los 2,965,337 registros de telemetría y los 24,422 de cuarentena contienen magnitudes eléctricas de inversores, por lo que **no son datos personales**. La exposición de privacidad se concentra en `solardb.registro_contexto`, que representa una fracción pequeña del volumen total, pero con contenido potencialmente identificador.

## 14.3 Inventario y clasificación de los datos

### 14.3.1 Telemetría eléctrica y cuarentena

La tabla `solardb.lectura_telemetria` (46 columnas) registra voltajes, corrientes, potencias, frecuencias, temperaturas, porcentajes y resistencia de aislamiento de dos inversores. La tabla `calidad.registro_cuarentena` conserva en formato JSONB las filas aisladas por las reglas de calidad. Ninguna de estas variables se refiere a una persona natural determinada o determinable, por lo que **quedan fuera del concepto de dato personal** del artículo 3, literal (c), de la Ley 1581 de 2012.

### 14.3.2 Registros de contexto operativo (25,178)

El campo `source`, contenido dentro del JSONB `valor`, identifica la fuente de cada registro:

| Fuente (`source`) | Registros | Contenido | ¿Datos personales? | Nivel de riesgo |
|---|---|---|---|---|
| `workstation2_log` | 8,902 | Logs GPU/CPU de la estación 2 | Posible (nombres de tareas) | Medio |
| `windows_event_log` | 6,271 | Eventos de Windows | Sí (nombres de usuario) | Alto |
| `workstation1_log` | 6,028 | Logs de tareas de la estación 1 | Posible | Medio |
| `derived_context_pipeline` | 3,708 | Eventos climáticos y solares | No | Bajo |
| `wsl_bash_history` | **204** | **Comandos de terminal Linux** | **Sí (nombres de usuario, rutas, IPs)** | **Crítico** |
| `manual entry` | 60 | Calendario institucional | No | Bajo |
| `manual_workload_entry` | 5 | Pruebas de carga | No | Bajo |
| **Total** | **25,178** | | | |

Verificación de cuadratura: 8,902 + 6,271 + 6,028 + 3,708 + 204 + 60 + 5 = **25,178**.

### 14.3.3 Por qué `wsl_bash_history` es la fuente crítica

Un historial de comandos de terminal revela quién ejecutó acciones en un equipo (nombre de usuario en rutas como `/home/<usuario>/`), qué recursos de red consultó (direcciones IP, hosts) y qué estructura de archivos maneja. Un usuario identificable asociado a una conducta digital es, en principio, un **dato personal** (art. 3, literal c). Además, por su naturaleza, un historial de terminal puede contener por descuido contraseñas, tokens o claves escritas en línea de comandos; esto es un riesgo de seguridad adicional (principio de seguridad, art. 4 literal g) que debe verificarse antes de cualquier publicación.

> No se afirma que los 204 registros contengan credenciales; se afirma que **pueden** contenerlas y que por eso se tratan con el máximo nivel de cautela.

### 14.3.4 ¿Datos sensibles?

El artículo 5 define como sensibles los datos que afectan la intimidad del Titular o cuyo uso indebido puede generar discriminación (origen racial o étnico, orientación política, convicciones religiosas o filosóficas, afiliación sindical, salud, vida sexual, datos biométricos, entre otros). Los nombres de usuario, rutas e IPs de los logs **no encajan en esa lista**; se clasifican como **datos personales privados o semiprivados de carácter común**. Si una revisión posterior encontrara en el contexto algún dato del artículo 5, aplicaría el régimen reforzado de tratamiento de datos sensibles.

## 14.4 Medida técnica en la base de datos: `contiene_datos_personales`

### 14.4.1 Definición

En `solardb.registro_contexto` (6 columnas) existe la columna:

```sql
contiene_datos_personales BOOLEAN NOT NULL DEFAULT FALSE
```

- **BOOLEAN:** solo admite verdadero o falso; ocupa 1 byte y permite filtrar con un predicado simple.
- **NOT NULL:** impide el estado ambiguo "no se sabe"; cada registro debe estar clasificado.
- **DEFAULT FALSE:** un registro nuevo se considera sin datos personales hasta que se marque, por lo que **el proceso de carga debe marcar explícitamente como TRUE** las fuentes con datos personales (ver 14.4.4).

La tabla también define `valor JSONB NOT NULL CHECK (jsonb_typeof(valor) = 'object')`, que garantiza una estructura de objeto y permite inspeccionar el contenido, y `lote_id`, que vincula cada registro con el lote auditado en `calidad.lote_carga` (trazabilidad de origen).

### 14.4.2 Función de la columna

1. **Filtrado:** separar rápidamente el contexto con datos personales del que no los tiene.
2. **Auditoría:** contar y listar qué registros requieren protección, y demostrarlo ante el profesor o ante una autoridad.
3. **Soporte de derechos del Titular:** localizar los registros sobre los que se ejerza una consulta, rectificación o supresión (arts. 8 y 15).
4. **Minimización en la publicación:** excluir los registros marcados al compartir el dataset o el informe.

### 14.4.3 Consultas de auditoría

Conteo por fuente y por marca (la suma de `total_registros` debe ser 25,178):

```sql
SELECT valor->>'source'                                  AS fuente,
       COUNT(*)                                          AS total_registros,
       COUNT(*) FILTER (WHERE contiene_datos_personales) AS marcados_con_datos_personales
FROM   solardb.registro_contexto
GROUP  BY valor->>'source'
ORDER  BY total_registros DESC;
```

Verificación de la fuente crítica (debe devolver 204 en `total_registros`):

```sql
SELECT COUNT(*) AS total_registros,
       COUNT(*) FILTER (WHERE contiene_datos_personales) AS marcados
FROM   solardb.registro_contexto
WHERE  valor->>'source' = 'wsl_bash_history';
```

Si `marcados` fuera menor que 204, la marca debe corregirse con un `UPDATE` auditado:

```sql
UPDATE solardb.registro_contexto
SET    contiene_datos_personales = TRUE
WHERE  valor->>'source' IN ('wsl_bash_history', 'windows_event_log')
AND    contiene_datos_personales = FALSE;
```

> Ejecute primero la consulta de verificación y conserve el resultado; el `UPDATE` solo se aplica si hay diferencias.

### 14.4.4 Medidas complementarias recomendadas (propuesta, no ejecutadas)

Las siguientes medidas **no forman parte de lo migrado**; se proponen como mejora y deben presentarse como tales en la sustentación.

**a) Vista de acceso sin datos personales**

```sql
CREATE VIEW solardb.v_registro_contexto_publico AS
SELECT *
FROM   solardb.registro_contexto
WHERE  contiene_datos_personales = FALSE;
```

Para producción conviene listar las columnas explícitamente en lugar de `SELECT *`.

**b) Separación de privilegios por rol**

```sql
CREATE ROLE rol_analista_contexto NOLOGIN;
GRANT USAGE ON SCHEMA solardb TO rol_analista_contexto;
GRANT SELECT ON solardb.v_registro_contexto_publico TO rol_analista_contexto;
REVOKE ALL ON solardb.registro_contexto FROM rol_analista_contexto;
```

El rol analista no accede a la tabla base, solo a la vista filtrada. Las credenciales reales de cada usuario se gestionan fuera del repositorio.

**c) Seudonimización o supresión de los registros críticos:** sustituir nombres de usuario y direcciones IP por valores genéricos dentro del JSONB, o eliminar los registros `wsl_bash_history` cuando ya no se requieran para la finalidad académica.

**d) Retención:** definir un plazo de conservación y eliminar al vencimiento (principio de finalidad y necesidad, art. 4 lit. b).

## 14.5 Análisis legal según la Ley 1581 de 2012

### 14.5.1 Ámbito de aplicación (art. 2)

La ley se aplica al tratamiento de datos personales en bases de datos que los hagan susceptibles de tratamiento por entidades públicas o privadas, cuando el tratamiento se realiza en territorio colombiano. El dataset OpenCEM proviene de un campus en Shenzhen, pero SolarDB lo almacena y procesa en Colombia (PostgreSQL y DBeaver ejecutados por estudiantes de una institución colombiana). Ese tratamiento local es el que se analiza. Quedan fuera las bases de datos mantenidas en un ámbito exclusivamente personal o doméstico; un proyecto universitario no cabe en esa excepción cuando maneja datos de terceros.

### 14.5.2 Definiciones (art. 3)

| Concepto (art. 3) | Aplicación en SolarDB |
|---|---|
| **Dato personal** (lit. c): información vinculada o que pueda asociarse a personas naturales determinadas o determinables | Nombres de usuario, rutas e IPs de los logs de contexto |
| **Base de datos** (lit. b): conjunto organizado de datos personales objeto de tratamiento | `solardb.registro_contexto`, en cuanto contiene datos personales |
| **Titular** (lit. f) | Personas que operaron las estaciones y terminales del campus |
| **Responsable del Tratamiento** (lit. e): decide sobre la base de datos y/o el tratamiento | Equipo del proyecto y la institución, respecto de la copia en SolarDB |
| **Encargado del Tratamiento** (lit. d): trata datos por cuenta del Responsable | No existe un tercero encargado; PostgreSQL se ejecuta localmente |
| **Tratamiento** (lit. g): cualquier operación sobre datos personales | Migración, almacenamiento, consulta y eventual publicación |
| **Autorización** (lit. a): consentimiento previo, expreso e informado | Ver 14.5.5 |

### 14.5.3 Principios (art. 4)

| Principio | Cómo se aplica en SolarDB |
|---|---|
| **Legalidad** (lit. a) | El tratamiento se rige por la Ley 1581 y su reglamentación |
| **Finalidad** (lit. b) | Los logs se usan solo para correlacionar contexto operativo con la telemetría en un trabajo académico |
| **Libertad** (lit. c) | Se requiere autorización previa del Titular salvo las excepciones del art. 10 |
| **Veracidad o calidad** (lit. d) | Los datos se migran sin alteración y con el lote de origen registrado (`lote_id`) |
| **Transparencia** (lit. e) | El Titular puede conocer qué datos suyos se tratan; la marca booleana facilita responder |
| **Acceso y circulación restringida** (lit. f) | Propuesta de vista y roles (14.4.4); no publicar los registros marcados |
| **Seguridad** (lit. g) | Separación por esquemas, control de acceso, no incluir credenciales en el repositorio |
| **Confidencialidad** (lit. h) | Deber de reserva de quienes accedan a los registros marcados |

### 14.5.4 Datos sensibles y menores (arts. 5 y 7)

- **Art. 5:** según 14.3.4, los datos de los logs no son sensibles; se debe vigilar que ningún registro de contexto contenga datos de esa categoría.
- **Art. 7:** el tratamiento de datos de niños, niñas y adolescentes está restringido a los de naturaleza pública y a los que respeten su interés superior. Se asume que los Titulares son personal adulto del campus; no se identificaron datos de menores en las fuentes descritas.

### 14.5.5 Derechos del Titular, autorización y excepciones (arts. 8, 9 y 10)

**Derechos (art. 8):** conocer, actualizar y rectificar sus datos; solicitar prueba de la autorización otorgada; ser informado del uso dado a sus datos; presentar quejas ante la Superintendencia de Industria y Comercio (SIC); revocar la autorización y/o solicitar la supresión del dato cuando no se respeten los principios, derechos y garantías; y acceder en forma gratuita a sus datos.

**Autorización (art. 9):** el tratamiento requiere autorización previa e informada del Titular, que puede darse por escrito, oral o mediante conductas inequívocas. En SolarDB no consta en el material disponible una autorización específica de las personas cuyos datos aparecen en los logs; esta carencia debe declararse con honestidad en la sustentación.

**Excepciones (art. 10):** no se requiere autorización, entre otros casos, para información requerida por una entidad pública en ejercicio de sus funciones, datos de naturaleza pública, casos de urgencia médica o sanitaria, tratamiento autorizado por la ley con fines históricos, estadísticos o científicos, y datos del registro civil. El dataset OpenCEM se encuentra publicado en un repositorio abierto (Zenodo) y su uso es con fines científicos y académicos, lo que respalda la finalidad, pero **no sustituye** el análisis de si una excepción aplica a cada registro con datos personales. La postura prudente del equipo es **minimizar**: no republicar ni difundir los registros marcados.

### 14.5.6 Deber de informar, suministro y reclamos (arts. 12, 13 y 15)

- **Art. 12:** al solicitar la autorización, el Responsable debe informar la finalidad del tratamiento, el carácter facultativo de las respuestas sobre datos sensibles, los derechos del Titular y la identificación del Responsable. El aviso de la sección 14.7 cumple este propósito.
- **Art. 13:** la información solo puede suministrarse al Titular, a sus causahabientes o representantes, a entidades públicas o administrativas en ejercicio de sus funciones y a terceros autorizados por el Titular o por la ley. Esto fundamenta que el equipo no comparta los registros marcados con terceros.
- **Art. 15 (reclamos):** el Titular que considere que sus datos deben ser corregidos, actualizados o suprimidos, o advierta un presunto incumplimiento, puede presentar un reclamo ante el Responsable. El reclamo se atiende en un máximo de quince (15) días hábiles contados desde su recibo, prorrogables en los términos de la ley. Para esto, la columna `contiene_datos_personales` y el `lote_id` permiten localizar y, si procede, suprimir o seudonimizar los registros.

### 14.5.7 Deberes de Responsables y Encargados (arts. 17 y 18)

| Deber | Artículo | Estado en SolarDB |
|---|---|---|
| Garantizar al Titular el ejercicio del hábeas data | 17 | Posible gracias a la marca y la trazabilidad por lote |
| Solicitar y conservar copia de la autorización | 17 | **Pendiente:** no hay evidencia de autorización individual |
| Informar la finalidad y los derechos | 17 | Cubierto por el aviso de la sección 14.7 |
| Conservar la información con seguridad | 17 | Parcial: esquemas separados, sin credenciales en repositorio; faltan roles y cifrado |
| Garantizar veracidad, actualización y rectificación | 17 | Datos migrados sin alteración; la rectificación se haría por `UPDATE` auditado |
| Tramitar consultas y reclamos | 17 | Procedimiento descrito en 14.5.6 |
| Informar a la SIC sobre violaciones de seguridad | 17 | Aplica en caso de incidente |
| Deberes equivalentes de seguridad, confidencialidad y trámite de reclamos | 18 | No aplica de momento: no hay Encargado externo; si se usara un servicio en la nube, se exigiría contrato de tratamiento |

### 14.5.8 Normas relacionadas

- **Decreto 1377 de 2013:** reglamenta aspectos de autorización, políticas de tratamiento y aviso de privacidad. Sustenta el aviso simplificado de la sección 14.7.
- **Ley 1266 de 2008:** regula el hábeas data financiero, crediticio y comercial. **No aplica** a SolarDB, que no trata información de ese tipo.

## 14.6 Roles de tratamiento

| Rol | Quién | Observación |
|---|---|---|
| **Titulares** | Personas del campus de origen cuyos nombres de usuario, rutas o IPs aparecen en los logs | No participan directamente en el proyecto |
| **Responsable** | Equipo del proyecto SolarDB, bajo la institución y la supervisión del docente | Decide finalidad y medios del tratamiento en el ámbito académico |
| **Encargado** | Ninguno | Base local; ningún tercero trata datos por cuenta del equipo |
| **Fuente de origen** | Autores del dataset OpenCEM | Bartels et al. (2026) |

## 14.7 Aviso de privacidad simplificado

> **AVISO DE PRIVACIDAD — PROYECTO SOLARDB**
>
> **Responsable:** Equipo del Taller 6 de Bases de Datos I, Institución Universitaria Pascual Bravo, grupo 811, semestre 2026-II.
>
> **Datos tratados:** registros de contexto operativo de una microrred (logs de estaciones de trabajo, eventos de sistema e historiales de terminal) que pueden contener nombres de usuario, rutas de archivos y direcciones IP.
>
> **Finalidad:** exclusivamente académica y científica: correlacionar el contexto operativo con la telemetría de los inversores y evaluar la calidad de los datos.
>
> **Derechos del Titular (art. 8, Ley 1581 de 2012):** conocer, actualizar, rectificar y suprimir sus datos, revocar la autorización, solicitar prueba de ella y presentar quejas ante la Superintendencia de Industria y Comercio.
>
> **Medidas:** los registros con datos personales están marcados en la base de datos y no se publican ni se comparten con terceros.
>
> **Contacto para consultas y reclamos:** jose.sosa216@pascualbravo.edu.co

## 14.8 Matriz de riesgos

| # | Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | Publicación de los 204 registros `wsl_bash_history` en el repositorio o informe | Media | Alto | Excluir registros marcados; no subir volcados de contexto a GitHub |
| 2 | Credenciales o tokens dentro de historiales de terminal | Baja a media | Alto | Revisión previa del contenido; eliminar o enmascarar |
| 3 | Marca `contiene_datos_personales` incorrecta por el `DEFAULT FALSE` | Media | Medio | Consulta de auditoría 14.4.3 y corrección con `UPDATE` |
| 4 | Acceso de usuarios sin privilegio a `registro_contexto` | Media | Medio | Vista pública y roles (14.4.4) |
| 5 | Falta de autorización individual de los Titulares | Alta | Medio | Minimizar, seudonimizar o suprimir; declararlo en la sustentación |
| 6 | Conservación indefinida de datos personales | Media | Medio | Definir plazo de retención y eliminar al vencimiento |

## 14.9 Conclusiones

1. De los 2,989,759 registros leídos de telemetría, ninguno es dato personal: 2,965,337 están en producción y 24,422 en cuarentena, todos con magnitudes eléctricas.
2. La superficie de privacidad está en `solardb.registro_contexto`: 25,178 registros migrados al 100%, de los cuales 204 (`wsl_bash_history`) son de riesgo crítico y 6,271 (`windows_event_log`) contienen nombres de usuario.
3. La columna `contiene_datos_personales BOOLEAN NOT NULL DEFAULT FALSE` es la medida técnica que permite filtrar, auditar y atender derechos del Titular, siempre que se mantenga correctamente poblada.
4. El principal pendiente jurídico es la ausencia de evidencia de autorización individual (art. 9); la estrategia es minimizar, no difundir y, cuando proceda, seudonimizar o suprimir.
5. Las medidas de la sección 14.4.4 son propuestas de mejora y deben presentarse como tales.

## 14.10 Referencias (APA 7.ª edición)

Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

Congreso de la República de Colombia. (2008). *Ley 1266 de 2008, por la cual se dictan las disposiciones generales del hábeas data y se regula el manejo de la información contenida en bases de datos personales*.

Congreso de la República de Colombia. (2012). *Ley Estatutaria 1581 de 2012, por la cual se dictan disposiciones generales para la protección de datos personales*.

Presidencia de la República de Colombia. (2013). *Decreto 1377 de 2013, por el cual se reglamenta parcialmente la Ley 1581 de 2012*.
