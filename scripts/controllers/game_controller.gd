
extends Node

# Controlador principal del juego Kroma.

# Estado actual del tablero.
var board: BoardState

# Historial para Undo y reinicio.
var history: HistoryController


func _ready() -> void:
	# Crear el estado del tablero y el historial.
	board = BoardState.new()
	history = HistoryController.new()

	# Cargar el nivel de prueba.
	var level := LevelLoader.load_from_file(
		"res://data/levels/level_01.json"
	)

	if not level.is_valid():
		push_error("\n".join(level.errors))
		return

	board.load_from_level(level)
	history.iniciar_nivel(board)

	print("GameController inicializado")
	print("Nivel cargado: ", level.level_name)
	print("Bloques disponibles: ", board.blocks.size())
	print("Movimientos en historial: ", history.cantidad_movimientos())



func _on_input_controller_deshacer_solicitado() -> void:
	if board == null or history == null:
		return


	if history.deshacer(board):
		print("Undo realizado correctamente")

		if not board.blocks.is_empty():
			print("Posicion actual: ", board.blocks[0]["pos"])
	else:
		print("No hay movimientos para deshacer")

		
		

func _on_input_controller_reiniciar_solicitado() -> void:
	if board == null or history == null:
		return

	history.reiniciar(board)

	print("Nivel reiniciado correctamente")
	if not board.blocks.is_empty():
		print("Posicion inicial: ", board.blocks[0]["pos"])
	print("Movimientos en historial: ", history.cantidad_movimientos())



func _on_input_controller_movimiento_solicitado(direccion: Vector2i) -> void:
	if board == null or history == null:
		$"../InputController".finalizar_movimiento()
		return

	print("GameController recibio movimiento: ", direccion)

	# Guardar una copia temporal del estado anterior.
	var estado_anterior: Dictionary = board.snapshot()

	# PENDIENTE: aqui se ejecutara la logica de movimiento de Ian.

	# Solo registrar el movimiento si realmente cambio el tablero.
	if board.snapshot() != estado_anterior:
		history.historial.append(estado_anterior)
		print("Movimiento guardado en historial")
	else:
		print("El tablero no cambio. No se guarda movimiento.")

	$"../InputController".finalizar_movimiento()
