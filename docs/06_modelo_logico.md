# 06 — Modelo Lógico Relacional de SolarDB

**Proyecto:** SolarDB — Integridad y calidad de datos en una microrred híbrida  
**Asignatura:** Bases de Datos I · Grupo 811 · Semestre 2026-II  
**Institución:** Institución Universitaria Pascual Bravo  
**Integrante responsable:** Deysi Carolina Echavarria Soto  
**Docente:** Ramiro Grisales Montoya  
**Fecha:** 2026-11-14  

---

## 1. Derivación del Modelo Lógico

El modelo lógico relacional se deriva directamente del modelo conceptual (doc `05_modelo_conceptual.md`). Cada entidad se convierte en una tabla, cada atributo en una columna, y cada relación 1:N se implementa mediante una clave foránea (`FOREIGN KEY`) en la tabla del lado "muchos".

---

## 2. Tablas del Modelo Lógico

### 2.1. `sitio` — Catálogo de ubicaciones físicas

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `sitio_id` | `SERIAL` | `PRIMARY KEY` | Identificador autoincremental del sitio |
| `nombre` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | Nombre del campus o instalación |
| `ciudad` | `VARCHAR(100)` | `NOT NULL` | Ciudad |
| `pais` | `VARCHAR(60)` | `NOT NULL` | País |
| `latitud` | `NUMERIC(9,6)` | | Latitud geográfica |
| `longitud` | `NUMERIC(9,6)` | | Longitud geográfica |
| `zona_horaria` | `VARCHAR(40)` | `NOT NULL`, `DEFAULT 'Asia/Hong_Kong'` | Zona horaria IANA |

**Clave primaria:** `sitio_id`  
**Claves foráneas:** Ninguna (tabla raíz del modelo jerárquico)  
**Restricción UNIQUE:** `nombre` — no puede haber dos sitios con el mismo nombre.

### 2.2. `subsistema` — Agrupación funcional de cargas

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `subsistema_id` | `SERIAL` | `PRIMARY KEY` | Identificador del subsistema |
| `sitio_id` | `INTEGER` | `NOT NULL`, `REFERENCES sitio(sitio_id) ON DELETE RESTRICT ON UPDATE CASCADE` | Sitio al que pertenece |
| `nombre` | `VARCHAR(100)` | `NOT NULL` | Nombre descriptivo |
| `descripcion` | `TEXT` | | Descripción de la carga |

**Clave primaria:** `subsistema_id`  
**Claves foráneas:**
- `sitio_id → sitio(sitio_id)`
  - `ON DELETE RESTRICT`: No se puede eliminar un sitio si tiene subsistemas asociados (protección de integridad).
  - `ON UPDATE CASCADE`: Si se modifica el ID del sitio, se propaga a los subsistemas.

### 2.3. `inversor` — Catálogo de inversores híbridos

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `inversor_id` | `SMALLINT` | `PRIMARY KEY` | ID del inversor (1 o 2) |
| `subsistema_id` | `INTEGER` | `NOT NULL`, `REFERENCES subsistema(subsistema_id) ON DELETE RESTRICT ON UPDATE CASCADE` | Subsistema al que pertenece |
| `fabricante` | `VARCHAR(100)` | `NOT NULL` | Fabricante (de `specs.manufacturename`) |
| `numero_serie` | `VARCHAR(50)` | `NOT NULL`, `UNIQUE` | Número de serie (de `specs.sourcesn`) |
| `version_hardware` | `VARCHAR(30)` | | Versión de hardware |
| `version_firmware` | `VARCHAR(30)` | | Versión de firmware |
| `version_protocolo` | `VARCHAR(30)` | | Versión del protocolo Modbus |
| `potencia_nominal_w` | `INTEGER` | `CHECK (potencia_nominal_w > 0)` | Potencia nominal (W) |
| `voltaje_nominal_bat_v` | `NUMERIC(5,1)` | `CHECK (voltaje_nominal_bat_v > 0)` | Voltaje nominal baterías (V) |
| `capacidad_bat_ah` | `NUMERIC(6,1)` | `CHECK (capacidad_bat_ah > 0)` | Capacidad baterías (Ah) |

