# Prompt para Deysi Carolina Echavarria Soto (Ronda 2)
## Rol: Ingeniera de Consultas SQL, Optimización y Pruebas de Integridad

---

### Contexto del Proyecto
Hola Deysi. Te escribe Juan Sebastian Raigosa Gil (coordinador del equipo).

Te tengo excelentes noticias: **la base de datos SolarDB ya fue creada e integrada en PostgreSQL con datos reales**. El pipeline de migración procesó los **2,989,759 registros** de telemetría de la microrred del campus CUHK-Shenzhen:
- **2,965,337 filas aceptadas** en producción en la tabla `solardb.lectura_telemetria`.
- **24,422 filas anómalas aisladas** en `calidad.registro_cuarentena` con trazabilidad JSONB.
- **25,178 registros de contexto operativo** migrados a `solardb.registro_contexto`.
- Esquema final validado con 12 dominios personalizados, 6 catálogos dimensionales y restricciones CHECK.

---

### Tu Misión en Esta Fase
Tu objetivo en esta etapa es **ejecutar, cronometrar y documentar las 10 consultas de negocio, las 3 vistas, los planes `EXPLAIN ANALYZE` de los índices y la batería de pruebas de integridad** directamente sobre la base de datos PostgreSQL poblada con los ~2.96 millones de datos reales.

---

### Herramientas que Tienes y Cómo Usarlas
Como tienes **AntiGravity** instalado en tu computadora, puedes pedirle a AntiGravity que realice la mayor parte de las verificaciones técnicas y la interacción con Git.

1. **Sincronización con GitHub:**
   En una terminal de tu proyecto o pidiéndoselo a AntiGravity:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b deysi/consultas-y-pruebas
   ```
2. **DBeaver / PostgreSQL:**
   Abre DBeaver y asegúrate de estar conectada a la base de datos `solardb` en `localhost:5432`.
   Si aún no tienes la base de datos localmente restaurada o clonada, puedes ejecutar el script maestro `sql/README_ORDEN_EJECUCION.sql` o pedirle a AntiGravity que ejecute el pipeline `migration/scripts/fast_pipeline.py`.

---

### Tareas Detalladas a Realizar

#### Tarea 1: Ejecución y Cronometraje de las 10 Consultas de Negocio
Abre el archivo [sql/12_consultas_negocio.sql](file:///c:/Users/Sebas/Desktop/Bases%20datos%201/ULTIMOWORK/sql/12_consultas_negocio.sql). Ejecuta cada una de las 10 consultas contra la base de datos real y anota:
1. Cantidad exacta de filas retornadas.
2. Tiempo de ejecución real (en milisegundos o segundos reportados por DBeaver).
3. Breve interpretación de los resultados (ej: "¿cuál inversor generó mayor energía acumulada?", "¿en qué fecha ocurrió el pico de consumo?").

#### Tarea 2: Validación de Vistas de Producción
Ejecuta y verifica las vistas creadas:
- `SELECT * FROM solardb.v_resumen_diario_energia LIMIT 15;`
- `SELECT * FROM calidad.v_dashboard_calidad;`
- `SELECT * FROM solardb.v_estado_baterias;`
Confirma que los cálculos agregados (promedios, máximos, tasas de rechazo) reflejen con precisión los datos de los 2 inversores.

#### Tarea 3: Captura de Planes de Ejecución (`EXPLAIN ANALYZE`)
El profesor evaluará la justificación técnica de los índices. Para los 3 índices principales:
- `idx_lectura_ts` (sobre `ts_lectura`)
- `idx_lectura_lote` (sobre `lote_id`)
- `idx_contexto_valor_gin` (GIN sobre `registro_contexto(valor)`)

Debes correr la consulta correspondiente antecedida de `EXPLAIN (ANALYZE, BUFFERS)`.
*Ejemplo:*
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM solardb.lectura_telemetria
WHERE ts_lectura BETWEEN '2026-01-01' AND '2026-01-07';
```
Copia el plan de texto resultante (donde se evidencie el `Bitmap Index Scan` o `Index Scan` en lugar de un `Seq Scan` costoso) y documenta la reducción drástica en costo estimado y tiempo.

#### Tarea 4: Batería de Pruebas de Integridad
Crea o actualiza el archivo `sql/13_pruebas_integridad.sql` y el documento `docs/13_pruebas_solar_db.md` con las pruebas que demuestren al profesor que SolarDB es invulnerable:
1. **Prueba de Inserción Válida:** INSERT de una fila con valores físicos normales $\rightarrow$ ACEPTADA.
2. **Prueba de Rechazo por Dominio:** INSERT con `battvolt = -10` o `fanduty = 150` $\rightarrow$ RECHAZADA por PostgreSQL (`CheckViolation`).
3. **Prueba de Clave Primaria Duplicada:** INSERT con `(inversor_id, ts_lectura)` existente $\rightarrow$ RECHAZADA por `UniqueViolation`.
4. **Prueba de Clave Foránea Inválida:** INSERT con `inversor_id = 99` $\rightarrow$ RECHAZADA por `ForeignKeyViolation`.
5. **Prueba de Idempotencia:** Reejecutar una carga y verificar que `ON CONFLICT DO NOTHING` no altera el conteo total.

---

### Formato de Entrega y Verificación
Actualiza el archivo:
- `docs/12_consultas_vistas_indices.md` (con los tiempos reales y salidas de las 10 consultas + los planes `EXPLAIN`).
- `docs/13_pruebas_solar_db.md` (con la evidencia de las pruebas de integridad pasadas y fallidas).

Al finalizar, sube tus cambios a GitHub:
```bash
git add sql/ docs/
git commit -m "feat(sql): ejecucion real de 10 consultas, explain analyze y pruebas de integridad"
git push origin deysi/consultas-y-pruebas
```
Cualquier duda, pregúntale a AntiGravity o avísame por el grupo de trabajo. ¡Gran trabajo!
