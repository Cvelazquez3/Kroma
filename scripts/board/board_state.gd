class_name BoardState
extends RefCounted
## Estado lógico puro del tablero de Kroma.
##
## Responsabilidades:
##   - Mantener la rejilla grid[x][y] con el tipo de celda de cada posición.
##   - Registrar la posición y color de cada bloque activo.
##   - Exponer snapshot() / restore(snapshot) para Undo ilimitado y reinicio.
##   - Aplicar un movimiento (apply_move) con inercia discreta + fusión cromática:
##     el bloque avanza celda a celda; si choca con un primario compatible, ambos
##     fusionan y el resultado continúa con inercia (MERGING → SLIDING, GDD pág 4/5).
##
## NO conoce Godot nodes, señales de escena ni lógica visual.
## La misma secuencia de apply_move siempre produce el mismo estado (determinismo).
##
## Uso típico:
##   var state := BoardState.new()
##   state.init_from_level(level_data)
##   var snap := state.snapshot()              # guardar ANTES de mover (Undo)
##   state.apply_move("b1", Vector2i.RIGHT)
##   state.restore(snap)                       # Undo

## Tipos de celda almacenados en _grid[x][y].
enum Cell {
	EMPTY    = 0,  ## Celda vacía transitable
	WALL     = 1,  ## Muro rígido (nivel o bloque LOCKED)
	VOID     = 2,  ## Abismo: bloque que cae → FELL
	BLOCK    = 3,  ## Celda ocupada por un bloque activo
	RECEPTOR = 4,  ## Receptor vacío (objetivo)
	LOCKED   = 5,  ## Bloque encajado → muro rígido permanente
}

## Resultado devuelto por apply_move().
enum MoveResult {
	OK        = 0,  ## El bloque se movió al menos una celda.
	BLOCKED   = 1,  ## No había espacio para avanzar.
	FELL      = 2,  ## El bloque cayó en un abismo.
	SNAPPED   = 3,  ## El bloque encajó en un receptor (quedan más por llenar).
	VICTORY   = 4,  ## Todos los receptores cubiertos.
	NOT_FOUND = 5,  ## El id de bloque no existe en el estado actual.
}

## Tabla de fusión cromática (GDD Página 5, Reglas Atómicas).
## Solo colores primarios → secundario. Un secundario NO puede re-fusionarse.
const MERGE_TABLE: Dictionary = {
	"red+blue":    "purple",
	"blue+red":    "purple",
	"blue+yellow": "green",
	"yellow+blue": "green",
	"yellow+red":  "orange",
	"red+yellow":  "orange",
}

## Colores primarios que pueden participar en una fusión.
const PRIMARY_COLORS: Array[String] = ["red", "blue", "yellow"]

## Ancho y alto del tablero en celdas.
var width: int = 0
var height: int = 0

## _grid[x][y] → Cell.*
var _grid: Array = []  # Array[Array[int]]

## Diccionario id_bloque → { "pos": Vector2i, "color": String, "locked": bool }
var _blocks: Dictionary = {}

## Lista de receptores: Array[{ "pos": Vector2i, "color": String }]
var _receptors: Array = []


# ──────────────────────────────────────────────────────────── inicialización ──

## Inicializa el tablero a partir de un LevelData ya validado.
func init_from_level(level: LevelData) -> void:
	width = level.width
	height = level.height
	_blocks.clear()
	_receptors.clear()
	_grid = _empty_grid(width, height)

	for cell: Vector2i in level.walls:
		_grid[cell.x][cell.y] = Cell.WALL

	for cell: Vector2i in level.voids:
		_grid[cell.x][cell.y] = Cell.VOID

	for r: Dictionary in level.receptors:
		var pos: Vector2i = r["pos"]
		_grid[pos.x][pos.y] = Cell.RECEPTOR
		_receptors.append({ "pos": pos, "color": r["color"] })

	for b: Dictionary in level.blocks:
		var pos: Vector2i = b["pos"]
		_grid[pos.x][pos.y] = Cell.BLOCK
		_blocks[b["id"]] = { "pos": pos, "color": b["color"], "locked": false }


# ──────────────────────────────────────────────────────────── snapshot / undo ──

