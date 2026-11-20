"""
build_master_presentation.py
-----------------------------
Genera presentacion/SolarDB_Final_Unificada.pptx (11 slides)
unificando SolarDB.pptx y SolarDB-EXPO.pptx.

Corrige la clonación de slides copiando también las relaciones
de imagen (blip embed) para evitar "No se puede mostrar la imagen".
"""

import copy
from pptx import Presentation
from pptx.util import Pt
from pptx.dml.color import RGBColor

# ── Namespace constants ──────────────────────────────────────────────────────
R_NS = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
A_NS = '{http://schemas.openxmlformats.org/drawingml/2006/main}'

# ── Design-system colours ────────────────────────────────────────────────────
C_HEADER  = RGBColor(0x27, 0x46, 0x4F)
C_TITLE   = RGBColor(0x10, 0x2D, 0x4D)
C_BODY    = RGBColor(0x23, 0x3A, 0x50)
C_BLACK   = RGBColor(0x00, 0x00, 0x00)
C_LABEL   = RGBColor(0x06, 0x2A, 0x33)
C_BADGE   = RGBColor(0x3F, 0x5F, 0x69)


def set_run(shape, text, font_name, size_pt, color, bold=False):
    """Overwrite every run in shape with *text*, preserving paragraph count."""
    if not shape.has_text_frame:
        return
    p = shape.text_frame.paragraphs[0]
    # Clear extra runs
    while len(p.runs) > 1:
        p.runs[-1]._r.getparent().remove(p.runs[-1]._r)
    if len(p.runs) == 0:
        r = p.add_run()
    else:
        r = p.runs[0]
    r.text = text
    r.font.name = font_name
    r.font.size = Pt(size_pt)
    r.font.color.rgb = color
    r.font.bold = bold


def clone_slide(prs, source_index):
    """
    Clone a slide INCLUDING its image relationships so that decorative
    blip-fill images are preserved on the new slide.
    """
    source = prs.slides[source_index]
    layout = source.slide_layout
    new_slide = prs.slides.add_slide(layout)

    # Remove layout-generated placeholder shapes so they don't stack
    placeholders_to_remove = []
    for sp_elem in list(new_slide.shapes._spTree):
        tag = sp_elem.tag.split('}')[-1]
        if tag in ('sp', 'pic', 'grpSp', 'cxnSp'):
            placeholders_to_remove.append(sp_elem)
    for sp_elem in placeholders_to_remove:
        new_slide.shapes._spTree.remove(sp_elem)

    # Build a map of old rId → image Part from the source slide
    image_parts = {}
    for rId_key in source.part.rels:
        rel = source.part.rels[rId_key]
        if 'image' in rel.reltype:
            image_parts[rId_key] = rel.target_part

    # Deep-copy every shape element from source
    for shp in source.shapes:
        el = copy.deepcopy(shp.element)
        new_slide.shapes._spTree.append(el)

    # Now fix blip embed references: add image rels to the new slide
    # and update the rId pointers in the copied XML.
    for blip in new_slide.shapes._spTree.iter(A_NS + 'blip'):
        old_rId = blip.get(R_NS + 'embed')
        if old_rId and old_rId in image_parts:
            # relate_to returns the new rId assigned by the package
            new_rId = new_slide.part.relate_to(
                image_parts[old_rId],
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
            )
            blip.set(R_NS + 'embed', new_rId)

    return new_slide


def setup_notes(slide, text, sample_ns):
    """Set speaker notes on *slide*, copying placeholders from *sample_ns*."""
    ns = slide.notes_slide
    if len(ns.shapes) == 0:
        for shp in sample_ns.shapes:
            ns.shapes._spTree.append(copy.deepcopy(shp.element))
    ns.notes_text_frame.text = text


