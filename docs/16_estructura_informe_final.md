**INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO**
**Bases de Datos I — Grupo 811 — Semestre 2026-II**
**Docente:** Ramiro Grisales Montoya
**Proyecto:** Taller 6 (Fase Final) — SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL

| Campo | Detalle |
|---|---|
| **Documento** | `docs/16_estructura_informe_final.md` |
| **Título** | Estructura y guía de compilación del informe final PDF |
| **Versión** | Ronda 2 |
| **Autor** | Jose Miguel Sosa Cartagena |
| **Equipo** | Juan Sebastian Raigosa Gil, Jose Miguel Sosa Cartagena, Deysi Carolina Echavarria Soto |
| **Motor / herramienta** | PostgreSQL 18 / DBeaver 26.2.2 |
| **Repositorio** | https://github.com/desarrollosebas/Trabajofinal |
| **Fecha** | 17 de noviembre de 2026 |

---

# 16. Estructura del informe final PDF

## 16.1 Objetivo

Definir cómo se ensambla el informe final del Taller 6 a partir de los documentos `docs/00` a `docs/15`: portada, resumen, tabla de contenidos, capítulos, responsables, formato, exportación a PDF y entrega en el repositorio.

## 16.2 Producto final

| Elemento | Valor |
|---|---|
| **Archivo** | `BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf` |
| **Ubicación** | `report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf` |
| **Responsable de compilar** | Jose Miguel Sosa Cartagena |
| **Formato** | A4, español, citas y referencias en APA 7.ª edición |
| **Contenido** | Portada, resumen, tabla de contenidos, 16 secciones (`docs/00` a `docs/15`) y referencias |

## 16.3 Convención de numeración

Para que las referencias cruzadas no se contradigan, **el número del capítulo coincide con el número del archivo**:

- `docs/00` es la sección preliminar (introducción), sin número de capítulo.
- `docs/01` a `docs/15` son los capítulos 1 a 15.

Así, el diccionario de datos (`docs/08`) es el capítulo 8, el análisis de privacidad (`docs/14`) es el capítulo 14 y la guía de sustentación (`docs/15`) es el capítulo 15. Los documentos `14` y `15` ya numeran sus apartados internos de esta forma (14.1, 15.1, etc.), por eso **no se debe activar la numeración automática de secciones** al exportar (ver 16.8).

## 16.4 Portada institucional

Contenido de la portada, en este orden y centrado:

1. **INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO** (y logotipo institucional si el docente lo exige).
2. Facultad y programa académico: *completar según tu carrera*.
3. **Título:** SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL.
4. **Subtítulo:** Taller 6 (Fase Final) — Línea de profundización: integridad y calidad de datos con restricciones, dominios y tablas de cuarentena.
5. **Asignatura:** Bases de Datos I — Grupo 811.
6. **Integrantes:**
   - Juan Sebastian Raigosa Gil
   - Jose Miguel Sosa Cartagena
   - Deysi Carolina Echavarria Soto
7. **Docente:** Ramiro Grisales Montoya.
8. **Semestre:** 2026-II.
9. **Ciudad y fecha:** *completar* (noviembre de 2026).
10. **Repositorio:** https://github.com/desarrollosebas/Trabajofinal

## 16.5 Resumen y palabras clave

Texto propuesto para la página de resumen (apóyalo en las cifras verificadas; no las modifiques):

> **Resumen.** SolarDB es una base de datos relacional en PostgreSQL 18 que integra la telemetría de una microrred híbrida fotovoltaica y de baterías a partir del dataset OpenCEM v1.0.0. El proyecto aborda la integridad y la calidad de los datos mediante restricciones declarativas, doce dominios personalizados y una tabla de cuarentena. De 2,989,759 lecturas leídas de dos inversores, 2,965,337 (99.18%) fueron aceptadas en producción y 24,422 (0.82%) se aislaron en cuarentena por violar reglas de calidad físicas, de las cuales 24,375 corresponden a potencia activa mayor que la aparente. Se migraron además 25,178 registros de contexto operativo, de los cuales 204 se identificaron como de riesgo crítico para datos personales conforme a la Ley 1581 de 2012. La base ocupa aproximadamente 3.88 GB en disco. La arquitectura se organiza en tres esquemas (`solardb`, `staging` y `calidad`) y la migración se audita mediante lotes de carga.
>
> **Palabras clave:** calidad de datos, integridad referencial, PostgreSQL, dominios, cuarentena, microrred, protección de datos personales.

