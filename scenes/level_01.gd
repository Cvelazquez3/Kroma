extends Node2D

# ==============================================================================
# CONSTANTES Y CONFIGURACIÓN BASE
# ==============================================================================

const BASE_CELL_SIZE := 80.0

const COLOR_MAP := {
	"red": Color(0.95, 0.22, 0.25),
	"blue": Color(0.20, 0.50, 1.00),
	"yellow": Color(1.00, 0.82, 0.15),
	"purple": Color(0.68, 0.25, 0.95),
	"green": Color(0.20, 0.88, 0.45),
	"orange": Color(1.00, 0.55, 0.12),
	"empty": Color(0.15, 0.15, 0.12, 0.22),
	"wall": Color(0.24, 0.26, 0.32, 1.00),
	"void": Color(0.00, 0.00, 0.00, 0.0)
}

# ==============================================================================
# VARIABLES DE ESTADO
# ==============================================================================

var cell_size: float = BASE_CELL_SIZE
var level_data: LevelData
var board: BoardState

var block_nodes: Dictionary = {}
var is_moving: bool = false
var bloque_seleccionado: String = ""

var history_stack: Array = []
var initial_snapshot: Dictionary = {}
var procedural_run_count: int = 0

# Referencias a nodos
@onready var board_container: Node2D = $BoardContainer
@onready var receptors_container: Node2D = $ReceptorsContainer
@onready var blocks_container: Node2D = $BlocksContainer


# ==============================================================================
# CICLO DE VIDA Y SETUP
# ==============================================================================

func _ready() -> void:
	_setup_hud()
	_cargar_nivel("res://data/levels/level_01.json")

func _setup_hud() -> void:
	# Contenedor superior ajustado a pantalla completa
	if has_node("HUD/HUDContainer"):
		var hud_box := $HUD/HUDContainer as BoxContainer
		if hud_box:
			hud_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
			hud_box.offset_left = 32.0
			hud_box.offset_top = 20.0
			hud_box.offset_right = -32.0
			hud_box.offset_bottom = 56.0
			hud_box.add_theme_constant_override("separation", 12)

	# Anclaje: Botones (izquierda), Etiqueta (derecha)
	if has_node("HUD/HUDContainer/RestartButton") and has_node("HUD/HUDContainer/SectorLabel"):
		var btn_r: Button = $HUD/HUDContainer/RestartButton
		var btn_u: Button = $HUD/HUDContainer/UndoButton
		var lbl: Label = $HUD/HUDContainer/SectorLabel

		$HUD/HUDContainer.move_child(btn_r, 0)
		$HUD/HUDContainer.move_child(btn_u, 1)
		$HUD/HUDContainer.move_child(lbl, 2)

		btn_r.custom_minimum_size = Vector2(110, 32)
		btn_u.custom_minimum_size = Vector2(110, 32)

		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))

	# Estilos de botones
	var btn_style := obtener_estilo(EstiloTipo.BOTON_HUD)
	for btn_path in ["HUD/HUDContainer/RestartButton", "HUD/HUDContainer/UndoButton"]:
		if has_node(btn_path):
			var b: Button = get_node(btn_path)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_stylebox_override("normal", btn_style)
			b.add_theme_stylebox_override("hover", btn_style)
			b.add_theme_stylebox_override("pressed", btn_style)
			b.add_theme_font_size_override("font_size", 11)

	# Conexión de señales
	if has_node("HUD/HUDContainer/RestartButton"):
		var btn_r: Button = $HUD/HUDContainer/RestartButton
		btn_r.text = "Reiniciar [R]"
		if not btn_r.pressed.is_connected(_restart):
			btn_r.pressed.connect(_restart)

	if has_node("HUD/HUDContainer/UndoButton"):
		var btn_u: Button = $HUD/HUDContainer/UndoButton
		btn_u.text = "Deshacer [Z]"
		if not btn_u.pressed.is_connected(_undo):
			btn_u.pressed.connect(_undo)

	if not has_node("HUD/TutorialPrompt"):
			var prompt := Label.new()
			prompt.name = "TutorialPrompt"
			prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			prompt.offset_top = -54.0
			prompt.offset_bottom = -20.0
			prompt.add_theme_font_size_override("font_size", 12)
			prompt.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78, 0.70))

			# Fondo sutil tipo cápsula translúcida
			var prompt_bg := StyleBoxFlat.new()
			prompt_bg.bg_color = Color(0.08, 0.10, 0.13, 0.60)
			prompt_bg.set_corner_radius_all(6)
			prompt_bg.border_width_left = 1
			prompt_bg.border_width_top = 1
			prompt_bg.border_width_right = 1
			prompt_bg.border_width_bottom = 1
			prompt_bg.border_color = Color(1.0, 1.0, 1.0, 0.08)
			prompt_bg.content_margin_left = 16
			prompt_bg.content_margin_right = 16
			prompt.add_theme_stylebox_override("panel", prompt_bg)

			var hud: Node = get_node_or_null("HUD")
			if hud:
				hud.add_child(prompt)

