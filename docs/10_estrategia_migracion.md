# 10 — Estrategia de Migración: SQLite a PostgreSQL

> **Proyecto:** SolarDB – Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
> **Materia:** Bases de Datos I – Taller 6  
> **Autor:** Juan Sebastian Raigosa Gil (Líder / Arquitectura y Migración)  
> **Fecha:** Noviembre 2026  

---

## 1. Objetivo y Reto Técnico

El requisito del Taller 6 exige migrar un mínimo de **1,000,000 de lecturas reales** desde el dataset OpenCEM v1.0.0 (SQLite de 4.13 GB) a PostgreSQL. SolarDB superó este requisito migrando la totalidad del dataset: **2,989,759 lecturas de telemetría** y **25,178 eventos de contexto**.

El reto principal radica en la aplicación estricta de restricciones de integridad:
1. Las tablas de producción poseen **12 dominios personalizados** (`dom_voltaje`, `dom_frecuencia`, etc.) con cláusulas `CHECK`.
2. Una inserción directa provocaría abortos de transacción ante cualquier anomalía de medición.
3. El dataset contiene **38 filas con fallos de sensor** (-20.3°C en clima subtropical), **24,375 filas con potencia activa superior a la aparente ($P > S$)**, y anomalías aisladas de corriente y potencia aparente negativa.

---

## 2. Arquitectura del Pipeline de Staging y Cuarentena

Para resolver este desafío sin perder datos ni relajar las restricciones de producción, se diseñó un pipeline en 4 etapas:

```
┌───────────────────────────────────────────────────────────────┐
│                      SQLite (OpenCEM v1.0.0)                  │
│       analog_measurements (2,989,759)  |  context (25,178)    │
└───────────────────────────────┬───────────────────────────────┘
                                │  Extracción y streaming CSV (COPY)
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                 staging.staging_telemetria                    │
│   • Esquema flexible: DOUBLE PRECISION / TEXT                 │
│   • Sin restricciones de dominio ni CHECK                     │
│   • Columna de control: estado_validacion ('PENDIENTE')       │
└───────────────────────────────┬───────────────────────────────┘
                                │  Clasificación por reglas (PL/pgSQL)
                ┌───────────────┴───────────────┐
                ▼                               ▼
    [estado_validacion = 'VALIDA']   [estado_validacion = 'RECHAZADA']
                │                               │
                │ Inserción en bloques          │ Inserción con fila original
                ▼                               ▼
┌───────────────────────────────┐   ┌───────────────────────────┐
│  solardb.lectura_telemetria   │   │calidad.registro_cuarentena│
│  • 2,965,337 filas aceptadas  │   │• 24,422 filas en          │
│  • 12 dominios activos        │   │  cuarentena con trazabilidad│
│  • Tipos: TIMESTAMPTZ, JSONB  │   │• Motivo y regla asociada  │
└───────────────────────────────┘   └───────────────────────────┘
```

---

## 3. Decisiones de Optimización de Rendimiento

1. **Liberación temporal de índices secundarios:**
   Durante la inserción masiva, se deshabilitaron `idx_lectura_ts` e `idx_lectura_lote`, conservando únicamente la clave primaria y la restricción de unicidad natural `(inversor_id, ts_lectura)`. Una vez completada la carga, los índices se reconstruyeron en paralelo en solo 117.5 segundos.
2. **Inserción por bloques (Chunking de 250,000 registros):**
   La transferencia desde staging a producción se particionó en bloques contiguos de `stg_id`, garantizando confirmaciones intermedias y evitando la saturación del WAL (*Write-Ahead Logging*) de PostgreSQL.
3. **Idempotencia Absoluta:**
   La sentencia de inserción utiliza `ON CONFLICT (inversor_id, ts_lectura) DO NOTHING`. Una reejecución accidental del pipeline no duplica datos ni corrompe el estado del sistema.
