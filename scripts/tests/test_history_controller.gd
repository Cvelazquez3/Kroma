
@tool
extends EditorScript

func _run() -> void:
	var level := LevelLoader.load_from_file("res://data/levels/level_01.json")

	if not level.is_valid():
		push_error("\n".join(level.errors))
		return

	var board := BoardState.new()
	board.init_from_level(level)

	var history := HistoryController.new()
	history.iniciar_nivel(board)

	var bloques := board.active_block_ids()
	if bloques.is_empty():
		push_error("No hay bloques disponibles para probar.")
		return

	var bloque_id: String = bloques[0]
	var posicion_inicial: Vector2i = board.block_info(bloque_id)["pos"]

	print("Posicion inicial: ", posicion_inicial)

	# Primer movimiento real.
	var estado_anterior := board.snapshot()
	board.apply_move(bloque_id, Vector2i.LEFT)

	if board.snapshot() != estado_anterior:
		history.historial.append(estado_anterior)

	print("Posicion despues del primer movimiento: ", board.block_info(bloque_id)["pos"])

	# Segundo movimiento real.
	estado_anterior = board.snapshot()
	board.apply_move(bloque_id, Vector2i.UP)

	if board.snapshot() != estado_anterior:
		history.historial.append(estado_anterior)

	print("Posicion despues del segundo movimiento: ", board.block_info(bloque_id)["pos"])
	print("Movimientos guardados: ", history.cantidad_movimientos())

	# Deshacer el segundo movimiento.
	var undo_1 := history.deshacer(board)
	print("Primer Undo correcto: ", undo_1)
	print("Posicion despues del primer Undo: ", board.block_info(bloque_id)["pos"])

	# Deshacer el primer movimiento.
	var undo_2 := history.deshacer(board)
	print("Segundo Undo correcto: ", undo_2)
	print("Posicion despues del segundo Undo: ", board.block_info(bloque_id)["pos"])

	var regreso_al_inicio: bool = board.block_info(bloque_id)["pos"] == posicion_inicial
	print("Coincide con el inicio: ", regreso_al_inicio)

	# Intentar deshacer sin historial.
	print("Undo sin historial: ", history.deshacer(board))

	# Realizar otro movimiento y reiniciar.
	estado_anterior = board.snapshot()
	board.apply_move(bloque_id, Vector2i.RIGHT)

	if board.snapshot() != estado_anterior:
		history.historial.append(estado_anterior)

	history.reiniciar(board)

	print("Posicion despues de reiniciar: ", board.block_info(bloque_id)["pos"])
	print("Historial despues de reiniciar: ", history.cantidad_movimientos())

	if regreso_al_inicio and history.cantidad_movimientos() == 0:
		print("Prueba de historial finalizada correctamente")
	else:
		push_error("La prueba de historial no obtuvo el resultado esperado")
