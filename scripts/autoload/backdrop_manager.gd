extends Node

const BLUR_SHADER := preload("res://assets/shaders/frosted_blur.gdshader")

var _halo_node: _AmbientHalo


func _ready() -> void:
	# Capa -10: Base oscura + Retícula ortogonal + Halo ambiental
	var bg_layer := CanvasLayer.new()
	bg_layer.name = "GlobalBackgroundLayer"
	bg_layer.layer = -10
	add_child(bg_layer)

	var base_bg := ColorRect.new()
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_bg.color = Color(0.03, 0.03, 0.04, 1.0)
	base_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(base_bg)

	var grid_bg := _GridBackground.new()
	grid_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(grid_bg)

	_halo_node = _AmbientHalo.new()
	_halo_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(_halo_node)

	# Capa -8: Vidrio esmerilado (desenfoca -10 y cualquier demo en -9, dejando gameplay en 0 nítido)
	var blur_layer := CanvasLayer.new()
	blur_layer.name = "GlobalBlurLayer"
	blur_layer.layer = -8
	add_child(blur_layer)

	var blur_rect := ColorRect.new()
	blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	mat.set_shader_parameter("blur_radius", 5.0)
	mat.set_shader_parameter("tint_color", Color(0.03, 0.03, 0.04, 0.34))
	blur_rect.material = mat
	blur_layer.add_child(blur_rect)

	get_tree().root.size_changed.connect(_update_responsive_scale)
	_update_responsive_scale()


func _update_responsive_scale() -> void:
	var root := get_tree().root
	if root == null:
		return
	var win_size := root.size
	var target := 2.15 if win_size.y > win_size.x else 1.0
	if not is_equal_approx(root.content_scale_factor, target):
		root.content_scale_factor = target


func set_halo_color(new_col: Color, duration: float = 0.65) -> void:
	if _halo_node:
		_halo_node.set_halo_color(new_col, duration)


class _GridBackground extends Control:
	func _draw() -> void:
		var step := 64.0
		var line_col := Color(1.0, 1.0, 1.0, 0.085)
		var dot_col := Color(1.0, 1.0, 1.0, 0.14)
		var w := size.x
		var h := size.y
		var ox := fmod(w, step) * 0.5
		var oy := fmod(h, step) * 0.5

		var x := ox
		while x <= w:
			draw_line(Vector2(x, 0.0), Vector2(x, h), line_col, 1.0)
			x += step
		var y := oy
		while y <= h:
			draw_line(Vector2(0.0, y), Vector2(w, y), line_col, 1.0)
			y += step
		x = ox
		while x <= w:
			y = oy
			while y <= h:
				draw_circle(Vector2(x, y), 1.5, dot_col)
				y += step
			x += step


class _AmbientHalo extends Control:
	var halo_color: Color = Color(0.28, 0.28, 0.32)
	var _tw: Tween

	func set_halo_color(new_col: Color, duration: float = 0.65) -> void:
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_method(func(c: Color):
			halo_color = c
			queue_redraw()
		, halo_color, new_col, duration)

	func _draw() -> void:
		var center := size * 0.5
		var max_r := maxf(size.x, size.y) * 0.52
		# Gradiente radial suave de 16 capas (sin bordes circulares duros)
		var steps := 16
		for i in range(steps):
			var r_norm := 1.0 - (float(i) / float(steps))
			var r := max_r * r_norm
			var falloff := pow(1.0 - r_norm, 2.2)
			draw_circle(center, r, Color(halo_color.r, halo_color.g, halo_color.b, 0.012 + 0.014 * falloff))

		for corner_pos: Vector2 in [Vector2(size.x * 0.12, size.y * 0.20), Vector2(size.x * 0.88, size.y * 0.80)]:
			var c_max := max_r * 0.55
			for j in range(12):
				var rn := 1.0 - (float(j) / 12.0)
				var cr := c_max * rn
				var cf := pow(1.0 - rn, 2.4)
				draw_circle(corner_pos, cr, Color(halo_color.r, halo_color.g, halo_color.b, 0.018 * cf))