# ==============================================================================
# ESTÉTICA Y GENERACIÓN DE ESTILOS
# ==============================================================================

enum EstiloTipo { SLOT, BOTON_HUD, OUTER_FRAME, GLASS_BLOCK, GLASS_BLOCK_SELECTED, WALL, VOID, RECEPTOR }

func obtener_estilo(tipo: EstiloTipo, color_param: Color = Color.WHITE, corner_r: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(corner_r)

	# Bordes activos por defecto
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	match tipo:
		EstiloTipo.SLOT:
			style.bg_color = color_param
			style.border_color = Color(1, 1, 1, 0.05)

		EstiloTipo.BOTON_HUD:
			style.set_corner_radius_all(6)
			style.bg_color = Color(0.10, 0.12, 0.16, 0.85)
			style.border_color = Color(1, 1, 1, 0.15)
			style.content_margin_left = 10
			style.content_margin_right = 10
			style.content_margin_top = 5
			style.content_margin_bottom = 5

		EstiloTipo.OUTER_FRAME:
			style.set_corner_radius_all(corner_r + 4)
			style.bg_color = Color(0.06, 0.07, 0.09, 0.85)
			style.border_color = Color(1.0, 1.0, 1.0, 0.14)
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
			style.shadow_size = 12
			style.shadow_offset = Vector2(0, 4)

		EstiloTipo.GLASS_BLOCK:
			style.bg_color = Color(color_param.r * 0.85, color_param.g * 0.85, color_param.b * 0.85, 0.90)
			style.border_color = Color(1.0, 1.0, 1.0, 0.35)
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0, 2)

		EstiloTipo.GLASS_BLOCK_SELECTED:
			style.bg_color = Color(color_param.r * 0.85, color_param.g * 0.85, color_param.b * 0.85, 0.90)
			style.border_color = Color(1.0, 1.0, 1.0, 0.90)
			style.shadow_color = Color(color_param.r, color_param.g, color_param.b, 0.60)
			style.shadow_size = 8
			style.shadow_offset = Vector2(0, 2)

		EstiloTipo.WALL:
			style.set_corner_radius_all(corner_r)
			style.bg_color = COLOR_MAP["wall"]
			style.border_color = Color(0.45, 0.48, 0.55, 0.80)
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
			style.shadow_size = 5
			style.shadow_offset = Vector2(0, 3)

		EstiloTipo.VOID:
			var col_void: Color = COLOR_MAP["void"]
			style.bg_color = col_void
			style.border_color = Color(col_void.r * 1.5 + 0.1, col_void.g * 1.5 + 0.1, col_void.b * 1.5 + 0.1, 0.85)
			style.shadow_color = Color(col_void.r, col_void.g, col_void.b, 0.35)
			style.shadow_size = 6

		EstiloTipo.RECEPTOR:
			style.bg_color = Color(color_param.r, color_param.g, color_param.b, 0.15)
			style.border_color = Color(color_param.r, color_param.g, color_param.b, 0.50)
			style.shadow_color = Color(color_param.r, color_param.g, color_param.b, 0.20)
			style.shadow_size = 6

	return style