# ═══════════════════════════════════════════════════════════════════════════════
def build():
    prs = Presentation('presentacion/SolarDB-EXPO.pptx')
    notes_donor = prs.slides[0].notes_slide  # used to seed empty notes

    # ── Slide 1 : Portada ─────────────────────────────────────────────────
    s = prs.slides[0]
    for shp in s.shapes:
        if shp.name == "Text 5" and shp.has_text_frame:
            tf = shp.text_frame
            tf.clear()
            lines = [
                "Juan Sebastian Raigosa Gil · Líder / Arquitectura y Pipeline",
                "Deysi Carolina Echavarria Soto · Modelado y Analítica SQL",
                "Jose Miguel Sosa Cartagena · Diseño Físico, Privacidad y Doc.",
            ]
            for i, line in enumerate(lines):
                p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
                p.text = line
                p.font.name = "Plus Jakarta Sans"
                p.font.size = Pt(11)
                p.font.color.rgb = C_BODY

    setup_notes(s, (
        "PRESENTA: Juan Sebastian (o el equipo completo).\n"
        "Buenas tardes profesor Ramiro y compañeros. Presentamos el proyecto final "
        "de Bases de Datos I: SolarDB.\n"
        "El equipo: Juan Sebastian (arquitectura y pipeline), Deysi Carolina "
        "(modelado y analítica SQL), Jose Miguel (diseño físico, privacidad Ley 1581 "
        "y documentación).\n"
        "Objetivo: PostgreSQL 18 como fuente única de verdad para telemetría de una "
        "microrred híbrida con paneles y baterías."
    ), notes_donor)

    # ── Slide 2 : Diagnóstico Operacional ─────────────────────────────────
    setup_notes(prs.slides[1], (
        "PRESENTA: Deysi Carolina.\n"
        "Los datos provienen del dataset OpenCEM v1.0.0 (CUHK-Shenzhen). "
        "Una microrred híbrida con paneles fotovoltaicos, baterías LiFePO4, "
        "2 inversores bidireccionales y red pública genera mediciones de voltaje, "
        "corriente, potencias y temperaturas cada 12.58 s.\n"
        "Con ~3 millones de lecturas anuales, el desafío: ¿cómo distinguir una "
        "anomalía física real de una descalibración o desfase de muestreo?"
    ), notes_donor)

    # ── Slide 3 : Arquitectura Propuesta ──────────────────────────────────
    setup_notes(prs.slides[2], (
        "PRESENTA: Juan Sebastian.\n"
        "SolarDB: PostgreSQL 18 como Fuente Única de Verdad.\n"
        "1) Centralización relacional robusta.\n"
        "2) Segregación: datos válidos vs sospechosos (tabla cuarentena + JSONB).\n"
        "3) Almacenamiento semiestructurado con JSONB e índices GIN."
    ), notes_donor)

    # ── Slide 4 : 3 Esquemas ─────────────────────────────────────────────
    setup_notes(prs.slides[3], (
        "PRESENTA: Juan Sebastian.\n"
        "3 esquemas: STAGING (carga COPY masiva), CALIDAD (reglas, lotes, cuarentena), "
        "SOLARDB (producción, 12 dominios, vistas analíticas)."
    ), notes_donor)

    # ── Slide 5 : Modelo Relacional y 3FN ─────────────────────────────────
    s5 = prs.slides[4]
    for shp in s5.shapes:
        if shp.name == "Text 16" and shp.has_text_frame:
            set_run(shp,
                    "Formato ancho (46 cols síncronas) evitando 125 M filas. "
                    "3FN: 6 catálogos dimensionales + 12 dominios CHECK.",
                    "Plus Jakarta Sans", 13, C_BODY)

    setup_notes(s5, (
        "PRESENTA: Deysi Carolina.\n"
        "Decisión formato ancho vs largo: largo hubiera creado 125 M filas (42 × 3 M). "
        "El ancho (46 cols) representa el vector síncrono instantáneo.\n"
        "Normalización 3FN: 6 catálogos (sitio, subsistema, inversor, tipo_contexto, "
        "unidad_medida, variable_física). Clave compuesta (inversor_id, ts_lectura). "
        "ON DELETE RESTRICT."
    ), notes_donor)

    # ── Slide 6 : Pipeline ETL ────────────────────────────────────────────
    setup_notes(prs.slides[5], (
        "PRESENTA: Jose Miguel (o Juan Sebastian).\n"
        "Pipeline 3 fases: Extracción → Validación PL/pgSQL → Dispersión "
        "(producción o cuarentena).\n"
        "Aclaración metodológica: 0 Hz o NULL en corriente = parada nocturna o "
        "modo isla, NO es error de sensor."
    ), notes_donor)

    # ── Slide 7 : Métricas de Ejecución ───────────────────────────────────
    s7 = prs.slides[6]
    for shp in s7.shapes:
        if shp.name == "Text 19" and shp.has_text_frame:
            set_run(shp,
                    "Cuadratura: 2.965.337 + 24.422 = 2.989.759 (Δ = 0). "
                    "~3,88 GB en PostgreSQL 18. Índice GIN sobre JSONB.",
                    "Plus Jakarta Sans", 13, C_BLACK)
        elif shp.name == "Text 20" and shp.has_text_frame:
            set_run(shp, "     07", "Red Hat Mono", 10.5, C_BADGE)

    setup_notes(s7, (
        "PRESENTA: Juan Sebastian.\n"
        "2.989.759 lecturas origen (≈ 3× el mínimo de 1 M del profesor). "
        "2.965.337 aceptadas (99.18 %) + 24.422 cuarentena (0.82 %). "
        "Delta exacto = 0. ~3.88 GB. 25.178 contextos operativos."
    ), notes_donor)

    # ── Slide 8 : Cuarentena (clonado de Slide 7 con imágenes) ───────────
    s8 = clone_slide(prs, 6)
    shape_map_8 = {
        "Text 0":  ("ANÁLISIS DE CUARENTENA",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 1":  ("Taxonomía física de las 24.422 lecturas aisladas",
                     "Chakra Petch SemiBold", 35, C_TITLE),
        "Text 4":  ("24.375",
                     "Chakra Petch Bold", 44, C_BODY),
        "Text 5":  ("R_P_MAYOR_S (99.8 %)",
                     "Jura SemiBold", 12, C_LABEL),
        "Text 6":  ("Violación P ≤ S = |V|·|I| por desfase temporal Modbus en transitorios rápidos de sol/carga.",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 7":  ("POTENCIA ACTIVA > APARENTE",
                     "Red Hat Mono Medium", 11, C_BODY),
        "Text 9":  ("38",
                     "Chakra Petch Bold", 44, C_BLACK),
        "Text 10": ("R_TEMP1_IMPOSIBLE",
                     "Jura SemiBold", 12, C_LABEL),
        "Text 11": ("Sensor reportó -20.3 °C en Shenzhen (mínima histórica 0.2 °C). Circuito abierto.",
                     "Plus Jakarta Sans", 13.5, C_BLACK),
        "Text 12": ("FALLA TÉRMICA DE SENSOR",
                     "Red Hat Mono Medium", 11, C_BLACK),
        "Text 14": ("8 y 1",
                     "Chakra Petch Bold", 44, C_BLACK),
        "Text 15": ("MAGNITUDES NEGATIVAS",
                     "Jura SemiBold", 12, C_LABEL),
        "Text 16": ("8 filas con potencia aparente negativa y 1 con corriente negativa en sensor monofásico.",
                     "Plus Jakarta Sans", 13.5, C_BLACK),
        "Text 17": ("LECTURAS ESPURIAS",
                     "Red Hat Mono Medium", 11, C_BLACK),
        "Text 19": ("TRAZABILIDAD JSONB: Cada registro en calidad.registro_cuarentena conserva fila, regla, "
                     "motivo y ciclo PENDIENTE → CORREGIDO → REPROCESADO.",
                     "Plus Jakarta Sans", 13.5, C_BLACK),
        "Text 20": ("     08",
                     "Red Hat Mono", 10.5, C_BADGE),
    }
    for shp in s8.shapes:
        if shp.name in shape_map_8:
            t, fn, sz, clr = shape_map_8[shp.name]
            set_run(shp, t, fn, sz, clr)

    setup_notes(s8, (
        "PRESENTA: Juan Sebastian.\n"
        "Corazón de la línea de profundización.\n"
        "• 24.375 (99.8 %) → R_P_MAYOR_S: P > S por desfase Modbus en transitorios.\n"
        "• 38 → R_TEMP1_IMPOSIBLE: -20.3 °C en Shenzhen (circuito abierto).\n"
        "• 8 → R_LINEPOWERVA_NEG: potencia aparente negativa.\n"
        "• 1 → R_LINECURRA_NEG: corriente negativa en sensor monofásico.\n"
        "Ningún dato borrado: todo respaldado como JSONB para auditoría."
    ), notes_donor)

    # ── Slide 9 : Analítica de Negocio (clonado de Slide 4) ──────────────
    s9 = clone_slide(prs, 3)
    shape_map_9 = {
        "Text 0":  ("ANALÍTICA DE NEGOCIO Y VISTAS",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 1":  ("10 consultas analíticas avanzadas y vistas SQL",
                     "Chakra Petch SemiBold", 35, C_TITLE),
        "Text 3":  ("1. INTEGRACIÓN DE ENERGÍA",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 4":  ("Integración trapezoidal ∫P(t)dt en kWh diarios y mensuales "
                     "para generación solar, consumo de carga e inyección a red "
                     "con EXTRACT(EPOCH...).",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 5":  ("2. ANALÍTICA DE OPERACIÓN",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 6":  ("Hora pico solar con RANK(). Factor de carga: Cómputo (53.8 %) "
                     "vs HVAC (46.2 %). Alerta descarga batería SOC < 20 %.",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 7":  ("3. OPTIMIZACIÓN Y VISTAS",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 8":  ("Vistas v_resumen_diario_energia y v_estado_baterias. "
                     "EXPLAIN ANALYZE: índice B-Tree (inversor_id, ts_lectura DESC) "
                     "e índice GIN sobre JSONB.",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 11": ("     09",
                     "Red Hat Mono", 10.5, C_BADGE),
    }
    for shp in s9.shapes:
        if shp.name in shape_map_9:
            t, fn, sz, clr = shape_map_9[shp.name]
            set_run(shp, t, fn, sz, clr)

    setup_notes(s9, (
        "PRESENTA: Deysi Carolina.\n"
        "10 consultas + 3 vistas sobre 2.9 M lecturas limpias.\n"
        "1) Energía real generada/consumida con integración trapezoidal (kWh).\n"
        "2) Hora pico solar (RANK), factor de carga cómputo vs HVAC, alerta SOC < 20 %.\n"
        "3) Vistas de producción + optimización EXPLAIN ANALYZE con índices B-Tree y GIN."
    ), notes_donor)

    # ── Slide 10 : Validación + Privacidad + Demo (clonado de Slide 4) ───
    s10 = clone_slide(prs, 3)
    shape_map_10 = {
        "Text 0":  ("VALIDACIÓN Y DEMOSTRACIÓN",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 1":  ("Pruebas de integridad, Ley 1581 y demo en vivo",
                     "Chakra Petch SemiBold", 35, C_TITLE),
        "Text 3":  ("1. 10 PRUEBAS AUTOMATIZADAS",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 4":  ("Batería formal con excepciones controladas. SQLSTATE: "
                     "23514 (CHECK dominio), 23505 (UNIQUE temporal), "
                     "23503 (FK huérfana), 00000 (inserción válida).",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 5":  ("2. PRIVACIDAD (LEY 1581)",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 6":  ("204 registros de wsl_bash_history con usuarios, correos y "
                     "rutas reales, identificados y protegidos con "
                     "contiene_datos_personales = TRUE.",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 7":  ("3. RUTA DEMO EN DBEAVER",
                     "Red Hat Mono Medium", 11, C_HEADER),
        "Text 8":  ("En vivo: 1) calidad.v_dashboard_calidad; "
                     "2) sql/13_pruebas_integridad.sql; "
                     "3) Inspección JSONB en registro_cuarentena.",
                     "Plus Jakarta Sans", 13.5, C_BODY),
        "Text 11": ("     10",
                     "Red Hat Mono", 10.5, C_BADGE),
    }
    for shp in s10.shapes:
        if shp.name in shape_map_10:
            t, fn, sz, clr = shape_map_10[shp.name]
            set_run(shp, t, fn, sz, clr)

    setup_notes(s10, (
        "PRESENTA: Jose Miguel.\n"
        "10 pruebas automatizadas: cada una viola una restricción a propósito y "
        "verifica el SQLSTATE devuelto por PostgreSQL.\n"
        "Privacidad (Ley 1581): 204 registros de bash_history con datos personales "
        "clasificados y enmascarados.\n"
        "Demo en DBeaver: v_dashboard_calidad → pruebas de integridad → inspección JSONB."
    ), notes_donor)

    # ── Mover Slide de Conclusiones al final ──────────────────────────────
    # El slide original 8 (Síntesis) quedó en index 7 después de las inserciones
    # lo movemos al final para que sea el slide 11.
    sldIdLst = prs.slides._sldIdLst
    concl_elem = sldIdLst[7]
    sldIdLst.remove(concl_elem)
    sldIdLst.append(concl_elem)

    s11 = prs.slides[10]
    for shp in s11.shapes:
        if shp.name == "Text 16" and shp.has_text_frame:
            set_run(shp, "     11", "Red Hat Mono", 10.5, C_BADGE)

    setup_notes(s11, (
        "PRESENTA: Juan Sebastian (o los tres juntos).\n"
        "SolarDB demuestra:\n"
        "1) Centralización con 12 dominios que protegen la física.\n"
        "2) Trazabilidad absoluta sin borrar datos (cuarentena JSONB).\n"
        "3) Flexibilidad semiestructurada con JSONB.\n"
        "Muchas gracias por su atención. ¿Preguntas?"
    ), notes_donor)

    # ── Guardar ───────────────────────────────────────────────────────────
    out = 'presentacion/SolarDB_Final_Unificada.pptx'
    prs.save(out)
    print(f"✓ Guardado: {out}  ({len(prs.slides)} slides)")


if __name__ == "__main__":
    build()
