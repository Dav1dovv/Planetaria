extends CanvasLayer
class_name QuestTerminal
## Окно заданий в виде корабельного терминала. Сцена: misc/UI/QuestTerminal/quest_terminal.tscn
##
## Как работает для игрока:
##  * зашёл на планету — терминал сам выезжает на несколько секунд с ближайшими целями и прячется;
##  * зажал клавишу ShowQuests (Tab) — виден полный список, отпустил — пропал;
##  * быстрый тап — список закрепляется, ещё тап — убирается;
##  * квест продвинулся (3/10 → 4/10) — терминал на пару секунд показывает, что изменилось;
##  * пока открыты инвентарь, пауза или другое окно — молчит.
##
## ЧТО ГДЕ МЕНЯТЬ (без кода):
##  * положение/размер окна — узел Panel (инструмент «Выделение» в 2D-вкладке или якоря в инспекторе);
##  * шрифт, цвета, рамка — Theme (common/Themes/terminal_theme.tres) или Theme Overrides узлов;
##  * тексты — узлы Title / Footer и ключи ниже; клавиша — действие ShowQuests в Input Map;
##  * тайминги и цвета строк — группы настроек ниже (в инспекторе корневого узла).

enum Mode { HIDDEN, BRIEFING, FULL }

@export_group("Ввод")
## Действие из Input Map. Если его нет, создаётся само (Tab / кнопка Back на геймпаде).
@export var action: StringName = &"ShowQuests"
## Нажатие короче этого (сек) считается «тапом» — закрепить/открепить окно.
@export_range(0.05, 1.0, 0.01) var tap_time: float = 0.25

@export_group("Тайминги")
## Сколько секунд висит подсказка при входе на планету.
@export_range(1.0, 20.0, 0.5) var briefing_time: float = 6.0
## Сколько секунд висит подсказка, когда продвинулся квест.
@export_range(1.0, 10.0, 0.5) var flash_time: float = 3.5
## Сколько целей показывать в кратком режиме.
@export_range(1, 8) var briefing_lines: int = 3
## Сигналы прогресса сразу после загрузки слота не показываем (мс).
@export var quiet_after_load_ms: int = 1200

@export_group("Вид")
## Бледная подсказка «[TAB] 4/9» в углу, когда терминал спрятан.
@export var show_idle_chip: bool = true
## Сколько клеток в шкале прогресса планеты.
@export_range(4, 30) var bar_cells: int = 12

@export_group("Тексты (ключи перевода)")
@export var title_key: String = "QUEST TERMINAL"
@export var title_prefix: String = "> "
@export var footer_full_key: String = "%s: hold - show, tap - pin"
@export var footer_brief_key: String = "%s - all orders"
@export var all_done_key: String = "ALL ORDERS COMPLETE"
@export var more_key: String = "more"
@export var base_group_key: String = "Базовые"
@export var unique_group_key: String = "Особые"

@export_group("Цвета строк")
@export var color_planet: Color = Color("ffc857")
@export var color_bar: Color = Color("45e6e6")
@export var color_group: Color = Color("1f7f86")
@export var color_next: Color = Color("45e6e6")
@export var color_next_text: Color = Color.WHITE
@export var color_done: Color = Color("6fe08a").darkened(0.25)
@export var color_all_done: Color = Color("6fe08a")
@export var color_changed: Color = Color("ffc857")

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _cursor: Label = %Cursor
@onready var _body: RichTextLabel = %Body
@onready var _footer: Label = %Footer
@onready var _chip: Label = %Chip

var _planet: PlanetData
var _mode: Mode = Mode.HIDDEN
var _pinned: bool = false
var _peeking: bool = false
var _press_time: float = 0.0
var _brief_left: float = 0.0
var _highlight: QuestData
var _quiet_until_ms: int = 0
var _blink: float = 0.0
var _refresh_queued: bool = false
var _tween: Tween


func _enter_tree() -> void:
	_ensure_action()


