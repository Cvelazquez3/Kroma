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

static func generate_level(width: int = 6, height: int = 6, min_steps: int = 5, max_steps: int = 12, max_attempts: int = 250) -> LevelData:
	for attempt in range(max_attempts):
		var candidate: LevelData = _create_candidate_layout(width, height)
		var solution: Array = solve_bfs(candidate, max_steps)
		
		if solution.size() >= min_steps and solution.size() <= max_steps:
			print("Nivel procedural generado con éxito en intento %d. Pasos requeridos: %d" % [attempt + 1, solution.size()])
			return candidate
			
	push_warning("No se halló un nivel con esos parámetros tras %d intentos." % max_attempts)
	return null

static func _create_candidate_layout(width: int, height: int) -> LevelData:
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

	var occupied: Dictionary = {}

	# 1. Muros base (12% del tablero)
	var wall_count := int((width * height) * 0.12)
	while lvl.walls.size() < wall_count:
		var pos := Vector2i(randi_range(1, width - 2), randi_range(1, height - 2))
		if not occupied.has(pos):
			occupied[pos] = true
			lvl.walls.append(pos)

	# 2. Elegir receta cromática al azar
	var recipe: Dictionary = COMBOS.pick_random()
	var target_color: String = recipe["target"]
	var primaries: Array = recipe["primaries"]

	# 3. Receptor con freno garantizado (Backstop)
	var receptor_pos := _get_random_free_edge_pos(width, height, occupied)
	occupied[receptor_pos] = true
	lvl.receptors.append({
		"pos": receptor_pos,
		"color": target_color
	})

	# Si el receptor no está en un borde exterior, colocarle un muro adyacente para frenar la inercia
	var is_on_edge := (receptor_pos.x == 0 or receptor_pos.x == width - 1 or receptor_pos.y == 0 or receptor_pos.y == height - 1)
	if not is_on_edge:
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var wall_back: Vector2i = receptor_pos + offset
			if wall_back.x >= 0 and wall_back.x < width and wall_back.y >= 0 and wall_back.y < height:
				if not occupied.has(wall_back):
					occupied[wall_back] = true
					lvl.walls.append(wall_back)
					break
			if wall_back.x >= 0 and wall_back.x < width and wall_back.y >= 0 and wall_back.y < height:
				if not occupied.has(wall_back):
					occupied[wall_back] = true
					lvl.walls.append(wall_back)
					break

	# 4. Abismos (Voids): 1 a 3 abismos que no toquen directamente al receptor
	var void_count := randi_range(1, 3)
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
	for i in range(primaries.size()):
		var p_pos := _get_random_free_pos(width, height, occupied)
		occupied[p_pos] = true
		lvl.blocks.append({
			"id": "b%d" % (i + 1),
			"color": primaries[i],
			"pos": p_pos
		})

	# 6. Bloque neutro / obstáculo móvil opcional (35% de probabilidad)
	if randf() < 0.35:
		var extra_color: String = "yellow" if not primaries.has("yellow") else "blue"
		var extra_pos := _get_random_free_pos(width, height, occupied)
		occupied[extra_pos] = true
		lvl.blocks.append({
			"id": "b3",
			"color": extra_color,
			"pos": extra_pos
		})

	return lvl

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

static func solve_bfs(lvl: LevelData, max_depth: int) -> Array:
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