## 16.6 Tabla de contenidos del informe

Las 16 secciones corresponden uno a uno con los archivos `docs/00` a `docs/15`. Los títulos de los archivos que no fueron revisados para esta guía deben copiarse del encabezado de cada archivo.

| Capítulo | Archivo fuente | Título | Responsable |
|---|---|---|---|
| Introducción | `docs/00_*.md` | *Copiar del encabezado del archivo* | Equipo / Coordinador |
| 1 | `docs/01_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 2 | `docs/02_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 3 | `docs/03_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 4 | `docs/04_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 5 | `docs/05_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 6 | `docs/06_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 7 | `docs/07_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 8 | `docs/08_diccionario_datos.md` | Diccionario de datos | Jose Miguel Sosa Cartagena |
| 9 | `docs/09_diseno_fisico.md` | Diseño físico | Jose Miguel Sosa Cartagena |
| 10 | `docs/10_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 11 | `docs/11_resultados_migracion.md` | Resultados de la migración | Juan Sebastian Raigosa Gil |
| 12 | `docs/12_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 13 | `docs/13_*.md` | *Copiar del encabezado del archivo* | Según autoría |
| 14 | `docs/14_seguridad_y_privacidad.md` | Seguridad y privacidad de datos personales | Jose Miguel Sosa Cartagena |
| 15 | `docs/15_guia_sustentacion.md` | Guía de sustentación | Jose Miguel Sosa Cartagena |
| — | — | Referencias (APA 7.ª edición) | Jose Miguel Sosa Cartagena |

**Cómo saber la autoría real de un archivo:** en la raíz del repositorio ejecuta

```bash
git log --format="%an" -- docs/05_*.md | sort -u
```

(cambia `05` por el número que quieras comprobar) y ajusta la columna "Responsable".

Referencia de áreas, según el reparto del equipo:

| Área | Responsable |
|---|---|
| Arquitectura SolarDB: dominios, staging, cuarentena, migración masiva y DDL | Juan Sebastian Raigosa Gil |
| Modelado conceptual, modelo lógico, normalización 3FN y consultas SQL de negocio | Deysi Carolina Echavarria Soto |
| Diccionario de datos, diseño físico, privacidad (Ley 1581), guía de sustentación e informe PDF | Jose Miguel Sosa Cartagena |

## 16.7 Figuras y tablas

- Numera las figuras como **Figura 1, 2, …** con título debajo, y las tablas como **Tabla 1, 2, …** con título arriba, y cítalas en el texto.
- Incluye solo figuras que existan en el repositorio (por ejemplo, el diagrama entidad-relación o las capturas de DBeaver). No agregues figuras inventadas.
- Cuida que las tablas anchas (por ejemplo, las de 46 columnas del diccionario) no se salgan de la página; si es necesario, reduce la fuente de la tabla o aplica orientación horizontal a esa sección.
- Las cifras de las tablas deben coincidir con las del capítulo 11 (resultados de la migración). Verifica especialmente 2,965,337; 24,422; 25,178; y 3.88 GB.

## 16.8 Formato

| Elemento | Especificación recomendada |
|---|---|
| Tamaño de página | A4 |
| Márgenes | 2.5 cm por lado |
| Fuente del texto | Times New Roman 12 pt (o Arial/Calibri 11 pt) |
| Fuente del código | Consolas, 9 a 10 pt |
| Interlineado | 1.15 a 1.5 |
| Encabezados | Capítulo en nivel 1; apartados en niveles 2 y 3 |
| Numeración de páginas | Pie de página, centrada o derecha |
| Citas y referencias | APA 7.ª edición |

Si el docente indica otro formato, prevalece su indicación.

> **Importante:** los archivos `docs/` ya traen numeración manual en los títulos (por ejemplo, "14.1", "15.4"). Si activas numeración automática de secciones, los números se duplicarán.

## 16.9 Instrucciones de exportación a PDF

Elige **una** de las tres rutas.

### Ruta A — Pandoc (recomendada)

Genera un PDF con tabla de contenidos automática y un solo comando. Requisitos: [Pandoc](https://pandoc.org/) y un motor LaTeX (MiKTeX o TeX Live). Los comandos son para PowerShell en Windows.

**1) Prepara la carpeta y verifica los archivos**

```powershell
cd "C:\ruta\a\tu\carpeta\ULTIMOWORK"
New-Item -ItemType Directory -Force report | Out-Null