**Clave primaria:** `inversor_id` (coincide con el campo `inverter` del dataset original)  
**Claves foráneas:**
- `subsistema_id → subsistema(subsistema_id)`
  - `ON DELETE RESTRICT`: No se puede eliminar un subsistema si tiene inversores.
  - `ON UPDATE CASCADE`: Propaga cambios de ID.

**Restricción UNIQUE:** `numero_serie` — cada inversor tiene un serial único de fábrica.

### 2.4. `lote_carga` — Trazabilidad de migraciones masivas

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `lote_id` | `SERIAL` | `PRIMARY KEY` | Identificador del lote |
| `fecha_inicio` | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()` | Inicio de la carga |
| `fecha_fin` | `TIMESTAMPTZ` | | Fin de la carga |
| `archivo_origen` | `VARCHAR(255)` | `NOT NULL` | Archivo fuente |
| `filas_leidas` | `INTEGER` | `CHECK (filas_leidas >= 0)` | Filas leídas del origen |
| `filas_aceptadas` | `INTEGER` | `CHECK (filas_aceptadas >= 0)` | Filas aceptadas |
| `filas_rechazadas` | `INTEGER` | `CHECK (filas_rechazadas >= 0)` | Filas rechazadas |
| `estado` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'en_proceso'`, `CHECK (estado IN ('en_proceso','completado','fallido'))` | Estado del proceso |

**Clave primaria:** `lote_id`  
**Claves foráneas:** Ninguna (tabla independiente de trazabilidad).  
**Restricción CHECK:** `estado` solo acepta tres valores válidos.

### 2.5. `lectura` — Telemetría analógica (tabla principal)

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `read_ts` | `TIMESTAMPTZ` | `PRIMARY KEY` (compuesta), `NOT NULL` | Timestamp UTC de la lectura |
| `inversor_id` | `SMALLINT` | `PRIMARY KEY` (compuesta), `NOT NULL`, `REFERENCES inversor(inversor_id) ON DELETE RESTRICT ON UPDATE CASCADE` | Inversor que registró la lectura |
| `lote_id` | `INTEGER` | `REFERENCES lote_carga(lote_id) ON DELETE SET NULL ON UPDATE CASCADE` | Lote de carga que importó este registro |
| `battvolt` | `NUMERIC(5,2)` | Dominio `voltaje_dc` | Voltaje batería (V) |
| `battcurr` | `NUMERIC(6,2)` | | Corriente batería (A), valores negativos = descarga |
| `battsoc` | `SMALLINT` | Dominio `porcentaje` | Estado de carga (%) |
| `battchgpower` | `INTEGER` | | Potencia carga/descarga (W) |
| `linechgcurr` | `NUMERIC(5,2)` | `CHECK (linechgcurr >= 0)` | Corriente de carga desde red (A) |
| `pvchgcurr` | `NUMERIC(5,2)` | `CHECK (pvchgcurr >= 0)` | Corriente de carga desde PV (A) |
| `pv1volt` | `NUMERIC(6,2)` | Dominio `voltaje_dc` | Voltaje arreglo solar (V) |
| `pv1curr` | `NUMERIC(5,2)` | `CHECK (pv1curr >= 0)` | Corriente arreglo solar (A) |
| `pv1power` | `INTEGER` | `CHECK (pv1power >= 0)` | Potencia solar (W) |
| `outvolta` | `NUMERIC(6,2)` | Dominio `voltaje_ac` | Voltaje salida CA (V) |
| `outcurra` | `NUMERIC(5,2)` | `CHECK (outcurra >= 0)` | Corriente salida CA (A) |
| `outfreq` | `NUMERIC(5,2)` | Dominio `frecuencia` | Frecuencia salida (Hz) |
| `invcurra` | `NUMERIC(5,2)` | `CHECK (invcurra >= 0)` | Corriente interna inversor (A) |
| `outw_a` | `INTEGER` | `CHECK (outw_a >= 0)` | Potencia activa carga fase A (W) |
| `outva_a` | `INTEGER` | `CHECK (outva_a >= 0)` | Potencia aparente carga fase A (VA) |
| `loadpercenta` | `SMALLINT` | Dominio `porcentaje_carga` | % carga del inversor |
| `normalloadw_a` | `INTEGER` | `CHECK (normalloadw_a >= 0)` | Potencia cargas normales (W) |
| `outsumw` | `INTEGER` | `CHECK (outsumw >= 0)` | Potencia activa total (W) |
| `outsumva` | `INTEGER` | `CHECK (outsumva >= 0)` | Potencia aparente total (VA) |
| `sumloadpercent` | `SMALLINT` | Dominio `porcentaje_carga` | % carga total |
| `linevolta` | `NUMERIC(6,2)` | Dominio `voltaje_ac` | Voltaje red CA (V) |
| `linecurra` | `NUMERIC(5,2)` | `CHECK (linecurra >= 0)` | Corriente de red (A) |
| `linefreq` | `NUMERIC(5,2)` | Dominio `frecuencia` | Frecuencia red (Hz) |
| `linepowerw_a` | `INTEGER` | | Potencia activa red (W), puede ser negativa (exportación) |
| `linepowerva_a` | `INTEGER` | `CHECK (linepowerva_a >= 0)` | Potencia aparente red (VA) |
| `gridpowerw_a` | `INTEGER` | | Potencia neta red (W), puede ser negativa |
| `gridcurr_a` | `NUMERIC(5,2)` | `CHECK (gridcurr_a >= 0)` | Corriente neta red (A) |
| `busvoltp` | `NUMERIC(6,2)` | `CHECK (busvoltp >= 0)` | Voltaje bus DC+ (V) |
| `busvoltn` | `NUMERIC(6,2)` | `CHECK (busvoltn >= 0)` | Voltaje bus DC- (V) |
| `temper1` | `NUMERIC(4,1)` | Dominio `temperatura` | Temperatura sensor 1 (°C) |
| `temper2` | `NUMERIC(4,1)` | Dominio `temperatura` | Temperatura sensor 2 (°C) |
| `temper3` | `NUMERIC(4,1)` | | Temperatura sensor 3 (°C) — canal inactivo |
| `temper4` | `NUMERIC(4,1)` | | Temperatura sensor 4 (°C) — canal inactivo |
| `sir` | `INTEGER` | `CHECK (sir >= 0)` | Resistencia aislamiento (kΩ) |
| `fanduty` | `SMALLINT` | Dominio `porcentaje` | Ciclo ventilador PWM (%) |
| `battreserve` | `JSONB` | | Reserva registros Modbus batería |
| `pvreserve` | `JSONB` | | Reserva registros Modbus solar |
| `otherreserve` | `JSONB` | | Reserva registros varios |
| `grid_reserve` | `JSONB` | | Reserva registros red |

