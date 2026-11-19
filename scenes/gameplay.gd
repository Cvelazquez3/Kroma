extends Node2D

## Controlador principal de partida: coordina BoardState, tablero visual, HUD, entrada y tutorial.

const BASE_CELL_SIZE := 80.0
const SWIPE_THRESHOLD := 32.0

var cell_size: float = BASE_CELL_SIZE
var level_data: LevelData
var board: BoardState

var block_nodes: Dictionary = {}
var is_moving: bool = false
var is_defeated: bool = false
var is_paused: bool = false
var run_is_perfect: bool = true
var bloque_seleccionado: String = ""

var history_stack: Array = []
var initial_snapshot: Dictionary = {}
var procedural_run_count: int = 0
var current_moves: int = 0
var par_moves: int = 0

var defeat_canvas: CanvasLayer = null
var pause_canvas: CanvasLayer = null
var moves_label: Label = null
var streak_label: Label = null
var streak_pill: PanelContainer = null

# Tutorial interactivo (pill inferior + guía visual sobre bloques)
var tutorial_wrap: CenterContainer = null
var tutorial_pill: PanelContainer = null
var tutorial_label: Label = null
var tutorial_dot: Panel = null
var tutorial_done: bool = false
var _tutorial_solution: Array = []
var _tutorial_step_idx: int = 0
var _tutorial_guide: TutorialGuideOverlay = null

# Seguimiento táctil / mouse para swipe y tap
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_touch_active: bool = false
var _swipe_triggered: bool = false

@onready var board_container: Node2D = $BoardContainer
@onready var receptors_container: Node2D = $ReceptorsContainer
@onready var blocks_container: Node2D = $BlocksContainer


# ==============================================================================
# CICLO DE VIDA Y SETUP
# ==============================================================================

func _ready() -> void:
	modulate.a = 0.0
	_tutorial_guide = TutorialGuideOverlay.new()
	_tutorial_guide.z_index = 40
	_tutorial_guide.visible = false
	add_child(_tutorial_guide)

	_setup_hud()
	if GameSession.mode == GameSession.Mode.PROCEDURAL:
		_generar_nuevo_procedural()
	else:
		_cargar_nivel("res://data/levels/level_01.json")
	_play_entry_transition()


