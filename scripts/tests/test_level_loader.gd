extends SceneTree
## Pruebas del cargador de niveles. No necesita escena.
##
## Ejecutar desde la raíz del proyecto:
##   godot --headless --path . --script res://scripts/tests/test_level_loader.gd
## (en Windows, usa el ejecutable *_console.exe de Godot en lugar de "godot")

var _failures: int = 0


func _init() -> void:
	_test_level_01()
	_test_missing_file()
	_test_invalid_json()
	_test_out_of_bounds()
	_test_overlap()
	_test_bad_color()
	_test_bad_size()
	_test_no_receptors()
	_test_deterministic_load()

	print("")
	if _failures == 0:
		print("TODO OK: el cargador de niveles pasa todas las pruebas")
	else:
		print("FALLARON %d pruebas" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok   - %s" % name)
	else:
		print("  FAIL - %s" % name)
		_failures += 1


## Base válida sobre la que cada prueba rompe una sola cosa.
func _base() -> Dictionary:
	return {
		"version": 1, "id": 99, "name": "prueba", "sector": 1,
		"size": { "width": 5, "height": 5 },
		"walls": [{ "x": 2, "y": 2 }],
		"voids": [],
		"blocks": [{ "id": "b1", "x": 0, "y": 0, "color": "red" }],
		"receptors": [{ "x": 4, "y": 0, "color": "red" }],
	}


func _test_level_01() -> void:
	print("Nivel 01 desde archivo")
	var level := LevelLoader.load_from_file("res://data/levels/level_01.json")
	_check(level.is_valid(), "es válido (errores: %s)" % [level.errors])
	_check(level.width == 5 and level.height == 5, "tablero de 5x5")
	_check(level.blocks.size() == 1 and level.receptors.size() == 1, "1 bloque y 1 receptor")
	_check(level.blocks[0]["pos"] == Vector2i(3, 3), "el bloque empieza en (3,3)")
	_check(level.receptors[0]["pos"] == Vector2i(4, 2), "el receptor está en (4,2)")
	_check(level.walls.has(Vector2i(4, 3)), "hay muro en (4,3)")
	_check(level.blocks[0]["color"] == "red" and level.receptors[0]["color"] == "red", "bloque y receptor rojos")


func _test_missing_file() -> void:
	print("Archivo inexistente")
	var level := LevelLoader.load_from_file("res://data/levels/no_existe.json")
	_check(not level.is_valid(), "se rechaza")


func _test_invalid_json() -> void:
	print("JSON mal formado")
	var level := LevelLoader.load_from_string("{ esto no es json ")
	_check(not level.is_valid(), "se rechaza")


func _test_out_of_bounds() -> void:
	print("Celda fuera del tablero")
	var data := _base()
	data["walls"] = [{ "x": 5, "y": 0 }]
	_check(not LevelLoader.load_from_dict(data).is_valid(), "muro en x=5 en tablero 5x5")


func _test_overlap() -> void:
	print("Celdas solapadas")
	var data := _base()
	data["receptors"] = [{ "x": 2, "y": 2, "color": "red" }]  # encima del muro
	_check(not LevelLoader.load_from_dict(data).is_valid(), "receptor sobre un muro")


func _test_bad_color() -> void:
	print("Color inválido")
	var data := _base()
	data["blocks"] = [{ "id": "b1", "x": 0, "y": 0, "color": "rosa" }]
	_check(not LevelLoader.load_from_dict(data).is_valid(), "color 'rosa'")


func _test_bad_size() -> void:
	print("Tamaño fuera de rango")
	var data := _base()
	data["size"] = { "width": 9, "height": 5 }
	_check(not LevelLoader.load_from_dict(data).is_valid(), "9x5 excede el máximo de 8")


func _test_no_receptors() -> void:
	print("Sin receptores")
	var data := _base()
	data["receptors"] = []
	_check(not LevelLoader.load_from_dict(data).is_valid(), "nivel sin receptores")


func _test_deterministic_load() -> void:
	print("Carga determinista")
	var a := LevelLoader.load_from_file("res://data/levels/level_01.json")
	var b := LevelLoader.load_from_file("res://data/levels/level_01.json")
	_check(a.walls == b.walls and a.blocks == b.blocks and a.receptors == b.receptors, "dos cargas dan el mismo resultado")
