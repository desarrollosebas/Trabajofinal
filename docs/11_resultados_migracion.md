# 11 — Resultados Oficiales de la Migración

> **Proyecto:** SolarDB – Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
> **Materia:** Bases de Datos I – Taller 6  
> **Autor:** Juan Sebastian Raigosa Gil (Líder / Arquitectura y Migración)  
> **Fecha de Ejecución:** 16 de Noviembre de 2026  

---

## 1. Balance General de Migración

| Indicador | Valor Observado | Meta / Requisito | Estado |
|---|---|---|---|
| **Filas leídas de telemetría (SQLite)** | 2,989,759 | ≥ 1,000,000 | **Superado (298.9%)** |
| **Filas aceptadas en producción** | **2,965,337** (99.18%) | ≥ 1,000,000 | **Aprobado** |
| **Filas aisladas en cuarentena** | **24,422** (0.82%) | N/A | **Trazabilidad 100%** |
| **Filas de contexto operativo** | **25,178** (100.0%) | Todas | **Aprobado** |
| **Cuadratura matemática** | $2,965,337 + 24,422 = 2,989,759$ | Coherencia total | **Exacta (0 discrepancias)** |

---

## 2. Desglose de Cuarentena por Regla de Calidad

| Código de Regla | Severidad | Filas Afectadas | Motivo Técnico / Físico |
|---|---|---|---|
| `R_P_MAYOR_S` | ERROR | **24,375** | Violación de la ley física en corriente alterna $P \le S = \|V\| \cdot \|I\|$. Potencia activa registrada supera a la potencia aparente (desfase temporal en registros Modbus o picos transitorios). |
| `R_TEMP1_IMPOSIBLE` | ERROR | **38** | Sensor `temper1` reporta **-20.3°C**. Imposible físicamente en el clima subtropical de Shenzhen (mínima histórica registrada ~0°C). Diagnóstico: circuito abierto / falla de cableado. |
| `R_LINEPOWERVA_NEG` | ERROR | **8** | Potencia aparente de red `linepowerva_a < 0`. La potencia aparente es una magnitud escalar estrictamente no negativa ($S \ge 0$). Falla de muestreo. |
| `R_LINECURRA_NEG` | ERROR | **1** | Corriente de red `linecurra < 0`. Sensor monofásico unidireccional con lectura espuria aislada. |
| **Total en Cuarentena** | | **24,422** | **Almacenadas en `calidad.registro_cuarentena` como JSONB con ciclo de vida PENDIENTE.** |

---

## 3. Distribución por Inversor en Producción

| Inversor | Filas Aceptadas | Porcentaje | Rango Temporal Cubierto |
|---|---|---|---|
| **Inversor 1** (Subsistema Cómputo) | **1,594,461** | 53.77% | `2025-07-12 13:31:35` a `2026-07-13 05:13:53` (~1 año) |
| **Inversor 2** (Subsistema HVAC) | **1,370,876** | 46.23% | `2025-07-14 05:53:32` a `2026-06-22 05:35:24` (~11 meses) |
| **Total** | **2,965,337** | **100.0%** | **Cadencia mediana:** 12.58 segundos |

---

## 4. Ocupación en Disco (Almacenamiento Físico)

| Tabla | Tamaño Total | Espacio de Datos | Espacio de Índices |
|---|---|---|---|
| `solardb.lectura_telemetria` | **3,824 MB** (~3.73 GB) | 3,440 MB | 384 MB |
| `calidad.registro_cuarentena` | **34 MB** | 32 MB | 2.2 MB |
| `solardb.registro_contexto` | **26 MB** | 17 MB | 9.3 MB |
| Catálogos dimensionales y reglas | **< 1 MB** | < 100 KB | < 200 KB |
| **Total Base de Datos SolarDB** | **~3.88 GB** | | |

---

## 5. Auditoría de Lotes de Carga (`calidad.lote_carga`)

```text
lote_id | tabla_origen         | estado     | filas_leidas | filas_aceptadas | filas_rechazadas
--------+----------------------+------------+--------------+-----------------+-----------------
4       | analog_measurements  | COMPLETADO | 2,989,759    | 2,965,337       | 24,422
6       | context              | COMPLETADO | 25,178       | 25,178          | 0
```
