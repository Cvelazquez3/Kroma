class_name Glyph
extends Node2D
## Dibuja la forma geometrica (glifo) que acompana a cada color.
## Sirve para que el juego no dependa solo del color (accesibilidad).

const SHAPES := {
	"red": "circle",
	"blue": "square",
	"yellow": "triangle",
	"purple": "diamond",
	"green": "cross",
	"orange": "hexagon",
}
const GLYPH_COLOR := Color(0.08, 0.08, 0.1, 0.9)

var color_name: String = ""
var glyph_size: float = 20.0


func setup(p_color_name: String, p_size: float) -> void:
	color_name = p_color_name
	glyph_size = p_size
	queue_redraw()


func _draw() -> void:
	var s: float = glyph_size
	match SHAPES.get(color_name, ""):
		"circle":
			draw_circle(Vector2.ZERO, s, GLYPH_COLOR)
		"square":
			draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), GLYPH_COLOR)
		"triangle":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -s), Vector2(s, s), Vector2(-s, s)
			]), GLYPH_COLOR)
		"diamond":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)
			]), GLYPH_COLOR)
		"cross":
			var t: float = s * 0.35
			draw_rect(Rect2(-t, -s, t * 2.0, s * 2.0), GLYPH_COLOR)
			draw_rect(Rect2(-s, -t, s * 2.0, t * 2.0), GLYPH_COLOR)
		"hexagon":
			var pts := PackedVector2Array()
			for i in 6:
				var a: float = deg_to_rad(60.0 * i)
				pts.append(Vector2(cos(a), sin(a)) * s)
			draw_colored_polygon(pts, GLYPH_COLOR)
