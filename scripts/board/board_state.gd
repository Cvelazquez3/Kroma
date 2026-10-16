class_name BoardState
extends RefCounted
## Hoja de control del tablero: guarda donde esta cada cosa.
## No dibuja nada, solo guarda datos.

enum Cell { EMPTY, WALL, VOID }

var width: int = 0
var height: int = 0
var cells: Array = []       # terreno fijo: vacio, muro o abismo
var blocks: Array = []      # los bloques que se mueven
var receptors: Array = []   # las metas


func load_from_level(level: LevelData) -> void:
	width = level.width
	height = level.height

	# Tablero vacio
	cells = []
	for x in range(width):
		var column: Array = []
		for y in range(height):
			column.append(Cell.EMPTY)
		cells.append(column)

	# Marcar muros y abismos
	for w in level.walls:
		cells[w.x][w.y] = Cell.WALL
	for v in level.voids:
		cells[v.x][v.y] = Cell.VOID

	# Copiar los bloques
	blocks = []
	for b in level.blocks:
		blocks.append({
			"id": b["id"],
			"pos": b["pos"],
			"color": b["color"],
			"slotted": false,
		})

	# Copiar los receptores
	receptors = []
	for r in level.receptors:
		receptors.append({
			"pos": r["pos"],
			"color": r["color"],
			"filled": false,
		})
		
		

# Toma una "foto" del estado actual
func snapshot() -> Dictionary:
	return {
		"blocks": blocks.duplicate(true),
		"receptors": receptors.duplicate(true),
	}


# Vuelve al estado de una foto guardada
func restore(snap: Dictionary) -> void:
	blocks = snap["blocks"].duplicate(true)
	receptors = snap["receptors"].duplicate(true)
	


# Devuelve el numero del bloque en esa celda, o -1 si no hay
func block_index_at(pos: Vector2i) -> int:
	for i in range(blocks.size()):
		if blocks[i]["pos"] == pos:
			return i
	return -1


# Devuelve el numero del receptor en esa celda, o -1 si no hay
func receptor_index_at(pos: Vector2i) -> int:
	for i in range(receptors.size()):
		if receptors[i]["pos"] == pos:
			return i
	return -1


# True si en esa celda hay un bloque ya encajado (cuenta como muro)
func is_solid_block(pos: Vector2i) -> bool:
	var i: int = block_index_at(pos)
	return i != -1 and blocks[i]["slotted"]


# Se llama cuando un bloque ya se detuvo.
# Si esta sobre un receptor libre del mismo color, lo encaja y devuelve true.
func try_slot(block_index: int) -> bool:
	var block: Dictionary = blocks[block_index]
	if block["slotted"]:
		return false
	var r: int = receptor_index_at(block["pos"])
	if r == -1:
		return false
	if receptors[r]["filled"]:
		return false
	if receptors[r]["color"] != block["color"]:
		return false
	block["slotted"] = true
	receptors[r]["filled"] = true
	return true
	


# True si todos los receptores estan ocupados
func is_won() -> bool:
	if receptors.is_empty():
		return false
	for r in receptors:
		if not r["filled"]:
			return false
	return true
