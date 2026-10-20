
extends Node

# Controlador principal del juego Kroma.

# Estado actual del tablero.
var board: BoardState

# Historial para Undo y reinicio.
var history: HistoryController


func _ready() -> void:
	# Crear el tablero y el historial.
	board = BoardState.new()
	history = HistoryController.new()

	# Cargar el nivel de prueba.
	var level := LevelLoader.load_from_file(
		"res://data/levels/level_01.json"
	)

	if not level.is_valid():
		push_error("\n".join(level.errors))
		return

	# Inicializar el tablero con la logica de Christian.
	board.init_from_level(level)
	history.iniciar_nivel(board)

	print("GameController inicializado")
	print("Nivel cargado: ", level.level_name)
	print("Bloques disponibles: ", board.active_block_ids().size())
	print("Movimientos en historial: ", history.cantidad_movimientos())


func _on_input_controller_deshacer_solicitado() -> void:
	if board == null or history == null:
		return

	if history.deshacer(board):
		print("Undo realizado correctamente")

		var bloques := board.active_block_ids()

		if not bloques.is_empty():
			var bloque_id: String = bloques[0]
			print("Posicion actual: ", board.block_info(bloque_id)["pos"])
	else:
		print("No hay movimientos para deshacer")


func _on_input_controller_reiniciar_solicitado() -> void:
	if board == null or history == null:
		return

	history.reiniciar(board)

	print("Nivel reiniciado correctamente")

	var bloques := board.active_block_ids()

	if not bloques.is_empty():
		var bloque_id: String = bloques[0]
		print("Posicion inicial: ", board.block_info(bloque_id)["pos"])

	print("Movimientos en historial: ", history.cantidad_movimientos())


func _on_input_controller_movimiento_solicitado(direccion: Vector2i) -> void:
	if board == null or history == null:
		$"../InputController".finalizar_movimiento()
		return

	var bloques := board.active_block_ids()

	if bloques.is_empty():
		print("No hay bloques disponibles para mover")
		$"../InputController".finalizar_movimiento()
		return

	# Seleccionar el primer bloque activo para esta prueba.
	var bloque_id: String = bloques[0]

	# Guardar el estado anterior.
	var estado_anterior: Dictionary = board.snapshot()

	# Ejecutar el movimiento real del tablero.
	var resultado: BoardState.MoveResult = board.apply_move(
		bloque_id,
		direccion
	)

	# Registrar solo los movimientos que modificaron el tablero.
	if board.snapshot() != estado_anterior:
		history.historial.append(estado_anterior)

		print("Movimiento guardado en historial")
		print("Resultado: ", resultado)
		print("Movimientos en historial: ", history.cantidad_movimientos())
	else:
		print("Movimiento bloqueado o sin cambios")

	# Regresar al estado IDLE.
	$"../InputController".finalizar_movimiento()
