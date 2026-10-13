extends Node

@onready var developer_console: devconsole = %DeveloperConsole
@onready var scene_manager: SceneManager    = $SceneManager
@onready var day_night: DayNightCycle = $DayNight
@onready var BGM: AudioStreamPlayer         = $AudioStreamPlayer
@onready var setting_manager: SettingManager = $SettingManager

# ─────────────────────────────────────────────────────────────────────────────
#  Session Data
# ─────────────────────────────────────────────────────────────────────────────

var player_name: String = "Default"
var player_skin_index: int = 0
var player_skin_head_index: int = 0
var game_difficult: int = 0
var current_save_slot: String = ""
## Меняется при смене локации; имя планеты совпадает с PlanetData.Planet_Name
signal location_changed(location: String)
## Прогресс планет загружен из слота
signal planets_loaded

var current_location: String = "Land":
	set(value):
		if current_location == value:
			return
		current_location = value
		location_changed.emit(value)

@export var planets_data : Array[PlanetData]


##Player last info
var last_location: String
var last_position: Vector2
var pending_exit_walk: Dictionary = {
	"active": false, "direction": Vector2.ZERO, "duration": 0.5, "speed_mult": 0.7
}


# ─────────────────────────────────────────────────────────────────────────────
#  UI / сервисы
# ─────────────────────────────────────────────────────────────────────────────

var is_opened_menu: bool = false
var hotbar
var inventory: Inventory
var music_key
var night_key

const MOUSE_Arrow = preload("res://Assets/Textures/UI/Cursors/Cursor1.png")
const HINT = preload("uid://wyeldfaexejh")



func _init() -> void:
	Input.set_custom_mouse_cursor(MOUSE_Arrow, Input.CURSOR_ARROW, Vector2.ZERO)


func _ready() -> void:
	if not Engine.has_singleton("Global"):
		Engine.register_singleton("Global", self)


# ─────────────────────────────────────────────────────────────────────────────
#  Имя персонажа
# ─────────────────────────────────────────────────────────────────────────────
#region
func set_character_name(new_name: String) -> void:
	if new_name.strip_edges().is_empty():
		push_error("[Global] Character name cannot be empty")
		return
	player_name = new_name.strip_edges()

#endregion
# ─────────────────────────────────────────────────────────────────────────────
#  Инвентарь
# ─────────────────────────────────────────────────────────────────────────────
#region inventory
func pickup_item(item_data: ItemData, amount: int = 1) -> void:
	if not hotbar or not inventory:
		push_error("[Global] Hotbar or Inventory not found")
		return

	if _try_add_to_container(hotbar, item_data, amount) \
			or _try_add_to_container(inventory, item_data, amount):
		report_item_picked(item_data, amount)
	else:
		print("[Global] Inventory full — item lost: ", item_data.item_name)


func _try_add_to_container(container, item_data: ItemData, amount: int) -> bool:
	if not container or not container.has_method("add_item"):
		return false
	return container.add_item(item_data, amount)


func add_initial_items() -> void:
	pickup_item(preload("uid://r4sg8e1stb8y").duplicate(), 1)
	pickup_item(preload("uid://bmkdrb4efmfp8").duplicate(), 1)
	pickup_item(preload("uid://dieok7r238rrp").duplicate(),1)
	pickup_item(preload("uid://dwmw15dg8pwvd").duplicate(),45)

#endregion

# ─────────────────────────────────────────────────────────────────────────────
#  Сохранение / удаление
# ─────────────────────────────────────────────────────────────────────────────
#region save/delete
func save() -> void:
	get_tree().call_group("Save", "save_game")
	save_planets_data()


## Сохраняет прогресс планет в текущий слот.
func save_planets_data() -> void:
	SaveLoad.save_planets(planets_data)


## Загружает прогресс планет из текущего слота.
## Совпадение по Planet_Name. Если сохранения нет — прогресс сбрасывается.
func load_planets_data() -> void:
	var saved: Array = SaveLoad.load_planets()

	# Сначала сбрасываем всё, чтобы прогресс не «перетекал» между слотами
	for planet in planets_data:
		planet.reset()

	for entry in saved:
		if not entry is Dictionary:
			continue
		var planet := get_planet(entry.get("planet_name", ""))
		if planet == null:
			push_warning("[Global] Planet from save not found in planets_data: %s" % entry.get("planet_name", ""))
			continue
		planet.apply_dict(entry)

	planets_loaded.emit()


