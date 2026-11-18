# 00 — Auditoría de Requisitos y Preparación

**Proyecto:** SolarDB — Integridad y calidad de datos en una microrred híbrida  
**Asignatura:** Bases de Datos I · Grupo 811 · Semestre 2026-II  
**Institución:** Institución Universitaria Pascual Bravo  
**Docente:** Ramiro Grisales Montoya  
**Línea de profundización:** SolarDB: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena  
**Integrantes:**
- Juan Sebastian Raigosa Gil  
- Jose Miguel Sosa Cartagena  
- Deysi Carolina Echavarria Soto  

**Repositorio GitHub:** https://github.com/desarrollosebas/Trabajofinal  
**Fecha de auditoría:** 2026-11-14  

---

## 1. Documentos disponibles en el workspace

| Archivo | Ubicación | Estado |
|---------|-----------|--------|
| `BDI_Taller6_Microrred_PostgreSQL.docx` | `ULTIMOWORK/` | ✅ Encontrado y leído |

---

## 2. Inventario de herramientas del entorno

| Herramienta | Versión | Estado |
|-------------|---------|--------|
| Python | 3.11.9 | ✅ Disponible |
| Git | 2.53.0.windows.1 | ✅ Disponible |
| PostgreSQL (psql) | 18.6 | ✅ Instalado en `C:\Program Files\PostgreSQL\18` |
| DBeaver | — | ⚠️ Acceso directo en escritorio; ubicación exacta pendiente de confirmar |
| sqlite3 (CLI) | — | ❌ No disponible como comando de sistema |
| Python sqlite3 | Integrado | ✅ Disponible (módulo estándar) |
| zstd (CLI) | — | ❌ No instalado |
| Python zstandard | — | ❌ No instalado (necesita `pip install zstandard`) |
| Espacio en disco | 101 GB libres en C: | ✅ Suficiente (se necesitan ~1-2 GB) |

### Acciones pendientes del entorno

1. **Instalar `zstandard` para Python:** necesario para descomprimir `opencem-v1.0.0.sqlite.zst`.
2. **Confirmar acceso a PostgreSQL:** verificar que podemos conectarnos con `psql` y crear bases de datos.
3. **Confirmar DBeaver:** el acceso directo existe en el escritorio; los scripts se ejecutarán desde DBeaver durante la sustentación.

---

## 3. Requisitos generales del Taller 6

Extraídos textualmente del documento `BDI_Taller6_Microrred_PostgreSQL.docx`:

### A. Análisis
- [ ] Identificar entidades, atributos y reglas de negocio desde los insumos.
- [ ] Diagnosticar problemas de diseño y calidad de la fuente, con conteos.
- [ ] Inventariar la fuente: tablas/archivos, columnas, número de filas, periodo cubierto.