**Clave primaria compuesta:** `(read_ts, inversor_id)`  
**Claves foráneas:**
- `inversor_id → inversor(inversor_id)`
  - `ON DELETE RESTRICT`: No se puede eliminar un inversor si tiene lecturas asociadas.
  - `ON UPDATE CASCADE`: Propaga cambios de ID.
- `lote_id → lote_carga(lote_id)`
  - `ON DELETE SET NULL`: Si se elimina un lote (poco probable), las lecturas no se pierden, solo pierden la referencia al lote.
  - `ON UPDATE CASCADE`: Propaga cambios de ID.

### 2.6. `tipo_contexto` — Catálogo de fuentes de contexto

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `tipo_contexto_id` | `SERIAL` | `PRIMARY KEY` | Identificador del tipo |
| `nombre` | `VARCHAR(50)` | `NOT NULL`, `UNIQUE` | Nombre de la fuente |
| `descripcion` | `TEXT` | | Descripción |
| `es_dato_personal` | `BOOLEAN` | `NOT NULL`, `DEFAULT FALSE` | Contiene datos personales (Ley 1581) |

**Clave primaria:** `tipo_contexto_id`  
**Claves foráneas:** Ninguna (tabla catálogo raíz).

### 2.7. `contexto` — Registros de contexto semiestructurados

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `contexto_id` | `INTEGER` | `PRIMARY KEY` | ID del registro (de `context.id` en el SQLite) |
| `tipo_contexto_id` | `INTEGER` | `NOT NULL`, `REFERENCES tipo_contexto(tipo_contexto_id) ON DELETE RESTRICT ON UPDATE CASCADE` | Tipo/fuente del contexto |
| `recorded_ts` | `TIMESTAMPTZ` | | Momento de persistencia |
| `start_ts` | `TIMESTAMPTZ` | | Inicio de ventana de validez |
| `end_ts` | `TIMESTAMPTZ` | | Fin de ventana de validez |
| `valor` | `JSONB` | | Carga útil JSON del evento |

