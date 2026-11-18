extends Control

## Pantalla de inicio: rieles laterales con teletransporte, logo sincronizado y modales glass.

const LOGO_TEXT_TEX := preload("res://assets/branding/logo_kroma_text.svg")
const LOGO_TRAILS_TEX := preload("res://assets/branding/logo_kroma_trails.svg")

const DEMO_RECIPES := [
	{"a": "red", "b": "blue", "result": "purple"},
	{"a": "blue", "b": "yellow", "result": "green"},
	{"a": "yellow", "b": "red", "result": "orange"}
]

var _logo_block: Panel
var _logo_glyph: Glyph
var _modal_layer: CanvasLayer
var _main_buttons: Array[Button] = []
var _is_transitioning: bool = false

# Rieles de demostración en layer -9 (detrás del blur global en -8)
var _demo_layer: CanvasLayer
var _demo_container: Control
var _demo_block_a: Panel
var _demo_block_b: Panel
var _demo_receptor: Panel
var _demo_cell_size: float = 64.0
var _demo_running: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_demo_board()
	_build_main_ui()
	_run_demo_loop()

	modulate.a = 0.0
	if _demo_container:
		_demo_container.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	if _demo_container:
		tw.tween_property(_demo_container, "modulate:a", 1.0, 0.25)

	if not _main_buttons.is_empty():
		_main_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if event.is_action_pressed("ui_cancel") and _modal_layer != null and is_instance_valid(_modal_layer):
		_close_modal()
		get_viewport().set_input_as_handled()


# ==============================================================================
# TABLERO DEMO EN ORILLAS EXTERIORES (16x6 ALINEADO A RETÍCULA DE 64PX)
# ==============================================================================

func _build_demo_board() -> void:
	_demo_layer = CanvasLayer.new()
	_demo_layer.name = "DemoBoardLayer"
	_demo_layer.layer = -9
	add_child(_demo_layer)

	var demo_w := _demo_cell_size * 16.0
	var demo_h := _demo_cell_size * 6.0
	_demo_container = Control.new()
	_demo_container.custom_minimum_size = Vector2(demo_w, demo_h)
	_demo_container.size = Vector2(demo_w, demo_h)
	_demo_container.set_anchors_preset(Control.PRESET_CENTER)
	_demo_container.offset_left = -demo_w * 0.5
	_demo_container.offset_top = -demo_h * 0.5
	_demo_container.offset_right = demo_w * 0.5
	_demo_container.offset_bottom = demo_h * 0.5
	_demo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_layer.add_child(_demo_container)

	# Solo las 3 columnas exteriores de cada lado (centro libre para el menú)
	for x in range(16):
		if x > 2 and x < 13:
			continue
		for y in range(6):
			var slot := Panel.new()
			slot.position = Vector2(x * _demo_cell_size + 3, y * _demo_cell_size + 3)
			slot.size = Vector2(_demo_cell_size - 6, _demo_cell_size - 6)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.14, 0.14, 0.17, 0.60)
			st.set_corner_radius_all(7)
			st.set_border_width_all(1)
			st.border_color = Color(1.0, 1.0, 1.0, 0.14)
			slot.add_theme_stylebox_override("panel", st)
			_demo_container.add_child(slot)

	for wall_pos: Vector2i in [Vector2i(1, 4), Vector2i(13, 3), Vector2i(15, 0)]:
		var wall := Panel.new()
		wall.position = Vector2(wall_pos.x * _demo_cell_size + 4, wall_pos.y * _demo_cell_size + 4)
		wall.size = Vector2(_demo_cell_size - 8, _demo_cell_size - 8)
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wst := StyleBoxFlat.new()
		wst.bg_color = Color(0.22, 0.22, 0.26, 0.90)
		wst.set_corner_radius_all(7)
		wall.add_theme_stylebox_override("panel", wst)
		_demo_container.add_child(wall)

	_demo_receptor = Panel.new()
	_demo_receptor.position = Vector2(14 * _demo_cell_size + 5, 0 * _demo_cell_size + 5)
	_demo_receptor.size = Vector2(_demo_cell_size - 10, _demo_cell_size - 10)
	_demo_receptor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_container.add_child(_demo_receptor)

	for blk_ref in ["a", "b"]:
		var blk := Panel.new()
		blk.size = Vector2(_demo_cell_size - 8, _demo_cell_size - 8)
		blk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_demo_container.add_child(blk)
		if blk_ref == "a":
			_demo_block_a = blk
		else:
			_demo_block_b = blk