func _play_entry_transition() -> void:
	# Entrada suave sobre el fondo continuo de BackdropManager
	var target_pos := position
	var board_sz := Vector2(level_data.width, level_data.height) * cell_size if level_data else Vector2(400, 400)
	scale = Vector2(0.97, 0.97)
	position = target_pos + board_sz * 0.015

	var hud_nodes := _get_hud_fade_targets()
	for n in hud_nodes:
		n.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.24)
	tw.tween_property(self, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target_pos, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for n in hud_nodes:
		tw.tween_property(n, "modulate:a", 1.0, 0.24)


func _get_hud_fade_targets() -> Array[Control]:
	var targets: Array[Control] = []
	for node_name: String in ["TopCenterHUD", "PauseButton", "BottomDock"]:
		var n := $HUD.get_node_or_null(node_name) as Control
		if n:
			targets.append(n)
	return targets


func _setup_hud() -> void:
	var hud_box := $HUD/HUDContainer as BoxContainer
	if hud_box:
		hud_box.visible = false

	# 1. Cabecera centrada: Título del sector + Pills de Pasos y Racha
	var top_center := VBoxContainer.new()
	top_center.name = "TopCenterHUD"
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 12.0
	top_center.offset_bottom = 84.0
	top_center.alignment = BoxContainer.ALIGNMENT_CENTER
	top_center.add_theme_constant_override("separation", 6)
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(top_center)

	var lbl_sector: Label = $HUD/HUDContainer/SectorLabel
	$HUD/HUDContainer.remove_child(lbl_sector)
	lbl_sector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_sector.add_theme_font_override("font", KromaTheme.bold_title_font())
	lbl_sector.add_theme_font_size_override("font_size", 18)
	lbl_sector.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	lbl_sector.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	lbl_sector.add_theme_constant_override("shadow_offset_y", 2)
	top_center.add_child(lbl_sector)

	var pills_row := HBoxContainer.new()
	pills_row.name = "PillsRow"
	pills_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pills_row.add_theme_constant_override("separation", 10)
	top_center.add_child(pills_row)

	moves_label = $HUD/HUDContainer/MovesLabel
	$HUD/HUDContainer.remove_child(moves_label)
	var moves_pill := PanelContainer.new()
	moves_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(0.94, 0.82, 0.35, 0.35)))
	moves_label.add_theme_font_size_override("font_size", 12)
	moves_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.38))
	moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	moves_pill.add_child(moves_label)
	pills_row.add_child(moves_pill)

	streak_pill = PanelContainer.new()
	streak_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(0.35, 0.88, 0.98, 0.40)))
	streak_label = Label.new()
	streak_label.name = "StreakLabel"
	streak_label.add_theme_font_size_override("font_size", 12)
	streak_label.add_theme_color_override("font_color", Color(0.40, 0.90, 1.0))
	streak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	streak_pill.add_child(streak_label)
	pills_row.add_child(streak_pill)

	# Botón de Pausa arriba a la derecha
	var btn_pause := KromaTheme.create_glass_button("||  PAUSA", Color(0.72, 0.78, 0.88), Vector2(108, 34), 11, false)
	btn_pause.name = "PauseButton"
	btn_pause.focus_mode = Control.FOCUS_NONE
	btn_pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_pause.offset_left = -132.0
	btn_pause.offset_top = 16.0
	btn_pause.offset_right = -24.0
	btn_pause.offset_bottom = 50.0
	btn_pause.pressed.connect(func():
		if not is_moving:
			_toggle_pause()
	)
	$HUD.add_child(btn_pause)

	# 2. Dock inferior táctil (ergonómico para teléfono y PC)
	var bottom_dock := HBoxContainer.new()
	bottom_dock.name = "BottomDock"
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_top = -60.0
	bottom_dock.offset_bottom = -16.0
	bottom_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_dock.add_theme_constant_override("separation", 12)
	$HUD.add_child(bottom_dock)

	var btn_u: Button = $HUD/HUDContainer/UndoButton
	var btn_r: Button = $HUD/HUDContainer/RestartButton
	$HUD/HUDContainer.remove_child(btn_u)
	$HUD/HUDContainer.remove_child(btn_r)

	var btn_cycle := KromaTheme.create_glass_button(KromaTheme.sym("⇄  CAMBIAR", "CAMBIAR"), KromaTheme.COLOR_MAP["blue"], Vector2(138, 42), 11, false)
	btn_cycle.name = "CycleButton"
	btn_cycle.focus_mode = Control.FOCUS_NONE
	btn_cycle.pressed.connect(_seleccionar_siguiente_bloque)

	btn_u.text = KromaTheme.sym("↶  DESHACER", "DESHACER")
	_apply_dock_button_style(btn_u, KromaTheme.COLOR_MAP["yellow"])
	if not btn_u.pressed.is_connected(_undo):
		btn_u.pressed.connect(_undo)

	btn_r.text = KromaTheme.sym("↺  REINICIAR", "REINICIAR")
	_apply_dock_button_style(btn_r, KromaTheme.COLOR_MAP["red"])
	if not btn_r.pressed.is_connected(_restart):
		btn_r.pressed.connect(_restart)

	bottom_dock.add_child(btn_u)
	bottom_dock.add_child(btn_cycle)
	bottom_dock.add_child(btn_r)

	# 3. Pill de Tutorial Interactivo encima del Dock
	tutorial_wrap = CenterContainer.new()
	tutorial_wrap.name = "TutorialWrap"
	tutorial_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_wrap.offset_top = -102.0
	tutorial_wrap.offset_bottom = -68.0
	tutorial_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_wrap.visible = false
	$HUD.add_child(tutorial_wrap)

	tutorial_pill = PanelContainer.new()
	tutorial_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(1.0, 1.0, 1.0, 0.24)))
	tutorial_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_wrap.add_child(tutorial_pill)

	var tut_hbox := HBoxContainer.new()
	tut_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tut_hbox.add_theme_constant_override("separation", 8)
	tutorial_pill.add_child(tut_hbox)

	tutorial_dot = Panel.new()
	tutorial_dot.custom_minimum_size = Vector2(8, 8)
	tutorial_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_sb := StyleBoxFlat.new()
	dot_sb.bg_color = Color(0.85, 0.86, 0.90)
	dot_sb.set_corner_radius_all(4)
	tutorial_dot.add_theme_stylebox_override("panel", dot_sb)
	tut_hbox.add_child(tutorial_dot)

	tutorial_label = Label.new()
	tutorial_label.add_theme_font_size_override("font_size", 11)
	tutorial_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))
	tut_hbox.add_child(tutorial_label)

	var btn_close_tut := Button.new()
	btn_close_tut.text = KromaTheme.sym("✕", "×")
	btn_close_tut.flat = true
	btn_close_tut.focus_mode = Control.FOCUS_NONE
	btn_close_tut.add_theme_font_size_override("font_size", 10)
	btn_close_tut.add_theme_color_override("font_color", Color(0.60, 0.66, 0.76))
	btn_close_tut.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn_close_tut.pressed.connect(func():
		tutorial_done = true
		var tw_c := create_tween()
		tw_c.tween_property(tutorial_wrap, "modulate:a", 0.0, 0.18)
		await tw_c.finished
		if is_instance_valid(tutorial_wrap):
			tutorial_wrap.visible = false
	)
	tut_hbox.add_child(btn_close_tut)


func _apply_dock_button_style(btn: Button, accent: Color) -> void:
	var styled := KromaTheme.create_glass_button(btn.text, accent, Vector2(138, 42), 11, false)
	btn.custom_minimum_size = Vector2(138, 42)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	for state_name: String in ["normal", "hover", "pressed"]:
		btn.add_theme_stylebox_override(state_name, styled.get_theme_stylebox(state_name))
	styled.queue_free()


