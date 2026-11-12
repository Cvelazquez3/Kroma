import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls

doc = docx.Document()

# Page Margins
for section in doc.sections:
    section.top_margin = Inches(0.8)
    section.bottom_margin = Inches(0.8)
    section.left_margin = Inches(0.8)
    section.right_margin = Inches(0.8)

# Color Palette
COLOR_PRIMARY = RGBColor(26, 54, 93)      # Dark Navy Blue
COLOR_SECONDARY = RGBColor(43, 108, 176)  # Slate Blue
COLOR_TEXT = RGBColor(45, 55, 72)         # Charcoal Gray
COLOR_MUTED = RGBColor(113, 128, 150)

# Set Normal Style
style_normal = doc.styles['Normal']
style_normal.font.name = 'Calibri'
style_normal.font.size = Pt(10.5)
style_normal.font.color.rgb = COLOR_TEXT
style_normal.paragraph_format.line_spacing = 1.15
style_normal.paragraph_format.space_after = Pt(4)

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def add_title_block():
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_sub = p.add_run('KROMA DEV STUDIO // REPORTE DE GESTIÓN Y CIERRE DE CURSO\n')
    run_sub.font.size = Pt(9.5)
    run_sub.font.bold = True
    run_sub.font.color.rgb = COLOR_SECONDARY

    run_title = p.add_run('Evaluación de Avances y Plan de Trabajo: KROMA')
    run_title.font.size = Pt(17)
    run_title.font.bold = True
    run_title.font.color.rgb = COLOR_PRIMARY

    # Metadata table
    table = doc.add_table(rows=2, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    
    col_widths = [Inches(3.4), Inches(3.4)]
    for row in table.rows:
        for idx, width in enumerate(col_widths):
            row.cells[idx].width = width

    cells = table.rows[0].cells
    cells[0].paragraphs[0].add_run('Videojuego: ').bold = True
    cells[0].paragraphs[0].add_run('KROMA (Puzzle 2D / Godot 4)')
    cells[1].paragraphs[0].add_run('Fecha emisión: ').bold = True
    cells[1].paragraphs[0].add_run('3 de noviembre de 2026')

    cells2 = table.rows[1].cells
    cells2[0].paragraphs[0].add_run('Integrantes: ').bold = True
    cells2[0].paragraphs[0].add_run('Toledo, Christian, Carlos, Ian')
    cells2[1].paragraphs[0].add_run('Fecha límite: ').bold = True
    cells2[1].paragraphs[0].add_run('29 de noviembre de 2026 (23 días)')

    for row in table.rows:
        for cell in row.cells:
            set_cell_background(cell, 'F7FAFC')
            for p in cell.paragraphs:
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.space_before = Pt(2)
                for r in p.runs:
                    r.font.size = Pt(9.5)

    doc.add_paragraph().paragraph_format.space_after = Pt(4)

def add_h1(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(11)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.font.size = Pt(12.5)
    run.font.bold = True
    run.font.color.rgb = COLOR_PRIMARY

def add_h2(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(7)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.font.size = Pt(10.5)
    run.font.bold = True
    run.font.color.rgb = COLOR_SECONDARY

def add_bullet(text, bold_prefix=''):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.15
    if bold_prefix:
        r_b = p.add_run(bold_prefix)
        r_b.bold = True
        r_b.font.color.rgb = COLOR_TEXT
    r_t = p.add_run(text)
    r_t.font.color.rgb = COLOR_TEXT

add_title_block()

# 1. ESTADO ACTUAL
add_h1('1. Estado Actual del Videojuego')
add_h2('1.1 Funcionalidades y mecánicas terminadas')
add_bullet('Cálculo cinemático discreto sin fricción en BoardState.gd, desacoplado de la vista.', 'Inercia discreta: ')
add_bullet('Rojo + Azul = Púrpura; Azul + Amarillo = Verde; Amarillo + Rojo = Naranja (con frenado de conveniencia).', 'Síntesis cromática: ')
add_bullet('Bloques encajados en receptores se transforman en muros rígidos permanentes.', 'Mutación topológica: ')
add_bullet('Símbolos geométricos unívocos en glyph.gd (círculo, cuadrado, triángulo, etc.) para accesibilidad universal en daltonismo.', 'Glifos universales: ')
add_bullet('Pila LIFO de snapshots en history_stack para reversión ilimitada y reinicio rápido.', 'Sistema Undo y Reinicio: ')
add_bullet('Algoritmo balanceado en level_generator.gd acoplado al verificador matemático level_solver.gd (BFS) garantizando solvencia matemática.', 'Generador procedural y solver: ')
add_bullet('Gestor AudioManager.gd reactivo, efectos de squash & stretch y rebote elástico ante colisiones.', 'Audio y respuesta visual: ')

add_h2('1.2 Funcionalidades en desarrollo')
add_bullet('La pieza cae y se elimina, pero resta integrar la detección automática de si el sector quedó irresoluble.', 'Abismos (voids): ')
add_bullet('El pase entre sectores es inmediato sin pantalla intermedia de rendimiento o racha.', 'Transición procedural: ')

add_h2('1.3 Problemas pendientes y deuda técnica')
add_bullet('El juego arranca directo en el tablero sin menú principal ni selector de dificultad.', 'Falta de Pantalla de Inicio: ')
add_bullet('Si caen piezas indispensables en abismos, el usuario queda en estado zombi sin aviso de fallo.', 'Sin condición formal de derrota: ')
add_bullet('No existe contador de movimientos frente al par óptimo ni cuantificador de racha.', 'Falta de condición de reto: ')
add_bullet('Renombrar level_01.gd y level_01.tscn a gameplay.gd y gameplay.tscn, ya que son el controlador general y no un solo nivel.', 'Deuda técnica crítica: ')

add_h2('1.4 Evidencia del estado actual')
add_bullet('Scripts modulares en scripts/board/, scripts/levels/, scripts/view/, suites de pruebas unitarias test_board_state.gd y test_solver.gd, y exportación funcional en Godot 4.')

# 2. TRABAJO PENDIENTE Y PRIORIDADES
add_h1('2. Trabajo Pendiente y Prioridades')
add_bullet('Renombrar level_01.gd a gameplay.gd y actualizar referencias en project.godot.', '1. Refactorización técnica (Indispensable): ')
add_bullet('Escena main_menu.tscn con opciones Jugar (Simulación), Selector de Dificultad y Créditos.', '2. Pantalla de Inicio (Indispensable): ')
add_bullet('Configurar parámetros en el generador procedural: tamaño (5x5, 6x6, 7x7), densidad de muros, abismos y múltiples acoples.', '3. Ajuste de Dificultad (Indispensable): ')
add_bullet('Detección de piezas insuficientes por caída en abismos o bloqueo total, con banner informativo y opciones de Deshacer [Z] o Reiniciar [R].', '4. Condición de Derrota (Indispensable): ')
add_bullet('Mostrar en HUD el par óptimo calculado por BFS y medir el logro de Racha Perfecta (niveles seguidos resueltos sin usar Undo, sin Restart y sin caer en abismos).', '5. Condición de Reto y Racha (Indispensable): ')
add_bullet('Salida al menú de inicio mediante tecla [ESC].', '6. Menú de Pausa (Indispensable): ')
add_bullet('Partículas de fusión, efectos de cámara, modo contrarreloj y exportación Web HTML5.', 'Opcional / Secundario: ')

# 3. PLAN DE TRABAJO
add_h1('3. Plan de Trabajo hasta el 29 de Noviembre (23 Días)')

table_plan = doc.add_table(rows=5, cols=4)
table_plan.alignment = WD_TABLE_ALIGNMENT.CENTER
table_plan.autofit = False

col_widths = [Inches(1.2), Inches(2.5), Inches(1.5), Inches(1.6)]
for row in table_plan.rows:
    for idx, width in enumerate(col_widths):
        row.cells[idx].width = width

headers = ['Periodo', 'Actividades', 'Responsables', 'Resultado Esperado']
for idx, text in enumerate(headers):
    cell = table_plan.rows[0].cells[idx]
    set_cell_background(cell, '2B6CB0')
    p = cell.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(text)
    r.bold = True
    r.font.color.rgb = RGBColor(255, 255, 255)
    r.font.size = Pt(9.0)

data_plan = [
    ('Semana 1\n(3-8 nov)', '• Renombrar level_01 a gameplay.\n• Lógica y feedback de derrota.\n• Par óptimo BFS en HUD.\n• Boceto preliminar de menú.', 'Toledo (Técnica)\nCarlos e Ian\n(Bocetos)', 'Build v0.3: Arquitectura limpia, derrota y par BFS visible.'),
    ('Semana 2\n(9-15 nov)', '• Pantalla de Inicio.\n• Selector de dificultad procedural.\n• Contador de Racha Perfecta.\n• Menú de pausa básico.', 'Toledo (Lógica/UI)\nChristian y Carlos\n(Nodos Godot)', 'Build v0.5: Flujo completo Menú -> Dificultad -> Partida con racha.'),
    ('Semana 3\n(16-22 nov)', '• Freeze de mecánicas (16 nov).\n• Playtesting con usuarios externos.\n• Registro de bugs y métricas.', 'Christian, Carlos e Ian (Pruebas)\nToledo (Triage)', 'Reporte de playtest y matriz de corrección priorizada.'),
    ('Semana 4\n(23-29 nov)', '• Corrección de bugs.\n• Ajustes de audio y animaciones.\n• Freeze de código (28 nov).\n• Compilación build Windows.', 'Toledo (Bugs/Build)\nEquipo (Verificación)', 'Versión Final v1.0 Gold entregada formalmente.')
]

for row_idx, data in enumerate(data_plan, start=1):
    row_cells = table_plan.rows[row_idx].cells
    for col_idx, text in enumerate(data):
        cell = row_cells[col_idx]
        set_cell_background(cell, 'F7FAFC' if row_idx % 2 == 1 else 'FFFFFF')
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.1
        r = p.add_run(text)
        r.font.size = Pt(8.5)

doc.add_paragraph().paragraph_format.space_after = Pt(4)

# 4. PLAYTESTING
add_h1('4. Plan de Pruebas de Jugabilidad (Playtesting)')
add_bullet('Del 16 al 20 de noviembre de 2026.', 'Cuándo: ')
add_bullet('8 a 10 evaluadores (4 compañeros de programación para estabilidad técnica y 4 a 6 jugadores externos para usabilidad, incluyendo al menos una persona con daltonismo).', 'Quiénes: ')
add_bullet('Variedad y justicia de la generación procedural, claridad del escalado de dificultad (5x5 a 7x7), entendimiento del fallo por abismos, motivación de la Racha Perfecta y ergonomía de controles/glifos.', 'Qué evaluar: ')
add_bullet('Observación directa Think-Aloud, telemetría por consola (tiempo, racha lograda, reinicios) y cuestionario breve en Google Forms (escala 1 a 5).', 'Cómo registrar: ')

# 5. ORGANIZACIÓN Y ESTUDIO
add_h1('5. Organización y Compromisos del Estudio')
add_h2('5.1 Distribución de responsabilidades')
add_bullet('Desarrollo técnico central y complejo: refactorización a gameplay.gd, detector de derrota, selector de dificultad procedural, cálculo del par BFS, lógica de racha perfecta, audio, resolución de PRs y compilación de builds.', 'Toledo: ')
add_bullet('Estructuración base de nodos UI en Godot y apoyo en aplicación de playtesting.', 'Christian: ')
add_bullet('Bocetos visuales de interfaz y aplicación de pruebas de jugabilidad.', 'Carlos: ')
add_bullet('Revisión de glifos de accesibilidad, textos instructivos y recolección de encuestas.', 'Ian: ')

add_h2('5.2 Coordinación técnica')
add_bullet('Desarrollo mediante ramas Git (feature/*). Al completar una tarea, el integrante sube su rama, abre el Pull Request y avisa por el grupo para que Toledo revise e integre.', 'Flujo Git: ')
add_bullet('Check-in diario asíncrono vía Discord/WhatsApp y reunión semanal de sincronización los viernes.', 'Comunicación: ')

add_h2('5.3 Matriz de riesgos y mitigación')
add_bullet('Toledo absorbe la totalidad de la arquitectura crítica indispensable, blindando el avance ante eventuales retrasos del equipo.', 'Riesgo de retrasos: ')
add_bullet('El solver BFS valida la solvencia antes de mostrar el nivel al jugador; si es inviable, genera una nueva semilla en milisegundos.', 'Riesgo de nivel irresoluble: ')
add_bullet('Se descartan mecánicas accesorias y selector estático de niveles para garantizar al 100% el bucle procedural principal.', 'Riesgo de tiempo: ')

output_path = 'Reporte_Plan_Trabajo_Kroma.docx'
doc.save(output_path)
print(f'Document saved successfully: {output_path}')