func _style_demo_block(panel: Panel, col: Color, is_receptor: bool = false) -> void:
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(8)
	if is_receptor:
		st.bg_color = Color(col.r, col.g, col.b, 0.24)
		st.set_border_width_all(3)
		st.border_color = Color(col.r, col.g, col.b, 0.92)
	else:
		st.bg_color = col
		st.set_border_width_all(2)
		st.border_color = Color(1.0, 1.0, 1.0, 0.65)
	panel.add_theme_stylebox_override("panel", st)


func _cell_to_demo_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * _demo_cell_size + 4, cell.y * _demo_cell_size + 4)


func _sync_theme_color(color_name: String) -> void:
	var col: Color = KromaTheme.COLOR_MAP[color_name]
	var bm := get_node_or_null("/root/BackdropManager")
	if bm:
		bm.call("set_halo_color", col.lerp(Color(0.24, 0.24, 0.28), 0.25), 0.65)
	if _logo_block:
		var tw_logo := create_tween()
		tw_logo.tween_property(_logo_block, "self_modulate", col, 0.45)
	if _logo_glyph:
		_logo_glyph.setup(color_name, 14.0)


func _run_demo_loop() -> void:
	var idx := 0
	while _demo_running and is_inside_tree():
		var recipe: Dictionary = DEMO_RECIPES[idx % DEMO_RECIPES.size()]
		idx += 1

		var res_name: String = recipe["result"]
		var col_res: Color = KromaTheme.COLOR_MAP[res_name]

		_style_demo_block(_demo_receptor, col_res, true)
		_style_demo_block(_demo_block_a, KromaTheme.COLOR_MAP[recipe["a"]])
		_style_demo_block(_demo_block_b, KromaTheme.COLOR_MAP[recipe["b"]])

		_demo_block_a.visible = true
		_demo_block_b.visible = true
		_demo_block_a.modulate.a = 0.0
		_demo_block_b.modulate.a = 0.0
		_demo_block_a.position = _cell_to_demo_pos(Vector2i(1, 0))
		_demo_block_b.position = _cell_to_demo_pos(Vector2i(14, 3))

		var tw_in := create_tween()
		tw_in.set_parallel(true)
		tw_in.tween_property(_demo_block_a, "modulate:a", 1.0, 0.35)
		tw_in.tween_property(_demo_block_b, "modulate:a", 1.0, 0.35)
		await tw_in.finished
		if not is_inside_tree():
			return

		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return

		# Bloque A baja y sale por el borde izquierdo para aparecer por la derecha
		var tw_down := create_tween()
		tw_down.tween_property(_demo_block_a, "position", _cell_to_demo_pos(Vector2i(1, 3)), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw_down.finished
		if not is_inside_tree():
			return

		var tw_exit := create_tween()
		tw_exit.set_parallel(true)
		tw_exit.tween_property(_demo_block_a, "position", _cell_to_demo_pos(Vector2i(-2, 3)), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_exit.tween_property(_demo_block_a, "modulate:a", 0.0, 0.22)
		await tw_exit.finished
		if not is_inside_tree():
			return

		_demo_block_a.position = _cell_to_demo_pos(Vector2i(17, 3))
		var tw_enter := create_tween()
		tw_enter.set_parallel(true)
		tw_enter.tween_property(_demo_block_a, "position", _cell_to_demo_pos(Vector2i(14, 3)), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_enter.tween_property(_demo_block_a, "modulate:a", 1.0, 0.16)
		await tw_enter.finished
		if not is_inside_tree():
			return

		# Fusión: sincroniza tablero, halo de fondo y logo
		_demo_block_a.visible = false
		_style_demo_block(_demo_block_b, col_res)
		_sync_theme_color(res_name)
		await get_tree().create_timer(0.35).timeout
		if not is_inside_tree():
			return

		var tw_snap := create_tween()
		tw_snap.tween_property(_demo_block_b, "position", _cell_to_demo_pos(Vector2i(14, 0)), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw_snap.finished
		if not is_inside_tree():
			return

		await get_tree().create_timer(1.05).timeout
		if not is_inside_tree():
			return

		var tw_out := create_tween()
		tw_out.tween_property(_demo_block_b, "modulate:a", 0.0, 0.35)
		await tw_out.finished


# ==============================================================================
# INTERFAZ PRINCIPAL (LIENZO 640x640 ALINEADO A RETÍCULA DE 64PX)
# ==============================================================================

func _build_main_ui() -> void:
	var grid_stage := Control.new()
	grid_stage.custom_minimum_size = Vector2(640, 640)
	grid_stage.size = Vector2(640, 640)
	grid_stage.set_anchors_preset(Control.PRESET_CENTER)
	grid_stage.offset_left = -320.0
	grid_stage.offset_top = -320.0
	grid_stage.offset_right = 320.0
	grid_stage.offset_bottom = 320.0
	add_child(grid_stage)

	# 1. Logo modular KR[O]MA centrado en la fila 64..128
	var logo_box := Control.new()
	logo_box.position = Vector2((640.0 - 480.0) * 0.5, 32.0)
	logo_box.size = Vector2(480, 128)
	grid_stage.add_child(logo_box)

	for tex: Texture2D in [LOGO_TEXT_TEX, LOGO_TRAILS_TEX]:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_box.add_child(tr)

	_logo_block = Panel.new()
	_logo_block.position = Vector2(212.8, 36.0)
	_logo_block.size = Vector2(56.0, 56.0)
	var blk_style := StyleBoxFlat.new()
	blk_style.bg_color = Color.WHITE
	blk_style.set_corner_radius_all(9)
	blk_style.set_border_width_all(2)
	blk_style.border_color = Color(1.0, 1.0, 1.0, 0.45)
	_logo_block.add_theme_stylebox_override("panel", blk_style)
	_logo_block.self_modulate = KromaTheme.COLOR_MAP["purple"]
	logo_box.add_child(_logo_block)

	_logo_glyph = Glyph.new()
	_logo_glyph.position = Vector2(28.0, 28.0)
	_logo_glyph.setup("purple", 14.0)
	_logo_block.add_child(_logo_glyph)

	# 2. Subtítulo en fila 128..192 con micro-estelas primarias
	var sub_row := HBoxContainer.new()
	sub_row.position = Vector2(0, 144)
	sub_row.size = Vector2(640, 32)
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 18)
	grid_stage.add_child(sub_row)

	for item: Array in [
		["INERCIA", KromaTheme.COLOR_MAP["red"]],
		["SÍNTESIS", KromaTheme.COLOR_MAP["blue"]],
		["ESPACIO", KromaTheme.COLOR_MAP["yellow"]]
	]:
		var pair := HBoxContainer.new()
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_theme_constant_override("separation", 7)
		sub_row.add_child(pair)

		var dash := Panel.new()
		dash.custom_minimum_size = Vector2(12, 4)
		dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dst := StyleBoxFlat.new()
		dst.bg_color = item[1]
		dst.set_corner_radius_all(2)
		dash.add_theme_stylebox_override("panel", dst)
		pair.add_child(dash)

		var lbl := Label.new()
		lbl.text = item[0]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.80, 0.81, 0.85, 0.88))
		pair.add_child(lbl)

	# 3. Botones centrados sobre las líneas 256, 320, 384, 448 y 512
	var btn_box := VBoxContainer.new()
	btn_box.position = Vector2(192, 232)
	btn_box.size = Vector2(256, 304)
	btn_box.add_theme_constant_override("separation", 16)
	grid_stage.add_child(btn_box)

	var btn_campaign := KromaTheme.create_glass_button("CAMPAÑA", KromaTheme.COLOR_MAP["blue"])
	btn_campaign.pressed.connect(_on_campaign_pressed)
	btn_box.add_child(btn_campaign)

	var btn_procedural := KromaTheme.create_glass_button("SIMULACIÓN INFINITA", KromaTheme.COLOR_MAP["purple"])
	btn_procedural.pressed.connect(_open_difficulty_modal)
	btn_box.add_child(btn_procedural)

	var btn_guide := KromaTheme.create_glass_button("GUÍA / CONTROLES", KromaTheme.COLOR_MAP["yellow"])
	btn_guide.pressed.connect(_open_guide_modal)
	btn_box.add_child(btn_guide)

	var btn_credits := KromaTheme.create_glass_button("CRÉDITOS", KromaTheme.COLOR_MAP["green"])
	btn_credits.pressed.connect(_open_credits_modal)
	btn_box.add_child(btn_credits)

	var btn_quit := KromaTheme.create_glass_button("SALIR", KromaTheme.COLOR_MAP["red"])
	btn_quit.pressed.connect(func():
		AudioManager.play("ui_back", 1.0, -6.0)
		get_tree().quit()
	)
	btn_box.add_child(btn_quit)

	_main_buttons = [btn_campaign, btn_procedural, btn_guide, btn_credits, btn_quit]

	# 4. Footer sobre la línea y=576
	var footer_row := HBoxContainer.new()
	footer_row.position = Vector2(0, 562)
	footer_row.size = Vector2(640, 28)
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 8)
	grid_stage.add_child(footer_row)

	footer_row.add_child(_create_footer_pill("v2.0", Color(0.62, 0.66, 0.74), Color(1.0, 1.0, 1.0, 0.16)))
	if GameSession.best_streak > 0:
		footer_row.add_child(_create_footer_pill(
			KromaTheme.sym("✦ MEJOR RACHA: %02d", "MEJOR RACHA: %02d") % GameSession.best_streak,
			Color(0.55, 0.92, 1.0),
			Color(0.35, 0.88, 0.98, 0.35)
		))
	else:
		footer_row.add_child(_create_footer_pill("KROMA DEV STUDIO", Color(0.62, 0.66, 0.74), Color(1.0, 1.0, 1.0, 0.16)))