## Возвращает PlanetData по имени планеты (или null).
func get_planet(planet_name: String) -> PlanetData:
	for planet in planets_data:
		if planet.Planet_Name == planet_name:
			return planet
	return null


## Предмет подобран — засчитываем во всех планетах, где он есть в заданиях.
## Вызывается автоматически из pickup_item().
func report_item_picked(item: ItemData, amount: int = 1) -> void:
	for planet in planets_data:
		planet.report_item_picked(item, amount)


## Предмет доставлен в базу. Вызывай из объекта базы после списания предмета:
## Global.report_item_delivered("Vehana", medkit_data, "base_alpha")
func report_item_delivered(planet_name: String, item: ItemData, destination_id: String, amount: int = 1) -> void:
	var planet := get_planet(planet_name)
	if planet:
		planet.report_item_delivered(item, destination_id, amount)


## Событие по ID (союз с расой, помощь жителям). Пример:
## Global.report_planet_event("Morva", QuestData.Kind.ALLIANCE, "race_x")
func report_planet_event(planet_name: String, kind: QuestData.Kind, target_id: String = "", amount: int = 1) -> void:
	var planet := get_planet(planet_name)
	if planet:
		planet.report_event(kind, target_id, amount)


func save_last_data() -> void:
	last_location = current_location
	last_position = get_tree().get_first_node_in_group("Player").global_position


func delete_game_data() -> void:
	SaveLoad.delete_all_saves()
#endregion

# ─────────────────────────────────────────────────────────────────────────────
#  UI-утилиты
# ─────────────────────────────────────────────────────────────────────────────
#region UI
func hint(object: Node2D, message: String) -> void:
	var hint_instant = HINT.instantiate()
	hint_instant.text     = message
	hint_instant.position = object.global_position + Vector2(0, -10)
	object.call_deferred("add_child", hint_instant)

func CraftMenu() -> void:
	inventory.call_craft()

func Trade(Trader : TraderData):
	inventory.call_trade(Trader)
#endregion
# ─────────────────────────────────────────────────────────────────────────────
#  Музыка
# ─────────────────────────────────────────────────────────────────────────────
#region Music
func _switch_bgm(clip_name: StringName) -> void:
	if not BGM.playing:
		BGM.play()
	var playback := BGM.get_stream_playback() as AudioStreamPlaybackInteractive
	if playback:
		playback.switch_to_clip_by_name(clip_name)


func _on_scene_manager_scene_change_finished(scene_key: String) -> void:
	music_key = scene_key
	var stream := BGM.get_stream() as AudioStreamInteractive
	if not stream:
		return
	if night_key:
		_switch_bgm(&"Night")
	else:
		match scene_key:
			"Main Menu":  _switch_bgm(&"Main Menu")
			"Land":       _switch_bgm(&"Land "      + str(randi_range(1, 4)))
			"Forest":     _switch_bgm(&"Forest")
			"Village":    _switch_bgm(&"Village "   + str(randi_range(1, 2)))
			"Cave":       _switch_bgm(&"Cave "      + str(randi_range(1, 2)))
			"Deep Cave":  _switch_bgm(&"Deep Cave " + str(randi_range(1, 2)))
			"Thundra":    _switch_bgm(&"Thundra 1")
			"Desert":     _switch_bgm(&"Desert 1")
			"Corrupted":  _switch_bgm(&"Corrupted " + str(randi_range(1, 2)))
			"Beach":      _switch_bgm(&"Beach "     + str(randi_range(1, 2)))
			"Lullaby":    _switch_bgm(&"Lullaby "   + str(randi_range(1, 2)))
			"World":      _switch_bgm(&"World")
			"Night":      _switch_bgm(&"Night")


func play_game_over() -> void:
	_switch_bgm(&"Game Over " + str(randi_range(1, 3)))


func _on_day_night_phase_changed(is_night: bool) -> void:
	night_key = is_night
	if is_night:
		_on_scene_manager_scene_change_finished("Night")
	else:
		_on_scene_manager_scene_change_finished(music_key)

#endregion
