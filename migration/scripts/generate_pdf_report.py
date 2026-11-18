#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de compilación del Informe Final en PDF para SolarDB.
Genera el informe académico oficial requerido para el Taller 6 de Bases de Datos I.
Institución Universitaria Pascual Bravo - Medellín, Colombia.
"""

import os
import re
import sys
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.units import inch, cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

# ─────────────────────────────────────────────────────────────────────────────
# 1. CANVAS NUMERADO (Página X de Y + Encabezados Institucionales)
# ─────────────────────────────────────────────────────────────────────────────
class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, total_pages):
        # Omitir decoraciones en la portada (página 1)
        if self._pageNumber == 1:
            return

        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#4A5568"))

        # Encabezado superior
        self.drawString(
            54, 750,
            "SolarDB — Integridad y Calidad de Datos en una Microrred Híbrida | PostgreSQL 18"
        )
        self.drawRightString(
            558, 750,
            "IU Pascual Bravo · Grupo 811"
        )
        self.setStrokeColor(colors.HexColor("#CBD5E0"))
        self.setLineWidth(0.5)
        self.line(54, 744, 558, 744)

        # Pie de página inferior
        self.line(54, 45, 558, 45)
        self.drawString(
            54, 32,
            "Taller 6 — Bases de Datos I | Docente: Ramiro Grisales Montoya"
        )
        page_str = f"Página {self._pageNumber} de {total_pages}"
        self.drawRightString(558, 32, page_str)
        self.restoreState()


# ─────────────────────────────────────────────────────────────────────────────
# 2. CONFIGURACIÓN DE ESTILOS TIPOGRÁFICOS
# ─────────────────────────────────────────────────────────────────────────────
def get_report_styles():
    base_styles = getSampleStyleSheet()
    
    NAVY = colors.HexColor("#1B365D")
    SLATE = colors.HexColor("#2C5282")
    DARK = colors.HexColor("#2D3748")
    MUTED = colors.HexColor("#4A5568")

    styles = {
        'CoverTitle': ParagraphStyle(
            'CoverTitle', parent=base_styles['Normal'],
            fontName='Helvetica-Bold', fontSize=24, leading=28,
            textColor=NAVY, alignment=1, spaceAfter=12
        ),
        'CoverSubtitle': ParagraphStyle(
            'CoverSubtitle', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=12, leading=16,
            textColor=SLATE, alignment=1, spaceAfter=25
        ),
        'CoverInst': ParagraphStyle(
            'CoverInst', parent=base_styles['Normal'],
            fontName='Helvetica-Bold', fontSize=14, leading=18,
            textColor=NAVY, alignment=1, spaceAfter=6
        ),
        'CoverDept': ParagraphStyle(
            'CoverDept', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=10, leading=14,
            textColor=MUTED, alignment=1, spaceAfter=30
        ),
        'CoverMeta': ParagraphStyle(
            'CoverMeta', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=10, leading=15,
            textColor=DARK, alignment=1
        ),
        'H1': ParagraphStyle(
            'H1', parent=base_styles['Normal'],
            fontName='Helvetica-Bold', fontSize=16, leading=20,
            textColor=NAVY, spaceBefore=18, spaceAfter=8,
            keepWithNext=True
        ),
        'H2': ParagraphStyle(
            'H2', parent=base_styles['Normal'],
            fontName='Helvetica-Bold', fontSize=12, leading=16,
            textColor=SLATE, spaceBefore=12, spaceAfter=6,
            keepWithNext=True
        ),
        'H3': ParagraphStyle(
            'H3', parent=base_styles['Normal'],
            fontName='Helvetica-Bold', fontSize=10, leading=14,
            textColor=DARK, spaceBefore=8, spaceAfter=4,
            keepWithNext=True
        ),
        'Body': ParagraphStyle(
            'Body', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=9, leading=13,
            textColor=DARK, spaceAfter=6, alignment=4
        ),
        'Bullet': ParagraphStyle(
            'Bullet', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=8.5, leading=12,
            textColor=DARK, leftIndent=15, spaceAfter=3
        ),
        'Blockquote': ParagraphStyle(
            'Blockquote', parent=base_styles['Normal'],
            fontName='Helvetica-Oblique', fontSize=8.5, leading=12,
            textColor=MUTED, leftIndent=20, rightIndent=20,
            spaceBefore=6, spaceAfter=6
        ),
        'Code': ParagraphStyle(
            'Code', parent=base_styles['Normal'],
            fontName='Courier', fontSize=7.5, leading=10,
            textColor=colors.HexColor("#742A2A"),
            leftIndent=15, spaceBefore=4, spaceAfter=6
        ),
        'TableHeader': ParagraphStyle(
            'TableHeader', parent=base_styles['Normal'],
            fontName='Helvetica-Bold', fontSize=8, leading=10,
            textColor=colors.white, alignment=1
        ),
        'TableCell': ParagraphStyle(
            'TableCell', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=7.5, leading=10,
            textColor=DARK
        ),
        'TocItem': ParagraphStyle(
            'TocItem', parent=base_styles['Normal'],
            fontName='Helvetica', fontSize=9, leading=14,
            textColor=DARK
        )
    }
    return styles


# ─────────────────────────────────────────────────────────────────────────────
# 3. PARSER Y LIMPIADOR DE TEXTO MARKDOWN A ELEMENTOS REPORTLAB
# ─────────────────────────────────────────────────────────────────────────────
def clean_markdown_inline(text):
    """Convierte marcas markdown básicas a etiquetas HTML soportadas por ReportLab sin colisiones de XML."""
    if not text:
        return ""
    
    # Escapar ampersands primero
    text = text.replace('&', '&amp;')

    # 1. Extraer código inline (`...`) a un almacén temporal protegido
    code_store = []
    def save_code(match):
        code_content = match.group(1).replace('<', '&lt;').replace('>', '&gt;')
        idx = len(code_store)
        code_store.append(f'<font name="Courier" color="#742A2A">{code_content}</font>')
        return f"§§CODE{idx}§§"

    text = re.sub(r'`([^`]+)`', save_code, text)

    # 2. Negrita (**texto**)
    text = re.sub(r'\*\*([^*]+)\*\*', r'§B§\1§/B§', text)

    # 3. Cursiva (*texto*) solo delimitada por asteriscos sin colisionar con underscores técnicos
    text = re.sub(r'(?<!\w)\*([^*]+)\*(?!\w)', r'§I§\1§/I§', text)

    # 4. Escapar < y > que queden en el texto crudo
    text = text.replace('<', '&lt;').replace('>', '&gt;')

    # 5. Restaurar tags válidos
    text = text.replace('§B§', '<b>').replace('§/B§', '</b>')
    text = text.replace('§I§', '<i>').replace('§/I§', '</i>')

    # 6. Restaurar bloques de código inline
    for idx, code_html in enumerate(code_store):
        text = text.replace(f"§§CODE{idx}§§", code_html)

    return text


def parse_markdown_table(table_lines, styles):
    """Convierte líneas de tabla Markdown a un flowable Table de ReportLab estilizado."""
    data = []
    for line in table_lines:
        line = line.strip()
        if not line or not line.startswith('|'):
            continue
        # Descartar filas separadoras tipo |---|---|
        if re.match(r'^\|[\s\-:|]+\|$', line):
            continue
        parts = [p.strip() for p in line.strip('|').split('|')]
        data.append(parts)

    if not data or len(data) < 1:
        return None

    # Normalizar número de columnas
    num_cols = max(len(row) for row in data)
    normalized_data = []
    
    # Ancho total disponible en A4 con márgenes de 54pt: ~504 pt
    total_width = 504.0
    col_width = total_width / float(num_cols)

    for i, row in enumerate(data):
        while len(row) < num_cols:
            row.append("")
        new_row = []
        for cell in row:
            style = styles['TableHeader'] if i == 0 else styles['TableCell']
            clean_cell = clean_markdown_inline(cell)
            new_row.append(Paragraph(clean_cell, style))
        normalized_data.append(new_row)

    t = Table(normalized_data, colWidths=[col_width] * num_cols, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1B365D")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor("#F7FAFC")]),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E0")),
    ]))
    return t


def parse_markdown_file(file_path, styles):
    """Lee un archivo Markdown y produce una lista de flowables."""
    if not os.path.exists(file_path):
        return []

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    flowables = []
    in_code_block = False
    code_lines = []
    in_table = False
    table_lines = []

    for line in lines:
        raw_line = line.rstrip('\r\n')

        # Bloques de código
        if raw_line.strip().startswith('```'):
            if in_code_block:
                in_code_block = False
                code_text = "<br/>".join([clean_markdown_inline(cl.replace(' ', '&nbsp;')) for cl in code_lines[:35]])
                if len(code_lines) > 35:
                    code_text += "<br/><i>[... código recortado para presentación ...]</i>"
                flowables.append(Paragraph(code_text, styles['Code']))
                flowables.append(Spacer(1, 4))
                code_lines = []
            else:
                in_code_block = True
                code_lines = []
            continue

        if in_code_block:
            code_lines.append(raw_line)
            continue

        # Detección de tablas Markdown
        if raw_line.strip().startswith('|') and raw_line.strip().endswith('|'):
            in_table = True
            table_lines.append(raw_line)
            continue
        elif in_table:
            in_table = False
            t = parse_markdown_table(table_lines, styles)
            if t:
                flowables.append(Spacer(1, 4))
                flowables.append(t)
                flowables.append(Spacer(1, 6))
            table_lines = []

        line_strip = raw_line.strip()
        if not line_strip:
            continue

        # Línea horizontal
        if re.match(r'^-{3,}$', line_strip) or re.match(r'^\*{3,}$', line_strip):
            flowables.append(Spacer(1, 4))
            flowables.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#CBD5E0"), spaceAfter=6))
            continue

        # Encabezados
        if line_strip.startswith('#### '):
            flowables.append(Paragraph(clean_markdown_inline(line_strip[5:]), styles['H3']))
        elif line_strip.startswith('### '):
            flowables.append(Paragraph(clean_markdown_inline(line_strip[4:]), styles['H3']))
        elif line_strip.startswith('## '):
            flowables.append(Paragraph(clean_markdown_inline(line_strip[3:]), styles['H2']))
        elif line_strip.startswith('# '):
            flowables.append(Paragraph(clean_markdown_inline(line_strip[2:]), styles['H1']))
        # Blockquotes
        elif line_strip.startswith('> '):
            flowables.append(Paragraph(clean_markdown_inline(line_strip[2:]), styles['Blockquote']))
        # Viñetas
        elif line_strip.startswith('- ') or line_strip.startswith('* '):
            bullet_text = f"• {clean_markdown_inline(line_strip[2:])}"
            flowables.append(Paragraph(bullet_text, styles['Bullet']))
        elif re.match(r'^\d+\.\s', line_strip):
            flowables.append(Paragraph(clean_markdown_inline(line_strip), styles['Bullet']))
        # Párrafos normales
        else:
            flowables.append(Paragraph(clean_markdown_inline(line_strip), styles['Body']))

    # Si quedó tabla pendiente al final
    if in_table and table_lines:
        t = parse_markdown_table(table_lines, styles)
        if t:
            flowables.append(t)
            flowables.append(Spacer(1, 6))

    return flowables


# ─────────────────────────────────────────────────────────────────────────────
# 4. GENERACIÓN DEL DOCUMENTO COMPLETO
# ─────────────────────────────────────────────────────────────────────────────
def build_final_pdf(output_pdf_path):
    print(f"Iniciando compilación de informe final en: {output_pdf_path}...")
    doc = SimpleDocTemplate(
        output_pdf_path,
        pagesize=A4,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = get_report_styles()
    story = []

    # ── PORTADA INSTITUCIONAL ─────────────────────────────────────────────────
    story.append(Spacer(1, 40))
    story.append(Paragraph("INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO", styles['CoverInst']))
    story.append(Paragraph("FACULTAD DE INGENIERÍA — DEPARTAMENTO DE SISTEMAS", styles['CoverDept']))
    story.append(Spacer(1, 20))
    
    story.append(HRFlowable(width="80%", thickness=2, color=colors.HexColor("#1B365D"), spaceAfter=20))
    story.append(Paragraph("SolarDB: Integridad y Calidad de Datos en una Microrred Híbrida mediante PostgreSQL", styles['CoverTitle']))
    story.append(Paragraph("Taller 6 — Bases de Datos I · Grupo 811 · Semestre 2026-II<br/>Línea de Profundización: Integridad y calidad de datos con restricciones, dominios y tablas de cuarentena", styles['CoverSubtitle']))
    story.append(HRFlowable(width="80%", thickness=1, color=colors.HexColor("#2C5282"), spaceAfter=30))
    
    story.append(Spacer(1, 40))
    meta_text = """
    <b>Integrantes del Equipo:</b><br/>
    Juan Sebastian Raigosa Gil (Líder / Arquitectura y Migración)<br/>
    Jose Miguel Sosa Cartagena (Diseño Físico, Privacidad y Documentación)<br/>
    Deysi Carolina Echavarria Soto (Modelado, Analítica SQL y Pruebas de Integridad)<br/><br/>
    <b>Docente Titular:</b> Ramiro Grisales Montoya<br/>
    <b>Dataset Base:</b> OpenCEM v1.0.0 (DOI: 10.5281/zenodo.21436223)<br/>
    <b>Repositorio Oficial:</b> https://github.com/desarrollosebas/Trabajofinal<br/><br/>
    <b>Medellín, Colombia — Noviembre de 2026</b>
    """
    story.append(Paragraph(meta_text, styles['CoverMeta']))
    story.append(PageBreak())

    # ── RESUMEN EJECUTIVO Y TABLA DE CONTENIDOS ───────────────────────────────
    story.append(Paragraph("Resumen Ejecutivo y Métricas Principales", styles['H1']))
    summary_text = """
    El presente informe documenta la solución integral de ingeniería desarrollada para el <b>Taller 6 de Bases de Datos I</b>.
    El proyecto <b>SolarDB</b> consolida una base de datos relacional robusta en <b>PostgreSQL 18</b> alimentada con 
    <b>2,989,759 lecturas reales</b> de telemetría eléctrica provenientes del dataset <i>OpenCEM v1.0.0</i> (CUHK-Shenzhen).<br/><br/>
    Mediante una arquitectura multiesquema (<code>staging</code>, <code>calidad</code>, <code>solardb</code>) y 
    <b>12 dominios personalizados (CREATE DOMAIN)</b>, el sistema garantizó la integridad del dato a nivel de motor. 
    El balance final arrojó <b>2,965,337 filas aceptadas en producción (3.82 GB)</b> y <b>24,422 filas aisladas en cuarentena (34 MB)</b> 
    con trazabilidad JSONB y cuadratura matemática exacta. Además, se migraron <b>25,178 registros de contexto</b> cumpliendo 
    con las directrices de privacidad de la <b>Ley 1581 de 2012</b>.
    """
    story.append(Paragraph(summary_text, styles['Body']))
    story.append(Spacer(1, 10))

    # Tabla de métricas ejecutivas
    exec_data = [
        ["Indicador de Gestión", "Meta / Requisito", "Valor Real Obtenido", "Evaluación"],
        ["Lecturas analizadas (SQLite)", "≥ 1,000,000", "2,989,759 filas", "Superado (298.9%)"],
        ["Lecturas en producción (solardb)", "≥ 1,000,000", "2,965,337 filas (99.18%)", "Aprobado certificado"],
        ["Lecturas en cuarentena (calidad)", "Trazabilidad", "24,422 filas (0.82%)", "Aisladas en JSONB"],
        ["Registros de contexto migrados", "100%", "25,178 filas (100.0%)", "Auditados con flag PII"],
        ["Cuadratura matemática", "Coherencia total", "2,965,337 + 24,422 = 2,989,759", "Exacta (0 error)"],
        ["Almacenamiento total en disco", "N/A", "≈ 3.88 GB (PostgreSQL 18)", "Verificado en disco"]
    ]
    t_exec = Table([[Paragraph(c, styles['TableHeader'] if i == 0 else styles['TableCell']) for c in row] for i, row in enumerate(exec_data)], colWidths=[150, 95, 155, 104])
    t_exec.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#1B365D")),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E0")),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor("#F7FAFC")]),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(t_exec)
    story.append(Spacer(1, 15))

    story.append(Paragraph("Tabla de Contenidos del Informe", styles['H2']))
    toc_entries = [
        ("Capítulo 0 — Requisitos y Auditoría del Taller", "docs/00_requisitos_y_auditoria.md"),
        ("Capítulo 1 — Inventario del Dataset OpenCEM", "docs/01_inventario_dataset.md"),
        ("Capítulo 2 — Diagnóstico de Calidad y Detección de Anomalías", "docs/02_diagnostico_calidad.md"),
        ("Capítulo 3 — Diseño Arquitectónico de SolarDB", "docs/03_diseno_solar_db.md"),
        ("Capítulo 4 — Matriz de Reglas de Calidad y Cuarentena", "docs/04_matriz_reglas_calidad.md"),
        ("Capítulo 5 — Modelo Conceptual y Formato de Almacenamiento", "docs/05_modelo_conceptual.md"),
        ("Capítulo 6 — Modelo Lógico Relacional y Restricciones", "docs/06_modelo_logico.md"),
        ("Capítulo 7 — Demostración Formal de Normalización hasta 3FN", "docs/07_normalizacion_3FN.md"),
        ("Capítulo 8 — Diccionario de Datos Exhaustivo", "docs/08_diccionario_datos.md"),
        ("Capítulo 9 — Diseño Físico, Índices y Almacenamiento en Disco", "docs/09_diseno_fisico.md"),
        ("Capítulo 10 — Estrategia de Migración y Optimización", "docs/10_estrategia_migracion.md"),
        ("Capítulo 11 — Resultados Oficiales y Certificación de la Migración", "docs/11_resultados_migracion.md"),
        ("Capítulo 12 — Consultas Analíticas, Vistas y Planes EXPLAIN ANALYZE", "docs/12_consultas_vistas_indices.md"),
        ("Capítulo 13 — Informe de Evidencias de Pruebas de Integridad", "docs/13_pruebas_solar_db.md"),
        ("Capítulo 14 — Seguridad y Privacidad de Datos Personales (Ley 1581)", "docs/14_seguridad_y_privacidad.md"),
        ("Capítulo 15 — Guía de Sustentación Oral y Demostración en Vivo", "docs/15_guia_sustentacion.md"),
    ]
    for title, path in toc_entries:
        story.append(Paragraph(f"• <b>{title}</b>", styles['TocItem']))
    story.append(PageBreak())

    # ── PROCESAMIENTO MODULAR DE CADA CAPÍTULO (docs/00 a docs/15) ────────────
    for title, doc_file in toc_entries:
        full_path = os.path.join(os.getcwd(), doc_file)
        if not os.path.exists(full_path):
            continue
        print(f"Procesando e integrando: {doc_file}...")
        story.append(Paragraph(title, styles['H1']))
        story.append(Spacer(1, 6))
        
        doc_elements = parse_markdown_file(full_path, styles)
        # Omitir el primer título redundante si coincide
        if doc_elements and isinstance(doc_elements[0], Paragraph) and doc_elements[0].style.name == 'H1':
            doc_elements = doc_elements[1:]
            
        story.extend(doc_elements)
        story.append(Spacer(1, 10))
        story.append(PageBreak())

    # ── REFERENCIAS BIBLIOGRÁFICAS (APA 7ª EDICIÓN) ───────────────────────────
    story.append(Paragraph("Referencias Bibliográficas", styles['H1']))
    refs = [
        "Bartels, T. S., Wu, R., Lu, X., Chen, Y., Lu, Y., Xia, F., Yang, H., Chen, Y., & Li, T. (2026). OpenCEM: Multimodal photovoltaic and battery microgrid dataset with context records and sky imagery (Version 1.0.0) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.21436223",
        "Congreso de la República de Colombia. (2012). Ley Estatutaria 1581 de 2012: Por la cual se dictan disposiciones generales para la protección de datos personales. Diario Oficial No. 48.587.",
        "Congreso de la República de Colombia. (2008). Ley 1266 de 2008: Por la cual se dictan las disposiciones generales del hábeas data y se regula el manejo de la información contenida en bases de datos personales. Diario Oficial No. 47.219.",
        "Elmasri, R., & Navathe, S. B. (2015). Fundamentals of Database Systems (7th ed.). Pearson.",
        "PostgreSQL Global Development Group. (2026). PostgreSQL 18 Documentation. https://www.postgresql.org/docs/18/",
        "Silberschatz, A., Korth, H. F., & Sudarshan, S. (2020). Database System Concepts (7th ed.). McGraw-Hill."
    ]
    for r in refs:
        story.append(Paragraph(f"• {r}", styles['Bullet']))
        story.append(Spacer(1, 4))

    # Construir documento final
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"¡Compilación final exitosa! Documento generado: {output_pdf_path}")


if __name__ == '__main__':
    output_dir = os.path.join(os.getcwd(), "report")
    os.makedirs(output_dir, exist_ok=True)
    target_pdf = os.path.join(output_dir, "BDI_Taller6_RaigosaGil_SosaCartagena_EchavarriaSoto.pdf")
    build_final_pdf(target_pdf)