## Devuelve una copia profunda del estado actual.
## Guardar ANTES de apply_move para poder hacer Undo.
func snapshot() -> Dictionary:
	var grid_copy: Array = []
	for x in width:
		var col: Array = []
		for y in height:
			col.append(_grid[x][y])
		grid_copy.append(col)

	var blocks_copy: Dictionary = {}
	for id: String in _blocks:
		blocks_copy[id] = _blocks[id].duplicate(true)

	var receptors_copy: Array = []
	for r: Dictionary in _receptors:
		receptors_copy.append(r.duplicate(true))

	return {
		"width": width,
		"height": height,
		"grid": grid_copy,
		"blocks": blocks_copy,
		"receptors": receptors_copy,
	}


## Restaura el estado a partir de un snapshot previo (para Undo / reinicio rápido).
func restore(snap: Dictionary) -> void:
	width = snap["width"]
	height = snap["height"]
	_grid = []
	for x in width:
		_grid.append(snap["grid"][x].duplicate(true))
	_blocks.clear()
	for id: String in snap["blocks"]:
		_blocks[id] = snap["blocks"][id].duplicate(true)
	_receptors.clear()
	for r: Dictionary in snap["receptors"]:
		_receptors.append(r.duplicate(true))


# ──────────────────────────────────────────────────────────── movimiento ──────

## Aplica inercia discreta al bloque [block_id] en dirección [dir].
## [dir] debe ser uno de: Vector2i.UP, DOWN, LEFT, RIGHT.
##
## FSM del GDD (Página 4-5):
##   IDLE → SLIDING → (MERGING → SLIDING) → IDLE / SLOTTED / VOIDED
##
## Devuelve un MoveResult. Si es OK/SNAPPED/VICTORY rellena [out_path]
## con las celdas recorridas (sin incluir la posición de origen).
func apply_move(block_id: String, dir: Vector2i, out_path: Array = []) -> MoveResult:
	if not _blocks.has(block_id):
		return MoveResult.NOT_FOUND

	var info: Dictionary = _blocks[block_id]
	if info["locked"]:
		return MoveResult.BLOCKED

	var origin: Vector2i = info["pos"]
	var current: Vector2i = origin
	out_path.clear()

	# ── Bucle de inercia (SLIDING) ──
	while true:
		var candidate: Vector2i = current + dir

		# Borde del tablero → freno en celda actual (GDD: "Borde perimetral → IDLE").
		if not _in_bounds(candidate):
			break

		var cell_type: int = _grid[candidate.x][candidate.y]

		# ── Abismo → VOIDED ──
		if cell_type == Cell.VOID:
			_grid[current.x][current.y] = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.WALL  # celda sellada tras caída
			out_path.append(candidate)
			_blocks.erase(block_id)
			return MoveResult.FELL

		# ── Receptor → SLOTTED o freno ──
		if cell_type == Cell.RECEPTOR:
			var receptor_color: String = _receptor_color_at(candidate)
			var block_color: String = _blocks[block_id]["color"]
			# Mover el bloque a la celda del receptor.
			_grid[current.x][current.y] = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.BLOCK
			_blocks[block_id]["pos"] = candidate
			out_path.append(candidate)
			current = candidate

			if receptor_color == block_color:
				# Encaje correcto → SLOTTED (muro rígido).
				_blocks[block_id]["locked"] = true
				_grid[candidate.x][candidate.y] = Cell.LOCKED
				if _all_receptors_filled():
					return MoveResult.VICTORY
				return MoveResult.SNAPPED
			else:
				# Color distinto → actúa como muro (GDD pág. 5: "Receptor incompatible → IDLE").
				break

		# ── Muro rígido o LOCKED → freno ──
		if cell_type == Cell.WALL or cell_type == Cell.LOCKED:
			break

		# ── Bloque activo → intentar fusión cromática (MERGING) ──
		if cell_type == Cell.BLOCK:
			var target_id: String = _block_id_at(candidate)
			if target_id.is_empty():
				break

			var moving_color: String = _blocks[block_id]["color"]
			var target_color: String = _blocks[target_id]["color"]
			var merge_key: String = moving_color + "+" + target_color

			if not MERGE_TABLE.has(merge_key):
				# Incompatibles o secundario → freno de conveniencia (GDD pág. 5).
				break

			# ── Fusión válida (MERGING) ──
			var merged_color: String = MERGE_TABLE[merge_key]
			# El bloque activo absorbe al objetivo y toma su posición.
			_grid[current.x][current.y] = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.BLOCK
			out_path.append(candidate)
			current = candidate
			_blocks.erase(target_id)
			_blocks[block_id]["pos"] = current
			_blocks[block_id]["color"] = merged_color
			# El bloque fusionado conserva inercia → continúa en SLIDING (GDD pág. 5).
			continue

		# ── Celda vacía → avanzar (SLIDING) ──
		if cell_type == Cell.EMPTY:
			_grid[current.x][current.y] = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.BLOCK
			out_path.append(candidate)
			current = candidate
			_blocks[block_id]["pos"] = current
			continue

		# Cualquier otro tipo desconocido → freno preventivo.
		break

	# Fin del bucle: el bloque quedó en [current].
	if current == origin:
		out_path.clear()
		return MoveResult.BLOCKED

	return MoveResult.OK


