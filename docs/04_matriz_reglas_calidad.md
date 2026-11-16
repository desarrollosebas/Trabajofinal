# 04 — Matriz de Reglas de Calidad

> **Proyecto:** SolarDB – Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
> **Materia:** Bases de Datos I – Taller 6  
> **Autor:** Juan Sebastian Raigosa Gil  
> **Fecha:** Noviembre 2026

---

## 1. Propósito

Esta matriz documenta todas las reglas de validación de calidad que SolarDB aplica a los datos durante el pipeline de migración. Cada regla fue diseñada a partir del **diagnóstico empírico** del dataset real OpenCEM v1.0.0 (documento 02).

---

## 2. Matriz de Reglas

### 2.1 Reglas de Rechazo (ERROR → CUARENTENA)

| ID | Código | Variable(s) | Regla | Mecanismo | Acción | Evidencia del Dataset |
|----|--------|-------------|-------|-----------|--------|----------------------|
| 1 | `R_TEMP1_IMPOSIBLE` | `temper1` | `temper1 ≤ -20°C` | Pipeline staging (PL/pgSQL) | CUARENTENA | 38 filas con temper1 = -20.3°C. Shenzhen tiene clima subtropical (mínima histórica ~0°C). Valor -20.3°C indica sensor abierto (circuito roto). |
| 2 | `R_P_MAYOR_S` | `outw_a`, `outva_a`, `outsumw`, `outsumva` | `P > S` (potencia activa mayor que aparente) | Pipeline staging (PL/pgSQL) | CUARENTENA | 3,811 filas (Inv1: 3,574, Inv2: 237). Ley física: P ≤ S = \|V\|×\|I\| en circuitos AC. Causas: error de medición o desfase temporal. |

### 2.2 Reglas Informativas (INFO → ACEPTAR)

| ID | Código | Variable(s) | Regla | Mecanismo | Acción | Evidencia del Dataset |
|----|--------|-------------|-------|-----------|--------|----------------------|
| 3 | `R_NULOS_MODBUS` | *(todas las columnas de medición)* | NULL en columnas numéricas | No aplica (se mantiene NULL) | ACEPTAR | ~58,000–60,000 filas (~2%). Causa: timeout Modbus entre inversor y sistema de adquisición. Es dato faltante legítimo, no error. |
| 4 | `R_FREQ_CERO` | `linefreq`, `outfreq` | `linefreq = 0 Hz` o `outfreq = 0 Hz` | No aplica (dominio permite 0) | ACEPTAR | linefreq=0: 342,592 filas. outfreq=0: 149,624 filas. Valor 0 indica modo isla o standby — estado operativo legítimo. |

### 2.3 Restricciones de Dominio (validación automática por el DBMS)

| ID | Dominio | Tipo Base | Restricción CHECK | Columnas Protegidas | Justificación |
|----|---------|-----------|-------------------|---------------------|---------------|
| D1 | `dom_voltaje` | DOUBLE PRECISION | `VALUE ≥ 0` | battvolt, pv1volt, outvolta, linevolta, busvoltp, busvoltn | Voltaje es magnitud escalar, siempre ≥ 0 |
| D2 | `dom_corriente_no_neg` | DOUBLE PRECISION | `VALUE ≥ 0` | linechgcurr, pvchgcurr, pv1curr, outcurra, invcurra, linecurra, gridcurr_a | Corrientes de carga/PV/salida: flujo unidireccional |
| D3 | `dom_potencia_activa_no_neg` | INTEGER | `VALUE ≥ 0` | pv1power, outw_a, normalloadw_a, outsumw, generatedpowerp_a | Potencia de generación/salida: siempre ≥ 0 |
| D4 | `dom_potencia_aparente` | INTEGER | `VALUE ≥ 0` | outva_a, outsumva, linepowerva_a, generatedpowers_a | S = \|V\|×\|I\| ≥ 0 por definición |
| D5 | `dom_frecuencia` | DOUBLE PRECISION | `VALUE ≥ 0` | outfreq, linefreq | Frecuencia ≥ 0; valor 0 = modo isla (legítimo) |
| D6 | `dom_porcentaje` | SMALLINT | `[0, 100]` | battsoc, fanduty | Porcentaje estándar |
| D7 | `dom_porcentaje_carga` | SMALLINT | `[0, 110]` | loadpercenta, sumloadpercent | Picos transitorios hasta 110% observados |
| D8 | `dom_resistencia_aislamiento` | INTEGER | `VALUE ≥ 0` | sir | Resistencia ≥ 0 |

### 2.4 Restricciones a Nivel de Tabla (CHECK cross-column)

| ID | Tabla | Restricción | Justificación |
|----|-------|-------------|---------------|
| T1 | `lectura_telemetria` | `ts_lectura BETWEEN '2025-01-01' AND '2027-01-01'` | Rango temporal válido del dataset con margen |
| T2 | `registro_cuarentena` | Si `estado IN ('CORREGIDO','REPROCESADO')` → `fecha_resolucion IS NOT NULL` | Coherencia del ciclo de vida |
| T3 | `lote_carga` | `filas_aceptadas + filas_rechazadas ≤ filas_leidas` | Invariante de auditoría |
| T4 | `lote_carga` | Si `estado = 'COMPLETADO'` → `fecha_fin IS NOT NULL` | Coherencia temporal |

---

## 3. Resumen de Impacto Esperado

| Categoría | Filas | % del Total |
|-----------|-------|-------------|
| **Aceptadas en producción** | ~2,985,910 | 99.87% |
| **Rechazadas a cuarentena** | ~3,849 | 0.13% |
| ├─ Por R_TEMP1_IMPOSIBLE | 38 | 0.001% |
| └─ Por R_P_MAYOR_S | 3,811 | 0.127% |
| **NULLs legítimos (aceptados)** | ~58,000 | ~2% de celdas |
| **Freq=0 legítimos (aceptados)** | 342,592 | 11.5% |
| **Total leídas** | 2,989,759 | 100% |

---

## 4. Decisiones de Diseño

### ¿Por qué no usar CHECK para P ≤ S?

Un `CHECK (outw_a <= outva_a)` rechazaría las 3,811 filas **silenciosamente** en un INSERT. No sabríamos:
- Cuáles filas se rechazaron
- Cuándo se rechazaron
- Por qué regla
- Si se corrigieron después

Con la **cuarentena de SolarDB**, cada fila rechazada se preserva completa como JSONB, con motivo específico, regla asociada y ciclo de vida de resolución.

### ¿Por qué no filtrar freq=0 ni NULLs?

- **freq=0** es un estado operativo legítimo (modo isla = inversor desconectado de red), no un error.
- **NULLs Modbus** son datos faltantes legítimos por timeout de comunicación, no valores corruptos.

Filtrarlos sería perder información valiosa sobre el comportamiento real del sistema.
