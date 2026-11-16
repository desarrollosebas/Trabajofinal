# 03 — Diseño de Arquitectura SolarDB

> **Proyecto:** SolarDB – Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
> **Materia:** Bases de Datos I – Taller 6  
> **Autor:** Juan Sebastian Raigosa Gil  
> **Fecha:** Noviembre 2026

---

## 1. Visión General

SolarDB es una base de datos PostgreSQL diseñada para almacenar, validar y auditar telemetría de una microrred solar híbrida. Su **línea de especialización** es la integridad y calidad de datos mediante tres mecanismos complementarios:

| Mecanismo | Implementación | Propósito |
|-----------|---------------|-----------|
| **Dominios personalizados** | `CREATE DOMAIN` con `CHECK` | Validación a nivel de tipo: el DBMS rechaza automáticamente valores que violen leyes físicas |
| **Tablas de staging** | Esquema `staging` sin restricciones | Zona de aterrizaje segura para datos crudos antes de validación |
| **Tablas de cuarentena** | Esquema `calidad` con trazabilidad | Preservación de filas rechazadas con motivo, regla y ciclo de vida |

---

## 2. Arquitectura de Esquemas

```
PostgreSQL (solardb database)
├── Schema: solardb (Producción)
│   ├── Dominios personalizados (12)
│   │   ├── dom_voltaje, dom_corriente, dom_corriente_no_neg
│   │   ├── dom_potencia_activa, dom_potencia_activa_no_neg
│   │   ├── dom_potencia_aparente, dom_potencia_reactiva
│   │   ├── dom_frecuencia, dom_temperatura
│   │   └── dom_porcentaje, dom_porcentaje_carga, dom_resistencia_aislamiento
│   ├── Tablas dimensionales
│   │   ├── dim_sitio (1 fila)
│   │   ├── dim_subsistema (2 filas)
│   │   ├── dim_inversor (2 filas)
│   │   ├── cat_tipo_contexto (7 filas)
│   │   ├── cat_unidad_medida (9 filas)
│   │   └── cat_variable_fisica (38 filas)
│   ├── Tablas de hechos
│   │   ├── lectura_telemetria (~2.9M filas, 46 columnas)
│   │   └── registro_contexto (~25K filas)
│   └── Vistas
│       ├── v_resumen_diario_energia
│       └── v_estado_baterias
│
├── Schema: staging (Zona de aterrizaje)
│   ├── staging_telemetria (transitoria, sin dominios)
│   ├── staging_contexto (transitoria)
│   └── Funciones PL/pgSQL del pipeline
│       ├── fn_validar_staging_telemetria()
│       ├── fn_mover_validas_a_produccion()
│       ├── fn_mover_rechazadas_a_cuarentena()
│       └── fn_ejecutar_pipeline_telemetria()
│
└── Schema: calidad (Auditoría)
    ├── lote_carga (auditoría de migraciones)
    ├── regla_calidad (catálogo de reglas, 4 reglas)
    ├── registro_cuarentena (filas rechazadas con JSONB)
    └── Vistas
        └── v_dashboard_calidad
```

---

## 3. Estrategia de Dominios Personalizados

### 3.1 ¿Qué es un dominio en PostgreSQL?

Un dominio (`CREATE DOMAIN`) es un tipo de dato personalizado que encapsula un tipo base con restricciones `CHECK`. A diferencia de un `CHECK` a nivel de tabla, el dominio se define **una sola vez** y se reutiliza en múltiples columnas y tablas.

```sql
-- Ejemplo: dominio de voltaje
CREATE DOMAIN solardb.dom_voltaje AS DOUBLE PRECISION
    CHECK (VALUE >= 0);

-- Se usa en 6 columnas diferentes:
battvolt  solardb.dom_voltaje,  -- V terminal batería
pv1volt   solardb.dom_voltaje,  -- V panel solar
outvolta  solardb.dom_voltaje,  -- V salida inversor
...
```

### 3.2 Los 12 Dominios de SolarDB

