# SolarDB: Integridad y Calidad de Datos en una Microrred Híbrida mediante PostgreSQL

> **Institución Universitaria Pascual Bravo**  
> **Facultad de Ingeniería — Departamento de Sistemas**  
> **Asignatura:** Bases de Datos I — Grupo 811 — Semestre 2026-II  
> **Docente:** Ramiro Grisales Montoya  
> **Fecha:** Noviembre de 2026  
> **Repositorio Oficial:** [https://github.com/desarrollosebas/Trabajofinal](https://github.com/desarrollosebas/Trabajofinal)

---

## 👥 Integrantes del Equipo y Roles

| Integrante | Rol en el Proyecto | Responsabilidades Principales |
|---|---|---|
| **Juan Sebastian Raigosa Gil** *(Coordinador)* | Arquitecto de Datos y Líder de Pipeline | Auditoría de requerimientos, diseño de arquitectura multiesquema, catálogo de reglas de calidad, scripts DDL (00-09), pipeline de staging/migración masiva y trazabilidad de cuarentena. |
| **Jose Miguel Sosa Cartagena** | Ingeniero de Diseño Físico, Privacidad y Documentación | Diccionario de datos exhaustivo, análisis de diseño físico y almacenamiento, estudio de privacidad bajo Ley 1581 de 2012, guía de sustentación oral (32 preguntas) y compilación del informe final PDF. |
| **Deysi Carolina Echavarria Soto** | Ingeniera de Modelado y Analítica SQL | Modelo conceptual y lógico relacional, normalización formal hasta 3FN, diseño y ejecución real de 10 consultas analíticas de negocio, 3 vistas, análisis de planes `EXPLAIN ANALYZE` y batería de 10 pruebas de integridad. |

---

## 🎯 Línea de Profundización

> **«SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena»**

El proyecto demuestra que un motor relacional empresarial (**PostgreSQL 18**) puede operar como la **Fuente Única de Verdad (*Single Source of Truth*)** para series de tiempo eléctricas masivas de Internet de las Cosas (IoT). La calidad del dato se garantiza en el propio DBMS mediante:
1. **12 Dominios Personalizados (`CREATE DOMAIN`):** Encapsulan las leyes físicas (magnitudes no negativas, voltajes $\ge 0$, potencias, frecuencias y ciclos) a nivel de tipo de dato reutilizable.
2. **Esquema Multicapa (`staging`, `calidad`, `solardb`):** Aislamiento estricto entre aterrizaje transitorio sin restricciones, auditoría/calidad con trazabilidad, y producción normalizada.
3. **Pipeline de Cuarentena con Trazabilidad Total:** Las tuplas con anomalías físicas complejas (ej. violación de $P \le S$ en corriente alterna) no se descartan a ciegas; se aíslan como `JSONB` en `calidad.registro_cuarentena` con marca temporal, motivo y ciclo de vida de resolución.

---

## 📊 Dataset: OpenCEM v1.0.0

El proyecto utiliza datos reales de telemetría de una microrred solar híbrida instalada en el campus de la **The Chinese University of Hong Kong, Shenzhen (CUHK-Shenzhen)**:
* **2 subsistemas independientes:** Inversor 1 (alimenta clusters de investigación con GPU/CPU) e Inversor 2 (alimenta climatización HVAC).
* **Frecuencia de muestreo:** Cadencia mediana de **12.58 segundos** vía Modbus/RS485.
* **Periodo de registro:** Julio de 2025 a Julio de 2026 (~1 año continuo de operación).

### Cita Oficial Obligatoria (APA 7.ª Edición)
```text
Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). 
OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery 
(Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223
```

---

## 📈 Balance Oficial de la Migración y Métricas Certificadas

| Indicador | Valor Observado | Requisito Académico | Estado / Evaluación |
|---|---|:---:|:---:|
| **Lecturas leídas en origen (SQLite)** | **2,989,759** | $\ge 1,000,000$ | **Superado en un 298.9%** |
| **Filas aceptadas en producción (`solardb.lectura_telemetria`)** | **2,965,337** (99.18%) | $\ge 1,000,000$ | **Aprobado con certificación** |
| **Filas aisladas en cuarentena (`calidad.registro_cuarentena`)** | **24,422** (0.82%) | N/A | **Trazabilidad 100% en JSONB** |
| **Registros de contexto operativo (`solardb.registro_contexto`)** | **25,178** (100.0%) | Todas | **Aprobado con flag de Ley 1581** |
| **Cuadratura matemática** | $2,965,337 + 24,422 = 2,989,759$ | Coherencia estricta | **Exacta (0 discrepancias)** |
| **Almacenamiento total en disco (PostgreSQL 18)** | **~3.88 GB** | N/A | Verificado en `pg_total_relation_size` |

### Desglose de Cuarentena por Regla de Calidad
* **`R_P_MAYOR_S` (24,375 filas):** Violación de la ley física en corriente alterna $P \le S = |V| \cdot |I|$. Se detectó potencia activa superior a la aparente por desfase temporal de muestreo Modbus en transitorios.
* **`R_TEMP1_IMPOSIBLE` (38 filas):** Sensor térmico reporta **-20.3°C**, temperatura físicamente imposible en el clima subtropical de Shenzhen (mínima histórica ~0°C). Se aisló por circuito abierto / falla física de sensor.
* **`R_LINEPOWERVA_NEG` (8 filas):** Potencia aparente de red negativa ($S < 0$). La potencia aparente es una magnitud escalar estrictamente no negativa.
* **`R_LINECURRA_NEG` (1 fila):** Corriente de red negativa en sensor monofásico unidireccional (lectura espuria aislada).

---

## 🏛️ Arquitectura del Sistema SolarDB

```text
                               ┌────────────────────────────────┐
                               │   Dataset OpenCEM (SQLite)     │
                               │  analog_measurements (2.98M)   │
                               │        context (25.1K)         │
                               └───────────────┬────────────────┘
                                               │
                                               │ COPY / Bulk Insert
                                               ▼
   ┌────────────────────────────────────────────────────────────────────────────────────────┐
   │ ESQUEMA STAGING                                                                        │
   │   • staging.staging_telemetria (Tablas de aterrizaje transitorio sin restricciones)     │
   │   • staging.staging_contexto                                                           │
   └───────────────────────────────────────┬────────────────────────────────────────────────┘
                                           │
                                           │ Pipeline PL/pgSQL de Validación
                                           │ (Clasificación por Reglas de Calidad)
                                           ▼
          ┌────────────────────────────────┬────────────────────────────────┐
          │                                                                 │
          │ ¿Cumple todas las reglas?                                       │ ¿Viola alguna regla?
          │ SÍ                                                              │ NO
          ▼                                                                 ▼
┌──────────────────────────────────────────────┐  ┌──────────────────────────────────────────────┐
│ ESQUEMA SOLARDB (Producción)                 │  │ ESQUEMA CALIDAD                              │
│   • lectura_telemetria (2,965,337 filas)     │  │   • registro_cuarentena (24,422 filas JSONB) │
│     - 12 Dominios personalizados             │  │   • regla_calidad (6 reglas activas)         │
│     - PK surrogate + UNIQUE natural          │  │   • lote_carga (Auditoría de ejecución)      │
│     - 4 FKs a catálogos dimensionales        │  │                                              │
│   • registro_contexto (25,178 filas)         │  │ Vistas de Calidad:                           │
│   • 6 Catálogos dimensionales (sitio, sub...) │  │   • calidad.v_dashboard_calidad             │
│   • Vistas analíticas:                       │  └──────────────────────────────────────────────┘
│     - solardb.v_resumen_diario_energia       │
│     - solardb.v_estado_baterias              │
└──────────────────────────────────────────────┘
```

---

## 🗂️ Estructura del Repositorio

```text
ULTIMOWORK/
├── README.md                           <- Este documento maestro
├── docs/                               <- Suite de documentación técnica (Capítulos 00 a 16)
│   ├── 00_requisitos_y_auditoria.md    <- Fase 0: Auditoría contra guía oficial
│   ├── 01_inventario_dataset.md        <- Fase 1: Análisis exploratorio y conteos exactos
│   ├── 02_diagnostico_calidad.md       <- Fase 1: Detección empírica de 6 anomalías
│   ├── 03_diseno_solar_db.md           <- Fase 2: Arquitectura y estrategia de dominios
│   ├── 04_matriz_reglas_calidad.md     <- Fase 2: Catálogo formal de reglas de validación
│   ├── 05_modelo_conceptual.md         <- Fase 3: Diagrama E-R y justificación ancho vs largo
│   ├── 06_modelo_logico.md             <- Fase 3: Diagrama relacional crow's foot y FKs
│   ├── 07_normalizacion_3FN.md         <- Fase 3: Demostración formal 1FN -> 2FN -> 3FN
│   ├── 08_diccionario_datos.md         <- Fase 4: Diccionario con métricas reales post-migración
│   ├── 09_diseno_fisico.md             <- Fase 4: Índices, esquemas y análisis de 3.88 GB en disco
│   ├── 10_estrategia_migracion.md      <- Fase 6: Pipeline de carga masiva y optimización
│   ├── 11_resultados_migracion.md      <- Fase 6: Certificación oficial con datos reales
│   ├── 12_consultas_vistas_indices.md  <- Fase 7: Documentación de 10 consultas y EXPLAIN ANALYZE
│   ├── 13_pruebas_solar_db.md          <- Fase 8: Evidencias de 10 pruebas de integridad
│   ├── 14_seguridad_y_privacidad.md    <- Análisis ético y legal bajo Ley 1581 de 2012
│   ├── 15_guia_sustentacion.md         <- 32 preguntas de sustentación, guion DBeaver y cifras
│   └── 16_estructura_informe_final.md  <- Estructura de compilación del documento PDF final
├── sql/                                <- Scripts DDL y consultas ejecutables en PostgreSQL
│   ├── 00_crear_esquemas.sql           <- Creación de esquemas solardb, staging y calidad
│   ├── 01_crear_dominios.sql           <- 12 dominios personalizados con CHECKs físicos
│   ├── 02_crear_catalogos.sql          <- 6 tablas de catálogo dimensional
│   ├── 03_crear_tablas.sql             <- Tablas principales (lectura_telemetria 46 cols, etc.)
│   ├── 04_crear_restricciones.sql      <- Restricciones CHECK de consistencia temporal
│   ├── 05_crear_indices.sql            <- 7 índices justificados (B-tree, GIN, parcial)
│   ├── 06_crear_vistas.sql             <- 3 vistas de analítica y monitoreo
│   ├── 07_crear_funciones_triggers.sql <- Funciones PL/pgSQL del pipeline de validación
│   ├── 08_crear_staging.sql            <- Tablas transitorias de aterrizaje
│   ├── 09_carga_catalogos.sql          <- Inserción de catálogos dimensionales
│   ├── 12_consultas_negocio.sql        <- 10 consultas analíticas avanzadas
│   ├── 13_pruebas_integridad.sql       <- 10 pruebas automatizadas con control de errores
│   └── README_ORDEN_EJECUCION.sql      <- Guía de ejecución ordenada para DBeaver / psql
├── migration/scripts/                  <- Scripts de extracción, transformación y carga (ETL)
│   ├── fast_pipeline.py                <- Pipeline de alta velocidad con COPY y validación
│   └── migrate_context.py              <- Migración de registros de contexto operativo
├── report/                             <- Informe final compilado para entrega
│   └── BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf
└── data/                               <- Documentación de datos crudos (SQLite en .gitignore)
    ├── README.md
    └── opencem-v1.0.0-SHA256SUMS.txt
```

---

## 🚀 Guía de Reproducción Paso a Paso

Para desplegar y verificar el proyecto desde cero en cualquier máquina:

### 1. Prerrequisitos
* **PostgreSQL 18** instalado y corriendo en `localhost:5432`.
* **DBeaver Community** (o cliente `psql`).
* **Python 3.10+** con dependencias: `pip install psycopg2-binary reportlab`.
* Base de datos SQLite original (`opencem-v1.0.0.sqlite`, 4.13 GB) en la carpeta `data/`.

### 2. Creación de la Base de Datos y Estructura DDL
En DBeaver o en `psql`:
```sql
CREATE DATABASE solardb;
```
Conéctate a `solardb` y ejecuta en orden secuencial los scripts ubicados en `sql/`:
1. `sql/00_crear_esquemas.sql`
2. `sql/01_crear_dominios.sql`
3. `sql/02_crear_catalogos.sql`
4. `sql/03_crear_tablas.sql`
5. `sql/04_crear_restricciones.sql`
6. `sql/05_crear_indices.sql`
7. `sql/06_crear_vistas.sql`
8. `sql/07_crear_funciones_triggers.sql`
9. `sql/08_crear_staging.sql`
10. `sql/09_carga_catalogos.sql`

*(O consulta [`sql/README_ORDEN_EJECUCION.sql`](sql/README_ORDEN_EJECUCION.sql) para ejecución automática en lote).*

### 3. Ejecución de la Migración Masiva (ETL)
Ejecuta el pipeline optimizado que procesa los ~3M de registros, clasifica por reglas de calidad y puebla producción y cuarentena:
```bash
python migration/scripts/fast_pipeline.py
python migration/scripts/migrate_context.py
```

### 4. Ejecución de Consultas de Negocio
Abre y ejecuta [`sql/12_consultas_negocio.sql`](sql/12_consultas_negocio.sql) en DBeaver. Incluye:
* Integración trapezoidal de energía solar, carga y red por día/mes.
* Detección de hora pico solar mediante `RANK()`.
* Comparación de factor de carga entre subsistema de cómputo y climatización.
* Monitoreo de batería baja (SOC < 20%).
* Consultas analíticas sobre objetos `JSONB` mediante operadores `@>` y `->>`.

### 5. Verificación de la Batería de Pruebas de Integridad
Ejecuta [`sql/13_pruebas_integridad.sql`](sql/13_pruebas_integridad.sql). El script evalúa transaccionalmente y confirma en consola:
```text
NOTICE:  ✅ PRUEBA 2 PASÓ: Dominio dom_voltaje rechazó voltaje negativo (-10.0 V).
NOTICE:  ✅ PRUEBA 3 PASÓ: Dominio dom_porcentaje rechazó ciclo ventilador (150%).
NOTICE:  ✅ PRUEBA 4 PASÓ: Dominio dom_porcentaje_carga rechazó carga fuera de límite (120%).
NOTICE:  ✅ PRUEBA 5 PASÓ: Restricción uq_lectura_inversor_ts rechazó tupla duplicada.
NOTICE:  ✅ PRUEBA 6 PASÓ: Foreign Key violada al intentar asociar inversor_id = 99.
NOTICE:  ✅ PRUEBA 7 PASÓ: Dominio dom_potencia_aparente rechazó potencia aparente negativa (-100 VA).
NOTICE:  ✅ PRUEBA 8 PASÓ: Idempotencia confirmada. Filas intactas: 2965337 (delta = 0).
NOTICE:  ✅ PRUEBA 9 PASÓ: Restricción chk_lectura_rango_temporal rechazó timestamp fuera de ventana.
NOTICE:  ✅ PRUEBA 10 PASÓ: Foreign Key de lote_carga rechazó lote_id huérfano.
```

---

## 🔒 Privacidad y Protección de Datos (Ley 1581 de 2012)

SolarDB implementa un modelo de **privacidad por diseño**:
* La telemetría analógica no contiene datos de personas naturales.
* En `solardb.registro_contexto`, los **204 registros de terminal Linux (`wsl_bash_history`)** que contienen nombres de investigadores, rutas locales y comandos son identificados y marcados con `contiene_datos_personales = TRUE`.
* El repositorio mantiene exclusión estricta de credenciales, contraseñas y archivos crudos mediante `.gitignore`.

---

## 📜 Licencia y Atribución

Este proyecto ha sido desarrollado exclusivamente con fines académicos para la asignatura **Bases de Datos I** de la **Institución Universitaria Pascual Bravo**. El dataset base está bajo la licencia y términos provistos por los autores originales de OpenCEM en Zenodo (DOI: 10.5281/zenodo.21436223).