### B. Modelo entidad-relación
- [ ] Modelo conceptual con entidades, atributos, relaciones, cardinalidades, participación.
- [ ] Modelo relacional (lógico) derivado del MER.
- [ ] Notación libre (Chen o crow's foot).
- [ ] Justificación del formato de lectura: ancho vs. largo.

### C. Normalización
- [ ] Evidencia del proceso desde la estructura original hasta 3FN mínimo.
- [ ] Para cada FN: qué dependencia/anomalía se elimina, con ejemplos reales.
- [ ] Justificación de desnormalizaciones intencionales.

### D. Diccionario de datos
- [ ] Por tabla: nombre, descripción, y por columna: tipo, longitud, nulabilidad, default, restricciones (PK, FK, UNIQUE, CHECK), descripción de negocio.
- [ ] Unidad de medida de cada variable física y evidencia utilizada.

### E. Implementación PostgreSQL (DDL)
- [ ] Script completo ejecutable sin errores en DBeaver.
- [ ] Uso justificado de PK, FK (ON DELETE/ON UPDATE), UNIQUE, CHECK, NOT NULL, DEFAULT.
- [ ] Tipos justificados para timestamps, medidas físicas, JSON.
- [ ] Mínimo 3 índices justificados con EXPLAIN/EXPLAIN ANALYZE.
- [ ] Mínimo 2 vistas útiles.

### F. Carga y manipulación (DML)
- [ ] Carga de catálogos.
- [ ] Migración de mínimo **un millón de lecturas**.
- [ ] Estrategia de carga documentada.
- [ ] Conteos antes y después.
- [ ] Reglas de limpieza documentadas con filas afectadas.
- [ ] Carga repetible sin duplicaciones.
- [ ] Ejemplos de INSERT, UPDATE, DELETE.
- [ ] Al menos un rechazo correcto demostrado.

### G. Consultas SQL
- [ ] Mínimo 10 consultas con preguntas reales del negocio.
- [ ] Técnicas requeridas: JOIN (varios tipos), agregaciones, GROUP BY, HAVING, subconsultas, filtros temporales.
- [ ] 6 consultas obligatorias específicas (ver sección 5 de este documento).
- [ ] 4+ consultas adicionales propuestas por el equipo.

### H. Manejo responsable
- [ ] Análisis de registros de contexto y medidas bajo Ley 1581 de 2012.
- [ ] Sin contraseñas ni cadenas de conexión en el repositorio.

### I. Git y GitHub
- [ ] Repositorio público con README.md completo.
- [ ] Scripts organizados y ejecutables en orden.
- [ ] Historial incremental de commits con aportes de ambos integrantes.
- [ ] Datos crudos excluidos.
- [ ] `.gitignore` adecuado.

### J. Entregables
- [ ] PDF: `BDI_Taller6_Apellido1_Apellido2.pdf`.

### K. Sustentación
- [ ] Exposición del flujo completo.
- [ ] Base creada en vivo desde cero con scripts del repositorio.
- [ ] Ambos integrantes dominan todo el proyecto.
- [ ] El profesor puede pedir modificaciones en vivo.

---

## 4. Requisitos particulares de SolarDB

> [!IMPORTANT]
> La guía del profesor establece una "línea de profundización" pero **no se encontró un documento separado** que desarrolle las condiciones particulares de SolarDB. Los siguientes requisitos se derivan de:
> 1. El nombre de la línea: "Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena".
> 2. La formulación del alcance del proyecto.
> 3. Buenas prácticas de calidad de datos en bases de datos.

### Propuesta técnica provisional para SolarDB

| Mecanismo | Descripción | Estado |
|-----------|-------------|--------|
| **Dominios personalizados** (`CREATE DOMAIN`) | Tipos con restricciones de negocio para porcentajes, voltajes, corrientes, potencias, temperaturas | Propuesto |
| **Restricciones declarativas** | CHECK, NOT NULL, UNIQUE, PK, FK, DEFAULT a nivel de columna y tabla | Requerido por la guía |
| **Tablas de staging** | Recepción temporal con tipos flexibles para detectar errores de formato/conversión | Propuesto |
| **Tablas de cuarentena** | Almacén de registros rechazados con trazabilidad completa | Propuesto |
| **Clasificación de errores** | Taxonomía: inválido, incompleto, duplicado, fuera de rango, formato incorrecto, sospechoso, válido | Propuesto |
| **Matriz de reglas de validación** | Tabla de reglas con variable, regla, justificación, mecanismo, acción, evidencia | Propuesto |
| **Trazabilidad** | Registro de origen, fecha, validaciones, motivo de aceptación/rechazo | Propuesto |
| **Pruebas de integridad** | Batería de pruebas que demuestren aceptación y rechazo en PostgreSQL | Propuesto |

> [!NOTE]
> Si el profesor entrega un documento adicional con condiciones específicas para SolarDB, lo incorporaremos inmediatamente. Mientras tanto, la propuesta anterior es coherente con el nombre de la línea y será refinada con datos reales del dataset.

---

## 5. Consultas obligatorias de la guía

| # | Pregunta |
|---|----------|
| 1 | Energía solar generada, energía entregada a la carga y energía tomada de la red, por inversor, día y mes |
| 2 | Hora del día con mayor generación solar promedio, por inversor y mes |
| 3 | Comparación entre los dos inversores en un mismo periodo |
| 4 | Número de lecturas con batería por debajo de un umbral justificado, por día |
| 5 | Días con datos incompletos y porcentaje de lecturas recibidas vs. esperadas |
| 6 | Al menos una consulta sobre registros JSON con operadores nativos de PostgreSQL |

---

## 6. Información del dataset OpenCEM (verificada por fuentes públicas)

### Fuente
- **Nombre:** OpenCEM v1.0.0 (Open In-Context Energy Management)
- **DOI:** 10.5281/zenodo.21436223
- **Zenodo:** https://zenodo.org/records/21436223
- **GitHub:** https://github.com/OpenCEM-platform/opencem-dataset
- **Artículo:** arXiv:2604.05429
- **Ubicación del sistema físico:** Campus CUHK-Shenzhen, China

### Sistema físico
- 2 subsistemas independientes de microrred híbrida
- Cada uno tiene:
  - Arreglo de paneles solares (26 paneles × 480 W)
  - Banco de baterías de litio (~200 Ah, 51.2 V)
  - Inversor híbrido
  - Conexión a red eléctrica pública
- **Inversor 1:** alimenta estaciones de trabajo de investigación (GPU/CPU)
- **Inversor 2:** alimenta equipo de climatización (HVAC)
- Muestreo via Modbus/RS485 cada ~15 segundos

### Estructura del SQLite (información de fuentes públicas)

#### Tabla `analog_measurements`
- **~82 columnas**
- **~15.5 millones de filas** (confirmar al abrir el archivo)
- Columna `inverter`: 1 o 2 (ambos inversores en la misma tabla)
- Columna `read_ts`: Unix timestamp
- Variables: voltajes, corrientes, potencias, estado de carga, temperaturas
- Muestreo: ~15 segundos

#### Tabla `context_records` (o `context`)
- **~5 columnas:** `id`, `recorded`, `start`, `end`, `value`
- **~15,000–25,000 filas** (confirmar)
- Campo `value`: JSON con `source` y `textual_description`
- Sources: `manual entry`, `workstation1_log`, `workstation2_log`

### Archivos a descargar
| Archivo | Tamaño | Propósito |
|---------|--------|-----------|
| `opencem-v1.0.0.sqlite.zst` | 302.1 MB | Fuente principal |
| `opencem-v1.0.0-support.zip` | 10.0 MB | Documentación de soporte |
| `opencem-v1.0.0-SHA256SUMS.txt` | 849 B | Verificación de integridad |
| `README.md` | < 5 kB | Descripción |
| `LICENSE-DATA.txt` | < 5 kB | Licencia |

> [!WARNING]
> **NO** descargar: `opencem-v1.0.0-sky-*.tar.zst` (imágenes de cielo, 0.1–4.0 GB c/u).

---

## 7. Decisiones técnicas pendientes

| # | Decisión | Estado | Depende de |
|---|----------|--------|------------|
| 1 | Formato de lecturas: ancho vs. largo | **Pendiente** | Análisis del SQLite |
| 2 | Rangos de validación de dominios | **Pendiente** | Documentación de equipos + distribución real de datos |
| 3 | Nivel de granularidad del staging | **Pendiente** | Análisis de tipos de error reales |
| 4 | Estructura exacta de cuarentena | **Pendiente** | Diseño del modelo lógico |
| 5 | Nombres de los integrantes del equipo | ✅ **Resuelto** | Juan S. Raigosa, José M. Sosa, Deysi C. Echavarría |
| 6 | Estrategia de migración (CSV + COPY vs. Python directo) | **Pendiente** | Pruebas de rendimiento |
| 7 | Esquemas PostgreSQL (uno o varios) | **Pendiente** | Decisión de diseño |
| 8 | ¿Existe documento adicional de SolarDB del profesor? | ✅ **No existe** | Trabajamos con propuesta técnica propia |

---

## 8. Información pendiente del estudiante

> [!IMPORTANT]
> Necesito que me confirmes lo siguiente antes de continuar:

1. **Nombres completos de ambos integrantes** del equipo (para el PDF y los commits).
2. **¿El profesor entregó algún documento adicional** que desarrolle los requisitos específicos de la línea de profundización "SolarDB"? Si no, trabajamos con la propuesta provisional.
3. **¿Tienes acceso a PostgreSQL desde DBeaver** y puedes crear bases de datos? (para confirmar que el ambiente funciona).
4. **¿Ya descargaste los archivos de OpenCEM?** Si no, necesitaré que los descargues (yo te guío con los pasos exactos).

---

## 9. Plan de trabajo propuesto

| Fase | Nombre | Entregables | Prerequisitos |
|------|--------|-------------|---------------|
| **0** | Auditoría de requisitos | ✅ `docs/00_requisitos_y_auditoria.md` (este documento) | Ninguno |
| **1** | Descarga, verificación e inventario | `docs/01_inventario_dataset.md`, `docs/02_diagnostico_calidad.md` | Descarga de OpenCEM |
| **2** | Definición de SolarDB | `docs/03_diseno_solar_db.md`, `docs/04_matriz_reglas_calidad.md` | Fase 1 |
| **3** | Modelo conceptual, lógico y normalización | `docs/05–07_*.md` + diagramas | Fases 1 y 2 |
| **4** | Diccionario y diseño físico | `docs/08_diccionario_datos.md`, `docs/09_diseno_fisico.md` | Fase 3 |
| **5** | Implementación PostgreSQL | Scripts `sql/00–08_*.sql` | Fase 4 |
| **6** | Migración de ≥ 1 millón de lecturas | `sql/09–11_*.sql`, `docs/10–11_*.md` | Fases 1 y 5 |
| **7** | Consultas, vistas e índices | `sql/12_consultas_negocio.sql`, `docs/12_*.md` | Fase 6 |
| **8** | Pruebas de SolarDB | `sql/13_pruebas_integridad.sql`, `docs/13_*.md` | Fases 5, 6, 7 |
| **9** | Git y GitHub | README, .gitignore, commits, `docs/14_*.md` | Todas las anteriores |
| **10** | Documento final y sustentación | PDF, `docs/15_guia_sustentacion.md` | Todo completado |

### Ruta crítica
```
Descarga → Inventario SQLite → Diseño modelo → DDL → Migración → Consultas → Pruebas → PDF
```

La Fase 1 (descargar y analizar el SQLite) **desbloquea todas las demás**. Sin los datos reales, cualquier decisión de diseño sería especulativa.

---

## 10. Cita bibliográfica obligatoria

Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

---

*Documento generado automáticamente durante la Fase 0 del proyecto SolarDB.*  
*Última actualización: 2026-11-14*