func _create_footer_pill(txt: String, text_col: Color, border_col: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var st := KromaTheme.glass_pill_style(border_col)
	st.content_margin_left = 12
	st.content_margin_right = 12
	pill.add_theme_stylebox_override("panel", st)

	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", text_col)
	pill.add_child(lbl)
	return pill


# ==============================================================================
# MODALES (DIFICULTAD, GUÍA Y CRÉDITOS)
# ==============================================================================

func _on_campaign_pressed() -> void:
	AudioManager.play("ui_click", 0.55, -5.0)
	GameSession.start_campaign()
	_transition_to_gameplay()


func _open_difficulty_modal() -> void:
	AudioManager.play("ui_click", 0.58, -6.0)
	var content := _create_modal_shell("SIMULACIÓN INFINITA  ·  DIFICULTAD", 440)

	var desc := Label.new()
	desc.text = "Selecciona la complejidad de la matriz procedural:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82))
	content.add_child(desc)

	for entry: Array in [
		[GameSession.Difficulty.EASY, KromaTheme.COLOR_MAP["green"]],
		[GameSession.Difficulty.NORMAL, KromaTheme.COLOR_MAP["yellow"]],
		[GameSession.Difficulty.HARD, KromaTheme.COLOR_MAP["red"]]
	]:
		var diff_id: GameSession.Difficulty = entry[0]
		var info: Dictionary = GameSession.get_difficulty_info(diff_id)
		var btn := KromaTheme.create_glass_button("%s  (%s)" % [info["label"], info["grid"]], entry[1], Vector2(360, 44))
		btn.pressed.connect(func():
			AudioManager.play("ui_click", 0.55, -5.0)
			GameSession.start_procedural(diff_id)
			_close_modal()
			_transition_to_gameplay()
		)
		content.add_child(btn)

		var sub := Label.new()
		sub.text = info["desc"]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", Color(0.62, 0.64, 0.70))
		content.add_child(sub)

	_add_modal_close_button(content)


func _open_guide_modal() -> void:
	AudioManager.play("ui_click", 0.58, -6.0)
	var content := _create_modal_shell("GUÍA Y CONTROLES", 540)

	# Controles
	var ctrl_card := _create_inner_card(Color(1.0, 1.0, 1.0, 0.14))
	content.add_child(ctrl_card)
	var ctrl_vbox := VBoxContainer.new()
	ctrl_vbox.add_theme_constant_override("separation", 4)
	ctrl_card.add_child(ctrl_vbox)

	var h_ctrl := Label.new()
	h_ctrl.text = "CONTROLES"
	h_ctrl.add_theme_font_size_override("font_size", 11)
	h_ctrl.add_theme_color_override("font_color", KromaTheme.COLOR_MAP["yellow"])
	ctrl_vbox.add_child(h_ctrl)

	var b_ctrl := Label.new()
	b_ctrl.text = "Deslizar / WASD / Flechas: Mover bloque con inercia\nTocar bloque / Tab / Cambiar: Alternar bloque activo\n[Z] Deshacer   ·   [R] Reiniciar   ·   [ESC] Pausa"
	b_ctrl.add_theme_font_size_override("font_size", 11)
	b_ctrl.add_theme_color_override("font_color", Color(0.86, 0.87, 0.90))
	ctrl_vbox.add_child(b_ctrl)

	# Síntesis Cromática (bloques + glifos + texto accesible)
	var syn_card := _create_inner_card(Color(1.0, 1.0, 1.0, 0.14))
	content.add_child(syn_card)
	var syn_vbox := VBoxContainer.new()
	syn_vbox.add_theme_constant_override("separation", 8)
	syn_card.add_child(syn_vbox)

	var h_syn := Label.new()
	h_syn.text = "SÍNTESIS CROMÁTICA"
	h_syn.add_theme_font_size_override("font_size", 11)
	h_syn.add_theme_color_override("font_color", KromaTheme.COLOR_MAP["yellow"])
	syn_vbox.add_child(h_syn)

	var eq_col := VBoxContainer.new()
	eq_col.add_theme_constant_override("separation", 6)
	syn_vbox.add_child(eq_col)

	var eq_texts := {
		"purple": "Rojo (Círculo) + Azul (Cuadrado) = Púrpura (Rombo)",
		"green": "Azul (Cuadrado) + Amarillo (Triángulo) = Verde (Cruz)",
		"orange": "Amarillo (Triángulo) + Rojo (Círculo) = Naranja (Hexágono)"
	}

	for recipe: Dictionary in DEMO_RECIPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		eq_col.add_child(row)

		var eq := HBoxContainer.new()
		eq.alignment = BoxContainer.ALIGNMENT_CENTER
		eq.add_theme_constant_override("separation", 4)
		eq.add_child(_create_mini_block_glyph(recipe["a"], 22))
		for sym_idx in range(2):
			var sym := Label.new()
			sym.text = "+" if sym_idx == 0 else "="
			sym.add_theme_font_size_override("font_size", 11)
			sym.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82))
			eq.add_child(sym)
			eq.add_child(_create_mini_block_glyph(recipe["b"] if sym_idx == 0 else recipe["result"], 22))
		row.add_child(eq)

		var txt_lbl := Label.new()
		txt_lbl.text = eq_texts.get(recipe["result"], "")
		txt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		txt_lbl.add_theme_font_size_override("font_size", 11)
		txt_lbl.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
		row.add_child(txt_lbl)

	# Racha Perfecta
	var str_card := _create_inner_card(Color(0.35, 0.88, 0.98, 0.30))
	content.add_child(str_card)
	var str_vbox := VBoxContainer.new()
	str_vbox.add_theme_constant_override("separation", 3)
	str_card.add_child(str_vbox)

	var h_str := Label.new()
	h_str.text = KromaTheme.sym("✦ RACHA PERFECTA", "RACHA PERFECTA")
	h_str.add_theme_font_size_override("font_size", 11)
	h_str.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	str_vbox.add_child(h_str)

	var b_str := Label.new()
	b_str.text = "Completa sectores consecutivos en movimientos óptimos (Rango S),\nsin usar Deshacer [Z], sin Reiniciar [R] y sin caer en abismos."
	b_str.add_theme_font_size_override("font_size", 11)
	b_str.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
	str_vbox.add_child(b_str)

	_add_modal_close_button(content)