func _crear_estilo_banner_victoria() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.10, 0.90)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(1.0, 1.0, 1.0, 0.14)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	s.shadow_size = 18
	return s

func _crear_estilo_footer_interno() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	# Fondo oscuro traslúcido para legibilidad sin tapar el bisel exterior
	s.bg_color = Color(0.04, 0.04, 0.06, 0.88)
	# Mismos radios en las esquinas inferiores que el chasis exterior
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_top_left = 0
	s.corner_radius_top_right = 0
	# Borde superior sutil como línea divisoria con las celdas
	s.border_width_top = 1
	s.border_color = Color(1.0, 1.0, 1.0, 0.08)
	return s

# ==============================================================================
# CONSTRUCCIÓN Y RENDERIZADO DEL TABLERO
# ==============================================================================

# Greybox
func _build_greybox() -> void:
	var max_dim := maxi(level_data.width, level_data.height)
	if max_dim > 5:
		cell_size = 520.0 / float(max_dim)
	else:
		cell_size = BASE_CELL_SIZE

	var board_pixel_width: float = level_data.width * cell_size
	var board_pixel_height: float = level_data.height * cell_size
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1152, 648)

	# Centrado vertical
	var hud_reserved_height: float = 76.0
	var playable_height: float = vp_size.y - hud_reserved_height

	position.x = floor((vp_size.x - board_pixel_width) * 0.5)
	position.y = floor(hud_reserved_height + (playable_height - board_pixel_height) * 0.5)
	
	var corner_rad := int(cell_size * 0.09)

	# Marco exterior de fondo (por debajo)
	var board_padding := 6.0
	var outer_frame := Panel.new()
	outer_frame.size = Vector2(board_pixel_width + board_padding * 2, board_pixel_height + board_padding * 2)
	outer_frame.position = Vector2(-board_padding, -board_padding)
	outer_frame.add_theme_stylebox_override("panel", obtener_estilo(EstiloTipo.OUTER_FRAME, Color.WHITE, corner_rad))
	board_container.add_child(outer_frame)

	# Celdas regulares
	for x in range(level_data.width):
		for y in range(level_data.height):
			var cell_pos := Vector2i(x, y)
			if level_data.walls.has(cell_pos) or level_data.voids.has(cell_pos):
				continue
				
			var cell := Panel.new()
			cell.size = Vector2(cell_size - 4, cell_size - 4)
			cell.position = Vector2(x * cell_size + 2, y * cell_size + 2)
			cell.add_theme_stylebox_override("panel", obtener_estilo(EstiloTipo.SLOT, COLOR_MAP["empty"], corner_rad))
			board_container.add_child(cell)

	# Abismos
	for v in level_data.voids:
		var void_panel := Panel.new()
		void_panel.size = Vector2(cell_size - 4, cell_size - 4)
		void_panel.position = Vector2(v.x * cell_size + 2, v.y * cell_size + 2)
		void_panel.add_theme_stylebox_override("panel", obtener_estilo(EstiloTipo.VOID, Color.WHITE, corner_rad))
		board_container.add_child(void_panel)

		var void_glyph := Label.new()
		void_glyph.text = "⤫"
		void_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		void_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		void_glyph.size = void_panel.size
		var c_glyph: Color = COLOR_MAP["void"]
		void_glyph.add_theme_color_override("font_color", Color(c_glyph.r + 0.4, c_glyph.g + 0.4, c_glyph.b + 0.4, 0.70))
		void_glyph.add_theme_font_size_override("font_size", int(cell_size * 0.30))
		void_panel.add_child(void_glyph)

	# Muros sólidos
	for w in level_data.walls:
		var wall := Panel.new()
		wall.size = Vector2(cell_size - 4, cell_size - 4)
		wall.position = Vector2(w.x * cell_size + 2, w.y * cell_size + 2)
		wall.add_theme_stylebox_override("panel", obtener_estilo(EstiloTipo.WALL, Color.WHITE, corner_rad - 1))
		board_container.add_child(wall)

	# Receptores
	for r in level_data.receptors:
		var pos_v: Vector2i = r["pos"]
		var rec := Panel.new()
		rec.size = Vector2(cell_size - 12, cell_size - 12)
		rec.position = Vector2(pos_v.x * cell_size + 6, pos_v.y * cell_size + 6)

		var c: Color = COLOR_MAP.get(r["color"], Color.WHITE)
		rec.add_theme_stylebox_override("panel", obtener_estilo(EstiloTipo.RECEPTOR, c, corner_rad))
		receptors_container.add_child(rec)

		var glyph := Glyph.new()
		glyph.name = "Glyph"
		glyph.position = rec.size / 2.0
		glyph.setup(r["color"], (cell_size - 12) * 0.24)
		rec.add_child(glyph)

	# Bloques móviles iniciales
	for b in level_data.blocks:
		_instanciar_bloque_visual(b["id"], b["color"], b["pos"])


