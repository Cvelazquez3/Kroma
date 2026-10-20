extends SceneTree
## Pruebas de BoardState: lógica pura del tablero.
##
## Ejecutar desde la raíz del proyecto:
##   godot --headless --path . --script res://scripts/tests/test_board_state.gd

var _failures: int = 0


func _init() -> void:
	_test_init_from_level()
	_test_blocked_by_wall()
	_test_blocked_by_border()
	_test_slides_to_wall()
	_test_slides_multiple_cells()
	_test_snap_and_undo()
	_test_reset()
	_test_victory()
	_test_fell_in_void()
	_test_determinism()

	print("")
	if _failures == 0:
		print("TODO OK: BoardState pasa todas las pruebas")
	else:
		print("FALLARON %d pruebas" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok   - %s" % name)
	else:
		print("  FAIL - %s" % name)
		_failures += 1


# ──────────────────────────────────────────────────────── utilidad ───────────

## Crea un LevelData sencillo de 5×5 con un bloque rojo y su receptor.
## Layout (0,0 arriba-izquierda):
##   . . . . .
##   . . . . .
##   . . . . R   <- receptor rojo en (4,2)
##   . . . B W   <- bloque rojo en (3,3), muro en (4,3)
##   . . . W .   <- muro en (3,4)
func _make_level_01() -> LevelData:
	return LevelLoader.load_from_file("res://data/levels/level_01.json")


func _make_state() -> BoardState:
	var level := _make_level_01()
	assert(level.is_valid(), "El nivel 01 debe ser válido para las pruebas")
	var state := BoardState.new()
	state.init_from_level(level)
	return state


# ──────────────────────────────────────────────────────── pruebas ────────────

func _test_init_from_level() -> void:
	print("Inicializar desde nivel")
	var state := _make_state()
	_check(state.width == 5 and state.height == 5, "tablero 5×5")
	_check(state.cell_at(Vector2i(4, 3)) == BoardState.Cell.WALL, "muro en (4,3)")
	_check(state.cell_at(Vector2i(3, 3)) == BoardState.Cell.BLOCK, "bloque en (3,3)")
	_check(state.cell_at(Vector2i(4, 2)) == BoardState.Cell.RECEPTOR, "receptor en (4,2)")
	_check(state.cell_at(Vector2i(0, 0)) == BoardState.Cell.EMPTY, "celda (0,0) vacía")


func _test_blocked_by_wall() -> void:
	print("Bloqueado por muro adyacente")
	var state := _make_state()
	# El bloque está en (3,3); a la derecha hay un muro en (4,3).
	var result := state.apply_move("b1", Vector2i.RIGHT)
	_check(result == BoardState.MoveResult.BLOCKED, "no puede moverse a la derecha (muro)")
	_check(state.block_info("b1")["pos"] == Vector2i(3, 3), "sigue en (3,3)")


func _test_blocked_by_border() -> void:
	print("Bloqueado por borde del tablero")
	var state := _make_state()
	# Mover abajo: (3,3) → el siguiente paso sería (3,4) → muro → BLOCKED.
	var result := state.apply_move("b1", Vector2i.DOWN)
	_check(result == BoardState.MoveResult.BLOCKED, "bloqueado por muro en (3,4)")


func _test_slides_to_wall() -> void:
	print("Deslizarse hasta muro")
	var state := _make_state()
	# Mover izquierda: (3,3) → (2,3) → (1,3) → (0,3) → borde → para en (0,3).
	var path: Array = []
	var result := state.apply_move("b1", Vector2i.LEFT, path)
	_check(result == BoardState.MoveResult.OK, "se mueve a la izquierda")
	_check(state.block_info("b1")["pos"] == Vector2i(0, 3), "termina en (0,3)")
	_check(path.size() == 3, "recorrió 3 celdas")
	_check(state.cell_at(Vector2i(3, 3)) == BoardState.Cell.EMPTY, "origen queda vacío")
	_check(state.cell_at(Vector2i(0, 3)) == BoardState.Cell.BLOCK, "destino ocupado")


func _test_slides_multiple_cells() -> void:
	print("Deslizamiento de múltiples celdas")
	var state := _make_state()
	# Mover arriba: (3,3) → (3,2) → (3,1) → (3,0) → borde → para en (3,0).
	var path: Array = []
	var result := state.apply_move("b1", Vector2i.UP, path)
	_check(result == BoardState.MoveResult.OK, "se mueve hacia arriba")
	_check(state.block_info("b1")["pos"] == Vector2i(3, 0), "termina en (3,0)")
	_check(path.size() == 3, "recorrió 3 celdas")


func _test_snap_and_undo() -> void:
	print("Snapshot y Undo")
	var state := _make_state()
	var snap := state.snapshot()
	state.apply_move("b1", Vector2i.LEFT)
	_check(state.block_info("b1")["pos"] != Vector2i(3, 3), "bloque se movió")
	state.restore(snap)
	_check(state.block_info("b1")["pos"] == Vector2i(3, 3), "Undo: vuelve a (3,3)")
	_check(state.cell_at(Vector2i(3, 3)) == BoardState.Cell.BLOCK, "rejilla restaurada")


func _test_reset() -> void:
	print("Reinicio rápido")
	var state := _make_state()
	var initial_snap := state.snapshot()
	# Mover varias veces.
	state.apply_move("b1", Vector2i.LEFT)
	state.apply_move("b1", Vector2i.UP)
	state.restore(initial_snap)
	_check(state.block_info("b1")["pos"] == Vector2i(3, 3), "posición reiniciada")
	_check(state.cell_at(Vector2i(3, 3)) == BoardState.Cell.BLOCK, "celda inicial restaurada")


func _test_victory() -> void:
	print("Victoria al encajar")
	var state := _make_state()
	# El receptor rojo está en (4,2). Necesitamos llevar el bloque ahí.
	# Primero subimos: (3,3) → (3,0).
	var snap := state.snapshot()
	state.apply_move("b1", Vector2i.UP)   # b1 en (3,0)
	# Luego a la derecha: (3,0) → (4,0) → borde derecho → para en (4,0)... 
	# pero (4,0) está libre. Después abajo: (4,0) → (4,1) → receptor en (4,2).
	state.apply_move("b1", Vector2i.RIGHT) # b1 en (4,0)
	var result := state.apply_move("b1", Vector2i.DOWN) # hacia (4,1) → (4,2) receptor
	_check(
		result == BoardState.MoveResult.SNAPPED or result == BoardState.MoveResult.VICTORY,
		"encaje en receptor (SNAPPED o VICTORY)"
	)
	_check(state.cell_at(Vector2i(4, 2)) == BoardState.Cell.LOCKED, "celda encajada = LOCKED")


func _test_fell_in_void() -> void:
	print("Bloque cae en abismo")
	# Crear un nivel ad-hoc con un abismo.
	var data: Dictionary = {
		"version": 1, "id": 99, "name": "test_void", "sector": 1,
		"size": { "width": 5, "height": 5 },
		"walls": [],
		"voids": [{ "x": 2, "y": 0 }],
		"blocks": [{ "id": "b1", "x": 2, "y": 2, "color": "blue" }],
		"receptors": [{ "x": 4, "y": 4, "color": "blue" }],
	}
	var level := LevelLoader.load_from_dict(data)
	assert(level.is_valid(), "nivel con abismo debe ser válido")
	var state := BoardState.new()
	state.init_from_level(level)
	var result := state.apply_move("b1", Vector2i.UP)
	_check(result == BoardState.MoveResult.FELL, "bloque cayó en el abismo")
	_check(not state.active_block_ids().has("b1"), "bloque eliminado del estado")


func _test_determinism() -> void:
	print("Determinismo: misma secuencia → mismo estado")
	var state_a := _make_state()
	var state_b := _make_state()
	var moves: Array = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
	for m: Vector2i in moves:
		state_a.apply_move("b1", m)
		state_b.apply_move("b1", m)
	_check(
		state_a.block_info("b1")["pos"] == state_b.block_info("b1")["pos"],
		"posición idéntica tras la misma secuencia"
	)
