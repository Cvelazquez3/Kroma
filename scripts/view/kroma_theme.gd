class_name KromaTheme
extends RefCounted

## Paleta central y estilos glassmorphism compartidos entre menús y tablero.

const BLUR_SHADER := preload("res://assets/shaders/frosted_blur.gdshader")

const COLOR_MAP := {
	"red": Color(0.95, 0.22, 0.25),
	"blue": Color(0.20, 0.50, 1.00),
	"yellow": Color(1.00, 0.82, 0.15),
	"purple": Color(0.68, 0.25, 0.95),
	"green": Color(0.20, 0.88, 0.45),
	"orange": Color(1.00, 0.55, 0.12),
	"empty": Color(0.14, 0.14, 0.17, 0.30),
	"wall": Color(0.20, 0.20, 0.24, 0.92),
	"void": Color(0.00, 0.00, 0.00, 0.0)
}

enum CellStyle { SLOT, OUTER_FRAME, GLASS_BLOCK, GLASS_BLOCK_SELECTED, VOID, RECEPTOR }


static func is_web() -> bool:
	return OS.has_feature("web")


static func sym(desktop_text: String, web_text: String = "") -> String:
	return web_text if OS.has_feature("web") else desktop_text


static func bold_title_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Inter", "Roboto", "Arial"])
	f.font_weight = 700
	return f


## Estilos para celdas, bloques, receptores y el marco del tablero.
static func cell_style(tipo: CellStyle, color_param: Color = Color.WHITE, corner_r: int = 7) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(corner_r)
	s.set_border_width_all(1)

	match tipo:
		CellStyle.SLOT:
			s.bg_color = color_param
			s.border_color = Color(1.0, 1.0, 1.0, 0.08)

		CellStyle.OUTER_FRAME:
			s.set_corner_radius_all(corner_r + 6)
			s.bg_color = Color(0.09, 0.09, 0.11, 0.36)
			s.border_width_top = 2
			s.border_blend = true
			s.border_color = Color(1.0, 1.0, 1.0, 0.28)
			s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
			s.shadow_size = 20
			s.shadow_offset = Vector2(0, 4)

		CellStyle.GLASS_BLOCK:
			s.bg_color = Color(color_param.r * 0.85, color_param.g * 0.85, color_param.b * 0.85, 0.90)
			s.border_color = Color(1.0, 1.0, 1.0, 0.35)
			s.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
			s.shadow_size = 4
			s.shadow_offset = Vector2(0, 2)

		CellStyle.GLASS_BLOCK_SELECTED:
			s.bg_color = Color(color_param.r * 0.85, color_param.g * 0.85, color_param.b * 0.85, 0.90)
			s.border_color = Color(1.0, 1.0, 1.0, 0.90)
			s.shadow_color = Color(color_param.r, color_param.g, color_param.b, 0.60)
			s.shadow_size = 8
			s.shadow_offset = Vector2(0, 2)

		CellStyle.VOID:
			var col_void: Color = COLOR_MAP["void"]
			s.bg_color = col_void
			s.border_color = Color(0.10, 0.10, 0.12, 0.85)
			s.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			s.shadow_size = 6

		CellStyle.RECEPTOR:
			s.bg_color = Color(color_param.r, color_param.g, color_param.b, 0.15)
			s.border_color = Color(color_param.r, color_param.g, color_param.b, 0.50)
			s.shadow_color = Color(color_param.r, color_param.g, color_param.b, 0.20)
			s.shadow_size = 6

	return s


## Une muros adyacentes quitando bordes y radios en los lados que se tocan.
static func connected_wall_style(has_up: bool, has_down: bool, has_left: bool, has_right: bool, rad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_MAP["wall"]
	s.border_blend = true
	s.border_color = Color(1.0, 1.0, 1.0, 0.28)

	s.corner_radius_top_left = 0 if (has_up or has_left) else rad
	s.corner_radius_top_right = 0 if (has_up or has_right) else rad
	s.corner_radius_bottom_left = 0 if (has_down or has_left) else rad
	s.corner_radius_bottom_right = 0 if (has_down or has_right) else rad

	s.border_width_left = 0 if has_left else 1
	s.border_width_right = 0 if has_right else 1
	s.border_width_top = 0 if has_up else 1
	s.border_width_bottom = 0 if has_down else 1
	return s


## Tarjeta principal de cristal gris carbón para modales, pausa y resultados.
static func glass_card_style(
	bg_col: Color = Color(0.09, 0.09, 0.11, 0.40),
	border_col: Color = Color(1.0, 1.0, 1.0, 0.36),
	pad_h: int = 28,
	pad_v: int = 24
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_corner_radius_all(12)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.set_border_width_all(1)
	s.border_width_top = 2
	s.border_blend = true
	s.border_color = border_col
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size = 24
	return s


## Cápsula translúcida para contadores del HUD, badges de racha y footer.
static func glass_pill_style(border_col: Color, bg_col: Color = Color(0.09, 0.09, 0.11, 0.42)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_corner_radius_all(12)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.set_border_width_all(1)
	s.border_blend = true
	s.border_color = border_col
	return s


## Botón estándar de cristal con borde de color al pasar el cursor o enfocar.
static func create_glass_button(
	label_text: String,
	accent: Color,
	min_size: Vector2 = Vector2(256, 48),
	font_size: int = 13,
	with_sfx: bool = true
) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.10, 0.12, 0.30)
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.24)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.16, 0.19, 0.48)
	hover.set_corner_radius_all(8)
	hover.set_border_width_all(1)
	hover.border_width_left = 2
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.90)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	pressed.set_corner_radius_all(8)
	pressed.set_border_width_all(1)
	pressed.border_width_left = 2
	pressed.border_color = accent

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	if with_sfx:
		btn.mouse_entered.connect(func(): AudioManager.play("ui_hover", 0.72, -13.0))
		btn.focus_entered.connect(func(): AudioManager.play("ui_hover", 0.72, -13.0))
	return btn


## Fondo desenfocado reutilizable para modales y overlays.
static func create_blur_backdrop(blur_radius: float = 5.5, tint_color: Color = Color(0.03, 0.03, 0.04, 0.60)) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	mat.set_shader_parameter("blur_radius", blur_radius)
	mat.set_shader_parameter("tint_color", tint_color)
	rect.material = mat
	return rect
