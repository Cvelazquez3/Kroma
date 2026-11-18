class_name LevelGenerator
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

# Recetas cromáticas válidas
const COMBOS := [
	{"target": "purple", "primaries": ["blue", "red"]},
	{"target": "green", "primaries": ["blue", "yellow"]},
	{"target": "orange", "primaries": ["red", "yellow"]}
]

const DIFFICULTY_PRESETS := {
	0: { # EASY
		"width": 5,
		"height": 5,
		"min_steps": 3,
		"max_steps": 5,
		"wall_density": 0.08,
		"min_voids": 0,
		"max_voids": 0,
		"extra_block_chance": 0.0,
		"multi_receptor_chance": 0.0
	},
	1: { # NORMAL
		"width": 6,
		"height": 6,
		"min_steps": 5,
		"max_steps": 9,
		"wall_density": 0.14,
		"min_voids": 1,
		"max_voids": 3,
		"extra_block_chance": 0.50,
		"multi_receptor_chance": 0.15
	},
	2: { # HARD
		"width": 7,
		"height": 7,
		"min_steps": 8,
		"max_steps": 14,
		"wall_density": 0.20,
		"min_voids": 3,
		"max_voids": 6,
		"extra_block_chance": 0.70,
		"multi_receptor_chance": 0.75
	}
}


static func generate_for_difficulty(difficulty: int, run_index: int = 1, max_attempts: int = 350) -> LevelData:
	var base: Dictionary = DIFFICULTY_PRESETS.get(difficulty, DIFFICULTY_PRESETS[1])
	var preset: Dictionary = base.duplicate()

	# Escalado progresivo sutil conforme avanza la racha (cada 3 sectores suma +1 paso mínimo)
	var step_bonus := clampi(int((max(run_index, 1) - 1) / 3), 0, 3)
	preset["min_steps"] = int(base["min_steps"]) + step_bonus
	preset["max_steps"] = int(base["max_steps"]) + step_bonus
	if difficulty >= 1:
		preset["multi_receptor_chance"] = clampf(float(base["multi_receptor_chance"]) + step_bonus * 0.08, 0.0, 0.90)

	var lvl := generate_level(
		preset["width"],
		preset["height"],
		preset["min_steps"],
		preset["max_steps"],
		max_attempts,
		preset
	)
	# Fallback seguro con los parámetros base si el escalado fue demasiado estricto
	if lvl == null and step_bonus > 0:
		lvl = generate_level(
			base["width"],
			base["height"],
			base["min_steps"],
			base["max_steps"],
			max_attempts,
			base
		)
	return lvl


static func generate_level(width: int = 6, height: int = 6, min_steps: int = 5, max_steps: int = 12, max_attempts: int = 250, preset: Dictionary = {}) -> LevelData:
	for attempt in range(max_attempts):
		var candidate: LevelData = _create_candidate_layout(width, height, preset)
		var solution: Array = solve_bfs(candidate, max_steps)
		
		if solution.size() >= min_steps and solution.size() <= max_steps:
			print("Nivel procedural generado con éxito en intento %d. Pasos requeridos: %d" % [attempt + 1, solution.size()])
			return candidate
			
	push_warning("No se halló un nivel con esos parámetros tras %d intentos." % max_attempts)
	return null

static func _create_candidate_layout(width: int, height: int, preset: Dictionary = {}) -> LevelData:
	var lvl := LevelData.new()
	lvl.id = 99
	lvl.sector = 99
	lvl.level_name = "PROCEDURAL MATRIX"
	lvl.width = width
	lvl.height = height
	lvl.walls = []
	lvl.voids = []
	lvl.receptors = []
	lvl.blocks = []

	var wall_density: float = float(preset.get("wall_density", 0.12))
	var min_voids: int = int(preset.get("min_voids", 1))
	var max_voids: int = int(preset.get("max_voids", 3))
	var extra_block_chance: float = float(preset.get("extra_block_chance", 0.35))
	var multi_receptor_chance: float = float(preset.get("multi_receptor_chance", 0.0))

	var occupied: Dictionary = {}

	# 1. Muros base según densidad configurada
	var wall_count := int((width * height) * wall_density)
	while lvl.walls.size() < wall_count:
		var pos := Vector2i(randi_range(1, width - 2), randi_range(1, height - 2))
		if not occupied.has(pos):
			occupied[pos] = true
			lvl.walls.append(pos)

	# 2. Elegir receta cromática al azar
	var recipe: Dictionary = COMBOS.pick_random()
	var target_color: String = recipe["target"]
	var primaries: Array = recipe["primaries"]

	# 3. Receptor principal con freno garantizado (Backstop)
	var receptor_pos := _get_random_free_edge_pos(width, height, occupied)
	occupied[receptor_pos] = true
	lvl.receptors.append({
		"pos": receptor_pos,
		"color": target_color
	})
	_ensure_receptor_backstop(receptor_pos, width, height, occupied, lvl.walls)

	# 4. Abismos (Voids) que no toquen directamente al receptor
	var void_count := randi_range(min_voids, max_voids)
	var voids_placed := 0
	var void_attempts := 0
	while voids_placed < void_count and void_attempts < 40:
		void_attempts += 1
		var v_pos := Vector2i(randi_range(1, width - 2), randi_range(1, height - 2))
		if not occupied.has(v_pos) and v_pos.distance_to(Vector2(receptor_pos)) > 1.5:
			occupied[v_pos] = true
			lvl.voids.append(v_pos)
			voids_placed += 1

	# 5. Bloques primarios de la receta
	var next_block_idx := 1
	for i in range(primaries.size()):
		var p_pos := _get_random_free_pos(width, height, occupied)
		occupied[p_pos] = true
		lvl.blocks.append({
			"id": "b%d" % next_block_idx,
			"color": primaries[i],
			"pos": p_pos
		})
		next_block_idx += 1

	# 6. Segundo acople opcional en dificultad alta (receptor + bloque primario extra)
	if randf() < multi_receptor_chance:
		var second_color: String = "yellow" if not primaries.has("yellow") else "blue"
		var rec2_pos := _get_random_free_edge_pos(width, height, occupied)
		occupied[rec2_pos] = true
		lvl.receptors.append({
			"pos": rec2_pos,
			"color": second_color
		})
		_ensure_receptor_backstop(rec2_pos, width, height, occupied, lvl.walls)

		var blk2_pos := _get_random_free_pos(width, height, occupied)
		occupied[blk2_pos] = true
		lvl.blocks.append({
			"id": "b%d" % next_block_idx,
			"color": second_color,
			"pos": blk2_pos
		})
		next_block_idx += 1
	elif randf() < extra_block_chance:
		# Bloque neutro / obstáculo móvil opcional
		var extra_color: String = "yellow" if not primaries.has("yellow") else "blue"
		var extra_pos := _get_random_free_pos(width, height, occupied)
		occupied[extra_pos] = true
		lvl.blocks.append({
			"id": "b%d" % next_block_idx,
			"color": extra_color,
			"pos": extra_pos
		})

	return lvl


