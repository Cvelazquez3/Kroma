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
