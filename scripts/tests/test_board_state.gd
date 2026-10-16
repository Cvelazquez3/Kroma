@tool
extends EditorScript

func _run() -> void:
	# 1. Leer el nivel con el cargador de Christian
	var level := LevelLoader.load_from_file("res://data/levels/level_01.json")
	if not level.is_valid():
		push_error("\n".join(level.errors))
		return

	# 2. Llenar tu hoja de control
	var board := BoardState.new()
	board.load_from_level(level)

	# 3. Imprimir lo que contiene
	print("Ancho: ", board.width)
	print("Alto: ", board.height)
	print("Hay muro en (2,2): ", board.cells[2][2] == BoardState.Cell.WALL)
	print("Hay muro en (0,0): ", board.cells[0][0] == BoardState.Cell.WALL)
	print("Cantidad de bloques: ", board.blocks.size())
	print("Posicion del bloque: ", board.blocks[0]["pos"])
	print("Cantidad de receptores: ", board.receptors.size())
	print("Posicion del receptor: ", board.receptors[0]["pos"])