func _open_credits_modal() -> void:
	AudioManager.play("ui_click", 0.58, -6.0)
	var content := _create_modal_shell("CRÉDITOS  ·  KROMA DEV STUDIO", 460)

	for m: Array in [
		["Toledo", "@bytoledo", "Arquitectura, Gameplay, Generador Procedural y Audio", "purple"],
		["Christian", "@Cvelazquez3", "Cargador JSON, BoardState y Solver BFS", "blue"],
		["Carlos", "@Carcamp016", "Control de Entradas, Historial Undo y HUD", "yellow"],
		["Ian", "@imartinez31", "Glifos de Accesibilidad y Modelado de Abismos", "green"]
	]:
		var accent_col: Color = KromaTheme.COLOR_MAP[m[3]]
		var card := _create_inner_card(Color(accent_col.r, accent_col.g, accent_col.b, 0.32))
		content.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(_create_mini_block_glyph(m[3], 32))

		var info_col := VBoxContainer.new()
		info_col.add_theme_constant_override("separation", 1)
		row.add_child(info_col)

		var top_line := HBoxContainer.new()
		top_line.add_theme_constant_override("separation", 8)
		info_col.add_child(top_line)

		var name_lbl := Label.new()
		name_lbl.text = m[0]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
		top_line.add_child(name_lbl)

		var handle_lbl := Label.new()
		handle_lbl.text = m[1]
		handle_lbl.add_theme_font_size_override("font_size", 11)
		handle_lbl.add_theme_color_override("font_color", accent_col.lerp(Color.WHITE, 0.35))
		top_line.add_child(handle_lbl)

		var role_lbl := Label.new()
		role_lbl.text = m[2]
		role_lbl.add_theme_font_size_override("font_size", 10)
		role_lbl.add_theme_color_override("font_color", Color(0.70, 0.72, 0.77))
		info_col.add_child(role_lbl)

	var foot_pill := _create_footer_pill("Godot Engine 4  ·  Licencia MIT", Color(0.68, 0.70, 0.75), Color(1.0, 1.0, 1.0, 0.14))
	foot_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(foot_pill)

	_add_modal_close_button(content)