func _instanciar_bloque_visual(b_id: String, color_name: String, grid_pos: Vector2i) -> void:
	var blk := Panel.new()
	blk.size = Vector2(cell_size - 8, cell_size - 8)
	blk.position = Vector2(grid_pos.x * cell_size + 4, grid_pos.y * cell_size + 4)
	blk.pivot_offset = blk.size / 2.0
	
	var corner_rad := int(cell_size * 0.09)
	var col: Color = COLOR_MAP.get(color_name, Color.WHITE)
	blk.add_theme_stylebox_override("panel", obtener_estilo(EstiloTipo.GLASS_BLOCK, col, corner_rad))
	
	blocks_container.add_child(blk)
	block_nodes[b_id] = blk

	var glyph := Glyph.new()
	glyph.name = "Glyph"
	glyph.position = blk.size / 2.0
	glyph.setup(color_name, (cell_size - 8) * 0.25)
	blk.add_child(glyph)


# ==============================================================================
# LÓGICA DE CONTROL Y MOVIMIENTO
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return

	# Alternar bloque activo
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_TAB:
			_seleccionar_siguiente_bloque()
			return

	# Direccionales
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_execute_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_execute_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_execute_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_execute_move(Vector2i.RIGHT)
	elif event.is_action_pressed("undo_move") or (event is InputEventKey and event.pressed and event.keycode == KEY_Z):
		_undo()
	elif event.is_action_pressed("restart_level") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		_restart()


func _seleccionar_siguiente_bloque() -> void:
	var bloques := board.active_block_ids()
	if bloques.is_empty():
		return
	var indice := bloques.find(bloque_seleccionado)
	if indice == -1:
		bloque_seleccionado = bloques[0]
	else:
		bloque_seleccionado = bloques[(indice + 1) % bloques.size()]
	_actualizar_seleccion_visual()


