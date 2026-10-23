class_name BoardState
extends RefCounted
## Estado lógico puro del tablero de Kroma.
##
## Implementa la FSM completa del GDD (Páginas 4-5):
##   IDLE → SLIDING → (MERGING → SLIDING) → IDLE / SLOTTED / VOIDED
##
## Reglas atómicas (GDD Página 5 - Matriz de Colisión):
##   • Celda vacía      → avanzar (SLIDING continúa)
##   • Primario compat. → fusión + inercia (MERGING → SLIDING)
##   • Bloque incompat. → frenado en celda previa (IDLE)
##   • Muro / LOCKED    → frenado en celda previa (IDLE)
##   • Borde            → frenado en celda previa (IDLE)
##   • Abismo           → bloque eliminado (VOIDED)
##   • Receptor correc. → encaje + muro rígido (SLOTTED)
##   • Receptor incorr. → frenado en celda previa como muro (IDLE)
##
## NO conoce nodos de Godot, señales ni lógica visual.
## Determinismo absoluto: misma secuencia → mismo estado (GDD: Cero Azar).

## Tipos de celda almacenados en _grid[x][y].
enum Cell {
	EMPTY    = 0,  ## Celda libre transitable
	WALL     = 1,  ## Muro rígido estático
	VOID     = 2,  ## Abismo: bloque que entra → FELL
	BLOCK    = 3,  ## Celda ocupada por bloque activo
	RECEPTOR = 4,  ## Receptor vacío (objetivo)
	LOCKED   = 5,  ## Bloque encajado → muro rígido permanente
}

## Resultado devuelto por apply_move().
enum MoveResult {
	OK        = 0,  ## El bloque se movió al menos una celda.
	BLOCKED   = 1,  ## No había espacio para avanzar; sin cambio de estado.
	FELL      = 2,  ## El bloque cayó en un abismo (VOIDED).
	SNAPPED   = 3,  ## El bloque encajó en su receptor (quedan más por llenar).
	VICTORY   = 4,  ## Todos los receptores cubiertos → nivel resuelto.
	NOT_FOUND = 5,  ## El id de bloque no existe.
}

## Tabla de fusión cromática (GDD Pág. 5 — solo primarios → secundario).
## Un bloque secundario NO puede volver a fusionarse (frenado de conveniencia).
const MERGE_TABLE: Dictionary = {
	"red+blue":    "purple",
	"blue+red":    "purple",
	"blue+yellow": "green",
	"yellow+blue": "green",
	"yellow+red":  "orange",
	"red+yellow":  "orange",
}

## Colores primarios válidos para iniciar una fusión.
const PRIMARY_COLORS: Array[String] = ["red", "blue", "yellow"]

var width: int  = 0
var height: int = 0

## _grid[x][y] → Cell.*
var _grid: Array = []  # Array[Array[int]]

## id → { "pos": Vector2i, "color": String, "locked": bool }
var _blocks: Dictionary = {}

## Array[{ "pos": Vector2i, "color": String }]
var _receptors: Array = []


# ──────────────────────────────────────────────────────────── inicialización ──

## Inicializa el tablero a partir de un LevelData ya validado.
func init_from_level(level: LevelData) -> void:
	width  = level.width
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
## Guardar ANTES de apply_move para Undo ilimitado (GDD Pág. 6).
func snapshot() -> Dictionary:
	var grid_copy: Array = []
	for x in width:
		grid_copy.append(_grid[x].duplicate())

	var blocks_copy: Dictionary = {}
	for id: String in _blocks:
		blocks_copy[id] = _blocks[id].duplicate(true)

	var receptors_copy: Array = []
	for r: Dictionary in _receptors:
		receptors_copy.append(r.duplicate(true))

	return {
		"width": width, "height": height,
		"grid": grid_copy,
		"blocks": blocks_copy,
		"receptors": receptors_copy,
	}


## Restaura el estado a partir de un snapshot previo.
## Uso: Undo (desapilar 1) o Reinicio rápido (restaurar snapshot inicial).
func restore(snap: Dictionary) -> void:
	width  = snap["width"]
	height = snap["height"]
	_grid  = []
	for x in width:
		_grid.append(snap["grid"][x].duplicate())
	_blocks.clear()
	for id: String in snap["blocks"]:
		_blocks[id] = snap["blocks"][id].duplicate(true)
	_receptors.clear()
	for r: Dictionary in snap["receptors"]:
		_receptors.append(r.duplicate(true))


# ──────────────────────────────────────────────────────────── movimiento ──────