func _create_inner_card(border_col: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.11, 0.13, 0.45)
	st.set_corner_radius_all(8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	st.set_border_width_all(1)
	st.border_width_left = 2
	st.border_color = border_col
	card.add_theme_stylebox_override("panel", st)
	return card


func _create_mini_block_glyph(color_name: String, sz: int) -> Panel:
	var blk := Panel.new()
	blk.custom_minimum_size = Vector2(sz, sz)
	blk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = KromaTheme.COLOR_MAP[color_name]
	st.set_corner_radius_all(int(sz * 0.22))
	st.set_border_width_all(1)
	st.border_color = Color(1.0, 1.0, 1.0, 0.42)
	blk.add_theme_stylebox_override("panel", st)

	var g := Glyph.new()
	g.position = Vector2(sz * 0.5, sz * 0.5)
	g.setup(color_name, sz * 0.25)
	blk.add_child(g)
	return blk


func _create_modal_shell(title_text: String, width_px: int) -> VBoxContainer:
	_close_modal()
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 50
	add_child(_modal_layer)

	_modal_layer.add_child(KromaTheme.create_blur_backdrop(6.0, Color(0.02, 0.02, 0.03, 0.64)))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width_px, 0)
	panel.add_theme_stylebox_override("panel", KromaTheme.glass_card_style(Color(0.09, 0.09, 0.11, 0.46)))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", KromaTheme.bold_title_font())
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	vbox.add_child(title)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	for c_key: String in ["red", "blue", "yellow"]:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(24, 3)
		seg.color = KromaTheme.COLOR_MAP[c_key]
		bar.add_child(seg)
	vbox.add_child(bar)

	return vbox


func _add_modal_close_button(vbox: VBoxContainer) -> void:
	var btn_close := KromaTheme.create_glass_button("VOLVER [ESC]", Color(0.75, 0.78, 0.85), Vector2(180, 38))
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func():
		AudioManager.play("ui_back", 1.0, -6.0)
		_close_modal()
	)
	vbox.add_child(btn_close)
	btn_close.grab_focus()


func _close_modal() -> void:
	if _modal_layer != null and is_instance_valid(_modal_layer):
		_modal_layer.queue_free()
		_modal_layer = null
		if not _main_buttons.is_empty():
			_main_buttons[0].grab_focus()


func _transition_to_gameplay() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_demo_running = false

	# Desvanece solo menú y rieles; el fondo global sigue intacto
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	if _demo_container:
		tw.tween_property(_demo_container, "modulate:a", 0.0, 0.18)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")
