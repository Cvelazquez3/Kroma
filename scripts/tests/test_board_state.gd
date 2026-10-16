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
	
	
	# --- Prueba del snapshot ---
	var foto := board.snapshot()
	board.blocks[0]["pos"] = Vector2i(0, 0)
	print("Bloque movido a: ", board.blocks[0]["pos"])
	board.restore(foto)
	print("Bloque tras restaurar: ", board.blocks[0]["pos"])
	
	
	# --- Prueba de encaje ---
	var foto2 := board.snapshot()

	# Caso 1: bloque lejos del receptor, no debe encajar
	print("Encaja lejos del receptor: ", board.try_slot(0))        # false

	# Caso 2: bloque sobre el receptor, mismo color, debe encajar
	board.blocks[0]["pos"] = Vector2i(4, 2)
	print("Encaja sobre el receptor: ", board.try_slot(0))         # true
	print("Es muro rigido: ", board.is_solid_block(Vector2i(4, 2))) # true

	# Caso 3: intentar encajarlo otra vez, no debe pasar
	print("Encaja por segunda vez: ", board.try_slot(0))           # false

	board.restore(foto2)
	print("Tras restaurar, esta encajado: ", board.blocks[0]["slotted"])  # false
	
	
	# --- Prueba de victoria ---
	var foto3 := board.snapshot()
	print("Victoria al inicio: ", board.is_won())            # false

	board.blocks[0]["pos"] = Vector2i(4, 2)
	board.try_slot(0)
	print("Victoria tras encajar: ", board.is_won())         # true

	board.restore(foto3)
	print("Victoria tras restaurar: ", board.is_won())       # false
