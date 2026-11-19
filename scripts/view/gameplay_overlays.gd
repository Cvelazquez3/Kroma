class_name GameplayOverlays
extends RefCounted

## Overlays modales de partida (Victoria, Derrota y Pausa) desacoplados de gameplay.gd.


static func show_victory(
	tree: SceneTree,
	current_moves: int,
	par_moves: int,
	perfect_streak: int,
	best_streak: int,
	is_perfect_run: bool,
	on_complete: Callable
) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	tree.root.add_child(canvas)

	var backdrop := KromaTheme.create_blur_backdrop(0.0, Color(0.03, 0.03, 0.04, 0.58))
	canvas.add_child(backdrop)
	var blur_mat := backdrop.material as ShaderMaterial

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", KromaTheme.glass_card_style(
		Color(0.09, 0.09, 0.11, 0.40),
		Color(1.0, 1.0, 1.0, 0.36),
		28,
		22
	))
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var lbl_sub := Label.new()
	lbl_sub.text = "ESTADO DEL SISTEMA  ·  RESUELTO"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 10)
	lbl_sub.add_theme_color_override("font_color", Color(0.64, 0.66, 0.72))
	vbox.add_child(lbl_sub)

	var lbl_main := Label.new()
	lbl_main.text = "SECTOR COMPLETADO"
	lbl_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_main.add_theme_font_override("font", KromaTheme.bold_title_font())
	lbl_main.add_theme_font_size_override("font_size", 19)
	lbl_main.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	vbox.add_child(lbl_main)

	if par_moves > 0:
		var rank_lit := 1
		var rank_col := Color(0.75, 0.78, 0.85)
		var rank_txt := KromaTheme.sym("★☆☆  ", "") + ("RANGO B — COMPLETADO (%d/%d PASOS)" % [current_moves, par_moves])
		if current_moves <= par_moves:
			rank_lit = 3
			rank_col = Color(1.0, 0.85, 0.20)
			rank_txt = KromaTheme.sym("★★★  ", "") + ("RANGO S — ÓPTIMO (%d/%d PASOS)" % [current_moves, par_moves])
		elif current_moves <= par_moves + 3:
			rank_lit = 2
			rank_col = KromaTheme.COLOR_MAP["green"]
			rank_txt = KromaTheme.sym("★★☆  ", "") + ("RANGO A — EFICIENTE (%d/%d PASOS)" % [current_moves, par_moves])

		var rank_bar := HBoxContainer.new()
		rank_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		rank_bar.add_theme_constant_override("separation", 6)
		for i in range(3):
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(32, 3)
			seg.color = rank_col if i < rank_lit else Color(1.0, 1.0, 1.0, 0.14)
			rank_bar.add_child(seg)
		vbox.add_child(rank_bar)

		var lbl_eval := Label.new()
		lbl_eval.text = rank_txt
		lbl_eval.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_eval.add_theme_font_size_override("font_size", 11)
		lbl_eval.add_theme_color_override("font_color", rank_col)
		vbox.add_child(lbl_eval)

	var badge := PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lbl_streak := Label.new()
	lbl_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_streak.add_theme_font_size_override("font_size", 10)

	if is_perfect_run:
		badge.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(
			Color(0.35, 0.88, 0.98, 0.55),
			Color(0.10, 0.24, 0.30, 0.55)
		))
		lbl_streak.text = KromaTheme.sym("✦ ", "") + ("RACHA PERFECTA: %02d  ·  RÉCORD: %02d" % [perfect_streak, best_streak])
		lbl_streak.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	else:
		badge.add_theme_stylebox_override("panel", KromaTheme.glass_pill_style(
			Color(1.0, 1.0, 1.0, 0.14),
			Color(0.12, 0.12, 0.15, 0.50)
		))
		lbl_streak.text = "Racha reiniciada (requiere Rango S sin deshacer, reiniciar ni abismos)"
		lbl_streak.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78))

	badge.add_child(lbl_streak)
	vbox.add_child(badge)

	# Fade in -> lectura (2.0s) -> Fade out -> callback
	panel.modulate.a = 0.0
	var tw_in := canvas.create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(blur_mat, "shader_parameter/blur_radius", 5.0, 0.25)
	tw_in.tween_property(panel, "modulate:a", 1.0, 0.25)
	await tw_in.finished

	await tree.create_timer(2.0).timeout

	if is_instance_valid(canvas):
		var tw_out := canvas.create_tween()
		tw_out.set_parallel(true)
		tw_out.tween_property(blur_mat, "shader_parameter/blur_radius", 0.0, 0.35)
		tw_out.tween_property(panel, "modulate:a", 0.0, 0.35)
		await tw_out.finished
		canvas.queue_free()
		if on_complete.is_valid():
			on_complete.call()


