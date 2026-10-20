# quest_terminal.gd
## Окно заданий в виде корабельного терминала.
##
## Как это работает для игрока:
##  * Зашёл на планету — терминал сам выезжает на ~6 секунд и показывает ближайшие цели, потом прячется.
##  * Зажал ShowQuests (по умолчанию Tab) — виден полный список, отпустил — пропал.
##  * Быстро нажал (тап) — список закрепляется на экране; ещё тап — убирается.
##  * Продвинулся квест (3/10 → 4/10) — терминал на пару секунд показывает, что именно изменилось.
##  * Пока открыты инвентарь, пауза или другое окно, терминал молчит.
##
## Подключение: в gui.gd (в _ready) две строки:
##     $QUESTBOX.visible = false          # старую панель выключаем
##     add_child(QuestTerminal.new())     # родитель не важен: это отдельный CanvasLayer
## Больше ничего не нужно — терминал сам следит за планетой и заданиями.
class_name QuestTerminal
extends CanvasLayer

const ACTION := &"ShowQuests"           ## действие InputMap (создаётся само, если его нет)
const BRIEFING_TIME := 6.0              ## сколько висит подсказка при входе на планету
const FLASH_TIME := 3.5                 ## сколько висит подсказка при изменении прогресса
const TAP_TIME := 0.25                  ## нажатие короче этого — «тап» (закрепить)
const BRIEFING_LINES := 3               ## сколько целей в кратком режиме
const QUIET_AFTER_LOAD_MS := 1200       ## сигналы прогресса сразу после загрузки слота — не показываем

enum Mode { HIDDEN, BRIEFING, FULL }

## Маленькая бледная подсказка «[TAB] 4/9» в углу, когда терминал спрятан.
@export var show_idle_chip: bool = true

## Размер окна: 1.0 — крупно, 0.7 — компактно (по умолчанию), 0.5 — совсем мелко.
## Меняется в инспекторе или одной строкой: QuestTerminal.new().ui_scale = 0.6
@export_range(0.4, 1.5, 0.05) var ui_scale: float = 0.7

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

var _panel: PanelContainer
var _title: Label
var _cursor: Label
var _body: RichTextLabel
var _footer: Label
var _chip: Label
var _tween: Tween


func _enter_tree() -> void:
	_ensure_action()


func _ready() -> void:
	layer = 2  # поверх HUD (слой 1); окна и пауза выше, а при них терминал и так прячется
	_build()
	Global.location_changed.connect(_on_location_changed)
	Global.planets_loaded.connect(_on_planets_loaded)
	_on_location_changed(Global.current_location)


## Клавишу можно переназначить в Project Settings → Input Map; если действия нет, создаём его.
static func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(ACTION, pad)


