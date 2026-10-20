
extends Node

# Estados del controlador
enum Estado {
	IDLE,
	SLIDING
}

# Estado inicial
var estado_actual: Estado = Estado.IDLE


# Posición donde comienza el gesto táctil
var inicio_swipe: Vector2 = Vector2.ZERO

# Distancia mínima para reconocer un swipe
const DISTANCIA_MINIMA_SWIPE: float = 50.0


# Señal para solicitar un movimiento
signal movimiento_solicitado(direccion: Vector2i)

signal deshacer_solicitado
signal reiniciar_solicitado


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("undo_move"):
		if estado_actual == Estado.IDLE:
			deshacer_solicitado.emit()
		return

	if event.is_action_pressed("restart_level"):
		if estado_actual == Estado.IDLE:
			reiniciar_solicitado.emit()
		return
	# Bloquear movimientos mientras se desliza
	if estado_actual != Estado.IDLE:
			return

	var direccion := Vector2i.ZERO

	if event.is_action_pressed("move_up"):
		direccion = Vector2i.UP
	elif event.is_action_pressed("move_down"):
		direccion = Vector2i.DOWN
	elif event.is_action_pressed("move_left"):
		direccion = Vector2i.LEFT
	elif event.is_action_pressed("move_right"):
		direccion = Vector2i.RIGHT

	if direccion != Vector2i.ZERO:
		solicitar_movimiento(direccion)


func solicitar_movimiento(direccion: Vector2i) -> void:
	if estado_actual != Estado.IDLE:
		return

	estado_actual = Estado.SLIDING
	print("Movimiento solicitado: ", direccion)
	movimiento_solicitado.emit(direccion)


func finalizar_movimiento() -> void:
	estado_actual = Estado.IDLE
	print("Movimiento finalizado")



# Detectar gestos táctiles
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			inicio_swipe = event.position
		else:
			var desplazamiento: Vector2 = event.position - inicio_swipe

			if desplazamiento.length() < DISTANCIA_MINIMA_SWIPE:
				return

			var direccion := Vector2i.ZERO

			if abs(desplazamiento.x) > abs(desplazamiento.y):
				if desplazamiento.x > 0:
					direccion = Vector2i.RIGHT
				else:
					direccion = Vector2i.LEFT
			else:
				if desplazamiento.y > 0:
					direccion = Vector2i.DOWN
				else:
					direccion = Vector2i.UP

			solicitar_movimiento(direccion)
			


func _on_deshacer_solicitado() -> void:
	pass # Replace with function body.