$archivos = Get-ChildItem docs\*.md |
    Where-Object { $_.Name -match '^(0\d|1[0-5])_' } |
    Sort-Object Name
$archivos | ForEach-Object Name
```

La lista debe mostrar **16 archivos** (del `00` al `15`) y no incluir el `16`. Si falta alguno, no continúes: revisa los nombres.

**2) Une los documentos con salto de página entre cada uno**

```powershell
$salida = "report\informe_completo.md"
Remove-Item $salida -ErrorAction SilentlyContinue
foreach ($a in $archivos) {
    Add-Content -Path $salida -Value "`n\newpage`n" -Encoding UTF8
    Get-Content $a.FullName -Raw -Encoding UTF8 | Add-Content -Path $salida -Encoding UTF8
}
```

**3) Crea `report/metadata.yaml`**

```yaml
---
title-meta: "SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL"
author-meta: "Raigosa Gil, Sosa Cartagena, Echavarria Soto"
lang: es-CO
---
```

**4) Crea la portada `report/portada.tex`** (ajusta los campos entre corchetes)

```latex
\begin{titlepage}
\centering
{\Large \textbf{INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO}\par}
\vspace{0.5cm}
{\large [Facultad y programa académico]\par}
\vspace{2cm}
{\LARGE \textbf{SolarDB: Integridad y calidad de datos en una microrred híbrida mediante PostgreSQL}\par}
\vspace{1cm}
{\large Taller 6 (Fase Final) — Bases de Datos I, Grupo 811\par}
\vspace{2cm}
{\large Juan Sebastian Raigosa Gil\par
Jose Miguel Sosa Cartagena\par
Deysi Carolina Echavarria Soto\par}
\vspace{1.5cm}
{\large Docente: Ramiro Grisales Montoya\par}
\vfill
{\large Semestre 2026-II\par
[Ciudad], noviembre de 2026\par}
\end{titlepage}
```

**5) Compila el PDF** (todo en una sola línea)

```powershell
pandoc report\metadata.yaml report\informe_completo.md -o report\BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf --pdf-engine=xelatex --include-before-body=report\portada.tex --toc --toc-depth=2 --top-level-division=chapter -V documentclass=report -V geometry:margin=2.5cm -V fontsize=11pt -V mainfont="Times New Roman" -V monofont="Consolas"
```

Notas:

- No uses `--number-sections` (ver 16.8).
- Si ves advertencias de caracteres faltantes (por ejemplo `≥`, `→`), cambia `mainfont` a `"Cambria"` o `"Segoe UI"`.
- Si el código SQL largo se sale del margen, reduce el tamaño del bloque de código o acorta la línea en el archivo `.md`.
- Revisa visualmente las tablas anchas; en un pipe table con líneas muy largas Pandoc puede comprimir las columnas.

### Ruta B — Word

1. Convierte a Word: `pandoc report\informe_completo.md -o report\informe.docx --toc`.
2. Abre `informe.docx` en Word y aplica el formato de 16.8 (estilos Título 1, 2 y 3, márgenes, fuente).
3. Inserta la portada al inicio y actualiza la tabla de contenidos (clic derecho → *Actualizar campo*).
4. Exporta: *Archivo → Exportar → Crear documento PDF/XPS* y guarda con el nombre de 16.2.

Sin Pandoc: abre cada `.md` en VS Code con la vista previa de Markdown, copia el contenido renderizado a Word y sigue desde el paso 2.

### Ruta C — Google Docs

1. En Google Docs activa el soporte de Markdown si tu versión lo ofrece (*Herramientas → Preferencias → Detectar Markdown*) y pega el contenido; o importa el `.docx` generado con Pandoc (Ruta B, paso 1).
2. Aplica los estilos de título y el formato de 16.8, inserta la portada y una tabla de contenidos (*Insertar → Tabla de contenidos*).
3. Descarga: *Archivo → Descargar → Documento PDF (.pdf)* y renombra con el nombre de 16.2.

## 16.10 Revisión antes de entregar

- [ ] Los 16 archivos (`00` a `15`) están incluidos y en orden.
- [ ] Todos los números coinciden con el capítulo 11: 2,989,759 leídas; 2,965,337 aceptadas (99.18%); 24,422 en cuarentena (0.82%); 25,178 de contexto; 24,375 / 38 / 8 / 1 por regla; ~3.88 GB.
- [ ] La cuadratura 2,965,337 + 24,422 = 2,989,759 aparece correctamente.
- [ ] La portada está completa, con integrantes, docente, grupo y semestre.
- [ ] La tabla de contenidos muestra los capítulos con su número de página.
- [ ] Figuras y tablas numeradas y citadas en el texto.
- [ ] Las referencias están en APA 7.ª edición e incluyen la cita de OpenCEM, la Ley 1581 de 2012 y el Decreto 1377 de 2013.
- [ ] No aparecen contraseñas, tokens ni credenciales.
- [ ] No se pegaron registros reales de `wsl_bash_history` ni otros datos personales del contexto en el informe.
- [ ] El PDF abre bien, el texto se puede seleccionar y los bloques de código no se cortan.
- [ ] El archivo tiene el nombre exacto y está en `report/`.

## 16.11 Entrega en GitHub

```bash
# 1. Configurar identidad (solo la primera vez)
git config --global user.name "Jose Miguel Sosa Cartagena"
git config --global user.email "jose.sosa216@pascualbravo.edu.co"