func _ready() -> void:
	_panel.visible = false
	_chip.visible = false
	Global.location_changed.connect(_on_location_changed)
	Global.planets_loaded.connect(_on_planets_loaded)
	_on_location_changed(Global.current_location)


## Клавишу можно переназначить в Project Settings → Input Map; если действия нет, создаём его.
func _ensure_action() -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	InputMap.action_add_event(action, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(action, pad)


# ─────────────────────────────────────────────────────────────────────────────
#  Планета и задания
# ─────────────────────────────────────────────────────────────────────────────
func _on_location_changed(location: String) -> void:
	_track(Global.get_planet(location))
	_brief_left = briefing_time if _planet != null else 0.0
	_pinned = false
	_highlight = null


func _on_planets_loaded() -> void:
	_track(Global.get_planet(Global.current_location))


func _track(planet: PlanetData) -> void:
	if _planet != null:
		for quest in _planet.get_all_quests():
			if quest.progress_changed.is_connected(_on_quest_progress):
				quest.progress_changed.disconnect(_on_quest_progress)
	_planet = planet if (planet != null and planet.max_explore_value > 0) else null
	if _planet != null:
		for quest in _planet.get_all_quests():
			quest.progress_changed.connect(_on_quest_progress)
	_quiet_until_ms = Time.get_ticks_msec() + quiet_after_load_ms
	_queue_refresh()


func _on_quest_progress(quest: QuestData) -> void:
	_queue_refresh()
	if Time.get_ticks_msec() < _quiet_until_ms or quest.progress <= 0:
		return  # загрузка слота / сброс — это не действие игрока
	_highlight = quest
	_brief_left = maxf(_brief_left, flash_time)


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if _mode != Mode.HIDDEN:
		_rebuild()
	_update_chip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_queue_refresh()


# ─────────────────────────────────────────────────────────────────────────────
#  Каждый кадр: ввод, таймеры, режим
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_blink += delta
	_cursor.visible = fmod(_blink, 1.0) < 0.6

	var blocked: bool = Global.is_opened_menu or get_tree().paused
	_chip.visible = show_idle_chip and _planet != null and _mode == Mode.HIDDEN and not blocked
	if blocked:
		_peeking = false
		_apply_mode(Mode.HIDDEN)
		return

	_poll_input(delta)
	if _brief_left > 0.0:
		_brief_left -= delta

	var target := Mode.HIDDEN
	if _planet != null:
		if _peeking or _pinned:
			target = Mode.FULL
		elif _brief_left > 0.0:
			target = Mode.BRIEFING
	_apply_mode(target)


## Зажатие = «посмотреть», быстрый тап = «закрепить / открепить».
func _poll_input(delta: float) -> void:
	if Input.is_action_just_pressed(action):
		_peeking = true
		_press_time = 0.0
	if _peeking:
		_press_time += delta
	if Input.is_action_just_released(action) and _peeking:
		_peeking = false
		if _press_time < tap_time:
			_pinned = not _pinned


func _apply_mode(target: Mode) -> void:
	if target == _mode:
		return
	var previous := _mode
	_mode = target
	if _mode == Mode.HIDDEN:
		_highlight = null
		_animate_out()
		return
	_rebuild()
	if previous == Mode.HIDDEN:
		_animate_in()


# ─────────────────────────────────────────────────────────────────────────────
#  Текст терминала
# ─────────────────────────────────────────────────────────────────────────────
func _rebuild() -> void:
	if _planet == null:
		return
	_title.text = title_prefix + Loc.t(title_key)
	_body.text = _compose_body(_mode == Mode.FULL)
	_footer.text = (Loc.t(footer_full_key) if _mode == Mode.FULL else Loc.t(footer_brief_key)) % _key_name()


func _col(c: Color) -> String:
	return "#" + c.to_html(false)


func _compose_body(full: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=%s]%s[/color]  [color=%s]%s[/color]" % [
		_col(color_planet), Loc.t(_planet.Planet_Name).to_upper(),
		_col(color_bar), _bar(_planet.get_progress_ratio())])
	lines.append("")

	var next := _next_quest()
	if full:
		_group(lines, Loc.t(base_group_key), _planet.base_quests, next)
		_group(lines, Loc.t(unique_group_key), _planet.unique_quests, next)
		return "\n".join(lines)

	var open: Array[QuestData] = []
	for quest in _planet.get_all_quests():
		if not quest.is_completed():
			open.append(quest)
	if open.is_empty():
		lines.append("[color=%s]%s[/color]" % [_col(color_all_done), Loc.t(all_done_key)])
		return "\n".join(lines)
	for i in mini(open.size(), briefing_lines):
		lines.append(_quest_line(open[i], open[i] == next))
	if open.size() > briefing_lines:
		lines.append("[color=%s]+%d %s[/color]" % [_col(color_group), open.size() - briefing_lines, Loc.t(more_key)])
	return "\n".join(lines)


