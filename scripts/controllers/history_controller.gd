
class_name HistoryController
extends RefCounted

# Guarda los estados anteriores del tablero.
var historial: Array[Dictionary] = []

# Guarda el estado inicial para reiniciar el nivel.
var estado_inicial: Dictionary = {}


# Se llama cuando comienza un nivel.
func iniciar_nivel(board: BoardState) -> void:
	historial.clear()
	estado_inicial = board.snapshot()


# Guarda el estado antes de un movimiento valido.
func guardar_movimiento(board: BoardState) -> void:
	historial.append(board.snapshot())


# Deshace el ultimo movimiento.
func deshacer(board: BoardState) -> bool:
	if historial.is_empty():
		return false

	var estado_anterior: Dictionary = historial.pop_back()
	board.restore(estado_anterior)
	return true


# Reinicia el nivel a su estado original.
func reiniciar(board: BoardState) -> void:
	if estado_inicial.is_empty():
		return

	board.restore(estado_inicial)
	historial.clear()


# Devuelve cuantos movimientos pueden deshacerse.
func cantidad_movimientos() -> int:
	return historial.size()
