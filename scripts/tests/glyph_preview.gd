extends Node2D
## Prueba visual: muestra los 6 colores con su glifo.

const COLORS := {
	"red": Color(0.9, 0.2, 0.2),
	"blue": Color(0.2, 0.4, 0.9),
	"yellow": Color(0.95, 0.8, 0.2),
	"purple": Color(0.6, 0.3, 0.8),
	"green": Color(0.2, 0.7, 0.3),
	"orange": Color(0.95, 0.5, 0.15),
}
const CELL := 80


func _ready() -> void:
	position = Vector2(60, 100)
	var i := 0
	for name in COLORS:
		var rect := ColorRect.new()
		rect.size = Vector2(CELL - 8, CELL - 8)
		rect.position = Vector2(i * CELL, 0)
		rect.color = COLORS[name]
		add_child(rect)

		var glyph := Glyph.new()
		glyph.position = rect.position + rect.size / 2.0
		glyph.setup(name, 18.0)
		add_child(glyph)
		i += 1