# ==============================================================================
# CONSTRUCCIÓN DEL TABLERO
# ==============================================================================

func _build_greybox() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1152, 648)

	var top_reserved := 94.0
	var bottom_reserved := 108.0 if level_data.instruction.strip_edges() != "" else 76.0
	var playable_height: float = vp_size.y - top_reserved - bottom_reserved
	var target_max := minf(vp_size.x - 28.0, 560.0) if vp_size.y > vp_size.x else 456.0
	var max_board_px := minf(target_max, playable_height - 16.0)

	var max_dim := maxi(level_data.width, level_data.height)
	cell_size = minf(BASE_CELL_SIZE, max_board_px / float(max_dim))

	var board_w: float = level_data.width * cell_size
	var board_h: float = level_data.height * cell_size
	position.x = floor((vp_size.x - board_w) * 0.5)
	position.y = floor(top_reserved + (playable_height - board_h) * 0.5)

	var corner_rad := int(cell_size * 0.09)
	var board_padding := 6.0

	var outer_frame := Panel.new()
	outer_frame.size = Vector2(board_w + board_padding * 2, board_h + board_padding * 2)
	outer_frame.position = Vector2(-board_padding, -board_padding)
	outer_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_frame.add_theme_stylebox_override("panel", KromaTheme.cell_style(KromaTheme.CellStyle.OUTER_FRAME, Color.WHITE, corner_rad))
	board_container.add_child(outer_frame)

	# Celdas vacías
	for x in range(level_data.width):
		for y in range(level_data.height):
			var cell_pos := Vector2i(x, y)
			if level_data.walls.has(cell_pos) or level_data.voids.has(cell_pos):
				continue
			var cell := Panel.new()
			cell.size = Vector2(cell_size - 4, cell_size - 4)
			cell.position = Vector2(x * cell_size + 2, y * cell_size + 2)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_stylebox_override("panel", KromaTheme.cell_style(KromaTheme.CellStyle.SLOT, KromaTheme.COLOR_MAP["empty"], corner_rad))
			board_container.add_child(cell)

	# Abismos
	for v in level_data.voids:
		var void_panel := Panel.new()
		void_panel.size = Vector2(cell_size - 4, cell_size - 4)
		void_panel.position = Vector2(v.x * cell_size + 2, v.y * cell_size + 2)
		void_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		void_panel.add_theme_stylebox_override("panel", KromaTheme.cell_style(KromaTheme.CellStyle.VOID, Color.WHITE, corner_rad))
		board_container.add_child(void_panel)

		if KromaTheme.is_web():
			var void_mark := _VoidMark.new()
			void_mark.size = void_panel.size
			void_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			void_panel.add_child(void_mark)
		else:
			var void_glyph := Label.new()
			void_glyph.text = "⤫"
			void_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			void_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			void_glyph.size = void_panel.size
			void_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			void_glyph.add_theme_color_override("font_color", Color(0.40, 0.40, 0.44, 0.70))
			void_glyph.add_theme_font_size_override("font_size", int(cell_size * 0.30))
			void_panel.add_child(void_glyph)

	# Muros unidos ortogonalmente (sin huecos ni saltos subpíxel)
	var wall_set := {}
	for w_pos in level_data.walls:
		wall_set[w_pos] = true

	for w in level_data.walls:
		var has_up := wall_set.has(w + Vector2i.UP)
		var has_down := wall_set.has(w + Vector2i.DOWN)
		var has_left := wall_set.has(w + Vector2i.LEFT)
		var has_right := wall_set.has(w + Vector2i.RIGHT)

		var x0 := floorf(w.x * cell_size + (0.0 if has_left else 2.0))
		var y0 := floorf(w.y * cell_size + (0.0 if has_up else 2.0))
		var x1 := floorf((w.x + 1) * cell_size - (0.0 if has_right else 2.0))
		var y1 := floorf((w.y + 1) * cell_size - (0.0 if has_down else 2.0))

		var wall := Panel.new()
		wall.position = Vector2(x0, y0)
		wall.size = Vector2(x1 - x0, y1 - y0)
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.add_theme_stylebox_override("panel", KromaTheme.connected_wall_style(has_up, has_down, has_left, has_right, maxi(2, corner_rad - 1)))
		board_container.add_child(wall)

	# Suavizar esquinas interiores cóncavas en uniones de muros en L
	var fillets := _WallInnerFillets.new()
	fillets.setup(level_data.width, level_data.height, cell_size, wall_set, float(maxi(4, corner_rad)))
	board_container.add_child(fillets)

	# Receptores
	for r in level_data.receptors:
		var pos_v: Vector2i = r["pos"]
		var rec := Panel.new()
		rec.size = Vector2(cell_size - 12, cell_size - 12)
		rec.position = Vector2(pos_v.x * cell_size + 6, pos_v.y * cell_size + 6)
		rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c: Color = KromaTheme.COLOR_MAP.get(r["color"], Color.WHITE)
		rec.add_theme_stylebox_override("panel", KromaTheme.cell_style(KromaTheme.CellStyle.RECEPTOR, c, corner_rad))
		receptors_container.add_child(rec)

		var glyph := Glyph.new()
		glyph.name = "Glyph"
		glyph.position = rec.size / 2.0
		glyph.setup(r["color"], (cell_size - 12) * 0.24)
		rec.add_child(glyph)

	for b in level_data.blocks:
		_instanciar_bloque_visual(b["id"], b["color"], b["pos"])


