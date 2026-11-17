# Prompt para Jose Miguel Sosa Cartagena (Ronda 2)
## Rol: Ingeniero de Auditoría, Seguridad y Compilación del Informe Final PDF

---

### Contexto del Proyecto
Hola Jose. Te escribe Juan Sebastian Raigosa Gil (coordinador del equipo).

Te comparto un avance crucial: **la base de datos SolarDB ya fue creada y migrada en PostgreSQL con el 100% del dataset real**.
Superamos con creces la meta del profesor (que pedía mínimo 1,000,000 de lecturas):
- **Total lecturas leídas:** 2,989,759 filas.
- **Filas aceptadas en producción:** **2,965,337 filas** en `solardb.lectura_telemetria` (ocupando 3,824 MB en disco).
- **Filas aisladas en cuarentena:** **24,422 filas** en `calidad.registro_cuarentena` (desglosadas en 24,375 por $P > S$, 38 por sensor térmico a -20.3°C, 8 por potencia aparente negativa y 1 por corriente negativa).
- **Eventos de contexto operativo:** **25,178 filas** en `solardb.registro_contexto` (analizados bajo la Ley 1581 de 2012 para protección de datos personales).

---

### Tu Misión en Esta Fase
Tu responsabilidad en esta etapa final es triple:
1. **Actualizar el Diccionario de Datos y el Diseño Físico** con las métricas reales exactas de almacenamiento y conteos post-migración.
2. **Actualizar la Guía de Sustentación Oral** con los números reales y las respuestas sólidas a las preguntas trampa del docente.
3. **Elaborar y compilar el Informe Final del Proyecto en PDF** en la carpeta `report/`, con la portada oficial, estructura institucional y anexos requeridos por el profesor Ramiro Grisales.

---

### Configuración de Herramientas (Git y GitHub paso a paso)
Si aún no tienes Git instalado o configurado en tu equipo, sigue estos sencillos pasos:

#### Paso 1: Instalación de Git (si no lo tienes)
1. Descarga el instalador oficial de Git para Windows desde: `https://git-scm.com/download/win`
2. Ejecuta el instalador dejando las opciones predeterminadas recomendadas (Next $\rightarrow$ Next $\rightarrow$ Install).
3. Abre una consola (PowerShell o Símbolo del Sistema) y verifica escribiendo:
   ```bash
   git --version
   ```

#### Paso 2: Configurar tu identidad en Git
Ejecuta estos dos comandos con tu nombre y tu correo institucional:
```bash
git config --global user.name "Jose Miguel Sosa Cartagena"
git config --global user.email "jose.sosa216@pascualbravo.edu.co"
```

#### Paso 3: Conectar y descargar el repositorio actualizado
1. Entra a la carpeta de trabajo:
   ```bash
   cd "ruta/a/tu/carpeta/ULTIMOWORK"
   ```
2. Asegúrate de traer los últimos cambios que ya subí a GitHub:
   ```bash
   git checkout main
   git pull origin main
   ```
3. Crea tu nueva rama de trabajo:
   ```bash
   git checkout -b jose/auditoria-e-informe-pdf
   ```

---

### Tareas Detalladas a Realizar

#### Tarea 1: Actualización del Diccionario de Datos y Diseño Físico
Abre y actualiza:
- `docs/08_diccionario_datos.md`
- `docs/09_diseno_fisico.md`

Reemplaza las estimaciones teóricas con los **números reales y definitivos**:
* **Lecturas de telemetría:** 2,965,337 filas en producción.
* **Cuarentena:** 24,422 filas en cuarentena.
* **Contexto:** 25,178 filas.
* **Tamaños reales en disco en PostgreSQL:**
  * `solardb.lectura_telemetria`: **3,824 MB** (3,440 MB datos + 384 MB índices).
  * `calidad.registro_cuarentena`: **34 MB**.
  * `solardb.registro_contexto`: **26 MB**.
  * Tamaño total de SolarDB: **~3.88 GB**.
* **Tasa de anomalías:** 0.82% de las lecturas fueron clasificadas a cuarentena por violaciones físicas, demostrando la efectividad de la línea de especialización.

#### Tarea 2: Actualización de la Guía de Sustentación Oral
Abre `docs/15_guia_sustentacion.md` y complementa las respuestas para el docente:
* **¿Por qué usamos dominios (`CREATE DOMAIN`) en lugar de simples CHECKs?** Porque encapsulan las leyes físicas (voltaje $\ge 0$, frecuencia $\ge 0$) a nivel de tipo de dato reutilizable en 38 columnas.
* **¿Por qué la regla $P \le S$ y la temperatura de -20.3°C fueron a cuarentena y no a un CHECK de tabla?** Porque si hubiéramos puesto un CHECK, el motor habría rechazado las 24,422 filas en silencio y habríamos perdido trazabilidad. La tabla de cuarentena almacena la fila completa como JSONB, con fecha, motivo y estado de revisión.
* **¿Cómo garantizamos la Ley 1581 de 2012 (Habeas Data)?** En `solardb.registro_contexto`, la columna booleana `contiene_datos_personales` marca automáticamente registros como `wsl_bash_history` (que contiene nombres de usuario y rutas locales), permitiendo filtrarlos en consultas públicas o auditorías externas.

#### Tarea 3: Compilación del Informe Final en PDF
El profesor Ramiro exige un informe formal escrito que documente todo el taller. Debes compilar el documento final siguiendo esta estructura:
1. **Portada oficial:**
   * Institución Universitaria Pascual Bravo.
   * Facultad de Ingeniería — Departamento de Sistemas.
   * Asignatura: Bases de Datos I — Taller 6 (Microrred Solar).
   * Docente: Ramiro Grisales Montoya.
   * Integrantes: Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto.
   * Medellín, Noviembre de 2026.
2. **Cuerpo del Informe:**
   * Introducción, Justificación y Línea de Especialización (Integridad, dominios y cuarentena).
   * Modelo Conceptual y Lógico (diagramas entidad-relación y tablas normalizadas en 3FN).
   * Diccionario de Datos y Arquitectura Física (con las métricas reales de 3.88 GB).
   * Pipeline de Staging y Cuarentena (justificación del flujo y reglas de calidad).
   * Análisis de Seguridad y Privacidad (Ley 1581 de 2012).
   * Evidencias de Ejecución (10 consultas SQL, vistas, planes EXPLAIN e índices).
   * Pruebas de Integridad (aceptación y rechazo por restricciones).
   * Conclusiones y Referencia al dataset OpenCEM v1.0.0 (DOI Zenodo).
3. **Guardar el archivo compilado en:**
   `report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`

---

### Envío y Sincronización
Una vez tengas los archivos actualizados y el PDF generado en `report/`:
```bash
git add docs/ report/
git commit -m "docs: actualizar metricas reales post-migracion y generar informe final PDF"
git push origin jose/auditoria-e-informe-pdf
```
Apenas hagas el push, me avisas para hacer el merge final hacia `main`. ¡Cualquier duda, estoy a la orden!
