extends Node2D

const BASE_CELL_SIZE := 80
const COLOR_MAP := {
	"red": Color(0.9, 0.2, 0.2),
	"blue": Color(0.2, 0.4, 0.9),
	"yellow": Color(0.95, 0.8, 0.2),
	"purple": Color(0.6, 0.2, 0.8),
	"green": Color(0.2, 0.8, 0.3),
	"orange": Color(1.0, 0.5, 0.1),
	"empty": Color(0.12, 0.12, 0.16),
	"wall": Color(0.35, 0.35, 0.4),
	"void": Color(0.04, 0.04, 0.06),
}

var cell_size: float = BASE_CELL_SIZE
var level_data: LevelData
var board: BoardState
var block_nodes: Dictionary = {}
var is_moving: bool = false
var bloque_seleccionado: String = "b1"

# Historial para Undo y Reinicio
var history_stack: Array = []
var initial_snapshot: Dictionary = {}

@onready var board_container: Node2D = $BoardContainer
@onready var receptors_container: Node2D = $ReceptorsContainer
@onready var blocks_container: Node2D = $BlocksContainer

func _ready() -> void:
	level_data = LevelLoader.load_from_file("res://data/levels/level_01.json")
	if not level_data.is_valid():
		push_error("Error al cargar nivel: \n" + "\n".join(level_data.errors))
		return
	
	board = BoardState.new()
	board.init_from_level(level_data)
	
	# Guardar snapshot inicial para el Reinicio
	initial_snapshot = board.snapshot()
	
	_build_greybox()
	_actualizar_seleccion_visual()
	$HUD/HUDContainer/RestartButton.pressed.connect(_restart)
	$HUD/HUDContainer/UndoButton.pressed.connect(_undo)

func _build_greybox() -> void:
	# Ajustar cell_size dinámicamente si el tablero supera 5 celdas
	var max_dim := max(level_data.width, level_data.height)
	if max_dim > 5:
		cell_size = 520.0 / float(max_dim)
	else:
		cell_size = float(BASE_CELL_SIZE)

	# Centrado en pantalla (resolución base típica 1152x648)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1152, 648)
	var board_pixel_width := level_data.width * cell_size
	var board_pixel_height := level_data.height * cell_size
	position = Vector2(
		max(40.0, (viewport_size.x - board_pixel_width) * 0.5),
		max(70.0, (viewport_size.y - board_pixel_height) * 0.5 + 20.0)
	)
	
	# Celdas vacías
	for x in range(level_data.width):
		for y in range(level_data.height):
			var cell := ColorRect.new()
			cell.size = Vector2(cell_size - 4, cell_size - 4)
			cell.position = Vector2(x * cell_size + 2, y * cell_size + 2)
			cell.color = COLOR_MAP["empty"]
			board_container.add_child(cell)

	# Abismos (voids)
	for v in level_data.voids:
		var void_rect := ColorRect.new()
		void_rect.size = Vector2(cell_size - 4, cell_size - 4)
		void_rect.position = Vector2(v.x * cell_size + 2, v.y * cell_size + 2)
		void_rect.color = COLOR_MAP["void"]
		board_container.add_child(void_rect)

	# Muros
	for w in level_data.walls:
		var wall := ColorRect.new()
		wall.size = Vector2(cell_size - 4, cell_size - 4)
		wall.position = Vector2(w.x * cell_size + 2, w.y * cell_size + 2)
		wall.color = COLOR_MAP["wall"]
		board_container.add_child(wall)

	# Receptores con Glifo de Ian
	for r in level_data.receptors:
		var pos_v: Vector2i = r["pos"]
		var rec := ColorRect.new()
		rec.size = Vector2(cell_size - 16, cell_size - 16)
		rec.position = Vector2(pos_v.x * cell_size + 8, pos_v.y * cell_size + 8)
		var c: Color = COLOR_MAP.get(r["color"], Color.WHITE)
		c.a = 0.45
		rec.color = c
		receptors_container.add_child(rec)

		# Glifo de accesibilidad en el receptor
		var glyph := Glyph.new()
		glyph.name = "Glyph"
		glyph.position = rec.size / 2.0
		glyph.setup(r["color"], (cell_size - 16) * 0.22)
		rec.add_child(glyph)

	# Bloques activos con Glifo de Ian
	for b in level_data.blocks:
		var pos_b: Vector2i = b["pos"]
		var blk := ColorRect.new()
		blk.size = Vector2(cell_size - 8, cell_size - 8)
		blk.position = Vector2(pos_b.x * cell_size + 4, pos_b.y * cell_size + 4)
		blk.color = COLOR_MAP.get(b["color"], Color.WHITE)
		blocks_container.add_child(blk)
		block_nodes[b["id"]] = blk
		blk.pivot_offset = blk.size / 2.0

		var glyph := Glyph.new()
		glyph.name = "Glyph"
		glyph.position = blk.size / 2.0
		glyph.setup(b["color"], (cell_size - 8) * 0.25)
		blk.add_child(glyph)

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_TAB:
		var bloques := board.active_block_ids()
		if not bloques.is_empty():
			var indice := bloques.find(bloque_seleccionado)
			bloque_seleccionado = bloques[(indice + 1) % bloques.size()]
			_actualizar_seleccion_visual()
			print("Bloque seleccionado: ", bloque_seleccionado)
		return
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