**Clave primaria:** `contexto_id`  
**Claves foráneas:**
- `tipo_contexto_id → tipo_contexto(tipo_contexto_id)`
  - `ON DELETE RESTRICT`: No se puede eliminar un tipo si hay contextos asociados.
  - `ON UPDATE CASCADE`: Propaga cambios de ID.

**Restricción temporal:** `CHECK (end_ts IS NULL OR end_ts >= start_ts)` — el fin no puede ser anterior al inicio.

### 2.8. `regla_calidad` — Catálogo de reglas de validación

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `regla_id` | `SERIAL` | `PRIMARY KEY` | Identificador de la regla |
| `nombre` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | Nombre descriptivo |
| `columna_afectada` | `VARCHAR(50)` | `NOT NULL` | Columna sobre la que aplica |
| `condicion_sql` | `TEXT` | `NOT NULL` | Expresión de la condición |
| `justificacion` | `TEXT` | `NOT NULL` | Justificación física o de negocio |
| `accion` | `VARCHAR(20)` | `NOT NULL`, `CHECK (accion IN ('rechazar','advertir','aceptar_con_marca'))` | Acción a ejecutar |

**Clave primaria:** `regla_id`  
**Claves foráneas:** Ninguna (tabla catálogo independiente).

### 2.9. `cuarentena` — Registros rechazados con trazabilidad

| Columna | Tipo PostgreSQL | Restricciones | Descripción |
|---------|----------------|---------------|-------------|
| `cuarentena_id` | `BIGSERIAL` | `PRIMARY KEY` | Identificador del registro |
| `lote_id` | `INTEGER` | `NOT NULL`, `REFERENCES lote_carga(lote_id) ON DELETE RESTRICT ON UPDATE CASCADE` | Lote de carga |
| `regla_id` | `INTEGER` | `NOT NULL`, `REFERENCES regla_calidad(regla_id) ON DELETE RESTRICT ON UPDATE CASCADE` | Regla violada |
| `read_ts_original` | `TIMESTAMPTZ` | `NOT NULL` | Timestamp original de la lectura |
| `inversor_id` | `SMALLINT` | `NOT NULL` | Inversor de origen |
| `datos_originales` | `JSONB` | `NOT NULL` | Fila completa como JSONB |
| `fecha_deteccion` | `TIMESTAMPTZ` | `NOT NULL`, `DEFAULT NOW()` | Momento de detección |
| `motivo` | `TEXT` | | Descripción del motivo |

**Clave primaria:** `cuarentena_id`  
**Claves foráneas:**
- `lote_id → lote_carga(lote_id)`
  - `ON DELETE RESTRICT`: No se puede eliminar un lote si tiene registros en cuarentena (trazabilidad obligatoria).
  - `ON UPDATE CASCADE`: Propaga cambios.
- `regla_id → regla_calidad(regla_id)`
  - `ON DELETE RESTRICT`: No se puede eliminar una regla si fue usada para rechazar datos.
  - `ON UPDATE CASCADE`: Propaga cambios.

---

## 3. Dominios PostgreSQL Propuestos

Los siguientes dominios implementan las restricciones de negocio a nivel de tipo de dato, permitiendo reutilización y consistencia:

```sql
-- Dominios para variables eléctricas y físicas
CREATE DOMAIN voltaje_dc   AS NUMERIC(6,2)  CHECK (VALUE IS NULL OR VALUE BETWEEN 0 AND 600);
CREATE DOMAIN voltaje_ac   AS NUMERIC(6,2)  CHECK (VALUE IS NULL OR VALUE BETWEEN 0 AND 500);
CREATE DOMAIN corriente    AS NUMERIC(6,2);  -- Puede ser negativa (descarga de batería)
CREATE DOMAIN frecuencia   AS NUMERIC(5,2)  CHECK (VALUE IS NULL OR VALUE BETWEEN 0 AND 100);
CREATE DOMAIN porcentaje   AS SMALLINT      CHECK (VALUE IS NULL OR VALUE BETWEEN 0 AND 100);
CREATE DOMAIN porcentaje_carga AS SMALLINT  CHECK (VALUE IS NULL OR VALUE BETWEEN 0 AND 150);
    -- loadpercenta llega hasta 110% en el dataset (sobrecarga momentánea)
CREATE DOMAIN temperatura  AS NUMERIC(4,1)  CHECK (VALUE IS NULL OR VALUE BETWEEN -40 AND 80);
    -- Rango amplio que cubre sensores industriales; valores fuera se detectan en cuarentena
```