# 2. Actualizar y crear tu rama
cd "C:\ruta\a\tu\carpeta\ULTIMOWORK"
git checkout main
git pull origin main
git checkout -b jose/auditoria-e-informe-pdf

# 3. Commit de cada archivo
git add docs/08_diccionario_datos.md
git commit -m "docs: actualizar diccionario de datos con metricas reales post-migracion"

git add docs/09_diseno_fisico.md
git commit -m "docs: actualizar diseno fisico con tamanos reales en disco"

git add docs/14_seguridad_y_privacidad.md
git commit -m "docs: actualizar analisis Ley 1581 con metricas reales"

git add docs/15_guia_sustentacion.md
git commit -m "docs: actualizar guia de sustentacion con datos reales"

git add docs/16_estructura_informe_final.md
git commit -m "docs: agregar estructura del informe final PDF"

git add report/
git commit -m "report: agregar informe final PDF compilado"

# 4. Subir la rama
git push origin jose/auditoria-e-informe-pdf
```

Observaciones:

- `git add report/` también agregará `informe_completo.md`, `metadata.yaml` y `portada.tex`. Si solo quieres el PDF, usa `git add report/BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf`.
- Si `git checkout -b` indica que la rama ya existe, usa `git checkout jose/auditoria-e-informe-pdf`.
- Después del `push`, abre un *Pull Request* hacia `main` si el equipo así lo acordó con el coordinador.

## 16.12 Reparto sugerido para la sustentación

| Tema | Quién responde |
|---|---|
| Arquitectura, dominios, cuarentena y migración | Juan Sebastian Raigosa Gil |
| Modelo conceptual y lógico, normalización 3FN y consultas de negocio | Deysi Carolina Echavarria Soto |
| Diccionario de datos, diseño físico, privacidad (Ley 1581) y estructura del informe | Jose Miguel Sosa Cartagena |

Acuerden con anticipación quién abre, quién maneja DBeaver y quién cierra.

## 16.13 Referencias (APA 7.ª edición)

Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). *OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery* (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223

Congreso de la República de Colombia. (2012). *Ley Estatutaria 1581 de 2012, por la cual se dictan disposiciones generales para la protección de datos personales*.

Presidencia de la República de Colombia. (2013). *Decreto 1377 de 2013, por el cual se reglamenta parcialmente la Ley 1581 de 2012*.