| Dominio | Tipo Base | Restricción | Columnas | Justificación Física |
|---------|-----------|-------------|----------|---------------------|
| `dom_voltaje` | DOUBLE PRECISION | ≥ 0 | 6 | Voltaje es magnitud escalar ≥ 0 |
| `dom_corriente` | DOUBLE PRECISION | *(ninguna)* | 1 | battcurr tiene signo (±) |
| `dom_corriente_no_neg` | DOUBLE PRECISION | ≥ 0 | 7 | Corrientes de carga/PV/salida ≥ 0 |
| `dom_potencia_activa` | INTEGER | *(ninguna)* | 3 | P puede ser ± (inyección vs consumo) |
| `dom_potencia_activa_no_neg` | INTEGER | ≥ 0 | 5 | P de PV/salida/carga siempre ≥ 0 |
| `dom_potencia_aparente` | INTEGER | ≥ 0 | 4 | S = \|V\|×\|I\| ≥ 0 por definición |
| `dom_potencia_reactiva` | INTEGER | *(ninguna)* | 1 | Q puede ser ± (inductivo/capacitivo) |
| `dom_frecuencia` | DOUBLE PRECISION | ≥ 0 | 2 | Frecuencia ≥ 0; valor 0 = modo isla |
| `dom_temperatura` | DOUBLE PRECISION | *(ninguna)* | 4 | Anomalías van a cuarentena, no CHECK |
| `dom_porcentaje` | SMALLINT | [0, 100] | 2 | SOC y fanduty: 0–100% |
| `dom_porcentaje_carga` | SMALLINT | [0, 110] | 2 | Picos transitorios hasta 110% |
| `dom_resistencia_aislamiento` | INTEGER | ≥ 0 | 1 | Resistencia ≥ 0 |

### 3.3 Decisión: ¿Por qué dom_temperatura NO tiene CHECK?

La temperatura `temper1 = -20.3°C` (38 filas) es físicamente imposible en Shenzhen. Sin embargo:

- Si ponemos `CHECK (VALUE > -20)`, PostgreSQL rechazaría esas filas **silenciosamente** en un INSERT.
- En SolarDB, queremos **cuarentena con trazabilidad**: saber exactamente cuáles filas tienen el error, cuándo se detectó y qué regla lo clasificó.
- Por eso, la restricción de temperatura se implementa como **regla de calidad** (`R_TEMP1_IMPOSIBLE`) en el pipeline de staging, no como CHECK en el dominio.

> **Principio de diseño:** Los dominios validan **invariantes universales** (voltaje ≥ 0 siempre). Las **anomalías de negocio** se detectan en staging y van a cuarentena con trazabilidad.

---

## 4. Pipeline de Staging y Validación

### 4.1 Flujo del Pipeline

```
┌─────────────────┐
│   SQLite         │  2,989,759 filas de analog_measurements
│   (OpenCEM)      │
└────────┬────────┘
         │  Python: extrae en lotes de 50,000
         │  COPY CSV → staging
         ▼
┌─────────────────┐
│   staging.       │  SIN dominios, SIN CHECK
│   staging_       │  Todo DOUBLE PRECISION / TEXT
│   telemetria     │  estado_validacion = 'PENDIENTE'
└────────┬────────┘
         │  fn_validar_staging_telemetria()
         │  Aplica reglas R_TEMP1_IMPOSIBLE y R_P_MAYOR_S
         ▼
    ┌────┴────┐
    │         │
    ▼         ▼
 VALIDA    RECHAZADA
    │         │
    │         │  fn_mover_rechazadas_a_cuarentena()
    │         ▼
    │    ┌─────────────┐
    │    │  calidad.    │  JSONB completo + motivo + regla
    │    │  registro_   │  estado = 'PENDIENTE'
    │    │  cuarentena  │  (~3,849 filas esperadas)
    │    └─────────────┘
    │
    │  fn_mover_validas_a_produccion()
    │  Convierte tipos, aplica dominios
    │  ON CONFLICT DO NOTHING (idempotencia)
    ▼
┌─────────────────┐
│   solardb.       │  CON dominios + CHECK + FK
│   lectura_       │  TIMESTAMPTZ, INTEGER, JSONB
│   telemetria     │  (~2,985,910 filas esperadas)
└─────────────────┘
```