> [!NOTE]
> Los dominios permiten `NULL` con la cláusula `VALUE IS NULL OR ...` porque ~2% de los registros tienen valores nulos por timeouts Modbus. Los registros con `temper1 = -20.3°C` pasarán el dominio (está dentro de -40 a 80) pero serán detectados por la regla de calidad específica de SolarDB ("temperatura mínima en Shenzhen") y enviados a cuarentena.

---

## 4. Resumen de Políticas ON DELETE / ON UPDATE

| FK | Tabla Origen | Tabla Destino | ON DELETE | ON UPDATE | Justificación |
|----|-------------|---------------|-----------|-----------|---------------|
| `subsistema.sitio_id` | subsistema | sitio | RESTRICT | CASCADE | No borrar sitios con subsistemas |
| `inversor.subsistema_id` | inversor | subsistema | RESTRICT | CASCADE | No borrar subsistemas con inversores |
| `lectura.inversor_id` | lectura | inversor | RESTRICT | CASCADE | No borrar inversores con datos |
| `lectura.lote_id` | lectura | lote_carga | SET NULL | CASCADE | Si se borra un lote, las lecturas mantienen sus datos |
| `contexto.tipo_contexto_id` | contexto | tipo_contexto | RESTRICT | CASCADE | No borrar tipos con contextos |
| `cuarentena.lote_id` | cuarentena | lote_carga | RESTRICT | CASCADE | Trazabilidad: no borrar lotes con rechazos |
| `cuarentena.regla_id` | cuarentena | regla_calidad | RESTRICT | CASCADE | No borrar reglas usadas en rechazos |

**Patrón general:**
- `ON DELETE RESTRICT` para todas las FKs excepto `lectura.lote_id`, protegiendo la integridad referencial contra borrados accidentales.
- `ON UPDATE CASCADE` universal para propagar cambios de claves primarias sin romper las referencias.
- `ON DELETE SET NULL` solo para `lectura.lote_id` porque la lectura tiene valor independiente del lote que la importó.

---

## 5. Diagrama del Modelo Lógico — Notación Crow's Foot (Pata de Gallo)

