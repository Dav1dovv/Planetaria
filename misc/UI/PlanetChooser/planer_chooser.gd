extends CanvasLayer
## Навигационная консоль: выбор планеты.
## Три экрана, как у оборудования на мостике: слева список направлений,
## в центре голографическая проекция планеты, справа данные разведки и топливо.
## Публичный API прежний (is_opened, toogle()), поэтому сцена корабля и Show_Child работают как раньше.
##
## Управление: стрелки / колесо / клик — выбор, Enter / A / двойной клик — запуск, Esc / B — закрыть.

const FUEL = preload("uid://dwmw15dg8pwvd")

## Атлас с картинками планет (в нём лежат все планеты, у каждой своя область).
const ATLAS: Texture2D = preload("res://Assets/Textures/Items/Planet.png")

## Направления. id = ключ сцены в SceneRegistry. Планеты без сцены показываются как «NO SIGNAL».
## icon — область планеты в атласе, type и desc — ключи перевода для досье планеты.
## Чтобы добавить планету (например Anelim, топливо 50) — одна запись здесь.
## Свободные картинки в атласе: Rect2i(104, 8, 17, 17) — ледяная, Rect2i(60, 80, 12, 12) — лавовая,
## Rect2i(4, 53, 41, 41) — звезда, Rect2i(49, 50, 19, 19) — пёстрая.
const PLANETS: Array[Dictionary] = [
	{"id": "Vehana", "fuel": 10, "tint": Color("5fd38d"), "icon": Rect2i(7, 9, 32, 32),
		"type": "HABITABLE",
		"desc": "A settlement under threat: pig raids, slime creeping over the glades and an awakened ancient guardian."},
	{"id": "Anelim",  "fuel": 46, "tint": Color("04b6caff"), "icon": Rect2i(76, 52, 25, 25),
		"type": "ARID", "desc": "No survey data available."},
	{"id": "Rodus",  "fuel": 25, "tint": Color("5fb4d8"), "icon": Rect2i(60, 80, 16,16),
		"type": "OCEANIC", "desc": "No survey data available."},
]

const LAUNCH_DELAY := 1

var is_opened: bool = false
var location_key: String = ""   ## оставлено для совместимости со старым кодом

var _index: int = 0
var _launching: bool = false
var _h: float = 360.0

var _rows: Array = []
var _screens: Array = []
var _viewer: _Viewer
var _view_title: Label
var _planet_name: Label
var _planet_type: Label
var _planet_desc: Label
var _info: RichTextLabel
var _title: Label
var _list_title: Label
var _info_title: Label
var _hint: Label
var _launch_button: Button
var _close_button: Button
var _overlay: Label


func _ready() -> void:
	layer = 20
	visible = false
	var legacy := get_node_or_null("Panel")  # старая панель с OptionButton больше не нужна
	if legacy:
		legacy.visible = false
	_h = get_viewport().get_visible_rect().size.y
	_build()
	_retranslate()


# ─────────────────────────────────────────────────────────────────────────────
#  Сборка интерфейса
# ─────────────────────────────────────────────────────────────────────────────
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # клики не проваливаются в игру
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.015, 0.03, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	# Корпус консоли
	var bezel := PanelContainer.new()
	bezel.anchor_left = 0.06
	bezel.anchor_right = 0.94
	bezel.anchor_top = 0.09
	bezel.anchor_bottom = 0.91
	bezel.add_theme_stylebox_override("panel", TerminalStyle.metal_style(_h))
	root.add_child(bezel)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", int(_h * 0.02))
	bezel.add_child(frame)

	# Шапка: индикатор, название, кнопка закрыть
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(_h * 0.015))
	frame.add_child(top)
	top.add_child(_Led.new(_h))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", maxi(7, roundi(_h * 0.04)))
	_title.add_theme_color_override("font_color", TerminalStyle.AMBER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)

	# Три экрана
	var screens := HBoxContainer.new()
	screens.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screens.add_theme_constant_override("separation", int(_h * 0.025))
	frame.add_child(screens)
	screens.add_child(_build_list_screen())
	screens.add_child(_build_planet_screen())
	screens.add_child(_build_info_screen())

	# Нижняя панель
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", int(_h * 0.02))
	frame.add_child(bottom)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", maxi(5, roundi(_h * 0.026)))
	_hint.add_theme_color_override("font_color", TerminalStyle.CYAN_DIM)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_hint)
	_close_button = _make_button(TerminalStyle.STEEL)
	_close_button.pressed.connect(toogle)
	bottom.add_child(_close_button)
	_launch_button = _make_button(TerminalStyle.CYAN)
	_launch_button.pressed.connect(_launch)
	bottom.add_child(_launch_button)

	bezel.add_child(_Bolts.new(_h))  # винты и огни — последним, поверх корпуса

	# Надпись при запуске гиперпрыжка
	_overlay = Label.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_theme_font_size_override("font_size", maxi(8, roundi(_h * 0.06)))
	_overlay.add_theme_color_override("font_color", TerminalStyle.CYAN)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	root.add_child(_overlay)