func _group(lines: PackedStringArray, title: String, quests: Array[QuestData], next: QuestData) -> void:
	if quests.is_empty():
		return
	lines.append("[color=%s]// %s[/color]" % [_col(color_group), title.to_upper()])
	for quest in quests:
		lines.append(_quest_line(quest, quest == next))


func _quest_line(quest: QuestData, is_next: bool) -> String:
	var title := (Loc.t(quest.title) if not quest.title.is_empty() else String(quest.quest_id)).replace("[", "[lb]")
	var tail := ""
	if quest.target_amount > 1:
		tail += "  " + quest.get_progress_text()
	if quest.kind == QuestData.Kind.DELIVER_ITEM and not quest.destination_id.is_empty():
		tail += "  -> " + quest.destination_id.replace("[", "[lb]")

	if quest.is_completed():
		return "[color=%s][lb]X[rb] [s]%s[/s][/color]" % [_col(color_done), title]
	if quest == _highlight:
		return "[color=%s][lb]>[rb] %s%s[/color]" % [_col(color_changed), title, tail]
	if is_next:
		return "[color=%s][lb]>[rb][/color] [color=%s]%s%s[/color]" % [_col(color_next), _col(color_next_text), title, tail]
	return "[lb] [rb] %s%s" % [title, tail]


func _next_quest() -> QuestData:
	for group in [_planet.base_quests, _planet.unique_quests]:
		for quest in group:
			if not quest.is_completed():
				return quest
	return null


func _bar(ratio: float) -> String:
	var filled := roundi(clampf(ratio, 0.0, 1.0) * bar_cells)
	return "[lb]%s%s[rb] %d%%" % ["#".repeat(filled), "-".repeat(bar_cells - filled), roundi(ratio * 100.0)]


func _update_chip() -> void:
	if _planet == null:
		return
	_chip.text = "[%s] %d/%d" % [_key_name(), _planet.get_completed_count(), _planet.max_explore_value]


func _key_name() -> String:
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		var code: Key = key_event.keycode
		if code == KEY_NONE:
			code = key_event.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code).to_upper()
	return "TAB"


# ─────────────────────────────────────────────────────────────────────────────
#  Анимация «включения экрана»
# ─────────────────────────────────────────────────────────────────────────────
func _animate_in() -> void:
	if _tween:
		_tween.kill()
	_panel.visible = true
	_panel.pivot_offset = Vector2(_panel.get_combined_minimum_size().x, 0.0)
	_panel.scale = Vector2(1.0, 0.1)
	_panel.modulate = Color(1.6, 1.6, 1.6, 0.0)
	_body.visible_ratio = 0.0
	var typing := clampf(_body.get_total_character_count() * 0.004, 0.15, 0.5)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.22)
	_tween.tween_property(_body, "visible_ratio", 1.0, typing).set_delay(0.12)


func _animate_out() -> void:
	if _tween:
		_tween.kill()
	_panel.pivot_offset = Vector2(_panel.size.x, 0.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.18)
	_tween.tween_property(_panel, "scale:y", 0.1, 0.18).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		if _mode == Mode.HIDDEN:
			_panel.visible = false)
