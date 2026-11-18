class_name TutorialGuideOverlay
extends Node2D

## Dibuja un marco redondeado pulsante y chevrones animados sobre el bloque sugerido.

var _grid_pos: Vector2i = Vector2i.ZERO
var _dir: Vector2i = Vector2i.RIGHT
var _cell_px: float = 80.0
var _show_arrow: bool = true
var _pulse_t: float = 0.0


func configure(grid_pos: Vector2i, dir: Vector2i, cell_px: float, show_arrow: bool) -> void:
	_grid_pos = grid_pos
	_dir = dir
	_cell_px = cell_px
	_show_arrow = show_arrow
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_pulse_t += delta * 4.2
		queue_redraw()


func _draw() -> void:
	var pulse := sin(_pulse_t) * 0.5 + 0.5
	var ring_alpha := 0.30 + 0.45 * pulse
	var expand := 1.0 + pulse * 3.0

	var rect := Rect2(
		Vector2(_grid_pos) * _cell_px + Vector2(3.0 - expand, 3.0 - expand),
		Vector2(_cell_px - 6.0 + expand * 2.0, _cell_px - 6.0 + expand * 2.0)
	)
	_draw_rounded_outline(rect, _cell_px * 0.11, Color(0.96, 0.97, 1.0, ring_alpha), 2.0)

	if not _show_arrow:
		return

	# Dos chevrones minimalistas pulsando en onda hacia la dirección indicada
	var center := (Vector2(_grid_pos) + Vector2(0.5, 0.5)) * _cell_px
	var dir_v := Vector2(_dir)
	var perp := Vector2(-dir_v.y, dir_v.x)
	var half_w := _cell_px * 0.13
	var depth := _cell_px * 0.10

	for idx in range(2):
		var phase := sin(_pulse_t - float(idx) * 1.1) * 0.5 + 0.5
		var dist := _cell_px * 0.58 + float(idx) * 11.0 + phase * 3.5
		var tip := center + dir_v * (dist + depth * 0.5)
		var back := tip - dir_v * depth
		draw_polyline(
			PackedVector2Array([back + perp * half_w, tip, back - perp * half_w]),
			Color(0.96, 0.97, 1.0, 0.28 + 0.67 * phase),
			2.5,
			true
		)


func _draw_rounded_outline(rect: Rect2, r: float, col: Color, width: float) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.position.x + rect.size.x
	var y1 := rect.position.y + rect.size.y
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)

	draw_line(Vector2(x0 + r, y0), Vector2(x1 - r, y0), col, width, true)
	draw_line(Vector2(x0 + r, y1), Vector2(x1 - r, y1), col, width, true)
	draw_line(Vector2(x0, y0 + r), Vector2(x0, y1 - r), col, width, true)
	draw_line(Vector2(x1, y0 + r), Vector2(x1, y1 - r), col, width, true)

	draw_arc(Vector2(x0 + r, y0 + r), r, PI, PI * 1.5, 8, col, width, true)
	draw_arc(Vector2(x1 - r, y0 + r), r, PI * 1.5, TAU, 8, col, width, true)
	draw_arc(Vector2(x1 - r, y1 - r), r, 0.0, PI * 0.5, 8, col, width, true)
	draw_arc(Vector2(x0 + r, y1 - r), r, PI * 0.5, PI, 8, col, width, true)