func _execute_move(dir: Vector2i) -> void:
	if not board.active_block_ids().has(bloque_seleccionado):
		_seleccionar_siguiente_bloque()
		if bloque_seleccionado.is_empty():
			return

	if not block_nodes.has(bloque_seleccionado):
		return

	var snap := {
		"board": board.snapshot(),
		"block_id": bloque_seleccionado
	}

	var path: Array = []
	var result = board.apply_move(bloque_seleccionado, dir, path)

	# 1. Sin movimiento: micro-bump elástico al topar
	if path.size() > 0:
		history_stack.push_back(snap)
		is_moving = true
		
		# Sonido de deslizamiento
		AudioManager.play("slide", 1.0, -6.0)

		var moving_id := bloque_seleccionado
		var moving_blk: Panel = block_nodes[moving_id]
		var target_pos := Vector2(path[-1].x * cell_size + 4, path[-1].y * cell_size + 4)

		var move_duration := clampf(0.05 + float(path.size()) * 0.03, 0.07, 0.22)
		var tw := create_tween()

		tw.tween_property(moving_blk, "position", target_pos, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Impacto / sincronización
		tw.tween_callback(func():
			_sincronizar_bloques_completos()
			if result == BoardState.MoveResult.FELL:
				AudioManager.play("void", 0.90, -2.0, 0.08)
			elif result == BoardState.MoveResult.SNAPPED:
				AudioManager.play("snap", 1.0, 8, 0.8)
			elif result == BoardState.MoveResult.OK:
				AudioManager.play("bump", 0.9, -12.0, 0.06)
			elif result == BoardState.MoveResult.VICTORY:
				AudioManager.play("victory", 1.0, 0.0, 2.6, 0.8)
				print("Resultado del movimiento: ", result)
				_mostrar_notificacion_victoria(func():
					is_moving = false
					var siguiente_id: int = int(level_data.id) + 1
					var siguiente_ruta: String = "res://data/levels/level_%02d.json" % siguiente_id

					if siguiente_id <= 4 and FileAccess.file_exists(siguiente_ruta):
						_cargar_nivel(siguiente_ruta)
					else:
						_generar_nuevo_procedural()
				)
		)

		# Reacción visual según el resultado
		if result == BoardState.MoveResult.FELL:
			tw.tween_property(moving_blk, "scale", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			# Freno elástico sutil o pulso de absorción
			var squash := Vector2(0.95, 1.05) if dir.x != 0 else Vector2(1.05, 0.95)
			tw.tween_property(moving_blk, "scale", squash, 0.03)
			tw.tween_property(moving_blk, "scale", Vector2.ONE, 0.04).set_trans(Tween.TRANS_SINE)

		# Liberación del turno
		tw.finished.connect(func():
			if result != BoardState.MoveResult.VICTORY:
				is_moving = false
				_sincronizar_bloques_completos()
		)

	else:
			# Ya está contra el muro
			var moving_blk: Panel = block_nodes[bloque_seleccionado]
			AudioManager.play("bump", 0.85, -14.0, 0.05)

			# Micro-choque
			var offset_bump := Vector2(dir.x, dir.y) * 3.0
			var pos_origen := moving_blk.position

			var tw_bump := create_tween()
			tw_bump.tween_property(moving_blk, "position", pos_origen + offset_bump, 0.03).set_trans(Tween.TRANS_QUAD)
			tw_bump.tween_property(moving_blk, "position", pos_origen, 0.04).set_trans(Tween.TRANS_SINE)

func _sincronizar_bloques_completos() -> void:
	var corner_rad := int(cell_size * 0.09)

	for id in block_nodes.keys():
		var info: Dictionary = board.block_info(id)
		var blk: Panel = block_nodes[id]

		# Bloque absorbido por fusión o caído en abismo
		if info.is_empty():
			blk.visible = false
			continue

		blk.visible = true
		var col: Color = COLOR_MAP.get(info["color"], Color.WHITE)
		var es_locked: bool = info.get("locked", false)
		var estilo := obtener_estilo(EstiloTipo.GLASS_BLOCK, col, corner_rad)

		if es_locked:
			estilo.shadow_size = 0
			estilo.border_color = Color(1.0, 1.0, 1.0, 0.15)
			blk.z_index = 1
		blk.add_theme_stylebox_override("panel", estilo)

		# Solo sincronizar la posición si no está en pleno tween activo
		if not is_moving or id != bloque_seleccionado:
			blk.position = Vector2(info["pos"].x * cell_size + 4, info["pos"].y * cell_size + 4)

		# Si el glifo cambió de color (hubo fusión), provocar un golpe de escala sutil (pop)
		if blk.has_node("Glyph"):
			var g: Glyph = blk.get_node("Glyph")
			if g.color_name != info["color"]:
				AudioManager.play("merge", 1.10, -8)
				var pop := create_tween()
				pop.tween_property(blk, "scale", Vector2(1.18, 1.18), 0.05).set_trans(Tween.TRANS_SINE)
				pop.tween_property(blk, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_SINE)
			g.setup(info["color"], (cell_size - 8) * 0.25)

		_actualizar_glifo(blk, info["color"])

	# Actualizar puntero al bloque activo
	var activos := board.active_block_ids()
	if not activos.has(bloque_seleccionado):
		bloque_seleccionado = activos[0] if not activos.is_empty() else ""

	_actualizar_seleccion_visual()


func _actualizar_glifo(blk: Panel, color_name: String) -> void:
	if blk.has_node("Glyph"):
		var g: Glyph = blk.get_node("Glyph")
		g.setup(color_name, (cell_size - 8) * 0.25)


# ==============================================================================
# GESTIÓN DE TURNOS Y DESHACER
# ==============================================================================

func _undo() -> void:
	if history_stack.is_empty() or is_moving:
		return
	AudioManager.play("undo", 1.0, -3.0, 0.08)

	var prev_record: Dictionary = history_stack.pop_back()
	board.restore(prev_record["board"])
	bloque_seleccionado = prev_record.get("block_id", bloque_seleccionado)
	_sincronizar_bloques_completos()


func _restart() -> void:
	if is_moving:
		return
	AudioManager.play("undo", 0.85, -2.0, 0.08)
	board.restore(initial_snapshot)
	history_stack.clear()

	if not level_data.blocks.is_empty():
		bloque_seleccionado = level_data.blocks[0]["id"]
	_sincronizar_bloques_completos()


# ==============================================================================
# FEEDBACK VISUAL Y NOTIFICACIONES
# ==============================================================================

func _actualizar_seleccion_visual() -> void:
	var corner_rad := int(cell_size * 0.09)
	for id in block_nodes:
		var blk: Panel = block_nodes[id]
		var info: Dictionary = board.block_info(id)
		if info.is_empty():
			continue
		var col: Color = COLOR_MAP.get(info["color"], Color.WHITE)
		var st := obtener_estilo(EstiloTipo.GLASS_BLOCK, col, corner_rad)

		if id == bloque_seleccionado:
			blk.z_index = 10
			blk.scale = Vector2(1.08, 1.08)
			st.border_width_left = 1
			st.border_width_top = 1
			st.border_width_right = 1
			st.border_width_bottom = 1
			st.border_color = Color(1.0, 1.0, 1.0, 0.90)
			st.shadow_color = Color(col.r, col.g, col.b, 0.60)
			st.shadow_size = 8
			st.shadow_offset = Vector2(0, 2)
		else:
			blk.z_index = 2
			blk.scale = Vector2.ONE
			st.shadow_color = Color(0, 0, 0, 0.35)
			st.shadow_size = 4
			st.shadow_offset = Vector2(0, 2)

		blk.add_theme_stylebox_override("panel", st)

		blk.add_theme_stylebox_override("panel", st)

func _mostrar_notificacion_victoria(on_complete: Callable) -> void:
	# 1. Crear CanvasLayer en la raíz absoluta de la ventana
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	get_tree().root.add_child(canvas)

	# 2. Fondo oscuro
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.04, 0.06, 0.75)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(backdrop)

	# 3. Tarjeta central
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 96)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _crear_estilo_banner_victoria())
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var lbl_sub := Label.new()
	lbl_sub.text = "ESTADO DEL SISTEMA // RESUELTO"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 10)
	lbl_sub.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.40))
	vbox.add_child(lbl_sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var lbl_main := Label.new()
	lbl_main.text = "SECTOR COMPLETADO"
	lbl_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_main.add_theme_font_size_override("font_size", 17)
	lbl_main.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98, 1.0))
	vbox.add_child(lbl_main)

	# 4. Control de opacidad directo sobre el CanvasLayer entero
	# Inicia completamente invisible
	backdrop.modulate.a = 0.0
	panel.modulate.a = 0.0

	# ── SECUENCIA CRONOLÓGICA CON AWAIT (Sin conflictos de Tweens encadenados) ──
	# A. Fade in limpio (0.25s)
	var tw_in := canvas.create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(backdrop, "modulate:a", 1.0, 0.25)
	tw_in.tween_property(panel, "modulate:a", 1.0, 0.25)
	await tw_in.finished

	# B. Tiempo garantizado de lectura (2.0 segundos reales sin tocar nada)
	await get_tree().create_timer(2.0).timeout

	# C. Fade out suave (0.35s)
	if is_instance_valid(canvas):
		var tw_out := canvas.create_tween()
		tw_out.set_parallel(true)
		tw_out.tween_property(backdrop, "modulate:a", 0.0, 0.35)
		tw_out.tween_property(panel, "modulate:a", 0.0, 0.35)
		await tw_out.finished

		# D. Destrucción del cartel y cambio de nivel
		canvas.queue_free()
		if on_complete.is_valid():
			on_complete.call()


