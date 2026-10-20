extends CanvasLayer
## Навигационная консоль: выбор планеты. Сцена: misc/UI/PlanetChooser/planer_chooser.tscn
## Три экрана: слева список направлений, в центре планета и досье, справа данные разведки и топливо.
## Публичный API прежний: is_opened, toogle() — сцена корабля и Show_Child работают как раньше.
##
## Управление: стрелки / колесо / клик — выбор, Enter / A / двойной клик — запуск, Esc / B — закрыть.
##
## ЧТО ГДЕ МЕНЯТЬ (без кода):
##  * добавить / убрать планету — список Planets в инспекторе (каждая планета — файл PlanetInfo .tres);
##  * внешний вид (рамки, шрифты, цвета панелей) — Theme: common/Themes/terminal_theme.tres;
##  * расположение экранов, размеры, надписи — узлы сцены (Screens, ListScreen, ViewScreen, InfoScreen…);
##  * анимация планеты — настройки узла Viewer; эффект экранов — настройки ListScreen/ViewScreen/InfoScreen;
##  * цвета статусов и тайминг запуска — группы настроек ниже.

@export_group("Данные")
## Список направлений. Порядок = порядок в списке на экране.
@export var planets: Array[PlanetInfo] = []
## Сцена строки списка (planet_row.tscn).
@export var row_scene: PackedScene
## Предмет, которым платим за прыжок.
@export var fuel_item: ItemData

@export_group("Запуск")
## Сколько секунд идёт надпись «запуск гипердвигателя» до перехода.
@export_range(0.1, 3.0, 0.1) var launch_delay: float = 0.8

@export_group("Тексты (ключи перевода)")
@export var launch_key: String = "LAUNCH"
@export var no_signal_key: String = "NO SIGNAL"
@export var here_key: String = "YOU ARE HERE"
@export var explored_key: String = "EXPLORED"
@export var orders_key: String = "ORDERS"
@export var fuel_required_key: String = "FUEL REQUIRED"
@export var fuel_on_board_key: String = "FUEL ON BOARD"
@export var ready_key: String = "READY FOR JUMP"
@export var not_enough_fuel_key: String = "Not enough fuel"
@export var type_label_key: String = "TYPE"
@export var engaging_key: String = "ENGAGING HYPERDRIVE..."
@export var not_charted_key: String = "Route not charted yet"

@export_group("Цвета статусов")
@export var color_ready: Color = Color("6fe08a")
@export var color_here: Color = Color("45e6e6")
@export var color_offline: Color = Color("e8454f")
@export var color_unavailable: Color = Color("5d6b73")
@export var color_fuel_ok: Color = Color("45e6e6")
@export var color_fuel_low: Color = Color("e8454f")
@export var color_label: Color = Color("1f7f86")
@export var color_bar: Color = Color("45e6e6")
@export var color_warning: Color = Color("ffc857")

@onready var _rows_box: VBoxContainer = %Rows
@onready var _screens: Array[TerminalScreen] = [%ListScreen, %ViewScreen, %InfoScreen]
@onready var _viewer: PlanetViewer = %Viewer
@onready var _planet_name: Label = %PlanetName
@onready var _planet_type: Label = %PlanetType
@onready var _planet_desc: Label = %PlanetDesc
@onready var _info: RichTextLabel = %Info
@onready var _launch_button: Button = %LaunchButton
@onready var _close_button: Button = %CloseButton
@onready var _overlay: Label = %Overlay

var is_opened: bool = false
var location_key: String = ""   ## оставлено для совместимости со старым кодом

var _index: int = 0
var _launching: bool = false
var _rows: Array[PlanetRow] = []


func _ready() -> void:
	visible = false
	_overlay.visible = false
	for child in _rows_box.get_children():  # убираем строки-заготовки, если они остались в сцене
		child.queue_free()
	for i in planets.size():
		var row: PlanetRow = row_scene.instantiate()
		_rows_box.add_child(row)
		row.selected.connect(_select.bind(i))
		row.activated.connect(_launch)
		_rows.append(row)
	_close_button.pressed.connect(toogle)
	_launch_button.pressed.connect(_launch)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_opened:
		_refresh()


func _c(color: Color) -> String:
	return "#" + color.to_html(false)


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