func _instanciar_bloque_visual(b_id: String, color_name: String, grid_pos: Vector2i) -> void:
	var blk := Panel.new()
	blk.size = Vector2(cell_size - 8, cell_size - 8)
	blk.position = Vector2(grid_pos.x * cell_size + 4, grid_pos.y * cell_size + 4)
	blk.pivot_offset = blk.size / 2.0
	blk.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col: Color = KromaTheme.COLOR_MAP.get(color_name, Color.WHITE)
	blk.add_theme_stylebox_override("panel", KromaTheme.cell_style(KromaTheme.CellStyle.GLASS_BLOCK, col, int(cell_size * 0.09)))
	blocks_container.add_child(blk)
	block_nodes[b_id] = blk

	var glyph := Glyph.new()
	glyph.name = "Glyph"
	glyph.position = blk.size / 2.0
	glyph.setup(color_name, (cell_size - 8) * 0.25)
	blk.add_child(glyph)


# ==============================================================================
# ENTRADA (TECLADO + TÁCTIL SWIPE / TAP)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not is_moving:
			_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if is_paused or is_moving:
		return

	if event.is_action_pressed("undo_move") or (event is InputEventKey and event.pressed and event.keycode == KEY_Z):
		_undo()
		return
	elif event.is_action_pressed("restart_level") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		_restart()
		return

	if is_defeated:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_TAB:
			_seleccionar_siguiente_bloque()
			return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_execute_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_execute_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_execute_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_execute_move(Vector2i.RIGHT)

	_handle_pointer_input(event)


