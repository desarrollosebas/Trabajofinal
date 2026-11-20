import copy
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

def set_shape_text_styled(shape, text, font_name="Plus Jakarta Sans", font_size_pt=13.5, color_rgb=RGBColor(0x23, 0x3A, 0x50), bold=False):
    if not shape.has_text_frame:
        return
    tf = shape.text_frame
    if len(tf.paragraphs) == 0:
        p = tf.add_paragraph()
    else:
        p = tf.paragraphs[0]
        # remove extra paragraphs if any
        while len(tf.paragraphs) > 1:
            p_extra = tf.paragraphs[-1]._p
            p_extra.getparent().remove(p_extra)
    
    if len(p.runs) == 0:
        r = p.add_run()
    else:
        r = p.runs[0]
        while len(p.runs) > 1:
            r_extra = p.runs[-1]._r
            r_extra.getparent().remove(r_extra)
            
    r.text = text
    if font_name:
        r.font.name = font_name
    if font_size_pt:
        r.font.size = Pt(font_size_pt)
    if color_rgb:
        r.font.color.rgb = color_rgb
    if bold is not None:
        r.font.bold = bold

def build_master_presentation():
    # Load base EXPO presentation
    prs = Presentation('presentacion/SolarDB-EXPO.pptx')
    s1_notes_sample = prs.slides[0].notes_slide
    
    def setup_notes_slide(target_slide, text):
        ns = target_slide.notes_slide
        if len(ns.shapes) == 0:
            for shp in s1_notes_sample.shapes:
                ns.shapes._spTree.append(copy.deepcopy(shp.element))
        ns.notes_text_frame.text = text

    # Common typography definitions
    COLOR_TEAL_HEADER = RGBColor(0x27, 0x46, 0x4F)
    COLOR_TITLE_DARK = RGBColor(0x10, 0x2D, 0x4D)
    COLOR_BODY_DARK = RGBColor(0x23, 0x3A, 0x50)
    COLOR_BLACK = RGBColor(0x00, 0x00, 0x00)
    COLOR_LABEL_DARK = RGBColor(0x06, 0x2A, 0x33)
    COLOR_BADGE = RGBColor(0x3F, 0x5F, 0x69)

    # ── SLIDE 1: Portada ─────────────────────────────────────────────────────
    s1 = prs.slides[0]
    for shp in s1.shapes:
        if shp.name == "Text 5" and shp.has_text_frame:
            tf = shp.text_frame
            tf.clear()
            p1 = tf.paragraphs[0]
            p1.text = "Juan Sebastian Raigosa Gil · Líder / Arquitectura y Pipeline"
            p1.font.name = "Plus Jakarta Sans"
            p1.font.size = Pt(11)
            p1.font.color.rgb = COLOR_BODY_DARK
            
            p2 = tf.add_paragraph()
            p2.text = "Deysi Carolina Echavarria Soto · Modelado y Analítica SQL"
            p2.font.name = "Plus Jakarta Sans"
            p2.font.size = Pt(11)
            p2.font.color.rgb = COLOR_BODY_DARK
            
            p3 = tf.add_paragraph()
            p3.text = "Jose Miguel Sosa Cartagena · Diseño Físico, Privacidad y Doc."
            p3.font.name = "Plus Jakarta Sans"
            p3.font.size = Pt(11)
            p3.font.color.rgb = COLOR_BODY_DARK

    setup_notes_slide(s1, 
        "PRESENTA: Juan Sebastian (o el equipo completo).\n"
        "Buenas tardes profesor Ramiro y compañeros. Presentamos el proyecto final de Bases de Datos I: SolarDB. "
        "El equipo está integrado por Juan Sebastian como líder de arquitectura y pipeline de migración, "
        "Deysi Carolina a cargo del modelado conceptual, lógico relacional y analítica SQL, y Jose Miguel en el diseño físico, "
        "análisis de privacidad bajo Ley 1581 y documentación. El objetivo fue construir una arquitectura en PostgreSQL 18 "
        "capaz de actuar como fuente única de verdad para la telemetría de una microrred híbrida con paneles y baterías."
    )

    # ── SLIDE 2: Diagnóstico Operacional (Deysi) ─────────────────────────────
    s2 = prs.slides[1]
    setup_notes_slide(s2, 
        "PRESENTA: Deysi Carolina.\n"
        "Comenzamos con el diagnóstico del problema operacional en campo. Los datos provienen del dataset OpenCEM v1.0.0, "
        "registrado en la Universidad China de Hong Kong en Shenzhen. Una microrred híbrida opera en condiciones muy dinámicas: "
        "paneles fotovoltaicos, baterías LiFePO4, 2 inversores bidireccionales y red pública generan mediciones de voltaje, corriente, "
        "potencias y temperaturas cada 12.58 segundos. Con casi 3 millones de lecturas anuales, el gran desafío de ingeniería fue: "
        "¿cómo distinguir en la base de datos una anomalía física real de una descalibración de sensor o un desfase de muestreo en la transmisión?"
    )

    # ── SLIDE 3: Arquitectura Propuesta ──────────────────────────────────────
    s3 = prs.slides[2]
    setup_notes_slide(s3, 
        "PRESENTA: Juan Sebastian.\n"
        "Para resolver este problema propusimos SolarDB, bajo la premisa de que PostgreSQL 18 debe ser la Fuente Única de Verdad. "
        "No dejamos la limpieza de datos en scripts externos frágiles de Python, sino que la gobernanza vive en el motor: "
        "1) Centralización relacional robusta de las mediciones; 2) Segregación de estados, separando datos válidos de sospechosos "
        "mediante una tabla de cuarentena con trazabilidad técnica; y 3) Almacenamiento semiestructurado con JSONB para el contexto "
        "operativo y logs, aprovechando índices GIN sin perder el rigor transaccional."
    )

    # ── SLIDE 4: Segregación en 3 Esquemas ────────────────────────────────────
    s4 = prs.slides[3]
    setup_notes_slide(s4, 
        "PRESENTA: Juan Sebastian.\n"
        "La arquitectura física se organizó en 3 esquemas independientes: "
        "1. STAGING: Recibe los datos crudos desde SQLite a alta velocidad mediante COPY, sin frenar el flujo. "
        "2. CALIDAD: Actúa como cortafuegos lógico; administra el catálogo de reglas de validación, auditoría de lotes de carga "
        "y la tabla de cuarentena. "
        "3. SOLARDB: El esquema de producción definitiva, con tablas normalizadas, 12 dominios personalizados y vistas analíticas "
        "para el usuario final y operadores energéticos."
    )

    # ── SLIDE 5: Estructura Relacional y 3FN ──────────────────────────────────
    s5 = prs.slides[4]
    for shp in s5.shapes:
        if shp.name == "Text 16" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Decisión Ancho vs Largo: Se adoptó formato ancho (46 cols síncronas) evitando inflar a 125M de filas. "
                "Normalización 3FN con 6 catálogos dimensionales y 12 dominios físicos.",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.0,
                color_rgb=COLOR_BODY_DARK
            )

    setup_notes_slide(s5, 
        "PRESENTA: Deysi Carolina.\n"
        "En el modelado relacional tomamos una decisión fundamental: ¿formato ancho o largo? El formato largo hubiera multiplicado "
        "las filas por 42 variables, creando más de 125 millones de registros y colapsando el servidor local. El formato ancho de 46 columnas "
        "representa fielmente el vector síncrono instantáneo de los sensores. Además, normalizamos en 3FN extrayendo 6 catálogos dimensionales "
        "(sitio, subsistema, inversor, tipo de contexto, unidad de medida y variable física), asegurando integridad con ON DELETE RESTRICT "
        "y clave natural compuesta (inversor_id, ts_lectura)."
    )

    # ── SLIDE 6: Pipeline de Migración ────────────────────────────────────────
    s6 = prs.slides[5]
    setup_notes_slide(s6, 
        "PRESENTA: Jose Miguel (o Juan Sebastian).\n"
        "El pipeline de migración opera en 3 fases: Extracción masiva a STAGING, Validación en lote mediante PL/pgSQL y Dispersión "
        "hacia producción o cuarentena. Es fundamental resaltar la aclaración metodológica: un valor de frecuencia en 0 Hz o valores nulos "
        "en corriente no son necesariamente errores de sensor, sino paradas nocturnas de paneles fotovoltaicos o transiciones a modo isla, "
        "por lo que el pipeline sabe diferenciar entre fallas físicas y eventos operacionales legítimos."
    )

    # ── SLIDE 7: Métricas Oficiales de Ejecución ─────────────────────────────
    s7 = prs.slides[6]
    for shp in s7.shapes:
        if shp.name == "Text 19" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Cuadratura matemática exacta: 2.965.337 + 24.422 = 2.989.759 (Delta = 0). "
                "Almacenamiento total: ~3,88 GB en PostgreSQL 18. Optimización con índice GIN sobre contexto JSONB.",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.0,
                color_rgb=COLOR_BLACK
            )
        elif shp.name == "Text 20" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "     07",
                font_name="Red Hat Mono",
                font_size_pt=10.5,
                color_rgb=COLOR_BADGE
            )

    setup_notes_slide(s7, 
        "PRESENTA: Juan Sebastian.\n"
        "Aquí presentamos los resultados oficiales certificados de la migración: De 2,989,759 lecturas extraídas de SQLite (superando "
        "el requisito del profesor de 1 millón en casi 300%), 2,965,337 fueron aceptadas en producción (99.18%) y 24,422 fueron aisladas "
        "en cuarentena (0.82%). La cuadratura matemática es exacta: la suma da exactamente las filas de origen con delta cero. "
        "La base de datos ocupa ~3.88 GB en PostgreSQL 18 e incluye 25,178 registros de contexto operativo."
    )

    # Helper function to clone slide
    def clone_slide(prs, source_slide_idx):
        source = prs.slides[source_slide_idx]
        layout = prs.slide_layouts[1]
        new_s = prs.slides.add_slide(layout)
        for shp in source.shapes:
            new_s.shapes._spTree.append(copy.deepcopy(shp.element))
        return new_s

    # ── SLIDE 8: Análisis de Cuarentena (Cloned from Slide 7) ─────────────────
    s8 = clone_slide(prs, 6) # index 6 is Slide 7
    for shp in s8.shapes:
        if shp.name == "Text 0" and shp.has_text_frame:
            set_shape_text_styled(shp, "ANÁLISIS DE CUARENTENA", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 1" and shp.has_text_frame:
            set_shape_text_styled(shp, "Taxonomía física de las 24.422 lecturas aisladas", font_name="Chakra Petch SemiBold", font_size_pt=35.0, color_rgb=COLOR_TITLE_DARK)
        elif shp.name == "Text 4" and shp.has_text_frame:
            set_shape_text_styled(shp, "24.375", font_name="Chakra Petch Bold", font_size_pt=44.0, color_rgb=COLOR_BODY_DARK)
        elif shp.name == "Text 5" and shp.has_text_frame:
            set_shape_text_styled(shp, "R_P_MAYOR_S (99.8%)", font_name="Jura SemiBold", font_size_pt=12.0, color_rgb=COLOR_LABEL_DARK)
        elif shp.name == "Text 6" and shp.has_text_frame:
            set_shape_text_styled(shp, "Violación física de P ≤ S = |V|·|I| en corriente alterna por desfase temporal Modbus en transitorios.", font_name="Plus Jakarta Sans", font_size_pt=13.5, color_rgb=COLOR_BODY_DARK)
        elif shp.name == "Text 7" and shp.has_text_frame:
            set_shape_text_styled(shp, "POTENCIA ACTIVA > APARENTE", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_BODY_DARK)
        elif shp.name == "Text 9" and shp.has_text_frame:
            set_shape_text_styled(shp, "38", font_name="Chakra Petch Bold", font_size_pt=44.0, color_rgb=COLOR_BLACK)
        elif shp.name == "Text 10" and shp.has_text_frame:
            set_shape_text_styled(shp, "R_TEMP1_IMPOSIBLE", font_name="Jura SemiBold", font_size_pt=12.0, color_rgb=COLOR_LABEL_DARK)
        elif shp.name == "Text 11" and shp.has_text_frame:
            set_shape_text_styled(shp, "Sensor reportando -20.3 °C en clima subtropical de Shenzhen (mínima histórica 0.2 °C). Falla de circuito abierto.", font_name="Plus Jakarta Sans", font_size_pt=13.5, color_rgb=COLOR_BLACK)
        elif shp.name == "Text 12" and shp.has_text_frame:
            set_shape_text_styled(shp, "FALLA TÉRMICA DE SENSOR", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_BLACK)
        elif shp.name == "Text 14" and shp.has_text_frame:
            set_shape_text_styled(shp, "8 y 1", font_name="Chakra Petch Bold", font_size_pt=44.0, color_rgb=COLOR_BLACK)
        elif shp.name == "Text 15" and shp.has_text_frame:
            set_shape_text_styled(shp, "MAGNITUDES NEGATIVAS", font_name="Jura SemiBold", font_size_pt=12.0, color_rgb=COLOR_LABEL_DARK)
        elif shp.name == "Text 16" and shp.has_text_frame:
            set_shape_text_styled(shp, "8 filas con potencia aparente negativa y 1 con corriente negativa en sensor monofásico unidireccional.", font_name="Plus Jakarta Sans", font_size_pt=13.5, color_rgb=COLOR_BLACK)
        elif shp.name == "Text 17" and shp.has_text_frame:
            set_shape_text_styled(shp, "LECTURAS ESPURIAS", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_BLACK)
        elif shp.name == "Text 19" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "TRAZABILIDAD EN JSONB: Cada registro aislado en calidad.registro_cuarentena conserva la fila íntegra, "
                "regla violada, motivo técnico y ciclo de vida de auditoría (PENDIENTE → CORREGIDO → REPROCESADO).",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BLACK
            )
        elif shp.name == "Text 20" and shp.has_text_frame:
            set_shape_text_styled(shp, "     08", font_name="Red Hat Mono", font_size_pt=10.5, color_rgb=COLOR_BADGE)

    setup_notes_slide(s8, 
        "PRESENTA: Juan Sebastian.\n"
        "Esta diapositiva es el corazón de nuestra línea de profundización. De las 24,422 filas en cuarentena, "
        "el 99.8% (24,375 filas) corresponden a la regla R_P_MAYOR_S. Físicamente en corriente alterna, la potencia activa jamás "
        "puede exceder la potencia aparente (P <= S = |V| * |I|). Descubrimos que esto se debió a un desfase de milisegundos en el muestreo "
        "Modbus durante transitorios rápidos de sol o carga. Además, 38 filas reportaron -20.3 °C en Shenzhen, una temperatura físicamente "
        "imposible debida a un circuito abierto del sensor. Ningún dato se borró: todo quedó respaldado como JSONB para auditoría."
    )

    # ── SLIDE 9: Analítica SQL de Negocio (Cloned from Slide 4) ──────────────
    s9 = clone_slide(prs, 3) # Slide 4 is 3-card layout
    for shp in s9.shapes:
        if shp.name == "Text 0" and shp.has_text_frame:
            set_shape_text_styled(shp, "ANALÍTICA DE NEGOCIO Y VISTAS", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 1" and shp.has_text_frame:
            set_shape_text_styled(shp, "10 consultas analíticas avanzadas y vistas SQL", font_name="Chakra Petch SemiBold", font_size_pt=35.0, color_rgb=COLOR_TITLE_DARK)
        elif shp.name == "Text 3" and shp.has_text_frame:
            set_shape_text_styled(shp, "1. INTEGRACIÓN DE ENERGÍA", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 4" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Integración trapezoidal numérica de potencia ∫P(t)dt en kWh diarios y mensuales para generación solar, "
                "consumo de carga e inyección a red eléctrica con EXTRACT(EPOCH...).",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BODY_DARK
            )
        elif shp.name == "Text 5" and shp.has_text_frame:
            set_shape_text_styled(shp, "2. ANALÍTICA DE OPERACIÓN", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 6" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Detección de hora pico solar mensual con ventana RANK(). Comparación de factor de carga: Cómputo (53.8%) vs HVAC (46.2%). "
                "Alerta de descarga crítica de batería (SOC < 20%).",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BODY_DARK
            )
        elif shp.name == "Text 7" and shp.has_text_frame:
            set_shape_text_styled(shp, "3. OPTIMIZACIÓN Y VISTAS", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 8" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Vistas solardb.v_resumen_diario_energia y v_estado_baterias. Optimización con EXPLAIN ANALYZE mediante índice "
                "compuesto (inversor_id, ts_lectura DESC) e índice GIN sobre JSONB.",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BODY_DARK
            )
        elif shp.name == "Text 11" and shp.has_text_frame:
            set_shape_text_styled(shp, "     09", font_name="Red Hat Mono", font_size_pt=10.5, color_rgb=COLOR_BADGE)

    setup_notes_slide(s9, 
        "PRESENTA: Deysi Carolina.\n"
        "Para aprovechar los 2.9 millones de lecturas limpias, diseñé 10 consultas analíticas de negocio y 3 vistas SQL de producción. "
        "1) Calculamos la energía real generada y consumida mediante integración trapezoidal en kilovatios-hora, descartando vacíos por apagones. "
        "2) Determinamos la hora pico solar por mes usando funciones de ventana RANK() y comparamos el consumo constante de los servidores "
        "frente al consumo estacional del aire acondicionado. 3) Monitoreamos la salud de las baterías disparando alarmas cuando el SOC cae del 20%. "
        "Todas las consultas fueron optimizadas y certificadas con planes EXPLAIN ANALYZE."
    )

    # ── SLIDE 10: Validación, Privacidad y Demo (Cloned from Slide 4) ────────
    s10 = clone_slide(prs, 3) # Slide 4 is 3-card layout
    for shp in s10.shapes:
        if shp.name == "Text 0" and shp.has_text_frame:
            set_shape_text_styled(shp, "VALIDACIÓN Y DEMOSTRACIÓN", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 1" and shp.has_text_frame:
            set_shape_text_styled(shp, "Pruebas de integridad, Ley 1581 y demo en vivo", font_name="Chakra Petch SemiBold", font_size_pt=35.0, color_rgb=COLOR_TITLE_DARK)
        elif shp.name == "Text 3" and shp.has_text_frame:
            set_shape_text_styled(shp, "1. 10 PRUEBAS AUTOMATIZADAS", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 4" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Batería formal con control de excepciones. Códigos oficiales SQLSTATE verificados: 23514 (CHECK de dominios), "
                "23505 (UNIQUE temporal), 23503 (Foreign Key huérfana) y 00000 (Inserción válida).",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BODY_DARK
            )
        elif shp.name == "Text 5" and shp.has_text_frame:
            set_shape_text_styled(shp, "2. PRIVACIDAD (LEY 1581)", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 6" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Auditoría de protección de datos: 204 comandos de terminal Linux (wsl_bash_history) contenían usuarios, correos y rutas. "
                "Fueron identificados y protegidos con contiene_datos_personales = TRUE.",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BODY_DARK
            )
        elif shp.name == "Text 7" and shp.has_text_frame:
            set_shape_text_styled(shp, "3. RUTA DEMO EN DBEAVER", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 8" and shp.has_text_frame:
            set_shape_text_styled(
                shp,
                "Demostración en vivo: 1) Consulta del balance en calidad.v_dashboard_calidad; 2) Ejecución del script sql/13_pruebas_integridad.sql; "
                "3) Inspección de tuplas aisladas en formato JSONB.",
                font_name="Plus Jakarta Sans",
                font_size_pt=13.5,
                color_rgb=COLOR_BODY_DARK
            )
        elif shp.name == "Text 11" and shp.has_text_frame:
            set_shape_text_styled(shp, "     10", font_name="Red Hat Mono", font_size_pt=10.5, color_rgb=COLOR_BADGE)

    setup_notes_slide(s10, 
        "PRESENTA: Jose Miguel.\n"
        "Para garantizar la robustez técnica, implementamos 10 pruebas automatizadas de integridad. Cada prueba intenta violar una restricción "
        "a propósito, demostrando en consola que PostgreSQL rechaza los datos corruptos con los códigos SQLSTATE estándar. "
        "En seguridad, aplicamos la Ley Estatutaria 1581 de 2012 de Colombia: descubrimos que la fuente wsl_bash_history contenía 204 registros "
        "con nombres y rutas reales de los investigadores, los cuales clasificamos y enmascaramos. "
        "A continuación, abriremos DBeaver para mostrar la base de datos solardb operando en vivo."
    )

    # ── SLIDE 11: Reorder Conclusion Slide to the End ────────────────────────
    sldIdLst = prs.slides._sldIdLst
    concl_elem = sldIdLst[7] # original slide 8 (Conclusions)
    sldIdLst.remove(concl_elem)
    sldIdLst.append(concl_elem)

    s_concl = prs.slides[10] # now index 10 is the conclusion slide
    for shp in s_concl.shapes:
        if shp.name == "Text 0" and shp.has_text_frame:
            set_shape_text_styled(shp, "SÍNTESIS DEL PROYECTO", font_name="Red Hat Mono Medium", font_size_pt=11.0, color_rgb=COLOR_TEAL_HEADER)
        elif shp.name == "Text 16" and shp.has_text_frame:
            set_shape_text_styled(shp, "     11", font_name="Red Hat Mono", font_size_pt=10.5, color_rgb=COLOR_BADGE)

    setup_notes_slide(s_concl, 
        "PRESENTA: Juan Sebastian (o los tres juntos).\n"
        "En conclusión, SolarDB demuestra cómo un motor relacional como PostgreSQL 18 puede convertirse en la Fuente Única de Verdad "
        "para Internet de las Cosas y microrredes industriales: 1) Centralización sólida con 12 dominios que protegen la física; "
        "2) Trazabilidad absoluta sin desechar datos gracias a la tabla de cuarentena; y 3) Flexibilidad semiestructurada con JSONB. "
        "Muchas gracias por su atención, abrimos el espacio para preguntas del docente y compañeros."
    )

    # Save master presentation
    target_path = 'presentacion/SolarDB_Final_Unificada.pptx'
    prs.save(target_path)
    print(f"Master presentation successfully saved to: {target_path} (Total slides: {len(prs.slides)})")

if __name__ == "__main__":
    build_master_presentation()
