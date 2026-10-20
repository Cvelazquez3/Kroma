
@tool
extends EditorScript

func _run() -> void:
	# Cargar el nivel de prueba.
	var level := LevelLoader.load_from_file("res://data/levels/level_01.json")

	if not level.is_valid():
		push_error("\n".join(level.errors))
		return

	var board := BoardState.new()
	board.load_from_level(level)

	var history := HistoryController.new()
	history.iniciar_nivel(board)

	var posicion_inicial: Vector2i = board.blocks[0]["pos"]

	# Simular dos movimientos.
	history.guardar_movimiento(board)
	board.blocks[0]["pos"] = Vector2i(1, 1)

	history.guardar_movimiento(board)
	board.blocks[0]["pos"] = Vector2i(2, 1)

	print("Posicion despues de dos movimientos: ", board.blocks[0]["pos"])
	print("Movimientos guardados: ", history.cantidad_movimientos())

	# Deshacer el segundo movimiento.
	history.deshacer(board)
	print("Despues del primer Undo: ", board.blocks[0]["pos"])

	# Deshacer el primer movimiento.
	history.deshacer(board)
	print("Despues del segundo Undo: ", board.blocks[0]["pos"])
	print("Coincide con el inicio: ", board.blocks[0]["pos"] == posicion_inicial)

	# Comprobar que no se puede deshacer sin historial.
	print("Undo sin historial: ", history.deshacer(board))

	# Simular otro movimiento y reiniciar.
	history.guardar_movimiento(board)
	board.blocks[0]["pos"] = Vector2i(3, 1)

	history.reiniciar(board)
	print("Posicion despues de reiniciar: ", board.blocks[0]["pos"])
	print("Historial despues de reiniciar: ", history.cantidad_movimientos())