func _handle_pointer_input(event: InputEvent) -> void:
	var is_press: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	var is_release: bool = (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
	var is_drag: bool = (event is InputEventScreenDrag) or (event is InputEventMouseMotion)

	if is_press:
		_touch_start_pos = event.position
		_is_touch_active = true
		_swipe_triggered = false
	elif is_release:
		if _is_touch_active and not _swipe_triggered:
			_try_select_block_at(event.position)
		_is_touch_active = false
	elif is_drag and _is_touch_active and not _swipe_triggered:
		_check_swipe_delta(event.position - _touch_start_pos)


func _check_swipe_delta(delta: Vector2) -> void:
	if delta.length() < SWIPE_THRESHOLD:
		return
	_swipe_triggered = true
	_is_touch_active = false
	var dir: Vector2i
	if absf(delta.x) > absf(delta.y):
		dir = Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	else:
		dir = Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
	_execute_move(dir)


func _try_select_block_at(screen_pos: Vector2) -> void:
	if board == null or cell_size <= 0.0:
		return
	var local_pos: Vector2 = blocks_container.get_global_transform().affine_inverse() * screen_pos
	var cell := Vector2i(int(floor(local_pos.x / cell_size)), int(floor(local_pos.y / cell_size)))
	var snap_blocks: Dictionary = board.snapshot()["blocks"]
	for b_id: String in board.active_block_ids():
		if snap_blocks[b_id]["pos"] == cell:
			if bloque_seleccionado != b_id:
				bloque_seleccionado = b_id
				_actualizar_seleccion_visual()
				AudioManager.play("ui_hover", 1.0, -8.0)
				if level_data and level_data.id == 2:
					_complete_tutorial_step("¡Bloque alternado! Ahora úsalo de freno")
				_refresh_tutorial_guide()
			return


func _seleccionar_siguiente_bloque() -> void:
	var bloques := board.active_block_ids()
	if bloques.is_empty():
		return
	var indice := bloques.find(bloque_seleccionado)
	var nuevo_id: String = bloques[0] if indice == -1 else bloques[(indice + 1) % bloques.size()]
	if nuevo_id != bloque_seleccionado:
		bloque_seleccionado = nuevo_id
		AudioManager.play("ui_hover", 1.0, -8.0)
	_actualizar_seleccion_visual()
	if level_data and level_data.id == 2:
		_complete_tutorial_step("¡Bloque alternado! Ahora úsalo de freno")
	_refresh_tutorial_guide()


# ==============================================================================
# MOVIMIENTO, SINCRONIZACIÓN Y TURNOS
# ==============================================================================

func _execute_move(dir: Vector2i) -> void:
	if bloque_seleccionado == "" or not block_nodes.has(bloque_seleccionado):
		return

	var snap := {"board": board.snapshot(), "block_id": bloque_seleccionado}
	var blocks_before := board.active_block_ids().size()
	var path: Array = []
	var result = board.apply_move(bloque_seleccionado, dir, path)

	if path.is_empty():
		var moving_blk: Panel = block_nodes[bloque_seleccionado]
		AudioManager.play("bump", 0.85, -12.0)
		var pos_origen := moving_blk.position
		var tw_bump := create_tween()
		tw_bump.tween_property(moving_blk, "position", pos_origen + Vector2(dir) * 3.0, 0.03).set_trans(Tween.TRANS_QUAD)
		tw_bump.tween_property(moving_blk, "position", pos_origen, 0.04).set_trans(Tween.TRANS_SINE)
		return

	history_stack.push_back(snap)
	current_moves += 1
	if par_moves > 0 and current_moves > par_moves and run_is_perfect:
		run_is_perfect = false
		GameSession.reset_streak()
	_actualizar_hud_movimientos()

	is_moving = true
	var moving_id := bloque_seleccionado

	# Actualizar progreso de guía visual y texto interactivo
	if _tutorial_step_idx < _tutorial_solution.size():
		var expected: Dictionary = _tutorial_solution[_tutorial_step_idx]
		if moving_id == expected["block"] and dir == LevelSolver.dir_from_name(expected["dir"]):
			_tutorial_step_idx += 1
		else:
			_tutorial_step_idx = 999
	if _tutorial_guide:
		_tutorial_guide.visible = false

	if level_data:
		if level_data.id == 1:
			_complete_tutorial_step("¡Bien! Los bloques avanzan hasta chocar")
		elif level_data.id == 3 and result == BoardState.MoveResult.OK and board.active_block_ids().size() < blocks_before:
			_complete_tutorial_step("¡Síntesis cromática completada!")
		elif level_data.id == 4 and current_moves >= 2 and result != BoardState.MoveResult.FELL:
			_complete_tutorial_step("¡Controlado! Lleva la pieza a la meta")

	var moving_blk: Panel = block_nodes[moving_id]
	var target_pos := Vector2(path[-1].x * cell_size + 4, path[-1].y * cell_size + 4)
	var move_duration := clampf(0.05 + float(path.size()) * 0.03, 0.07, 0.22)
	AudioManager.play("slide", 1.0, -8.0, move_duration + 0.03, 0.05)

	var tw := create_tween()
	tw.tween_property(moving_blk, "position", target_pos, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_callback(func():
		AudioManager.stop_sfx("slide", 0.03)
		_sincronizar_bloques_completos()
		if result == BoardState.MoveResult.FELL:
			run_is_perfect = false
			GameSession.reset_streak()
			_actualizar_hud_movimientos()
			AudioManager.play("void", 0.95, -4.0)
		elif result == BoardState.MoveResult.SNAPPED:
			AudioManager.play("snap", 1.0, -4.0)
		elif result == BoardState.MoveResult.OK:
			AudioManager.play("bump", 0.95, -6.0)
		elif result == BoardState.MoveResult.VICTORY:
			var victory_sfx := "victory_2"
			var victory_pitch := randf_range(0.94, 1.08)
			if par_moves > 0:
				if current_moves <= par_moves:
					# Rango S: usa victory_2 (actual) subiendo sutilmente de brillo con la racha
					victory_sfx = "victory_2"
					victory_pitch = clampf(0.96 + float(GameSession.perfect_streak) * 0.03, 0.96, 1.18)
				elif current_moves <= par_moves + 3:
					# Rango A: alterna entre victory_1 y victory_3 con variación de tono
					victory_sfx = ["victory_1", "victory_3"].pick_random()
					victory_pitch = randf_range(0.95, 1.10)
				else:
					# Rango B: tono más calmado variando entre victory_1 y victory_3
					victory_sfx = ["victory_1", "victory_3"].pick_random()
					victory_pitch = randf_range(0.86, 0.98)
			AudioManager.play(victory_sfx, victory_pitch, -3.0, 2.4, 0.6)
			_on_level_victory()
	)

	if result == BoardState.MoveResult.FELL:
		tw.tween_property(moving_blk, "scale", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var squash := Vector2(0.95, 1.05) if dir.x != 0 else Vector2(1.05, 0.95)
		tw.tween_property(moving_blk, "scale", squash, 0.03)
		tw.tween_property(moving_blk, "scale", Vector2.ONE, 0.04).set_trans(Tween.TRANS_SINE)

	tw.finished.connect(func():
		if result != BoardState.MoveResult.VICTORY:
			is_moving = false
			_sincronizar_bloques_completos()
			if board.is_defeated():
				_mostrar_derrota(result == BoardState.MoveResult.FELL)
			else:
				_refresh_tutorial_guide()
	)


func _sincronizar_bloques_completos() -> void:
	var corner_rad := int(cell_size * 0.09)
	for id in block_nodes.keys():
		var info: Dictionary = board.block_info(id)
		var blk: Panel = block_nodes[id]

		if info.is_empty():
			blk.visible = false
			continue

		blk.visible = true
		if not is_moving:
			blk.scale = Vector2.ONE
		var col: Color = KromaTheme.COLOR_MAP.get(info["color"], Color.WHITE)
		var estilo := KromaTheme.cell_style(KromaTheme.CellStyle.GLASS_BLOCK, col, corner_rad)
		if info.get("locked", false):
			estilo.shadow_size = 0
			estilo.border_color = Color(1.0, 1.0, 1.0, 0.15)
			blk.z_index = 1
		blk.add_theme_stylebox_override("panel", estilo)

		if not is_moving or id != bloque_seleccionado:
			blk.position = Vector2(info["pos"].x * cell_size + 4, info["pos"].y * cell_size + 4)

		if blk.has_node("Glyph"):
			var g: Glyph = blk.get_node("Glyph")
			if g.color_name != info["color"]:
				AudioManager.play("merge", 1.05, -4.0)
				var pop := create_tween()
				pop.tween_property(blk, "scale", Vector2(1.18, 1.18), 0.05).set_trans(Tween.TRANS_SINE)
				pop.tween_property(blk, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_SINE)
			g.setup(info["color"], (cell_size - 8) * 0.25)

	var activos := board.active_block_ids()
	if not activos.has(bloque_seleccionado):
		bloque_seleccionado = activos[0] if not activos.is_empty() else ""
	_actualizar_seleccion_visual()


func _actualizar_seleccion_visual() -> void:
	var corner_rad := int(cell_size * 0.09)
	for id in block_nodes.keys():
		var info: Dictionary = board.block_info(id)
		if info.is_empty() or info.get("locked", false):
			continue
		var blk: Panel = block_nodes[id]
		var col: Color = KromaTheme.COLOR_MAP.get(info["color"], Color.WHITE)
		var style_type := KromaTheme.CellStyle.GLASS_BLOCK_SELECTED if id == bloque_seleccionado else KromaTheme.CellStyle.GLASS_BLOCK
		blk.add_theme_stylebox_override("panel", KromaTheme.cell_style(style_type, col, corner_rad))
		blk.z_index = 10 if id == bloque_seleccionado else 2


func _undo() -> void:
	if history_stack.is_empty() or is_moving or is_paused:
		return
	_cerrar_derrota()
	run_is_perfect = false
	GameSession.reset_streak()
	AudioManager.play("undo", 1.0, -5.0)

	var prev_record: Dictionary = history_stack.pop_back()
	board.restore(prev_record["board"])
	bloque_seleccionado = prev_record.get("block_id", bloque_seleccionado)
	current_moves = maxi(0, current_moves - 1)
	_actualizar_hud_movimientos()
	_sincronizar_bloques_completos()
	_tutorial_step_idx = 999
	_refresh_tutorial_guide()


func _restart() -> void:
	if is_moving or is_paused:
		return
	_cerrar_derrota()
	run_is_perfect = false
	GameSession.reset_streak()
	AudioManager.play("undo", 0.85, -4.0)
	board.restore(initial_snapshot)
	history_stack.clear()
	current_moves = 0
	_actualizar_hud_movimientos()

	if not level_data.blocks.is_empty():
		bloque_seleccionado = level_data.blocks[0]["id"]
	_sincronizar_bloques_completos()
	_tutorial_step_idx = 0
	_refresh_tutorial_guide()


# ==============================================================================
# OVERLAYS (VICTORIA, DERROTA, PAUSA) Y HUD
# ==============================================================================

func _on_level_victory() -> void:
	var nivel_perfecto := run_is_perfect and (par_moves <= 0 or current_moves <= par_moves)
	GameSession.register_level_clear(nivel_perfecto)
	_actualizar_hud_movimientos()

	GameplayOverlays.show_victory(
		get_tree(),
		current_moves,
		par_moves,
		GameSession.perfect_streak,
		GameSession.best_streak,
		nivel_perfecto,
		func():
			is_moving = false
			var siguiente_id: int = int(level_data.id) + 1
			var siguiente_ruta := "res://data/levels/level_%02d.json" % siguiente_id
			if siguiente_id <= 4 and FileAccess.file_exists(siguiente_ruta):
				_cargar_nivel(siguiente_ruta)
			else:
				_generar_nuevo_procedural()
	)


func _mostrar_derrota(from_void_fall: bool = false) -> void:
	if is_defeated or defeat_canvas != null:
		return
	is_defeated = true
	if not from_void_fall:
		AudioManager.play("void", 0.85, -4.0)
	defeat_canvas = GameplayOverlays.show_defeat(get_tree(), _undo, _restart)


func _cerrar_derrota() -> void:
	is_defeated = false
	if defeat_canvas != null and is_instance_valid(defeat_canvas):
		defeat_canvas.queue_free()
		defeat_canvas = null


func _toggle_pause() -> void:
	if is_paused:
		_cerrar_pausa()
	else:
		_mostrar_pausa()


func _mostrar_pausa() -> void:
	if is_paused or pause_canvas != null:
		return
	is_paused = true
	AudioManager.play("ui_click", 0.78, -6.0)

	var ctx := ""
	if GameSession.mode == GameSession.Mode.PROCEDURAL:
		var info := GameSession.get_difficulty_info()
		ctx = "SIMULACIÓN %02d  ·  %s (%s)" % [procedural_run_count, info["label"], info["grid"]]
	else:
		ctx = "SECTOR %02d  ·  %s" % [level_data.sector, level_data.level_name]

	pause_canvas = GameplayOverlays.show_pause(
		get_tree(),
		ctx,
		func():
			AudioManager.play("ui_click", 0.82, -6.0)
			_cerrar_pausa(),
		func():
			_cerrar_pausa()
			_restart(),
		func():
			AudioManager.play("ui_back", 1.0, -6.0)
			_cerrar_pausa()
			_cerrar_derrota()
			var tw_exit := create_tween()
			tw_exit.set_parallel(true)
			tw_exit.tween_property(self, "modulate:a", 0.0, 0.18)
			for n in _get_hud_fade_targets():
				tw_exit.tween_property(n, "modulate:a", 0.0, 0.18)
			await tw_exit.finished
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)


func _cerrar_pausa() -> void:
	is_paused = false
	if pause_canvas != null and is_instance_valid(pause_canvas):
		pause_canvas.queue_free()
		pause_canvas = null


func _actualizar_hud_movimientos() -> void:
	if moves_label:
		moves_label.text = ("PASOS %02d / PAR %02d" % [current_moves, par_moves]) if par_moves > 0 else ("PASOS %02d" % current_moves)

	if streak_label:
		if run_is_perfect:
			streak_label.text = KromaTheme.sym("✦ RACHA %02d", "RACHA %02d") % GameSession.perfect_streak
			streak_label.add_theme_color_override("font_color", Color(0.40, 0.90, 1.0))
			if streak_pill:
				streak_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(0.35, 0.88, 0.98, 0.45)))
		else:
			streak_label.text = "RACHA --"
			streak_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65, 0.75))
			if streak_pill:
				streak_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(1.0, 1.0, 1.0, 0.12)))