### 4.2 Idempotencia

La migración es **idempotente**: si se ejecuta dos veces, no duplica filas. Esto se logra con:

- `UNIQUE(inversor_id, ts_lectura)` en `lectura_telemetria`
- `ON CONFLICT DO NOTHING` en el INSERT de producción
- Cada ejecución crea un nuevo `lote_id` en `lote_carga`

---

## 5. Diseño de Cuarentena

### 5.1 Estructura de `registro_cuarentena`

| Campo | Propósito |
|-------|-----------|
| `cuarentena_id` | PK surrogate |
| `lote_id` | FK → lote_carga: ¿en qué migración se detectó? |
| `regla_id` | FK → regla_calidad: ¿qué regla la rechazó? |
| `read_ts_original` | Timestamp Unix original (trazabilidad) |
| `inversor_original` | Inversor original |
| `fila_original` | JSONB: **copia completa** de la fila rechazada |
| `motivo_rechazo` | Texto descriptivo específico (ej: "temper1 = -20.3°C") |
| `estado` | Ciclo de vida: PENDIENTE → CORREGIDO \| DESCARTADO \| REPROCESADO |
| `fecha_registro` | Cuándo se detectó |
| `fecha_resolucion` | Cuándo se resolvió |

### 5.2 Taxonomía de Errores

| Código | Severidad | Acción | Filas Afectadas |
|--------|-----------|--------|----------------|
| `R_TEMP1_IMPOSIBLE` | ERROR | CUARENTENA | 38 |
| `R_P_MAYOR_S` | ERROR | CUARENTENA | 3,811 |
| `R_NULOS_MODBUS` | INFO | ACEPTAR (NULL legítimo) | ~58,000 |
| `R_FREQ_CERO` | INFO | ACEPTAR (modo isla) | 342,592 |

**Total esperado en cuarentena: ~3,849 filas** (38 + 3,811)  
**Total esperado en producción: ~2,985,910 filas** (2,989,759 - 3,849)

---

## 6. Estrategia de Índices

| Índice | Tipo | Tabla | Justificación |
|--------|------|-------|---------------|
| PK `lectura_id` | B-tree (auto) | lectura_telemetria | Acceso por ID |
| UNIQUE `(inversor_id, ts_lectura)` | B-tree (auto) | lectura_telemetria | Idempotencia + consultas por inversor+tiempo |
| `idx_lectura_ts` | B-tree | lectura_telemetria | Consultas de rango temporal sin filtro de inversor |
| `idx_lectura_lote` | B-tree | lectura_telemetria | Auditoría por lote |
| `idx_contexto_valor_gin` | GIN (jsonb_path_ops) | registro_contexto | Búsquedas de contención en JSONB |
| `idx_contexto_tipo` | B-tree | registro_contexto | Filtrado por fuente |
| `idx_cuarentena_pendiente` | B-tree parcial | registro_cuarentena | Solo filas PENDIENTES (compacto) |
| `idx_cuarentena_regla` | B-tree | registro_cuarentena | Agrupación por regla |
| `idx_cuarentena_lote` | B-tree | registro_cuarentena | Trazabilidad por lote |

---

## 7. Estimación de Almacenamiento

| Objeto | Tamaño Estimado |
|--------|----------------|
| `lectura_telemetria` (tabla + índices) | ~1.0–1.1 GiB |
| `registro_contexto` (tabla + GIN) | ~20–50 MB |
| `registro_cuarentena` (con JSONB) | ~3–6 MB |
| Catálogos y control | < 1 MB |
| **Total producción** | **~1.1–1.2 GiB** |
| `staging_telemetria` (temporal) | ~0.8 GiB |
| **Pico durante migración** | **~2 GiB** |

---

## 8. Citación del Dataset

> Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026).  
> *OpenCEM v1.0.0* [Dataset]. Zenodo.  
> https://doi.org/10.5281/zenodo.21436223
