extends CanvasLayer
class_name VictoryScreen

## Финальный экран: итоги забега с «отсчётом» цифр, тизер следующей планеты
## и два выбора — продолжить или в меню. На выставке сам возвращает в меню.

signal continue_pressed
signal menu_pressed

var _was_paused: bool = false
var _closing: bool = false
var _countdown: float = -1.0
var _countdown_full: float = -1.0
var _countdown_label: Label


func _init() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS


## Вызывать ПОСЛЕ add_child.
func setup(planet: PlanetData, summary: Dictionary, auto_return: bool, auto_return_sec: float) -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true

	var h := get_viewport().get_visible_rect().size.y
	var gold := Color(1.0, 0.85, 0.3)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.86)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(h * 0.025))
	center.add_child(box)

	var title := _label(Loc.t("PLANET SAVED"), int(h * 0.09), gold, true)
	box.add_child(title)
	var percent := roundi(planet.get_progress_ratio() * 100.0)
	box.add_child(_label("%s  —  %s" % [Loc.t(planet.Planet_Name),
			Loc.t("explored %d%%") % percent], int(h * 0.045), Color.WHITE))
	box.add_child(HSeparator.new())

	# ── Статистика: строки появляются по очереди, числа «накручиваются» ──
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(h * 0.08))
	grid.add_theme_constant_override("v_separation", int(h * 0.015))
	box.add_child(grid)

	var rows: Array = [
		[Loc.t("Time"), SessionTracker.format_time(summary.get("playtime", 0.0)), -1],
		[Loc.t("Enemies defeated"), "", int(summary.get("kills", 0))],
		[Loc.t("Best combo"), "", int(summary.get("best_combo", 0))],
		[Loc.t("Elites"), "", int(summary.get("elites", 0))],
		[Loc.t("Events"), "", int(summary.get("events", 0))],
		[Loc.t("Quests"), "%d / %d" % [summary.get("quests_done", 0), summary.get("quests_total", 0)], -1],
		[Loc.t("Achievements"), "%d / %d" % [summary.get("achv_done", 0), summary.get("achv_total", 0)], -1],
		[Loc.t("Falls"), "", int(summary.get("deaths", 0))],
	]
	var delay := 0.4
	for row in rows:
		var name_label := _label(row[0], int(h * 0.04), Color(0.75, 0.8, 0.9))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var value_label := _label(row[1] if row[2] < 0 else "0", int(h * 0.04), Color.WHITE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(name_label)
		grid.add_child(value_label)
		name_label.modulate.a = 0.0
		value_label.modulate.a = 0.0
		_reveal_row(name_label, value_label, int(row[2]), delay)
		delay += 0.35

	box.add_child(HSeparator.new())
	box.add_child(_label(Loc.t("Next stop: Morva — coming soon"),
			int(h * 0.035), Color(0.6, 0.85, 1.0)))
	box.add_child(_label(Loc.t("Thanks for playing!"), int(h * 0.045), gold))

	# ── Кнопки ──
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", int(h * 0.03))
	box.add_child(buttons)
	var keep_btn := _button(Loc.t("Keep exploring"), int(h * 0.04))
	var menu_btn := _button(Loc.t("Main menu"), int(h * 0.04))
	buttons.add_child(keep_btn)
	buttons.add_child(menu_btn)
	keep_btn.pressed.connect(_on_continue)
	menu_btn.pressed.connect(_on_menu)
	keep_btn.grab_focus()

	if auto_return:
		_countdown_full = auto_return_sec
		_countdown = auto_return_sec
		_countdown_label = _label("", int(h * 0.03), Color(0.7, 0.7, 0.7))
		box.add_child(_countdown_label)


func _reveal_row(name_label: Label, value_label: Label, count_to: int, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		name_label.modulate.a = 1.0
		value_label.modulate.a = 1.0)
	if count_to > 0:
		tw.tween_method(func(v: float) -> void: value_label.text = str(roundi(v)),
				0.0, float(count_to), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _process(delta: float) -> void:
	if _countdown < 0.0 or _closing:
		return
	_countdown -= delta
	if _countdown_label:
		_countdown_label.text = Loc.t("Returning to menu in %d…") % maxi(0, ceili(_countdown))
	if _countdown <= 0.0:
		_on_menu()


func _input(event: InputEvent) -> void:
	# Любая активность посетителя продлевает отсчёт
	if _countdown_full > 0.0 and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			_countdown = _countdown_full


func _on_continue() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	continue_pressed.emit()
	queue_free()


func _on_menu() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	menu_pressed.emit()
	queue_free()


func _label(text: String, size_px: int, color: Color, use_title_font: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", maxi(2, int(size_px * 0.1)))
	if use_title_font:
		var font := GameJuice.get_title_font()
		if font:
			label.add_theme_font_override("font", font)
	return label


func _button(text: String, size_px: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size_px)
	button.custom_minimum_size = Vector2(size_px * 7.0, size_px * 2.0)
	return button