# ==============================================================================
# CARGA, GENERACIÓN PROCEDURAL Y TUTORIAL
# ==============================================================================

func _cargar_nivel(origen: Variant) -> void:
	var nuevo_nivel: LevelData = LevelLoader.load_from_file(origen) if origen is String else origen
	if nuevo_nivel == null or not nuevo_nivel.is_valid():
		push_error("No se pudo cargar el nivel.")
		return

	level_data = nuevo_nivel
	board = BoardState.new()
	board.init_from_level(level_data)

	initial_snapshot = board.snapshot()
	history_stack.clear()
	is_moving = false
	is_defeated = false
	is_paused = false
	run_is_perfect = true
	current_moves = 0
	_cerrar_derrota()
	_cerrar_pausa()

	var sol: Dictionary = LevelSolver.solve(level_data, 50000)
	if sol.get("solved", false):
		par_moves = sol["moves"].size()
		_tutorial_solution = sol["moves"]
	else:
		par_moves = 0
		_tutorial_solution = []
	_tutorial_step_idx = 0
	_actualizar_hud_movimientos()

	for contenedor in [board_container, receptors_container, blocks_container]:
		for hijo in contenedor.get_children():
			contenedor.remove_child(hijo)
			hijo.queue_free()

	block_nodes.clear()
	bloque_seleccionado = level_data.blocks[0]["id"] if not level_data.blocks.is_empty() else ""

	_build_greybox()
	_actualizar_seleccion_visual()
	_actualizar_mensaje_tutorial()
	_refresh_tutorial_guide()

	var sector_lbl := get_node_or_null("HUD/TopCenterHUD/SectorLabel") as Label
	if sector_lbl:
		if level_data.id == 99:
			var info := GameSession.get_difficulty_info()
			sector_lbl.text = "%s  ·  %s" % [level_data.level_name, info["label"]]
		else:
			sector_lbl.text = "SECTOR %02d  ·  %s" % [level_data.sector, level_data.level_name]

	if not level_data.receptors.is_empty():
		var target_col: Color = KromaTheme.COLOR_MAP.get(level_data.receptors[0]["color"], KromaTheme.COLOR_MAP["blue"])
		var bm := get_node_or_null("/root/BackdropManager")
		if bm:
			bm.call("set_halo_color", target_col.lerp(Color(0.24, 0.24, 0.28), 0.25))