```mermaid
erDiagram
    sitio ||--o{ subsistema : "1 sitio tiene N subsistemas"
    subsistema ||--o{ inversor : "1 subsistema tiene N inversores"
    inversor ||--o{ lectura : "1 inversor genera N lecturas"
    lote_carga ||--o{ lectura : "1 lote contiene N lecturas"
    tipo_contexto ||--o{ contexto : "1 tipo clasifica N contextos"
    lote_carga ||--o{ cuarentena : "1 lote genera N rechazos"
    regla_calidad ||--o{ cuarentena : "1 regla detecta N violaciones"

    sitio {
        serial sitio_id PK
        varchar nombre UK "NOT NULL"
        varchar ciudad "NOT NULL"
        varchar pais "NOT NULL"
        numeric latitud
        numeric longitud
        varchar zona_horaria "NOT NULL DEFAULT Asia/Hong_Kong"
    }

    subsistema {
        serial subsistema_id PK
        integer sitio_id FK "NOT NULL → sitio"
        varchar nombre "NOT NULL"
        text descripcion
    }

    inversor {
        smallint inversor_id PK
        integer subsistema_id FK "NOT NULL → subsistema"
        varchar fabricante "NOT NULL"
        varchar numero_serie UK "NOT NULL"
        varchar version_hardware
        varchar version_firmware
        varchar version_protocolo
        integer potencia_nominal_w "CHECK > 0"
        numeric voltaje_nominal_bat_v "CHECK > 0"
        numeric capacidad_bat_ah "CHECK > 0"
    }

    lote_carga {
        serial lote_id PK
        timestamptz fecha_inicio "NOT NULL DEFAULT NOW()"
        timestamptz fecha_fin
        varchar archivo_origen "NOT NULL"
        integer filas_leidas "CHECK >= 0"
        integer filas_aceptadas "CHECK >= 0"
        integer filas_rechazadas "CHECK >= 0"
        varchar estado "CHECK IN en_proceso completado fallido"
    }

    lectura {
        timestamptz read_ts PK "Parte 1 de PK compuesta"
        smallint inversor_id PK_FK "Parte 2 de PK compuesta → inversor"
        integer lote_id FK "→ lote_carga ON DELETE SET NULL"
        numeric battvolt "Dominio voltaje_dc"
        numeric battcurr
        smallint battsoc "Dominio porcentaje"
        integer battchgpower
        numeric pv1volt "Dominio voltaje_dc"
        numeric pv1curr "CHECK >= 0"
        integer pv1power "CHECK >= 0"
        numeric outvolta "Dominio voltaje_ac"
        numeric outcurra "CHECK >= 0"
        numeric outfreq "Dominio frecuencia"
        integer outw_a "CHECK >= 0"
        integer outva_a "CHECK >= 0"
        integer outsumw "CHECK >= 0"
        integer outsumva "CHECK >= 0"
        numeric linevolta "Dominio voltaje_ac"
        numeric linecurra "CHECK >= 0"
        numeric linefreq "Dominio frecuencia"
        integer linepowerw_a
        integer gridpowerw_a
        numeric gridcurr_a "CHECK >= 0"
        numeric temper1 "Dominio temperatura"
        numeric temper2 "Dominio temperatura"
        smallint sir "CHECK >= 0"
        smallint fanduty "Dominio porcentaje"
        jsonb battreserve
        jsonb pvreserve
        jsonb otherreserve
        jsonb grid_reserve
    }

    tipo_contexto {
        serial tipo_contexto_id PK
        varchar nombre UK "NOT NULL"
        text descripcion
        boolean es_dato_personal "NOT NULL DEFAULT FALSE"
    }

    contexto {
        integer contexto_id PK
        integer tipo_contexto_id FK "NOT NULL → tipo_contexto"
        timestamptz recorded_ts
        timestamptz start_ts
        timestamptz end_ts "CHECK end_ts >= start_ts"
        jsonb valor
    }

    regla_calidad {
        serial regla_id PK
        varchar nombre UK "NOT NULL"
        varchar columna_afectada "NOT NULL"
        text condicion_sql "NOT NULL"
        text justificacion "NOT NULL"
        varchar accion "CHECK IN rechazar advertir aceptar_con_marca"
    }

    cuarentena {
        bigserial cuarentena_id PK
        integer lote_id FK "NOT NULL → lote_carga"
        integer regla_id FK "NOT NULL → regla_calidad"
        timestamptz read_ts_original "NOT NULL"
        smallint inversor_id "NOT NULL"
        jsonb datos_originales "NOT NULL"
        timestamptz fecha_deteccion "NOT NULL DEFAULT NOW()"
        text motivo
    }
```

---

## 6. Verificación de Consistencia con el Modelo Conceptual

| Entidad Conceptual (doc 05) | Tabla Lógica (doc 06) | PK | FKs | Estado |
|-----------------------------|-----------------------|----|-----|--------|
| Sitio | `sitio` | `sitio_id` | — | ✅ Implementada |
| Subsistema | `subsistema` | `subsistema_id` | `sitio_id → sitio` | ✅ Implementada |
| Inversor | `inversor` | `inversor_id` | `subsistema_id → subsistema` | ✅ Implementada |
| Lectura de Telemetría | `lectura` | `(read_ts, inversor_id)` | `inversor_id → inversor`, `lote_id → lote_carga` | ✅ Implementada |
| Registro de Contexto | `contexto` | `contexto_id` | `tipo_contexto_id → tipo_contexto` | ✅ Implementada |
| Tipo de Contexto | `tipo_contexto` | `tipo_contexto_id` | — | ✅ Implementada |
| Lote de Carga | `lote_carga` | `lote_id` | — | ✅ Implementada |
| Regla de Calidad | `regla_calidad` | `regla_id` | — | ✅ Implementada |
| Registro de Cuarentena | `cuarentena` | `cuarentena_id` | `lote_id → lote_carga`, `regla_id → regla_calidad` | ✅ Implementada |

Todas las 9 entidades del modelo conceptual tienen su tabla correspondiente en el modelo lógico. Todas las 7 relaciones se implementan mediante claves foráneas con políticas explícitas.

---

## 7. Cita Bibliográfica

Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223
