extends SceneTree
## Valida los Niveles 01-03 con el solver BFS y guarda las secuencias de solución.
##
## Tarea Sprint 2 – Christian (fecha: miércoles 22 oct).
## Referencia GDD Página 7: "Verificación algorítmica de la solvencia matemática."
##
## Ejecutar:
##   godot --headless --path . --script res://scripts/tests/test_solver.gd

var _failures: int = 0
var _total:    int = 0


func _init() -> void:
	print("═══════════════════════════════════════════")
	print("  Kroma — Validación de Niveles con Solver ")
	print("═══════════════════════════════════════════")
	print("")

	_validate_level(1, "res://data/levels/level_01.json")
	_validate_level(2, "res://data/levels/level_02.json")
	_validate_level(3, "res://data/levels/level_03.json")

	print("")
	print("───────────────────────────────────────────")
	if _failures == 0:
		print("RESULTADO: %d/%d niveles resolubles ✓" % [_total, _total])
	else:
		print("RESULTADO: %d/%d niveles con problemas" % [_total - _failures, _total])
	print("═══════════════════════════════════════════")
	quit(1 if _failures > 0 else 0)


func _validate_level(id: int, path: String) -> void:
	_total += 1
	print("── Nivel %02d: %s" % [id, path])

	# 1. Cargar y validar formato
	var level: LevelData = LevelLoader.load_from_file(path)
	if not level.is_valid():
		print("   ✗ JSON inválido: %s" % [level.errors])
		_failures += 1
		return
	print("   • Tablero %d×%d  bloques: %d  receptores: %d" % [
		level.width, level.height, level.blocks.size(), level.receptors.size()
	])

	# 2. Resolver con BFS
	var result: Dictionary = LevelSolver.solve(level)
	print("   • Estados explorados: %d" % result.get("states_explored", 0))

	if not result["solved"]:
		print("   ✗ SIN SOLUCIÓN — el nivel puede ser irresoluble o muy profundo")
		_failures += 1
		return

	# 3. Mostrar secuencia de solución
	var moves: Array = result["moves"]
	print("   ✓ Resoluble en %d movimiento(s):" % moves.size())
	for i: int in moves.size():
		var m: Dictionary = moves[i]
		print("     %d. %s → %s" % [i + 1, m["block"], m["dir"]])

	# 4. Verificar que la solución realmente resuelve el nivel (replay)
	var verify_ok: bool = _replay_solution(level, moves)
	if verify_ok:
		print("   ✓ Solución verificada por replay")
	else:
		print("   ✗ La solución NO reproduce victoria — bug en solver o BoardState")
		_failures += 1
		return

	# 5. Guardar solución en JSON
	LevelSolver.save_solution(result, id)
	print("   ✓ Guardada en data/solutions/level_%02d_solution.json" % id)
	print("")


## Ejecuta la secuencia de movimientos sobre un BoardState fresco y comprueba VICTORY.
func _replay_solution(level: LevelData, moves: Array) -> bool:
	var state := BoardState.new()
	state.init_from_level(level)

	for i: int in moves.size():
		var m: Dictionary = moves[i]
		var dir: Vector2i = LevelSolver.dir_from_name(m["dir"])
		var result: BoardState.MoveResult = state.apply_move(m["block"], dir)

		# El último movimiento debe ser VICTORY; los anteriores OK/SNAPPED.
		var is_last: bool = (i == moves.size() - 1)
		if is_last:
			if result != BoardState.MoveResult.VICTORY:
				return false
		else:
			if result == BoardState.MoveResult.BLOCKED or result == BoardState.MoveResult.NOT_FOUND:
				return false

	return true