func _generar_nuevo_procedural() -> void:
	procedural_run_count += 1
	var diff_info: Dictionary = GameSession.get_difficulty_info()
	print("Calculando tablero procedural (%s %s)..." % [diff_info["label"], diff_info["grid"]])
	var nuevo_nivel := LevelGenerator.generate_for_difficulty(GameSession.difficulty, procedural_run_count)
	if nuevo_nivel:
		nuevo_nivel.sector = 4
		nuevo_nivel.level_name = "SIMULACIÓN %02d" % procedural_run_count
		_cargar_nivel(nuevo_nivel)


func _actualizar_mensaje_tutorial() -> void:
	if tutorial_wrap == null or tutorial_label == null:
		return
	var mensaje: String = level_data.instruction.strip_edges()
	if KromaTheme.is_web():
		mensaje = mensaje.replace("⤫", "×")
	tutorial_done = false

	if mensaje == "":
		tutorial_wrap.visible = false
		return

	var dot_sb := tutorial_dot.get_theme_stylebox("panel") as StyleBoxFlat
	if dot_sb:
		dot_sb.bg_color = Color(0.85, 0.86, 0.90)
	tutorial_label.text = mensaje
	tutorial_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))
	tutorial_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(1.0, 1.0, 1.0, 0.24)))

	tutorial_wrap.visible = true
	tutorial_wrap.modulate.a = 0.0
	create_tween().tween_property(tutorial_wrap, "modulate:a", 1.0, 0.25)