# ==============================================================================
# CARGA Y GENERACIÓN PROCEDURAL
# ==============================================================================

func _cargar_nivel(origen: Variant) -> void:
	var nuevo_nivel: LevelData = null

	if origen is String:
		nuevo_nivel = LevelLoader.load_from_file(origen)
	elif origen is LevelData:
		nuevo_nivel = origen

	if nuevo_nivel == null or not nuevo_nivel.is_valid():
		push_error("No se pudo cargar el nivel.")
		return

	level_data = nuevo_nivel
	board = BoardState.new()
	board.init_from_level(level_data)

	initial_snapshot = board.snapshot()
	history_stack.clear()
	is_moving = false

	# Limpiar capas visuales anteriores
	for contenedor in [board_container, receptors_container, blocks_container]:
		for hijo in contenedor.get_children():
			contenedor.remove_child(hijo)
			hijo.queue_free()

	block_nodes.clear()
	if not level_data.blocks.is_empty():
		bloque_seleccionado = level_data.blocks[0]["id"]
	else:
		bloque_seleccionado = ""

	_build_greybox()
	_actualizar_seleccion_visual()
	_actualizar_mensaje_tutorial()

	if has_node("HUD/HUDContainer/SectorLabel"):
		if level_data.id == 99:
			$HUD/HUDContainer/SectorLabel.text = "SECTOR ∞ — %s" % level_data.level_name
		else:
			$HUD/HUDContainer/SectorLabel.text = "SECTOR %02d — %s" % [level_data.sector, level_data.level_name]