static func _ensure_receptor_backstop(receptor_pos: Vector2i, width: int, height: int, occupied: Dictionary, walls: Array) -> void:
	var is_on_edge := (receptor_pos.x == 0 or receptor_pos.x == width - 1 or receptor_pos.y == 0 or receptor_pos.y == height - 1)
	if is_on_edge:
		return
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var wall_back: Vector2i = receptor_pos + offset
		if wall_back.x >= 0 and wall_back.x < width and wall_back.y >= 0 and wall_back.y < height:
			if not occupied.has(wall_back):
				occupied[wall_back] = true
				walls.append(wall_back)
				return

static func _get_random_free_edge_pos(w: int, h: int, occupied: Dictionary) -> Vector2i:
	for _i in range(100):
		var x := randi_range(0, w - 1)
		var y := randi_range(0, h - 1)
		if x == 0 or x == w - 1 or y == 0 or y == h - 1:
			var pos := Vector2i(x, y)
			if not occupied.has(pos):
				return pos
	return _get_random_free_pos(w, h, occupied)

static func _get_random_free_pos(w: int, h: int, occupied: Dictionary) -> Vector2i:
	for _i in range(200):
		var pos := Vector2i(randi_range(0, w - 1), randi_range(0, h - 1))
		if not occupied.has(pos):
			return pos
	return Vector2i.ZERO

# --- SOLVER BFS CON CAÍDA A ABISMOS Y FUSIONES ---

static func solve_bfs(lvl: LevelData, max_depth: int, max_states: int = 4000) -> Array:
	var initial_board := BoardState.new()
	initial_board.init_from_level(lvl)

	var queue: Array = []
	var visited: Dictionary = {}

	var root_snap := initial_board.snapshot()
	var root_key := _hash_state(root_snap)
	
	queue.push_back({
		"snapshot": root_snap,
		"path": [],
		"depth": 0
	})
	visited[root_key] = true

	while not queue.is_empty():
		if visited.size() >= max_states:
			return []
		var current: Dictionary = queue.pop_front()
		
		if current["depth"] >= max_depth:
			continue

		var current_snap: Dictionary = current["snapshot"]
		
		for b_id in current_snap["blocks"].keys():
			for dir in DIRECTIONS:
				var sim_board := BoardState.new()
				sim_board.restore(current_snap)
				
				var move_path: Array = []
				var result = sim_board.apply_move(b_id, dir, move_path)
				
				if move_path.is_empty():
					continue
				
				# Si el movimiento completó todas las metas requeridas
				if result == BoardState.MoveResult.VICTORY:
					var final_path: Array = current["path"].duplicate()
					final_path.append({"block": b_id, "dir": dir})
					return final_path

				# Poda temprana: si cayó en un abismo y el tablero ya es irresoluble, no expandir esta rama
				if result == BoardState.MoveResult.FELL and sim_board.is_defeated():
					continue
				
				# Si el bloque cayó a un vacío y dejó el nivel sin solución inmediata, el estado no aporta
				var next_snap := sim_board.snapshot()
				var next_key := _hash_state(next_snap)
				
				if not visited.has(next_key):
					visited[next_key] = true
					var next_path: Array = current["path"].duplicate()
					next_path.append({"block": b_id, "dir": dir})
					
					queue.push_back({
						"snapshot": next_snap,
						"path": next_path,
						"depth": current["depth"] + 1
					})
					
	return []

static func _hash_state(snap: Dictionary) -> String:
	var blocks: Dictionary = snap["blocks"]
	var keys: Array = blocks.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		var b: Dictionary = blocks[k]
		parts.append("%s:%s:%d,%d" % [k, b["color"], b["pos"].x, b["pos"].y])
	return "|".join(parts)