func _complete_tutorial_step(success_msg: String) -> void:
	if tutorial_done or tutorial_wrap == null or not tutorial_wrap.visible:
		return
	tutorial_done = true
	var dot_sb := tutorial_dot.get_theme_stylebox("panel") as StyleBoxFlat
	if dot_sb:
		dot_sb.bg_color = KromaTheme.COLOR_MAP["green"]
	tutorial_label.text = success_msg
	tutorial_label.add_theme_color_override("font_color", Color(0.75, 0.96, 0.84))
	tutorial_pill.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(Color(0.20, 0.88, 0.45, 0.65)))

	var current_lvl_id := level_data.id
	await get_tree().create_timer(2.2).timeout
	if is_inside_tree() and level_data and level_data.id == current_lvl_id and tutorial_done:
		create_tween().tween_property(tutorial_wrap, "modulate:a", 0.35, 0.35)


func _refresh_tutorial_guide() -> void:
	if _tutorial_guide == null or level_data == null or board == null:
		return
	if is_defeated or is_moving:
		_tutorial_guide.visible = false
		return

	var max_guided_steps := 0
	if level_data.id == 1:
		max_guided_steps = _tutorial_solution.size()
	elif level_data.id == 2 or level_data.id == 3:
		max_guided_steps = 1

	if _tutorial_step_idx >= max_guided_steps or _tutorial_step_idx >= _tutorial_solution.size():
		_tutorial_guide.visible = false
		return

	var step: Dictionary = _tutorial_solution[_tutorial_step_idx]
	var target_id: String = step["block"]
	var snap_blocks: Dictionary = board.snapshot()["blocks"]
	if not snap_blocks.has(target_id) or snap_blocks[target_id]["locked"]:
		_tutorial_guide.visible = false
		return

	_tutorial_guide.configure(
		snap_blocks[target_id]["pos"],
		LevelSolver.dir_from_name(step["dir"]),
		cell_size,
		bloque_seleccionado == target_id
	)


class _WallInnerFillets extends Node2D:
	var _w: int = 0
	var _h: int = 0
	var _cell_px: float = 80.0
	var _walls: Dictionary = {}
	var _rad: float = 6.0

	func setup(w: int, h: int, cell_px: float, walls: Dictionary, rad: float) -> void:
		_w = w
		_h = h
		_cell_px = cell_px
		_walls = walls
		_rad = rad
		queue_redraw()

	func _draw() -> void:
		var col: Color = KromaTheme.COLOR_MAP["wall"]
		for gx in range(1, _w):
			for gy in range(1, _h):
				var tl := _walls.has(Vector2i(gx - 1, gy - 1))
				var tr := _walls.has(Vector2i(gx, gy - 1))
				var bl := _walls.has(Vector2i(gx - 1, gy))
				var br := _walls.has(Vector2i(gx, gy))
				var px := floorf(float(gx) * _cell_px)
				var py := floorf(float(gy) * _cell_px)

				if not tl and tr and bl and br:
					_draw_fillet(Vector2(px + 2.0, py + 2.0), Vector2(-_rad, -_rad), 0.0, PI * 0.5, col)
				elif tl and not tr and bl and br:
					_draw_fillet(Vector2(px - 2.0, py + 2.0), Vector2(_rad, -_rad), PI * 0.5, PI, col)
				elif tl and tr and bl and not br:
					_draw_fillet(Vector2(px - 2.0, py - 2.0), Vector2(_rad, _rad), PI, PI * 1.5, col)
				elif tl and tr and not bl and br:
					_draw_fillet(Vector2(px + 2.0, py - 2.0), Vector2(-_rad, _rad), PI * 1.5, TAU, col)

	func _draw_fillet(corner: Vector2, center_offset: Vector2, a0: float, a1: float, col: Color) -> void:
		var pts := PackedVector2Array([corner])
		var center := corner + center_offset
		var steps := 8
		for i in range(steps + 1):
			var ang := lerpf(a0, a1, float(i) / float(steps))
			pts.append(center + Vector2(cos(ang), sin(ang)) * _rad)
		draw_colored_polygon(pts, col)


class _VoidMark extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.095
		var col := Color(0.45, 0.46, 0.52, 0.45)
		draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 1.4, true)
		draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, 1.4, true)