static func show_defeat(tree: SceneTree, on_undo: Callable, on_restart: Callable) -> CanvasLayer:
	var canvas := CanvasLayer.new()
	canvas.layer = 127
	tree.root.add_child(canvas)

	var backdrop := KromaTheme.create_blur_backdrop(0.0, Color(0.08, 0.02, 0.03, 0.62))
	canvas.add_child(backdrop)
	var blur_mat := backdrop.material as ShaderMaterial

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", KromaTheme.glass_card_style(
		Color(0.24, 0.08, 0.11, 0.36),
		Color(0.95, 0.25, 0.28, 0.75)
	))
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var lbl_sub := Label.new()
	lbl_sub.text = "ESTADO DEL SISTEMA  ·  IRRESOLUBLE"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 10)
	lbl_sub.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 0.88))
	vbox.add_child(lbl_sub)

	var lbl_main := Label.new()
	lbl_main.text = "SIMULACIÓN BLOQUEADA"
	lbl_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_main.add_theme_font_override("font", KromaTheme.bold_title_font())
	lbl_main.add_theme_font_size_override("font_size", 19)
	lbl_main.add_theme_color_override("font_color", Color(0.98, 0.95, 0.95))
	vbox.add_child(lbl_main)

	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(96, 3)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.color = Color(0.95, 0.22, 0.25, 0.75)
	vbox.add_child(bar)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var btn_undo := KromaTheme.create_glass_button(KromaTheme.sym("↶  DESHACER", "DESHACER"), KromaTheme.COLOR_MAP["yellow"], Vector2(142, 40), 11, false)
	btn_undo.focus_mode = Control.FOCUS_NONE
	btn_undo.pressed.connect(on_undo)
	btn_row.add_child(btn_undo)

	var btn_restart := KromaTheme.create_glass_button(KromaTheme.sym("↺  REINICIAR", "REINICIAR"), KromaTheme.COLOR_MAP["red"], Vector2(142, 40), 11, false)
	btn_restart.focus_mode = Control.FOCUS_NONE
	btn_restart.pressed.connect(on_restart)
	btn_row.add_child(btn_restart)

	panel.modulate.a = 0.0
	var tw := canvas.create_tween()
	tw.set_parallel(true)
	tw.tween_property(blur_mat, "shader_parameter/blur_radius", 5.0, 0.20)
	tw.tween_property(panel, "modulate:a", 1.0, 0.20)
	return canvas


static func show_pause(
	tree: SceneTree,
	context_text: String,
	on_resume: Callable,
	on_restart: Callable,
	on_menu: Callable
) -> CanvasLayer:
	var canvas := CanvasLayer.new()
	canvas.layer = 126
	tree.root.add_child(canvas)

	var backdrop := KromaTheme.create_blur_backdrop(0.0, Color(0.03, 0.03, 0.04, 0.62))
	canvas.add_child(backdrop)
	var blur_mat := backdrop.material as ShaderMaterial

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", KromaTheme.glass_card_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var lbl_sub := Label.new()
	lbl_sub.text = "ESTADO DEL SISTEMA  ·  EN ESPERA"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 10)
	lbl_sub.add_theme_color_override("font_color", Color(0.64, 0.66, 0.72))
	vbox.add_child(lbl_sub)

	var lbl_title := Label.new()
	lbl_title.text = "PAUSA"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_override("font", KromaTheme.bold_title_font())
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	vbox.add_child(lbl_title)

	var lbl_ctx := Label.new()
	lbl_ctx.text = context_text
	lbl_ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ctx.add_theme_font_size_override("font_size", 11)
	lbl_ctx.add_theme_color_override("font_color", Color(0.62, 0.64, 0.70))
	vbox.add_child(lbl_ctx)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	for c_key: String in ["red", "blue", "yellow"]:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(28, 3)
		seg.color = KromaTheme.COLOR_MAP[c_key]
		bar.add_child(seg)
	vbox.add_child(bar)

	var btn_resume := KromaTheme.create_glass_button("REANUDAR  [ESC]", KromaTheme.COLOR_MAP["blue"], Vector2(280, 42))
	btn_resume.pressed.connect(on_resume)
	vbox.add_child(btn_resume)

	var btn_restart := KromaTheme.create_glass_button("REINICIAR SECTOR  [R]", KromaTheme.COLOR_MAP["yellow"], Vector2(280, 42))
	btn_restart.pressed.connect(on_restart)
	vbox.add_child(btn_restart)

	var btn_menu := KromaTheme.create_glass_button("VOLVER AL MENÚ PRINCIPAL", KromaTheme.COLOR_MAP["red"], Vector2(280, 42))
	btn_menu.pressed.connect(on_menu)
	vbox.add_child(btn_menu)

	btn_resume.grab_focus()

	panel.modulate.a = 0.0
	var tw := canvas.create_tween()
	tw.set_parallel(true)
	tw.tween_property(blur_mat, "shader_parameter/blur_radius", 5.5, 0.16)
	tw.tween_property(panel, "modulate:a", 1.0, 0.14)
	return canvas
