extends CanvasLayer

var player

@onready var hud: Control = $HUD
@onready var inventory: Inventory = $HUD/Inventory
@onready var death_menu: Control = $DeathMenu
@onready var pause_menu: Control = $PauseMenu

# Панель заданий (справа по центру): список заданий + шкала исследования планеты
@onready var quest_box: HBoxContainer = $QUESTBOX
@onready var quest_label: RichTextLabel = $QUESTBOX/RichTextLabel
@onready var quest_progress: ProgressBar = $QUESTBOX/ProgressBar

const COLOR_DONE := "#6fdc6f"
const COLOR_TITLE := "#ffd966"

var _tracked_planet: PlanetData = null
var _refresh_queued: bool = false


func _ready() -> void:
	quest_label.bbcode_enabled = true
	quest_label.fit_content = true
	quest_label.scroll_active = false
	quest_progress.min_value = 0.0
	quest_progress.max_value = 100.0
	quest_progress.step = 0.1

	hud.visibility_changed.connect(_queue_quest_refresh)
	# Кнопки «инвентарь» и «меню» для сенсорного экрана (на ПК скрыты)
	hud.add_child(TouchHudButtons.new())
	Global.location_changed.connect(_on_location_changed)
	Global.planets_loaded.connect(_on_planets_loaded)
	_on_location_changed(Global.current_location)


#func _on_inventory_visibility_changed() -> void:
	#if inventory.visible:
		#pause_menu.visible = false
	


func call_death():
	death_menu.death()
	hud.visible = false
	pause_menu.visible = false
	pause_menu.anotherMenuOpened = true


# ─────────────────────────────────────────────────────────────────────────────
#  Панель заданий
# ─────────────────────────────────────────────────────────────────────────────

func _on_location_changed(location: String) -> void:
	_set_tracked_planet(Global.get_planet(location))

func _on_planets_loaded() -> void:
	# Ресурсы планет могли измениться (загрузка слота) — переподписываемся
	_set_tracked_planet(Global.get_planet(Global.current_location))

## Начинаем следить за заданиями планеты, где сейчас игрок.
## Если игрок не на планете (null) — панель скрывается.
func _set_tracked_planet(planet: PlanetData) -> void:
	if _tracked_planet:
		for quest in _tracked_planet.get_all_quests():
			if quest.progress_changed.is_connected(_on_quest_changed):
				quest.progress_changed.disconnect(_on_quest_changed)

	_tracked_planet = planet

	if _tracked_planet:
		for quest in _tracked_planet.get_all_quests():
			quest.progress_changed.connect(_on_quest_changed)

	_queue_quest_refresh()

## Язык сменили — перерисовываем панель заданий (она собирается из BBCode-строки)
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _tracked_planet != null:
		_queue_quest_refresh()


func _on_quest_changed(_quest: QuestData) -> void:
	_queue_quest_refresh()

## Обновление откладываем на конец кадра: при загрузке слота сигналов приходит много,
## а перерисовать панель достаточно один раз.
func _queue_quest_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_quest_box.call_deferred()

func _refresh_quest_box() -> void:
	_refresh_queued = false

	if _tracked_planet == null or _tracked_planet.max_explore_value == 0:
		quest_box.visible = false
		return

	var ratio := _tracked_planet.get_progress_ratio()
	var lines: PackedStringArray = []

	# Заголовок: планета и этап исследования
	lines.append("[color=%s][b]%s[/b][/color]  %d%%" % [
		COLOR_TITLE, Loc.t(_tracked_planet.Planet_Name), roundi(ratio * 100.0)])

	_append_quest_group(lines, Loc.t("Базовые"), _tracked_planet.base_quests)
	_append_quest_group(lines, Loc.t("Особые"), _tracked_planet.unique_quests)

	quest_label.text = "[right]%s[/right]" % "\n".join(lines)
	quest_progress.value = ratio * 100.0
	quest_box.visible = hud.visible

func _append_quest_group(lines: PackedStringArray, group_title: String, quests: Array[QuestData]) -> void:
	if quests.is_empty():
		return
	lines.append("[color=gray]%s[/color]" % group_title)
	for quest in quests:
		lines.append(_format_quest_line(quest))

func _format_quest_line(quest: QuestData) -> String:
	var title := Loc.t(quest.title) if not quest.title.is_empty() else String(quest.quest_id)
	title = title.replace("[", "[lb]")

	var text := title
	if quest.target_amount > 1:
		text += "  %s" % quest.get_progress_text()
	# Куда нужно доставить — подсказка по локации
	if quest.kind == QuestData.Kind.DELIVER_ITEM and not quest.destination_id.is_empty():
		text += "  → %s" % quest.destination_id.replace("[", "[lb]")

	if quest.is_completed():
		return "[color=%s][s]%s[/s][/color]" % [COLOR_DONE, text]
	return text
