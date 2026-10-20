class_name BoardState
extends RefCounted
## Estado lógico puro del tablero de Kroma.
##
## Responsabilidades:
##   - Mantener la rejilla grid[x][y] con el tipo de celda de cada posición.
##   - Registrar la posición y color de cada bloque activo.
##   - Exponer snapshot() / restore(snapshot) para Undo ilimitado y reinicio.
##   - Aplicar un movimiento (apply_move) con inercia discreta: el bloque se
##     desplaza celda a celda hasta chocar con un muro, borde u otro bloque.
##
## NO conoce Godot nodes, señales de escena ni lógica visual.
## La misma secuencia de apply_move siempre produce el mismo estado (determinismo).
##
## Uso típico:
##   var state := BoardState.new()
##   state.init_from_level(level_data)
##   var snap := state.snapshot()         # guardar antes de mover
##   state.apply_move("b1", Vector2i.RIGHT)
##   state.restore(snap)                  # undo

## Tipos de celda almacenados en _grid[x][y].
enum Cell {
	EMPTY    = 0,  ## Celda vacía transitables
	WALL     = 1,  ## Muro rígido (borde de nivel o muro de datos)
	VOID     = 2,  ## Abismo (celda nula: bloque que cae → derrota)
	BLOCK    = 3,  ## Celda ocupada por un bloque activo
	RECEPTOR = 4,  ## Receptor vacío (objetivo)
	LOCKED   = 5,  ## Bloque encajado en receptor (se vuelve muro rígido)
}

## Resultado devuelto por apply_move().
enum MoveResult {
	OK        = 0,  ## El bloque se movió al menos una celda.
	BLOCKED   = 1,  ## El bloque ya estaba pegado a un obstáculo; no se movió.
	FELL      = 2,  ## El bloque cayó en un abismo → derrota.
	SNAPPED   = 3,  ## El bloque encajó en un receptor → comprobar victoria.
	VICTORY   = 4,  ## Todos los receptores están cubiertos.
	NOT_FOUND = 5,  ## El id de bloque no existe en el estado actual.
}

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


## Restaura el estado a partir de un snapshot previo (para Undo / reinicio).
func restore(snap: Dictionary) -> void:
	width = snap["width"]
	height = snap["height"]
	_grid = snap["grid"].duplicate(true)
	# duplicate profundo de la rejilla
	for x in width:
		_grid[x] = snap["grid"][x].duplicate(true)
	_blocks.clear()
	for id: String in snap["blocks"]:
		_blocks[id] = snap["blocks"][id].duplicate(true)
	_receptors.clear()
	for r: Dictionary in snap["receptors"]:
		_receptors.append(r.duplicate(true))


# ──────────────────────────────────────────────────────────── movimiento ──────

## Aplica inercia discreta al bloque [block_id] en dirección [dir].
## [dir] debe ser uno de: Vector2i.UP, DOWN, LEFT, RIGHT.
## Devuelve un MoveResult y, si el resultado es OK/SNAPPED/VICTORY,
## rellena [out_path] con la lista ordenada de Vector2i que recorrió el bloque
## (sin incluir la posición inicial).
func apply_move(block_id: String, dir: Vector2i, out_path: Array = []) -> MoveResult:
	if not _blocks.has(block_id):
		return MoveResult.NOT_FOUND

	var info: Dictionary = _blocks[block_id]
	if info["locked"]:
		return MoveResult.BLOCKED

	var pos: Vector2i = info["pos"]
	var next: Vector2i = pos + dir

	# ¿El bloque ni siquiera puede avanzar un paso?
	if not _can_enter(next):
		return MoveResult.BLOCKED

	# Inercia: avanzar celda a celda hasta que el siguiente paso no sea válido.
	var current: Vector2i = pos
	out_path.clear()

	while true:
		var candidate: Vector2i = current + dir

		# Fuera del tablero → detenerse en la celda actual.
		if not _in_bounds(candidate):
			break

		var cell_type: int = _grid[candidate.x][candidate.y]

		if cell_type == Cell.VOID:
			# El bloque cae: moverlo a la celda del abismo y terminar.
			_move_block(block_id, current, candidate, out_path)
			_grid[candidate.x][candidate.y] = Cell.WALL  # celda bloqueada tras la caída
			_blocks.erase(block_id)
			return MoveResult.FELL

		if cell_type == Cell.RECEPTOR:
			# ¿El color del bloque coincide con el del receptor?
			var receptor_color: String = _receptor_color_at(candidate)
			_move_block(block_id, current, candidate, out_path)
			if receptor_color == info["color"]:
				# Encaje: el bloque se vuelve muro rígido (LOCKED).
				_blocks[block_id]["locked"] = true
				_grid[candidate.x][candidate.y] = Cell.LOCKED
				if _all_receptors_filled():
					return MoveResult.VICTORY
				return MoveResult.SNAPPED
			else:
				# El receptor tiene otro color: el bloque se detiene encima
				# sin encajar (queda como BLOCK tapando el receptor visualmente
				# pero no lo bloquea en el estado lógico hasta que se mueva).
				# Para el prototipo greybox, simplemente se para.
				break

		if cell_type != Cell.EMPTY:
			# WALL, BLOCK o LOCKED: obstáculo, detener.
			break

		# La celda siguiente está vacía: avanzar.
		current = candidate
		out_path.append(current)

	# El bloque terminó en [current] (que puede ser la misma posición inicial).
	if current == pos:
		out_path.clear()
		return MoveResult.BLOCKED

	# Actualizar rejilla y registro del bloque.
	_grid[pos.x][pos.y] = Cell.EMPTY
	_grid[current.x][current.y] = Cell.BLOCK
	_blocks[block_id]["pos"] = current
	return MoveResult.OK


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


## Verdadero si un bloque puede entrar en [pos] (celda vacía, receptor o abismo).
func _can_enter(pos: Vector2i) -> bool:
	if not _in_bounds(pos):
		return false
	var t: int = _grid[pos.x][pos.y]
	return t == Cell.EMPTY or t == Cell.RECEPTOR or t == Cell.VOID


## Devuelve el color del receptor en [pos], o "" si no hay ninguno.
func _receptor_color_at(pos: Vector2i) -> String:
	for r: Dictionary in _receptors:
		if r["pos"] == pos:
			return r["color"]
	return ""


## Mueve el bloque de [from] a [to] y registra las celdas intermedias en [path].
func _move_block(block_id: String, from: Vector2i, to: Vector2i, path: Array) -> void:
	_grid[from.x][from.y] = Cell.EMPTY
	_grid[to.x][to.y] = Cell.BLOCK
	_blocks[block_id]["pos"] = to
	path.append(to)