func _make_button(edge: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE  # управление идёт через консоль, а не через фокус кнопок
	b.custom_minimum_size = Vector2(_h * 0.32, _h * 0.085)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", maxi(6, roundi(_h * 0.034)))
	b.add_theme_color_override("font_color", TerminalStyle.TEXT)
	b.add_theme_color_override("font_disabled_color", TerminalStyle.GREY)
	b.add_theme_stylebox_override("normal", TerminalStyle.button_style(_h, TerminalStyle.METAL_DARK, edge))
	b.add_theme_stylebox_override("hover", TerminalStyle.button_style(_h, Color(0.09, 0.2, 0.24), TerminalStyle.CYAN))
	b.add_theme_stylebox_override("pressed", TerminalStyle.button_style(_h, Color(0.12, 0.3, 0.34), TerminalStyle.AMBER))
	b.add_theme_stylebox_override("disabled", TerminalStyle.button_style(_h, TerminalStyle.METAL_DARK, TerminalStyle.GREY))
	return b


func _small_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", maxi(5, roundi(_h * 0.028)))
	l.add_theme_color_override("font_color", TerminalStyle.CYAN_DIM)
	return l


func _build_list_screen() -> Control:
	var screen := _Screen.new(_h, TerminalStyle.CYAN_DIM)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_stretch_ratio = 3.0
	_list_title = _small_label()
	screen.content.add_child(_list_title)
	for i in PLANETS.size():
		var row := _Row.new(_h)
		row.selected.connect(_select.bind(i))
		row.activated.connect(_launch)
		screen.content.add_child(row)
		_rows.append(row)
	_screens.append(screen)
	return screen


func _build_planet_screen() -> Control:
	var screen := _Screen.new(_h, TerminalStyle.CYAN)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_stretch_ratio = 4.0
	_view_title = _small_label()
	screen.content.add_child(_view_title)

	_viewer = _Viewer.new()
	_viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.content.add_child(_viewer)

	_planet_name = Label.new()
	_planet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_name.add_theme_font_size_override("font_size", maxi(8, roundi(_h * 0.048)))
	_planet_name.add_theme_color_override("font_color", TerminalStyle.TEXT)
	screen.content.add_child(_planet_name)

	_planet_type = _small_label()
	_planet_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_type.add_theme_color_override("font_color", TerminalStyle.AMBER)
	screen.content.add_child(_planet_type)

	_planet_desc = _small_label()
	_planet_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_planet_desc.custom_minimum_size = Vector2(0.0, _h * 0.085)  # место под 3 строки: экран не «прыгает» при смене планеты
	_planet_desc.add_theme_color_override("font_color", TerminalStyle.TEXT.darkened(0.25))
	screen.content.add_child(_planet_desc)

	_screens.append(screen)
	return screen


func _build_info_screen() -> Control:
	var screen := _Screen.new(_h, TerminalStyle.CYAN_DIM)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_stretch_ratio = 3.0
	_info_title = _small_label()
	screen.content.add_child(_info_title)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = false
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("normal_font_size", maxi(6, roundi(_h * 0.032)))
	_info.add_theme_color_override("default_color", TerminalStyle.TEXT)
	screen.content.add_child(_info)
	_screens.append(screen)
	return screen


func _retranslate() -> void:
	_title.text = Loc.t("NAVIGATION CONSOLE")
	_list_title.text = "// " + Loc.t("DESTINATIONS")
	_info_title.text = "// " + Loc.t("SCAN DATA")
	_view_title.text = "// " + Loc.t("PLANET FILE")
	_hint.text = Loc.t("Up/Down - select  |  Enter - launch  |  Esc - close")
	_close_button.text = Loc.t("Close")
	if is_opened:
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


# ─────────────────────────────────────────────────────────────────────────────
#  Открытие / закрытие
# ─────────────────────────────────────────────────────────────────────────────
func toogle() -> void:
	_set_open(not is_opened)


func _set_open(open: bool) -> void:
	if open == is_opened or _launching:
		return
	if open and Global.is_opened_menu:
		return  # поверх другого окна не открываемся
	is_opened = open
	Global.is_opened_menu = open
	visible = open
	if not open:
		return
	_index = _default_index()
	_refresh()
	await get_tree().process_frame  # размеры экранов известны только после раскладки
	for i in _screens.size():
		_screens[i].boot(i * 0.09)


## Сразу выбираем ближайшую доступную планету, а не «Vehana», на которой игрок, возможно, и так стоит.
func _default_index() -> int:
	for i in PLANETS.size():
		var s := _state(i)
		if not s.offline and not s.here:
			return i
	return 0


func _input(event: InputEvent) -> void:
	if not is_opened:
		return
	if Global.is_escape_event(event):
		get_viewport().set_input_as_handled()
		if not _launching:
			_set_open(false)
			Global.mark_menu_closed()
		return
	if _launching:
		return
	if _pressed(event, ["ui_down", "MoveDown"]):
		_select(wrapi(_index + 1, 0, PLANETS.size()))
		get_viewport().set_input_as_handled()
	elif _pressed(event, ["ui_up", "MoveUp"]):
		_select(wrapi(_index - 1, 0, PLANETS.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_launch()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(wrapi(_index + 1, 0, PLANETS.size()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(wrapi(_index - 1, 0, PLANETS.size()))


func _pressed(event: InputEvent, actions: Array) -> bool:
	if event.is_echo() and not event is InputEventKey:
		return false
	for action in actions:
		if InputMap.has_action(action) and event.is_action_pressed(action, true):
			return true
	return false


# ─────────────────────────────────────────────────────────────────────────────
#  Состояние и отображение
# ─────────────────────────────────────────────────────────────────────────────
## Всё, что нужно знать о направлении, в одном словаре.
func _state(i: int) -> Dictionary:
	var id: String = PLANETS[i].id
	var need: int = PLANETS[i].fuel
	var have := 0
	if Global.inventory != null:
		have = Global.inventory.get_total_item_count(FUEL)
	var planet: PlanetData = Global.get_planet(id)
	var manager = Global.scene_manager
	var registry = manager.get("scene_registry") if manager != null else null
	return {
		"offline": registry == null or not registry.has_scene(id),
		"here": Global.current_location == id,
		"need": need,
		"have": have,
		"fuel_ok": have >= need,
		"ratio": planet.get_progress_ratio() if planet != null else 0.0,
		"done": planet.get_completed_count() if planet != null else 0,
		"total": planet.max_explore_value if planet != null else 0,
	}


func _refresh() -> void:
	for i in _rows.size():
		var s := _state(i)
		var row: _Row = _rows[i]
		row.title = Loc.t(PLANETS[i].id).to_upper()
		row.dimmed = s.offline
		if s.offline:
			row.led = TerminalStyle.RED
			row.right_text = "--"
			row.right_color = TerminalStyle.GREY
			row.sub_text = Loc.t("NO SIGNAL")
		else:
			row.led = TerminalStyle.CYAN if s.here else TerminalStyle.GREEN
			row.right_text = "x%d" % s.need
			row.right_color = TerminalStyle.CYAN if s.fuel_ok else TerminalStyle.RED
			row.sub_text = Loc.t("YOU ARE HERE") if s.here else "%s %d%%" % [Loc.t("EXPLORED"), roundi(s.ratio * 100.0)]
		row.queue_redraw()
	_select(_index)


func _select(i: int) -> void:
	_index = clampi(i, 0, PLANETS.size() - 1)
	location_key = PLANETS[_index].id
	var s := _state(_index)
	for k in _rows.size():
		_rows[k].is_selected = (k == _index)
		_rows[k].queue_redraw()

	_viewer.set_planet(PLANETS[_index].icon, PLANETS[_index].tint, s.offline)
	_planet_name.text = Loc.t(PLANETS[_index].id).to_upper()
	_planet_type.text = "%s: %s" % [Loc.t("TYPE"), Loc.t(PLANETS[_index].type)]
	_planet_desc.text = Loc.t(PLANETS[_index].desc)
	_info.text = _info_text(s)

	_launch_button.text = Loc.t("LAUNCH") + (" x%d" % s.need if not s.offline else "")
	_launch_button.disabled = s.offline or s.here or not s.fuel_ok


func _info_text(s: Dictionary) -> String:
	var dim := TerminalStyle.CYAN_DIM.to_html(false)
	var lines: PackedStringArray = []
	if s.offline:
		lines.append("[color=#%s]%s[/color]" % [TerminalStyle.RED.to_html(false), Loc.t("NO SIGNAL")])
		lines.append("")
		lines.append("[color=#%s]%s[/color]" % [dim, Loc.t("Route not charted yet")])
		return "\n".join(lines)

	var filled := roundi(s.ratio * 12.0)
	lines.append("[color=#%s]%s[/color]" % [dim, Loc.t("EXPLORED")])
	lines.append("[color=#%s][lb]%s%s[rb] %d%%[/color]" % [
		TerminalStyle.CYAN.to_html(false), "#".repeat(filled), "-".repeat(12 - filled), roundi(s.ratio * 100.0)])
	lines.append("[color=#%s]%s[/color]  %d/%d" % [dim, Loc.t("ORDERS"), s.done, s.total])
	lines.append("")
	lines.append("[color=#%s]%s[/color]  %d" % [dim, Loc.t("FUEL REQUIRED"), s.need])
	var have_color := TerminalStyle.GREEN if s.fuel_ok else TerminalStyle.RED
	lines.append("[color=#%s]%s[/color]  [color=#%s]%d[/color]" % [dim, Loc.t("FUEL ON BOARD"), have_color.to_html(false), s.have])
	lines.append("")
	if s.here:
		lines.append("[color=#%s]%s[/color]" % [TerminalStyle.CYAN.to_html(false), Loc.t("YOU ARE HERE")])
	elif not s.fuel_ok:
		lines.append("[color=#%s]%s: %d[/color]" % [TerminalStyle.RED.to_html(false), Loc.t("Not enough fuel"), s.need - s.have])
	else:
		lines.append("[color=#%s]%s[/color]" % [TerminalStyle.GREEN.to_html(false), Loc.t("READY FOR JUMP")])
	return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
#  Запуск
# ─────────────────────────────────────────────────────────────────────────────
func _launch() -> void:
	if _launching:
		return
	var s := _state(_index)
	if s.offline:
		GameJuice.banner(Loc.t("NO SIGNAL"), "", TerminalStyle.RED, 1.5)
		return
	if s.here:
		GameJuice.banner(Loc.t("YOU ARE HERE"), "", TerminalStyle.AMBER, 1.5)
		return
	if not s.fuel_ok:
		GameJuice.banner(Loc.t("Not enough fuel"), "× %d" % s.need, Color(1.0, 0.5, 0.4), 1.5)
		return

	_launching = true
	_launch_button.disabled = true
	Global.inventory.remove_from_total(FUEL, s.need)
	Global.save()

	_overlay.text = Loc.t("ENGAGING HYPERDRIVE...")
	_overlay.visible = true
	var tw := create_tween().set_loops(int(LAUNCH_DELAY / 0.2))
	tw.tween_property(_overlay, "modulate:a", 0.3, 0.1)
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(LAUNCH_DELAY).timeout

	var target: String = PLANETS[_index].id
	_overlay.visible = false
	_launching = false
	_set_open(false)
	Global.scene_manager.change_scene(target, Vector2.ZERO)


# Обработчики из старой сцены (сигналы подключены в planer_chooser.tscn) — оставлены, чтобы не было ошибок.
func _on_option_button_item_selected(index: int) -> void:
	_select(index)

func _on_button_pressed() -> void:
	_launch()

func _on_button_2_pressed() -> void:
	toogle()


# ═════════════════════════════════════════════════════════════════════════════
#  Виджеты консоли
# ═════════════════════════════════════════════════════════════════════════════

## Экран: тёмная панель с бирюзовой рамкой и развёрсткой. Содержимое — в content.
class _Screen extends PanelContainer:
	var content := VBoxContainer.new()

	func _init(h: float, edge: Color) -> void:
		add_theme_stylebox_override("panel", TerminalStyle.screen_style(h, edge))
		content.add_theme_constant_override("separation", int(h * 0.012))
		add_child(content)
		add_child(TerminalStyle.Scan.new())  # последним: поверх содержимого

	## «Включение монитора»: линия раскрывается в экран со вспышкой.
	func boot(delay: float) -> void:
		pivot_offset = size * 0.5
		scale = Vector2(1.0, 0.04)
		modulate = Color(2.0, 2.0, 2.0, 0.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale:y", 1.0, 0.22).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate", Color.WHITE, 0.3).set_delay(delay)


## Строка списка направлений. Рисуется вручную: пиксельный вид и никаких лишних рамок.
class _Row extends Control:
	signal selected
	signal activated

	var title := ""
	var sub_text := ""
	var right_text := ""
	var right_color := TerminalStyle.CYAN
	var led := TerminalStyle.GREEN
	var dimmed := false
	var is_selected := false

	var _hover := false
	var _h := 360.0

	func _init(h: float) -> void:
		_h = h
		custom_minimum_size = Vector2(0.0, h * 0.095)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	func _set_hover(value: bool) -> void:
		_hover = value
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			selected.emit()
			if mb.double_click:
				activated.emit()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if is_selected:
			draw_rect(rect, Color(TerminalStyle.CYAN, 0.16))
			draw_rect(Rect2(0.0, 0.0, maxf(2.0, _h * 0.006), size.y), TerminalStyle.CYAN)
		elif _hover:
			draw_rect(rect, Color(TerminalStyle.CYAN, 0.07))
		draw_line(Vector2(0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(TerminalStyle.CYAN_DIM, 0.35))

		var font := get_theme_default_font()
		var fs := maxi(6, roundi(_h * 0.034))
		var fs_small := maxi(5, roundi(_h * 0.026))
		var pad := _h * 0.025
		draw_circle(Vector2(pad * 1.6, size.y * 0.5), maxf(2.0, _h * 0.009), led)
		var text_x := pad * 3.2
		draw_string(font, Vector2(text_x, size.y * 0.46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				TerminalStyle.GREY if dimmed else TerminalStyle.TEXT)
		draw_string(font, Vector2(text_x, size.y * 0.84), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_small,
				TerminalStyle.CYAN_DIM)
		draw_string(font, Vector2(0.0, size.y * 0.56), right_text, HORIZONTAL_ALIGNMENT_RIGHT,
				size.x - pad, fs, right_color)


## Витрина планеты: настоящая картинка из атласа на «голографической» подставке.
## Спрайт рисуется целым масштабом (×3, ×4...), поэтому пиксели остаются чёткими,
## а планеты разного размера выглядят примерно одинаково крупно.
class _Viewer extends Control:
	var _tint := Color.WHITE
	var _offline := false
	var _icon := Rect2i(0, 0, 32, 32)

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func set_planet(icon: Rect2i, tint: Color, offline: bool) -> void:
		_icon = icon
		_tint = TerminalStyle.GREY if offline else tint
		_offline = offline
		queue_redraw()

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var c := size * 0.5 - Vector2(0.0, size.y * 0.03)
		var target := minf(size.x, size.y) * 0.7
		var k := maxi(1, int(target / maxf(_icon.size.x, _icon.size.y)))
		var dst_size := Vector2(_icon.size * k)
		var r := dst_size.x * 0.5
		var line_w := maxf(1.0, r * 0.015)

		var flicker := 1.0
		if _offline:
			flicker = 0.4 + 0.3 * absf(sin(t * 17.0))  # нет сигнала — картинка мерцает

		# Проектор и конус света под планетой
		var base_y := c.y + r * 1.25
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - r * 0.35, base_y), Vector2(c.x + r * 0.35, base_y),
			Vector2(c.x + r * 1.0, c.y + r * 0.7), Vector2(c.x - r * 1.0, c.y + r * 0.7)]),
			Color(_tint, 0.08))
		draw_rect(Rect2(c.x - r * 0.5, base_y, r, r * 0.09), TerminalStyle.STEEL)
		draw_rect(Rect2(c.x - r * 0.3, base_y + r * 0.09, r * 0.6, r * 0.05), TerminalStyle.METAL_DARK)

		# Свечение за планетой
		for i in 4:
			draw_circle(c, r * (1.5 - i * 0.12), Color(_tint, 0.035 * flicker))

		# Орбита с «спутником»: наклонный эллипс, который медленно вращается
		var orbit_pts := PackedVector2Array()
		for i in 49:
			var a := i * TAU / 48.0
			orbit_pts.append(c + Vector2(cos(a) * r * 1.38, sin(a) * r * 0.42))
		draw_polyline(orbit_pts, Color(_tint, 0.3 * flicker), line_w)
		var sa := t * 0.7
		var moon := c + Vector2(cos(sa) * r * 1.38, sin(sa) * r * 0.42)
		draw_circle(moon, maxf(2.0, r * 0.07), Color(TerminalStyle.TEXT, 0.9 * flicker))

		# Сама планета (лёгкое «парение» целыми пикселями — чтобы не мылить пиксель-арт)
		var bob := roundf(sin(t * 1.6) * maxf(1.0, r * 0.03))
		var origin := (c - dst_size * 0.5 + Vector2(0.0, bob)).round()
		var tint := Color.WHITE if not _offline else Color(0.45, 0.5, 0.55)
		draw_texture_rect_region(ATLAS, Rect2(origin, dst_size), Rect2(_icon), Color(tint, flicker))

		# Часть орбиты и спутник «перед» планетой
		if sin(sa) > 0.0:
			draw_circle(moon, maxf(2.0, r * 0.07), Color(TerminalStyle.TEXT, 0.95 * flicker))

		# Бегущая линия скана по планете
		var dy := -r + fmod(t * 0.4, 1.0) * 2.0 * r
		var half_w := sqrt(maxf(0.0, r * r - dy * dy))
		draw_line(Vector2(c.x - half_w, c.y + dy + bob), Vector2(c.x + half_w, c.y + dy + bob),
				Color(TerminalStyle.CYAN, 0.5 * flicker), line_w * 1.5)

		# Рамка-«уголки» видоискателя
		var m := r * 1.7
		var arm := r * 0.28
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := c + Vector2(sx * m, sy * m * 0.8)
				corner.x = clampf(corner.x, line_w * 3.0, size.x - line_w * 3.0)
				corner.y = clampf(corner.y, line_w * 3.0, size.y - line_w * 3.0)
				draw_line(corner, corner + Vector2(-sx * arm, 0), Color(TerminalStyle.CYAN, 0.55), line_w)
				draw_line(corner, corner + Vector2(0, -sy * arm), Color(TerminalStyle.CYAN, 0.55), line_w)


## Светодиод на корпусе (мигает).
class _Led extends Control:
	func _init(h: float) -> void:
		custom_minimum_size = Vector2(h * 0.03, h * 0.03)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var on := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.8
		var col := TerminalStyle.RED if on else TerminalStyle.RED.darkened(0.7)
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.4, col)


## Винты по углам корпуса и пара индикаторов — чтобы консоль выглядела железом, а не плашкой.
class _Bolts extends Control:
	var _h := 360.0

	func _init(h: float) -> void:
		_h = h
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var inset := _h * 0.016
		var r := maxf(2.0, _h * 0.007)
		for corner in [Vector2(inset, inset), Vector2(size.x - inset, inset),
				Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)]:
			draw_circle(corner, r, TerminalStyle.METAL_DARK)
			draw_arc(corner, r, 0.0, TAU, 12, TerminalStyle.STEEL, 1.0)
			draw_line(corner + Vector2(-r, 0) * 0.6, corner + Vector2(r, 0) * 0.6, TerminalStyle.STEEL, 1.0)