## Сразу выбираем ближайшую доступную планету, а не ту, на которой игрок и так стоит.
func _default_index() -> int:
	for i in planets.size():
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
	if _launching or planets.is_empty():
		return
	if _pressed(event, ["ui_down", "MoveDown"]):
		_select(wrapi(_index + 1, 0, planets.size()))
		get_viewport().set_input_as_handled()
	elif _pressed(event, ["ui_up", "MoveUp"]):
		_select(wrapi(_index - 1, 0, planets.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_launch()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(wrapi(_index + 1, 0, planets.size()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(wrapi(_index - 1, 0, planets.size()))


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
	var info := planets[i]
	var have := 0
	if Global.inventory != null and fuel_item != null:
		have = Global.inventory.get_total_item_count(fuel_item)
	var planet: PlanetData = Global.get_planet(info.id)
	var manager = Global.scene_manager
	var registry = manager.get("scene_registry") if manager != null else null
	return {
		"offline": registry == null or not registry.has_scene(info.id),
		"here": Global.current_location == info.id,
		"need": info.fuel_cost,
		"have": have,
		"fuel_ok": have >= info.fuel_cost,
		"ratio": planet.get_progress_ratio() if planet != null else 0.0,
		"done": planet.get_completed_count() if planet != null else 0,
		"total": planet.max_explore_value if planet != null else 0,
	}


func _refresh() -> void:
	for i in _rows.size():
		var s := _state(i)
		var row := _rows[i]
		row.title = Loc.t(planets[i].id).to_upper()
		row.dimmed = s.offline
		if s.offline:
			row.led = color_offline
			row.right_text = "--"
			row.right_color = color_unavailable
			row.sub_text = Loc.t(no_signal_key)
		else:
			row.led = color_here if s.here else color_ready
			row.right_text = "x%d" % s.need
			row.right_color = color_fuel_ok if s.fuel_ok else color_fuel_low
			row.sub_text = Loc.t(here_key) if s.here else "%s %d%%" % [Loc.t(explored_key), roundi(s.ratio * 100.0)]
		row.queue_redraw()
	_select(_index)


func _select(i: int) -> void:
	if planets.is_empty():
		return
	_index = clampi(i, 0, planets.size() - 1)
	var info := planets[_index]
	location_key = info.id
	var s := _state(_index)
	for k in _rows.size():
		_rows[k].is_selected = (k == _index)
		_rows[k].queue_redraw()

	_viewer.set_planet(info.icon_region, info.tint, s.offline)
	_planet_name.text = Loc.t(info.id).to_upper()
	_planet_type.text = "%s: %s" % [Loc.t(type_label_key), Loc.t(info.type_key)]
	_planet_desc.text = Loc.t(info.description_key)
	_info.text = _info_text(s)

	_launch_button.text = Loc.t(launch_key) + (" x%d" % s.need if not s.offline else "")
	_launch_button.disabled = s.offline or s.here or not s.fuel_ok


func _info_text(s: Dictionary) -> String:
	var dim := _c(color_label)
	var lines: PackedStringArray = []
	if s.offline:
		lines.append("[color=%s]%s[/color]" % [_c(color_offline), Loc.t(no_signal_key)])
		lines.append("")
		lines.append("[color=%s]%s[/color]" % [dim, Loc.t(not_charted_key)])
		return "\n".join(lines)

	var filled := roundi(s.ratio * 12.0)
	lines.append("[color=%s]%s[/color]" % [dim, Loc.t(explored_key)])
	lines.append("[color=%s][lb]%s%s[rb] %d%%[/color]" % [
		_c(color_bar), "#".repeat(filled), "-".repeat(12 - filled), roundi(s.ratio * 100.0)])
	lines.append("[color=%s]%s[/color]  %d/%d" % [dim, Loc.t(orders_key), s.done, s.total])
	lines.append("")
	lines.append("[color=%s]%s[/color]  %d" % [dim, Loc.t(fuel_required_key), s.need])
	var have_color := color_ready if s.fuel_ok else color_fuel_low
	lines.append("[color=%s]%s[/color]  [color=%s]%d[/color]" % [dim, Loc.t(fuel_on_board_key), _c(have_color), s.have])
	lines.append("")
	if s.here:
		lines.append("[color=%s]%s[/color]" % [_c(color_here), Loc.t(here_key)])
	elif not s.fuel_ok:
		lines.append("[color=%s]%s: %d[/color]" % [_c(color_fuel_low), Loc.t(not_enough_fuel_key), s.need - s.have])
	else:
		lines.append("[color=%s]%s[/color]" % [_c(color_ready), Loc.t(ready_key)])
	return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
#  Запуск
# ─────────────────────────────────────────────────────────────────────────────
func _launch() -> void:
	if _launching or planets.is_empty():
		return
	var s := _state(_index)
	if s.offline:
		GameJuice.banner(Loc.t(no_signal_key), "", color_offline, 1.5)
		return
	if s.here:
		GameJuice.banner(Loc.t(here_key), "", color_warning, 1.5)
		return
	if not s.fuel_ok:
		GameJuice.banner(Loc.t(not_enough_fuel_key), "× %d" % s.need, Color(1.0, 0.5, 0.4), 1.5)
		return

	_launching = true
	_launch_button.disabled = true
	Global.inventory.remove_from_total(fuel_item, s.need)
	Global.save()

	_overlay.text = Loc.t(engaging_key)
	_overlay.visible = true
	var tw := create_tween().set_loops(maxi(1, int(launch_delay / 0.2)))
	tw.tween_property(_overlay, "modulate:a", 0.3, 0.1)
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(launch_delay).timeout

	var target := planets[_index].id
	_overlay.visible = false
	_launching = false
	_set_open(false)
	Global.scene_manager.change_scene(target, Vector2.ZERO)
