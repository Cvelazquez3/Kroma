class_name LevelData
extends RefCounted

## Datos de un nivel de Kroma, ya leídos y validados desde un archivo JSON.
## Solo describe el ESTADO INICIAL del tablero: no tiene lógica de juego.

## Coordenadas: x = columna (0 a la izquierda), y = fila (0 arriba).
## Es la misma convención que grid[x][y] y que el sistema 2D de Godot.

var id: int = 0
var level_name: String = ""
var sector: int = 1
var width: int = 0
var height: int = 0
var instruction: String = ""

## Celda rigida
var walls: Array[Vector2i] = []
## Celdas nulas (abismo).
var voids: Array[Vector2i] = []
## Un elemento por bloque: { "id": String, "pos": Vector2i, "color": String }
var blocks: Array[Dictionary] = []
## Un elemento por receptor: { "pos": Vector2i, "color": String }
var receptors: Array[Dictionary] = []

## Errores de validación. Si no está vacío, el nivel NO debe usarse.
var errors: Array[String] = []

func is_valid() -> bool:
	return errors.is_empty()

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height