## Aplica inercia discreta al bloque [block_id] en dirección [dir].
## [dir]: Vector2i.UP / DOWN / LEFT / RIGHT.
##
## Rellena [out_path] con las celdas recorridas (sin incluir el origen).
## Para Undo: guardar snapshot() ANTES de llamar a apply_move.
func apply_move(block_id: String, dir: Vector2i, out_path: Array = []) -> MoveResult:
	if not _blocks.has(block_id):
		return MoveResult.NOT_FOUND
	if _blocks[block_id]["locked"]:
		return MoveResult.BLOCKED

	var origin: Vector2i = _blocks[block_id]["pos"]
	var current: Vector2i = origin
	out_path.clear()

	# ── Bucle de inercia (FSM SLIDING) ──────────────────────────────────────
	while true:
		var candidate: Vector2i = current + dir

		# Borde del tablero → frenado en celda actual (GDD: "Borde perimetral → IDLE")
		if not _in_bounds(candidate):
			break

		var ct: int = _grid[candidate.x][candidate.y]

		# ── Abismo → VOIDED (GDD pág. 5) ──────────────────────────────────
		if ct == Cell.VOID:
			_grid[current.x][current.y] = Cell.EMPTY
			# La celda de abismo permanece VOID (otros bloques también pueden caer)
			out_path.append(candidate)
			_blocks.erase(block_id)
			return MoveResult.FELL

		# ── Receptor (GDD pág. 5) ──────────────────────────────────────────
		if ct == Cell.RECEPTOR:
			var rc: String = _receptor_color_at(candidate)
			var bc: String = _blocks[block_id]["color"]
			if rc != bc:
				# Color distinto → actúa EXACTAMENTE como muro (GDD: "frenado en celda previa")
				break
			# Color correcto → SLOTTED
			_grid[current.x][current.y] = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.LOCKED
			_blocks[block_id]["pos"]    = candidate
			_blocks[block_id]["locked"] = true
			out_path.append(candidate)
			if _all_receptors_filled():
				return MoveResult.VICTORY
			return MoveResult.SNAPPED

		# ── Muro rígido o bloque encajado → freno ─────────────────────────
		if ct == Cell.WALL or ct == Cell.LOCKED:
			break

		# ── Bloque activo → intentar fusión cromática (GDD pág. 5 MERGING) ─
		if ct == Cell.BLOCK:
			var target_id: String = _block_id_at(candidate)
			if target_id.is_empty():
				break
			var moving_color: String = _blocks[block_id]["color"]
			var target_color: String = _blocks[target_id]["color"]
			var key: String = moving_color + "+" + target_color
			if not MERGE_TABLE.has(key):
				# Incompatibles o secundario → freno de conveniencia (GDD pág. 5)
				break
			# Fusión válida: absorber bloque objetivo, continuar con inercia (MERGING → SLIDING)
			var merged: String = MERGE_TABLE[key]
			_grid[current.x][current.y]    = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.BLOCK
			out_path.append(candidate)
			current = candidate
			_blocks.erase(target_id)
			_blocks[block_id]["pos"]   = current
			_blocks[block_id]["color"] = merged
			continue

		# ── Celda vacía → avanzar (SLIDING continúa) ──────────────────────
		if ct == Cell.EMPTY:
			_grid[current.x][current.y]    = Cell.EMPTY
			_grid[candidate.x][candidate.y] = Cell.BLOCK
			out_path.append(candidate)
			current = candidate
			_blocks[block_id]["pos"] = current
			continue

		# Tipo desconocido → freno preventivo
		break

	# Fin del bucle
	if current == origin:
		out_path.clear()
		return MoveResult.BLOCKED
	return MoveResult.OK


## Calcula el destino de [block_id] en [dir] SIN modificar el estado real.
## Rellena [out_path] con las celdas que recorrería (incluye la de destino).
## Uso: feedforward visual — línea punteada del HUD (GDD Página 9).
func preview_move(block_id: String, dir: Vector2i, out_path: Array = []) -> Vector2i:
	if not _blocks.has(block_id):
		return Vector2i(-1, -1)
	var info: Dictionary = _blocks[block_id]
	if info["locked"]:
		return info["pos"]

	var current: Vector2i = info["pos"]
	var sim_color: String  = info["color"]
	out_path.clear()

	while true:
		var candidate: Vector2i = current + dir
		if not _in_bounds(candidate):
			break

		var ct: int = _grid[candidate.x][candidate.y]

		if ct == Cell.VOID:
			out_path.append(candidate)
			current = candidate
			break

		if ct == Cell.RECEPTOR:
			var rc: String = _receptor_color_at(candidate)
			if rc == sim_color:
				out_path.append(candidate)
				current = candidate
			# Stop in either case (snap or wall behavior)
			break

		if ct == Cell.WALL or ct == Cell.LOCKED:
			break

		if ct == Cell.BLOCK:
			var target_id: String = _block_id_at(candidate)
			if not target_id.is_empty():
				var merge_key: String = sim_color + "+" + _blocks[target_id]["color"]
				if MERGE_TABLE.has(merge_key):
					sim_color = MERGE_TABLE[merge_key]
					out_path.append(candidate)
					current = candidate
					continue  # fusión simulada → seguir avanzando
			break

		if ct == Cell.EMPTY:
			current = candidate
			out_path.append(current)
			continue

		break

	return current


# ──────────────────────────────────────────────────────────── consultas ───────

## Devuelve el tipo de celda. Retorna Cell.WALL si está fuera del tablero.
func cell_at(pos: Vector2i) -> int:
	if not _in_bounds(pos):
		return Cell.WALL
	return _grid[pos.x][pos.y]


## Devuelve la información del bloque con [id], o {} si no existe.
func block_info(id: String) -> Dictionary:
	return _blocks.get(id, {})


## Devuelve los ids de bloques activos (no encajados, no eliminados).
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
		for _y in h:
			col.append(Cell.EMPTY)
		g.append(col)
	return g


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func _all_receptors_filled() -> bool:
	for r: Dictionary in _receptors:
		var pos: Vector2i = r["pos"]
		if _grid[pos.x][pos.y] != Cell.LOCKED:
			return false
	return true


func _receptor_color_at(pos: Vector2i) -> String:
	for r: Dictionary in _receptors:
		if r["pos"] == pos:
			return r["color"]
	return ""


func _block_id_at(pos: Vector2i) -> String:
	for id: String in _blocks:
		if _blocks[id]["pos"] == pos:
			return id
	return ""
