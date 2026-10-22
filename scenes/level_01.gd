extends Node2D

const CELL_SIZE := 80
const COLOR_MAP := {
	"red": Color(0.9, 0.2, 0.2),
	"blue": Color(0.2, 0.4, 0.9),
	"yellow": Color(0.95, 0.8, 0.2),
	"empty": Color(0.12, 0.12, 0.16),
	"wall": Color(0.35, 0.35, 0.4)
}

var level_data: LevelData
var board: BoardState
var block_nodes: Dictionary = {}
var is_moving: bool = false

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

func _build_greybox() -> void:
	position = Vector2(100, 60)
	
	for x in range(level_data.width):
		for y in range(level_data.height):
			var cell := ColorRect.new()
			cell.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
			cell.position = Vector2(x * CELL_SIZE + 2, y * CELL_SIZE + 2)
			cell.color = COLOR_MAP["empty"]
			board_container.add_child(cell)

	for w in level_data.walls:
		var wall := ColorRect.new()
		wall.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
		wall.position = Vector2(w.x * CELL_SIZE + 2, w.y * CELL_SIZE + 2)
		wall.color = COLOR_MAP["wall"]
		board_container.add_child(wall)

	for r in level_data.receptors:
		var rec := ColorRect.new()
		rec.size = Vector2(CELL_SIZE - 16, CELL_SIZE - 16)
		rec.position = Vector2(r["pos"].x * CELL_SIZE + 8, r["pos"].y * CELL_SIZE + 8)
		var c: Color = COLOR_MAP.get(r["color"], Color.WHITE)
		c.a = 0.45
		rec.color = c
		receptors_container.add_child(rec)

	for b in level_data.blocks:
		var blk := ColorRect.new()
		blk.size = Vector2(CELL_SIZE - 8, CELL_SIZE - 8)
		blk.position = Vector2(b["pos"].x * CELL_SIZE + 4, b["pos"].y * CELL_SIZE + 4)
		blk.color = COLOR_MAP.get(b["color"], Color.WHITE)
		blocks_container.add_child(blk)
		block_nodes[b["id"]] = blk

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return
		
	if event.is_action_pressed("ui_up"):
		_execute_move(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		_execute_move(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		_execute_move(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		_execute_move(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_undo") or (event is InputEventKey and event.pressed and event.keycode == KEY_Z):
		_undo()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()

func _execute_move(dir: Vector2i) -> void:
	# Guardamos tanto el estado lógico como la posición visual previa
	var blk: ColorRect = block_nodes["b1"]
	var snap := {
		"board": board.snapshot(),
		"pos": blk.position
	}
	
	var path: Array = []
	var result = board.apply_move("b1", dir, path)
	
	if result == BoardState.MoveResult.BLOCKED or result == BoardState.MoveResult.NOT_FOUND:
		return
	
	if path.size() > 0:
		history_stack.push_back(snap)
		is_moving = true
		var target_pos := Vector2(path[-1].x * CELL_SIZE + 4, path[-1].y * CELL_SIZE + 4)
		
		var tween := create_tween()
		tween.tween_property(blk, "position", target_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		tween.finished.connect(func():
			is_moving = false
			if result == BoardState.MoveResult.VICTORY:
				print("¡NIVEL 1 COMPLETADO: SISTEMA ESTABILIZADO!")
		)

func _undo() -> void:
	if history_stack.is_empty() or is_moving:
		return
	
	var prev_record: Dictionary = history_stack.pop_back()
	board.restore(prev_record["board"])
	
	# Restaurar de inmediato la posición en pantalla con animación
	var blk: ColorRect = block_nodes["b1"]
	is_moving = true
	var tw := create_tween()
	tw.tween_property(blk, "position", prev_record["pos"], 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		is_moving = false
	)
	print("Undo ejecutado. Pasos restantes: ", history_stack.size())

func _restart() -> void:
	if is_moving:
		return
	board.restore(initial_snapshot)
	history_stack.clear()
	
	# Regresar visualmente al punto de partida
	var blk: ColorRect = block_nodes["b1"]
	var start_pos := Vector2(level_data.blocks[0]["pos"].x * CELL_SIZE + 4, level_data.blocks[0]["pos"].y * CELL_SIZE + 4)
	blk.position = start_pos
	print("Nivel reiniciado.")

func _sync_visuals() -> void:
	# Sincroniza la posición visual con el estado de BoardState
	var blk: ColorRect = block_nodes["b1"]
	for b in level_data.blocks:
		if b["id"] == "b1":
			# Como b1 es el único bloque, buscamos su celda en el tablero
			for x in range(level_data.width):
				for y in range(level_data.height):
					var cell_val = board.get_cell(x, y) if board.has_method("get_cell") else -1
					# Si BoardState guarda la posición interna en su snapshot, se restaura
	# Posición inicial o previa:
	# Nota: Si el snapshot guarda los datos de bloque, animamos de regreso
	var target_pos := Vector2(level_data.blocks[0]["pos"].x * CELL_SIZE + 4, level_data.blocks[0]["pos"].y * CELL_SIZE + 4) if history_stack.is_empty() else blk.position
	blk.position = target_pos