# ─────────────────────────────────────────────────────────────────────────────
#  Сборка интерфейса (всё кодом, сцену править не нужно)
# ─────────────────────────────────────────────────────────────────────────────
func _build() -> void:
	var h := get_viewport().get_visible_rect().size.y
	var u := h * ui_scale  # все размеры терминала считаем от u, а положение на экране — от h
	var font_size := maxi(6, roundi(u * 0.032))
	var small_size := maxi(5, roundi(u * 0.026))
	var margin := h * 0.02
	var top := h * 0.17  # ниже иконок валюты в правом верхнем углу

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := TerminalStyle.screen_style(h)
	style.set_content_margin_all(u * 0.02)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -margin
	_panel.offset_right = -margin
	_panel.offset_top = top
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(u * 0.01))
	_panel.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", font_size)
	_title.add_theme_color_override("font_color", TerminalStyle.CYAN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_cursor = Label.new()
	_cursor.text = "_"
	_cursor.add_theme_font_size_override("font_size", font_size)
	_cursor.add_theme_color_override("font_color", TerminalStyle.CYAN)
	header.add_child(_cursor)

	_body = RichTextLabel.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(u * 0.72, 0.0)
	_body.add_theme_font_size_override("normal_font_size", font_size)
	_body.add_theme_color_override("default_color", TerminalStyle.TEXT)
	box.add_child(_body)

	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", small_size)
	_footer.add_theme_color_override("font_color", TerminalStyle.CYAN_DIM)
	box.add_child(_footer)

	_panel.add_child(TerminalStyle.Scan.new())  # последним: лежит поверх текста

	_chip = Label.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.offset_left = -margin
	_chip.offset_right = -margin
	_chip.offset_top = top
	_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_chip.add_theme_font_size_override("font_size", small_size)
	_chip.add_theme_color_override("font_color", Color(TerminalStyle.CYAN, 0.7))
	_chip.add_theme_color_override("font_outline_color", Color.BLACK)
	_chip.add_theme_constant_override("outline_size", 3)
	_chip.visible = false
	add_child(_chip)


# ─────────────────────────────────────────────────────────────────────────────
#  Планета и задания
# ─────────────────────────────────────────────────────────────────────────────
func _on_location_changed(location: String) -> void:
	_track(Global.get_planet(location))
	_brief_left = BRIEFING_TIME if _planet != null else 0.0
	_pinned = false
	_highlight = null


func _on_planets_loaded() -> void:
	# Слот загрузили: ресурсы планет сменились — переподписываемся, но подсказку не мигаем
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
	_quiet_until_ms = Time.get_ticks_msec() + QUIET_AFTER_LOAD_MS
	_queue_refresh()


func _on_quest_progress(quest: QuestData) -> void:
	_queue_refresh()
	if Time.get_ticks_msec() < _quiet_until_ms or quest.progress <= 0:
		return  # загрузка слота / сброс — это не действие игрока
	_highlight = quest
	_brief_left = maxf(_brief_left, FLASH_TIME)


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
		_apply_mode(Mode.HIDDEN)  # окно поверх — терминал уступает место, таймеры стоят
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
	if Input.is_action_just_pressed(ACTION):
		_peeking = true
		_press_time = 0.0
	if _peeking:
		_press_time += delta
	if Input.is_action_just_released(ACTION) and _peeking:
		_peeking = false
		if _press_time < TAP_TIME:
			_pinned = not _pinned


func _apply_mode(target: Mode) -> void:
	if target == _mode:
		return
	var previous := _mode
	_mode = target
	if _mode == Mode.HIDDEN:
		_highlight = null  # подсветка «только что изменилось» живёт, пока терминал виден
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
	_title.text = "> " + Loc.t("QUEST TERMINAL")
	_body.text = _compose_body(_mode == Mode.FULL)
	var key := _key_name()
	_footer.text = (Loc.t("%s: hold - show, tap - pin") if _mode == Mode.FULL
			else Loc.t("%s - all orders")) % key


func _compose_body(full: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#%s]%s[/color]  [color=#%s]%s[/color]" % [
		TerminalStyle.AMBER.to_html(false), Loc.t(_planet.Planet_Name).to_upper(),
		TerminalStyle.CYAN.to_html(false), _bar(_planet.get_progress_ratio())])
	lines.append("")

	var next := _next_quest()
	if full:
		_group(lines, Loc.t("Базовые"), _planet.base_quests, next)
		_group(lines, Loc.t("Особые"), _planet.unique_quests, next)
		return "\n".join(lines)

	# Краткий режим: только то, что делать прямо сейчас
	var open: Array[QuestData] = []
	for quest in _planet.get_all_quests():
		if not quest.is_completed():
			open.append(quest)
	if open.is_empty():
		lines.append("[color=#%s]%s[/color]" % [TerminalStyle.GREEN.to_html(false), Loc.t("ALL ORDERS COMPLETE")])
		return "\n".join(lines)
	for i in mini(open.size(), BRIEFING_LINES):
		lines.append(_quest_line(open[i], open[i] == next))
	if open.size() > BRIEFING_LINES:
		lines.append("[color=#%s]+%d %s[/color]" % [
			TerminalStyle.CYAN_DIM.to_html(false), open.size() - BRIEFING_LINES, Loc.t("more")])
	return "\n".join(lines)


func _group(lines: PackedStringArray, title: String, quests: Array[QuestData], next: QuestData) -> void:
	if quests.is_empty():
		return
	lines.append("[color=#%s]// %s[/color]" % [TerminalStyle.CYAN_DIM.to_html(false), title.to_upper()])
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
		return "[color=#%s][lb]X[rb] [s]%s[/s][/color]" % [TerminalStyle.GREEN.darkened(0.25).to_html(false), title]
	if quest == _highlight:  # только что продвинулся — подсвечиваем янтарным
		return "[color=#%s][lb]>[rb] %s%s[/color]" % [TerminalStyle.AMBER.to_html(false), title, tail]
	if is_next:
		return "[color=#%s][lb]>[rb][/color] [color=#ffffff]%s%s[/color]" % [TerminalStyle.CYAN.to_html(false), title, tail]
	return "[lb] [rb] %s%s" % [title, tail]


## Первая невыполненная цель (сначала базовые, потом особые).
func _next_quest() -> QuestData:
	for group in [_planet.base_quests, _planet.unique_quests]:
		for quest in group:
			if not quest.is_completed():
				return quest
	return null


## Шкала из символов: работает в любом пиксельном шрифте.
func _bar(ratio: float, cells: int = 12) -> String:
	var filled := roundi(clampf(ratio, 0.0, 1.0) * cells)
	return "[lb]%s%s[rb] %d%%" % ["#".repeat(filled), "-".repeat(cells - filled), roundi(ratio * 100.0)]


func _update_chip() -> void:
	if _planet == null:
		return
	_chip.text = "[%s] %d/%d" % [_key_name(), _planet.get_completed_count(), _planet.max_explore_value]


## Имя клавиши из InputMap (с учётом раскладки), чтобы подсказка не врала после переназначения.
func _key_name() -> String:
	for event in InputMap.action_get_events(ACTION):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		var code: Key = key_event.keycode
		if code == KEY_NONE:
			code = key_event.physical_keycode
			# Раскладка: на AZERTY физическая «W» — это «Z». В headless-режиме дисплея нет — берём как есть.
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