func _execute_move(dir: Vector2i) -> void:
	if not block_nodes.has(bloque_seleccionado):
		return
	var blk: ColorRect = block_nodes[bloque_seleccionado]
	var snap := {
		"board": board.snapshot(),
		"pos": blk.position,
		"block_id": bloque_seleccionado
	}
	
	var path: Array = []
	var result = board.apply_move(bloque_seleccionado, dir, path)
	var info_bloque: Dictionary = board.block_info(bloque_seleccionado)
	if info_bloque.has("color"):
		blk.color = COLOR_MAP.get(info_bloque["color"], Color.WHITE)
		_actualizar_glifo(blk, info_bloque["color"])

	for id in block_nodes:
		block_nodes[id].visible = not board.block_info(id).is_empty()
	if result == BoardState.MoveResult.BLOCKED or result == BoardState.MoveResult.NOT_FOUND:
		return
	
	if path.size() > 0:
		history_stack.push_back(snap)
		is_moving = true
		var target_pos := Vector2(path[-1].x * cell_size + 4, path[-1].y * cell_size + 4)
		
		var tween := create_tween()
		tween.tween_property(blk, "position", target_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		tween.finished.connect(func():
			is_moving = false
			
			if board.block_info(bloque_seleccionado).is_empty():
				var disponibles := board.active_block_ids()
				if not disponibles.is_empty():
					bloque_seleccionado = disponibles[0]
				_actualizar_seleccion_visual()
			if result == BoardState.MoveResult.VICTORY:
				print("¡Nivel completado!")
				var siguiente_id: int = int(level_data.id) + 1
				var siguiente_ruta: String = "res://data/levels/level_%02d.json" % siguiente_id

				if FileAccess.file_exists(siguiente_ruta):
					_cargar_nivel(siguiente_ruta)
				else:
					print("¡Has completado todos los niveles disponibles!")
		)

func _actualizar_glifo(blk: ColorRect, color_name: String) -> void:
	if blk.has_node("Glyph"):
		var g: Glyph = blk.get_node("Glyph")
		g.setup(color_name, (cell_size - 8) * 0.25)

func _undo() -> void:
	if history_stack.is_empty() or is_moving:
		return
	
	var prev_record: Dictionary = history_stack.pop_back()
	board.restore(prev_record["board"])
	
	for id in block_nodes:
		var info: Dictionary = board.block_info(id)
		block_nodes[id].visible = not info.is_empty()
		if not info.is_empty():
			block_nodes[id].color = COLOR_MAP.get(info["color"], Color.WHITE)
			block_nodes[id].position = Vector2(info["pos"].x * cell_size + 4, info["pos"].y * cell_size + 4)
			_actualizar_glifo(block_nodes[id], info["color"])

	# Asegurar bloque seleccionado válido
	if not board.active_block_ids().has(bloque_seleccionado):
		var act := board.active_block_ids()
		if not act.is_empty():
			bloque_seleccionado = act[0]
	_actualizar_seleccion_visual()
	print("Undo ejecutado. Pasos restantes: ", history_stack.size())

func _restart() -> void:
	if is_moving:
		return
	board.restore(initial_snapshot)
	history_stack.clear()
	
	for b in level_data.blocks:
		var blk: ColorRect = block_nodes[b["id"]]
		var start_pos := Vector2(b["pos"].x * cell_size + 4, b["pos"].y * cell_size + 4)
		blk.position = start_pos
		blk.color = COLOR_MAP.get(b["color"], Color.WHITE)
		blk.visible = true
		_actualizar_glifo(blk, b["color"])

	bloque_seleccionado = level_data.blocks[0]["id"]
	_actualizar_seleccion_visual()
	print("Nivel reiniciado.")

func _actualizar_seleccion_visual() -> void:
	for id in block_nodes:
		var blk: ColorRect = block_nodes[id]
		if id == bloque_seleccionado:
			blk.scale = Vector2(1.12, 1.12)
		else:
			blk.scale = Vector2.ONE
			
func _cargar_nivel(ruta: String) -> void:
	var nuevo_nivel: LevelData = LevelLoader.load_from_file(ruta)

	if not nuevo_nivel.is_valid():
		push_error("No se pudo cargar el nivel: " + ruta)
		return

	level_data = nuevo_nivel
	board = BoardState.new()
	board.init_from_level(level_data)

	initial_snapshot = board.snapshot()
	history_stack.clear()
	is_moving = false

	for contenedor in [board_container, receptors_container, blocks_container]:
		for hijo in contenedor.get_children():
			contenedor.remove_child(hijo)
			hijo.queue_free()

	block_nodes.clear()
	bloque_seleccionado = level_data.blocks[0]["id"]

	_build_greybox()
	_actualizar_seleccion_visual()

	$HUD/HUDContainer/SectorLabel.text = "SECTOR " + str(level_data.sector) + " - " + str(level_data.name)
