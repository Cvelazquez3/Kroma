class_name LevelSolver
extends RefCounted
## Solver BFS determinista para niveles de Kroma.
##
## Responsabilidades (Sprint 2, Christian — GDD Página 7):
##   • Verificar algorítmicamente que un nivel es resoluble.
##   • Devolver la secuencia de solución óptima (mínimo de movimientos).
##   • Guardar el resultado en data/solutions/level_XX_solution.json.
##
## Algoritmo: Breadth-First Search (BFS) sobre el espacio de estados del tablero.
##   Estado: posiciones + colores de todos los bloques activos
##            + qué receptores están llenos (LOCKED).
##   Acciones: para cada bloque activo × 4 direcciones cardinales.
##   Complejidad: O(S) donde S = número de estados únicos alcanzables.
##   Para tableros de 5×5 a 8×8 con ≤ 5 bloques, S ≈ decenas de miles.
##
## Uso:
##   var result := LevelSolver.solve(level_data)
##   if result["solved"]:
##       print(result["moves"])   # Array[{block, dir}]
##   LevelSolver.save_solution(result, level_data.id)

## Resuelve [level] con BFS. Devuelve un Dictionary con:
##   "solved":          bool
##   "moves":           Array[Dictionary]  — cada uno: {block: String, dir: String}
##   "states_explored": int
## [max_states] es el límite de estados explorados antes de declararlo irresoluble.
static func solve(level: LevelData, max_states: int = 200_000) -> Dictionary:
	var state := BoardState.new()
	state.init_from_level(level)

	var initial_snap: Dictionary = state.snapshot()
	var initial_key: String = _state_key(initial_snap)

	# ── Cola BFS ────────────────────────────────────────────────────────────
	# Cada entrada: { snap, parent_idx, move }
	# • snap:       snapshot del estado al llegar aquí
	# • parent_idx: índice del estado predecesor (-1 para el inicial)
	# • move:       { block, dir } que produjo esta entrada (vacío para inicial)
	var queue: Array = [{
		"snap":       initial_snap,
		"parent_idx": -1,
		"move":       {}
	}]
	var visited: Dictionary = { initial_key: 0 }  # key → índice en queue
	var front: int = 0

	var working := BoardState.new()

	while front < queue.size():
		if front >= max_states:
			return { "solved": false, "moves": [], "states_explored": front }

		var entry: Dictionary = queue[front]
		front += 1

		working.restore(entry["snap"])
		var block_ids: Array = working.active_block_ids()

		for block_id: String in block_ids:
			for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				# Restaurar desde el snap del estado actual antes de cada prueba.
				working.restore(entry["snap"])
				var result: BoardState.MoveResult = working.apply_move(block_id, dir)

				if result == BoardState.MoveResult.BLOCKED or result == BoardState.MoveResult.NOT_FOUND:
					continue  # movimiento nulo, no genera nuevo estado

				var dir_str: String = _dir_name(dir)

				if result == BoardState.MoveResult.VICTORY:
					# ── Reconstruir el camino de solución ──────────────────
					var moves: Array = [{ "block": block_id, "dir": dir_str }]
					var idx: int = front - 1
					while queue[idx]["parent_idx"] >= 0:
						moves.push_front(queue[idx]["move"])
						idx = queue[idx]["parent_idx"]
					return {
						"solved": true,
						"moves": moves,
						"states_explored": front,
					}

				# Estado nuevo (no victoria): añadir a la cola si no visitado.
				var new_snap: Dictionary = working.snapshot()
				var new_key: String = _state_key(new_snap)
				if not visited.has(new_key):
					visited[new_key] = queue.size()
					queue.append({
						"snap":       new_snap,
						"parent_idx": front - 1,
						"move":       { "block": block_id, "dir": dir_str },
					})

	return { "solved": false, "moves": [], "states_explored": front }


## Guarda el resultado del solver en res://data/solutions/level_XX_solution.json.
## Crea el directorio si no existe.
static func save_solution(result: Dictionary, level_id: int) -> void:
	var dir_path: String = "res://data/solutions"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var path: String = "%s/level_%02d_solution.json" % [dir_path, level_id]
	var data: Dictionary = {
		"level_id":       level_id,
		"solved":         result["solved"],
		"moves_count":    result["moves"].size(),
		"states_explored": result.get("states_explored", 0),
		"solution":       result["moves"],
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_error("LevelSolver: no se pudo escribir %s" % path)


# ──────────────────────────────────────────────────────────── helpers privados ─

## Genera una clave de cadena única para un snapshot de BoardState.
## Representa la posición+color de cada bloque activo y el estado de cada receptor.
## Los bloques se ordenan por id para que el mismo estado siempre produzca la misma clave.
static func _state_key(snap: Dictionary) -> String:
	var parts: Array[String] = []

	var ids: Array = snap["blocks"].keys()
	ids.sort()
	for id: String in ids:
		var b: Dictionary = snap["blocks"][id]
		parts.append("%s:%d,%d:%s:%s" % [
			id,
			b["pos"].x, b["pos"].y,
			b["color"],
			"L" if b["locked"] else "A"
		])

	# El estado de cada receptor es parte de la clave (topología mutable, GDD pág. 4)
	for r: Dictionary in snap["receptors"]:
		var pos: Vector2i = r["pos"]
		var filled: bool = snap["grid"][pos.x][pos.y] == BoardState.Cell.LOCKED
		parts.append("R:%d,%d:%s" % [pos.x, pos.y, "1" if filled else "0"])

	return "|".join(parts)


static func _dir_name(dir: Vector2i) -> String:
	match dir:
		Vector2i.UP:    return "up"
		Vector2i.DOWN:  return "down"
		Vector2i.LEFT:  return "left"
		Vector2i.RIGHT: return "right"
	return "unknown"


## Convierte un nombre de dirección a Vector2i (para cargar soluciones desde JSON).
static func dir_from_name(name: String) -> Vector2i:
	match name:
		"up":    return Vector2i.UP
		"down":  return Vector2i.DOWN
		"left":  return Vector2i.LEFT
		"right": return Vector2i.RIGHT
	push_error("LevelSolver: dirección desconocida '%s'" % name)
	return Vector2i.ZERO
