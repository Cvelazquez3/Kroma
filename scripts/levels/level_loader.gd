class_name LevelLoader
extends RefCounted
## Lee un nivel desde JSON, lo valida y devuelve un LevelData.
##
## Uso:
##   var level := LevelLoader.load_from_file("res://data/levels/level_01.json")
##   if not level.is_valid():
##       push_error("\n".join(level.errors))
##       return
##   # level.width, level.height, level.walls, level.blocks, level.receptors ...
##
## Siempre devuelve un LevelData (nunca null). Hay que revisar is_valid().
## Formato del JSON documentado en res://docs/formato_nivel.md

const FORMAT_VERSION := 1
const MIN_SIZE := 5
const MAX_SIZE := 8
const PRIMARY_COLORS: Array[String] = ["red", "blue", "yellow"]
const SECONDARY_COLORS: Array[String] = ["purple", "green", "orange"]


static func load_from_file(path: String) -> LevelData:
	if not FileAccess.file_exists(path):
		var missing := LevelData.new()
		missing.errors.append("No existe el archivo de nivel: %s" % path)
		return missing
	return load_from_string(FileAccess.get_file_as_string(path))


static func load_from_string(json_text: String) -> LevelData:
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		var broken := LevelData.new()
		broken.errors.append("JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		return broken
	if typeof(json.data) != TYPE_DICTIONARY:
		var wrong := LevelData.new()
		wrong.errors.append("La raíz del JSON debe ser un objeto { ... }")
		return wrong
	return load_from_dict(json.data)


static func load_from_dict(data: Dictionary) -> LevelData:
	var level := LevelData.new()

	# --- Metadatos ---
	var version: Variant = _to_int(data.get("version", FORMAT_VERSION))
	if version == null or version != FORMAT_VERSION:
		level.errors.append("'version' no soportada (se espera %d)" % FORMAT_VERSION)
	var id_value: Variant = _to_int(data.get("id", 0))
	level.id = id_value if id_value != null else 0
	level.level_name = str(data.get("name", ""))
	var sector_value: Variant = _to_int(data.get("sector", 1))
	level.sector = sector_value if sector_value != null else 1

	# --- Directiva técnica / Instrucción tutorial ---
	if data.has("instruction"):
		level.instruction = str(data["instruction"])
	elif data.has("instruccion"):
		level.instruction = str(data["instruccion"])

	# --- Tamaño ---
	var size: Variant = data.get("size")
	if typeof(size) != TYPE_DICTIONARY:
		level.errors.append("Falta 'size': { \"width\": N, \"height\": N }")
		return level
	var w: Variant = _to_int(size.get("width"))
	var h: Variant = _to_int(size.get("height"))
	if w == null or h == null:
		level.errors.append("'size.width' y 'size.height' deben ser enteros")
		return level
	if w < MIN_SIZE or w > MAX_SIZE or h < MIN_SIZE or h > MAX_SIZE:
		level.errors.append("El tablero debe medir entre %dx%d y %dx%d (recibido %dx%d)" % [MIN_SIZE, MIN_SIZE, MAX_SIZE, MAX_SIZE, w, h])
		return level
	level.width = w
	level.height = h

	# Registro de celdas ocupadas para detectar solapamientos.
	var occupied: Dictionary = {}

	# --- Muros y abismos ---
	for raw in _get_list(data, "walls", level):
		var cell: Variant = _parse_cell(raw, "walls", level)
		if cell != null and _claim(occupied, cell, "muro", level):
			level.walls.append(cell)

	for raw in _get_list(data, "voids", level):
		var cell: Variant = _parse_cell(raw, "voids", level)
		if cell != null and _claim(occupied, cell, "abismo", level):
			level.voids.append(cell)

	# --- Bloques ---
	var block_ids: Dictionary = {}
	var block_list := _get_list(data, "blocks", level)
	for i in block_list.size():
		var raw: Variant = block_list[i]
		var cell: Variant = _parse_cell(raw, "blocks[%d]" % i, level)
		var color: Variant = _parse_color(raw, "blocks[%d]" % i, level)
		var block_id := str(raw.get("id", "b%d" % (i + 1))) if typeof(raw) == TYPE_DICTIONARY else ""
		if block_ids.has(block_id):
			level.errors.append("blocks[%d]: el id '%s' está repetido" % [i, block_id])
		block_ids[block_id] = true
		if cell != null and color != null and _claim(occupied, cell, "bloque '%s'" % block_id, level):
			level.blocks.append({ "id": block_id, "pos": cell, "color": color })

	# --- Receptores ---
	var receptor_list := _get_list(data, "receptors", level)
	for i in receptor_list.size():
		var raw: Variant = receptor_list[i]
		var cell: Variant = _parse_cell(raw, "receptors[%d]" % i, level)
		var color: Variant = _parse_color(raw, "receptors[%d]" % i, level)
		if cell != null and color != null and _claim(occupied, cell, "receptor", level):
			level.receptors.append({ "pos": cell, "color": color })

	# --- Reglas de coherencia del nivel ---
	if level.blocks.is_empty():
		level.errors.append("El nivel necesita al menos 1 bloque")
	if level.receptors.is_empty():
		level.errors.append("El nivel necesita al menos 1 receptor")
	if level.blocks.size() < level.receptors.size():
		level.errors.append("Hay menos bloques (%d) que receptores (%d): el nivel no puede resolverse" % [level.blocks.size(), level.receptors.size()])

	return level


# ---------------------------------------------------------------- helpers

## Devuelve un int si el valor es un número entero (el JSON de Godot entrega floats), si no null.
static func _to_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and value == floorf(value):
		return int(value)
	return null


static func _get_list(data: Dictionary, key: String, level: LevelData) -> Array:
	var value: Variant = data.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		level.errors.append("'%s' debe ser una lista" % key)
		return []
	return value


## Lee "x" e "y" de un objeto y devuelve Vector2i, o null si es inválido.
static func _parse_cell(raw: Variant, where: String, level: LevelData) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		level.errors.append("%s: debe ser un objeto con 'x' e 'y'" % where)
		return null
	var x: Variant = _to_int(raw.get("x"))
	var y: Variant = _to_int(raw.get("y"))
	if x == null or y == null:
		level.errors.append("%s: 'x' e 'y' deben ser enteros" % where)
		return null
	var cell := Vector2i(x, y)
	if not level.in_bounds(cell):
		level.errors.append("%s: la celda (%d, %d) está fuera del tablero %dx%d" % [where, x, y, level.width, level.height])
		return null
	return cell


## Lee "color" y verifica que sea uno de los 6 colores válidos. Devuelve String o null.
static func _parse_color(raw: Variant, where: String, level: LevelData) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null  # el error ya lo reportó _parse_cell
	var color: Variant = raw.get("color")
	if typeof(color) != TYPE_STRING or not (color in PRIMARY_COLORS or color in SECONDARY_COLORS):
		level.errors.append("%s: 'color' debe ser uno de %s" % [where, PRIMARY_COLORS + SECONDARY_COLORS])
		return null
	return color


## Marca la celda como usada. Devuelve false (y registra error) si ya lo estaba.
static func _claim(occupied: Dictionary, cell: Vector2i, label: String, level: LevelData) -> bool:
	if occupied.has(cell):
		level.errors.append("La celda (%d, %d) está repetida: %s y %s" % [cell.x, cell.y, occupied[cell], label])
		return false
	occupied[cell] = label
	return true
