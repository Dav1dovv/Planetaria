extends CanvasLayer
class_name JuiceLayer

## Экранный слой для всплывающих эффектов. Создаётся и используется через
## GameJuice — напрямую с ним работать не нужно.

const MAX_TOASTS := 4

var _toast_box: VBoxContainer


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _vp_height() -> float:
	var vp := get_viewport()
	return vp.get_visible_rect().size.y if vp else 270.0


# ─────────────────────────────────────────────────────────────────────────────
#  Всплывающий текст
# ─────────────────────────────────────────────────────────────────────────────
func spawn_floating_text(world_pos: Vector2, message: String, color: Color,
		size_mult: float, life: float, rise: float, pop_scale: float) -> void:
	var h := _vp_height()
	var label := FloatingText.new()
	var font_size := maxi(8, int(h * 0.032 * size_mult))
	label.setup(world_pos, message, color, font_size, life, rise * h / 270.0, pop_scale)
	add_child(label)


# ─────────────────────────────────────────────────────────────────────────────
#  Баннер
# ─────────────────────────────────────────────────────────────────────────────
func show_banner(title: String, subtitle: String, color: Color, hold: float) -> void:
	if not is_inside_tree():
		await tree_entered
	var h := _vp_height()
	var title_size := int(h * 0.085)
	var sub_size := int(h * 0.04)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var band := ColorRect.new()
	band.color = Color(0.0, 0.0, 0.0, 0.62)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.28
	band.anchor_bottom = 0.28
	var band_h := float(title_size + h * 0.05) + (sub_size + h * 0.01 if not subtitle.is_empty() else 0.0)
	band.offset_top = -band_h * 0.5
	band.offset_bottom = band_h * 0.5
	root.add_child(band)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(_make_label(title, title_size, color, true))
	if not subtitle.is_empty():
		box.add_child(_make_label(subtitle, sub_size, Color(0.92, 0.92, 0.92), false))

	# Выезд плашки: растёт из линии по высоте
	await get_tree().process_frame
	band.pivot_offset = band.size * 0.5
	band.scale = Vector2(1.0, 0.0)
	box.modulate.a = 0.0
	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(band, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(box, "modulate:a", 1.0, 0.25)
	await tw_in.finished

	await get_tree().create_timer(hold).timeout

	var tw_out := create_tween()
	tw_out.tween_property(root, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	root.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
#  Тосты
# ─────────────────────────────────────────────────────────────────────────────
func show_toast(message: String, color: Color, hold: float) -> void:
	if not is_inside_tree():
		await tree_entered
	_ensure_toast_box()

	# Не копим очередь: лишние старые тосты убираем сразу
	while _toast_box.get_child_count() >= MAX_TOASTS:
		var old := _toast_box.get_child(0)
		_toast_box.remove_child(old)
		old.queue_free()

	var h := _vp_height()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.78)
	style.set_corner_radius_all(int(h * 0.01))
	style.set_content_margin_all(h * 0.012)
	style.border_color = color
	style.set_border_width_all(maxi(1, int(h * 0.003)))
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(_make_label(message, int(h * 0.035), color, false))
	panel.modulate.a = 0.0
	_toast_box.add_child(panel)

	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(hold)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


func _ensure_toast_box() -> void:
	if is_instance_valid(_toast_box):
		return
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", int(_vp_height() * 0.008))
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.anchor_top = 0.0
	_toast_box.anchor_bottom = 0.0
	_toast_box.offset_top = _vp_height() * 0.06
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_toast_box)


func _make_label(text: String, size_px: int, color: Color, use_title_font: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", maxi(2, int(size_px * 0.12)))
	if use_title_font:
		var font := GameJuice.get_title_font()
		if font:
			label.add_theme_font_override("font", font)
	return label