func _actualizar_mensaje_tutorial() -> void:
	if not has_node("HUD/TutorialPrompt"):
		return
		
	var prompt: Label = $HUD/TutorialPrompt
	var mensaje: String = level_data.instruction.strip_edges()

	# Si no hay texto, ocultar
	if mensaje == "":
		prompt.visible = false
		return

	# Tamaño en píxeles de una casilla (ajustar si tu constante se llama distinto, ej. CELL_SIZE)
	var cell_px: float = 64.0
	if "cell_size" in self:
		cell_px = float(cell_size)

	var ancho_tablero: float = float(level_data.width) * cell_px
	var alto_tablero: float = float(level_data.height) * cell_px
	var alto_banner: float = 24.0

	prompt.text = mensaje
	prompt.visible = true
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
	prompt.add_theme_stylebox_override("normal", _crear_estilo_footer_interno())

	# Dimensionar y anclar en la orilla inferior interna de board_container
	prompt.size = Vector2(ancho_tablero, alto_banner)
	prompt.global_position = Vector2(
		board_container.global_position.x,
		board_container.global_position.y + alto_tablero - alto_banner
	)
	prompt.z_index = 50

func _generar_nuevo_procedural() -> void:
	procedural_run_count += 1
	print("Calculando tablero procedural con solución...")
	var nuevo_nivel := LevelGenerator.generate_level(6, 6, 4, 8)

	if nuevo_nivel:
		nuevo_nivel.sector = 4
		nuevo_nivel.level_name = "SIMULATION // %02d" % procedural_run_count

		var ruta_solucion := LevelGenerator.solve_bfs(nuevo_nivel, 10)
		print("--- SOLUCIÓN CALCULADA POR BFS (%d pasos) ---" % ruta_solucion.size())
		for paso in ruta_solucion:
			print("Mover %s hacia %s" % [paso["block"], paso["dir"]])
		print("---------------------------------------------")

		_cargar_nivel(nuevo_nivel)