## Calcula el destino de [block_id] en [dir] SIN modificar el estado real.
## Rellena [out_path] con las celdas que recorrería.
## Uso: feedforward visual (línea punteada, GDD Página 9).
func preview_move(block_id: String, dir: Vector2i, out_path: Array = []) -> Vector2i:
	if not _blocks.has(block_id):
		return Vector2i(-1, -1)
	var info: Dictionary = _blocks[block_id]
	if info["locked"]:
		return info["pos"]

	var current: Vector2i = info["pos"]
	var sim_color: String = info["color"]
	out_path.clear()

	while true:
		var candidate: Vector2i = current + dir
		if not _in_bounds(candidate):
			break

		var cell_type: int = _grid[candidate.x][candidate.y]

		if cell_type == Cell.VOID or cell_type == Cell.RECEPTOR:
			out_path.append(candidate)
			current = candidate
			break

		if cell_type == Cell.WALL or cell_type == Cell.LOCKED:
			break

		if cell_type == Cell.BLOCK:
			var target_id: String = _block_id_at(candidate)
			if not target_id.is_empty():
				var merge_key: String = sim_color + "+" + _blocks[target_id]["color"]
				if MERGE_TABLE.has(merge_key):
					sim_color = MERGE_TABLE[merge_key]
					out_path.append(candidate)
					current = candidate
					continue  # fusión simulada → continuar
			break

		# EMPTY
		current = candidate
		out_path.append(current)

	return current


# ──────────────────────────────────────────────────────────── consultas ───────

## Devuelve verdadero si todas las celdas RECEPTOR tienen un bloque encajado.
func _all_receptors_filled() -> bool:
	for r: Dictionary in _receptors:
		var pos: Vector2i = r["pos"]
		if _grid[pos.x][pos.y] != Cell.LOCKED:
			return false
	return true


## Devuelve el tipo de celda en (x, y). Retorna WALL si está fuera del tablero.
func cell_at(pos: Vector2i) -> int:
	if not _in_bounds(pos):
		return Cell.WALL
	return _grid[pos.x][pos.y]


## Devuelve la información del bloque con el id dado, o un diccionario vacío.
func block_info(id: String) -> Dictionary:
	return _blocks.get(id, {})


## Devuelve todos los ids de bloques activos (no encajados).
func active_block_ids() -> Array:
	var result: Array = []
	for id: String in _blocks:
		if not _blocks[id]["locked"]:
			result.append(id)
	return result


## Devuelve una copia de la lista de receptores.
func get_receptors() -> Array:
	return _receptors.duplicate(true)


# ──────────────────────────────────────────────────────────── helpers privados ─

func _empty_grid(w: int, h: int) -> Array:
	var g: Array = []
	for x in w:
		var col: Array = []
		for y in h:
			col.append(Cell.EMPTY)
		g.append(col)
	return g


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


## Devuelve el color del receptor en [pos], o "" si no hay ninguno.
func _receptor_color_at(pos: Vector2i) -> String:
	for r: Dictionary in _receptors:
		if r["pos"] == pos:
			return r["color"]
	return ""


## Devuelve el id del bloque en [pos], o "" si no hay ninguno.
func _block_id_at(pos: Vector2i) -> String:
	for id: String in _blocks:
		if _blocks[id]["pos"] == pos:
			return id
	return ""
