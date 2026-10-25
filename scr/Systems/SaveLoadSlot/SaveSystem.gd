extends Node
class_name SaveLoadSystem

#   user://Saves/{slot}/save_data.json      — мета-данные слота (имя, скин, налёт, даты) — из них рисуется пропуск
#   user://Saves/{slot}/player_data.char    — здоровье, экипировка
#   user://Saves/{slot}/worldsave/world_seeds.json
#   user://Saves/{slot}/worldsave/harvested.json
#   user://Saves/{slot}/worldsave/planets.json

## Находит живой экземпляр системы сохранений по классу, не завися от имени автозагрузки.
## Ищет среди детей root, затем среди детей Global. null, если не нашёл.
static var _instance: SaveLoadSystem = null
static func find_instance(tree: SceneTree) -> SaveLoadSystem:
	if is_instance_valid(_instance):
		return _instance
	for n in tree.root.get_children():
		if n is SaveLoadSystem:
			_instance = n
			return _instance
		for c in n.get_children():
			if c is SaveLoadSystem:
				_instance = c
				return _instance
	push_warning("[SaveSystem] экземпляр SaveLoadSystem не найден в дереве")
	return null


# ─────────────────────────────────────────────────────────────────────────────
#  Константы путей
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_DIR        := "user://Saves/"
const SLOT_META_FILE  := "save_data.json"
const PLAYER_FILE     := "player_data.char"
const SEEDS_FILE      := "worldsave/world_seeds.json"
const HARVESTED_FILE  := "worldsave/harvested.json"
const PLANETS_FILE    := "worldsave/planets.json"
const ACHIEVEMENTS_FILE := "achievements.json"

# Общий для всех слотов профиль (одноразовые флаги: обучение пройдено и т.п.)
const PROFILE_PATH := "user://profile.json"

# Расстояние «склейки» добытых позиций (0 = точное совпадение)
const HARVEST_SNAP: float = 0.0

# Налёт (время в игре) считаем как «накопленное в слоте + текущая сессия».
var _session_started_ms: int = -1
var _session_base_playtime: int = 0

var _profile: Dictionary = {}
var _profile_loaded: bool = false


# ─────────────────────────────────────────────────────────────────────────────
#  Вспомогательные пути  (все пути строим только здесь)
# ─────────────────────────────────────────────────────────────────────────────

## Возвращает папку слота: "user://Saves/PlayerName/"
func slot_dir(slot: String) -> String:
	return SAVE_DIR + slot + "/"

func _meta_path(slot: String)      -> String: return slot_dir(slot) + SLOT_META_FILE
func _player_path(slot: String)    -> String: return slot_dir(slot) + PLAYER_FILE
func _seeds_path(slot: String)     -> String: return slot_dir(slot) + SEEDS_FILE
func _harvested_path(slot: String) -> String: return slot_dir(slot) + HARVESTED_FILE
func _planets_path(slot: String)   -> String: return slot_dir(slot) + PLANETS_FILE

## Безопасное имя папки: убираем пробелы и слэши
func _safe_name(name: String) -> String:
	return name.replace(" ", "_").replace("/", "").replace("\\", "")


# ─────────────────────────────────────────────────────────────────────────────
#  Инициализация
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_dir(SAVE_DIR)


# ─────────────────────────────────────────────────────────────────────────────
#  Работа со слотами
# ─────────────────────────────────────────────────────────────────────────────

## Возвращает список имён всех слотов (папок в SAVE_DIR).
func get_save_slots() -> Array:
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return []
	var slots: Array = []
	for folder in dir.get_directories():
		slots.append(folder)
	return slots

## Загружает мета-данные слота (имя игрока, скины, дата).
## Возвращает словарь или пустой Dictionary при ошибке.
func load_slot_meta(slot: String) -> Dictionary:
	return _read_json(_meta_path(slot))

## Обновляет мета-данные текущего слота при каждом сохранении:
## время последнего входа, налёт, скин (−1 = оставить как было) и цвета
## (update_colors = true: записать colors, null = вернуть оригинальные).
## Читаем-меняем-пишем, поэтому лишние поля (в том числе от будущих версий) не теряются.
func touch_slot_meta(skin_index: int = -1, head_index: int = -1, colors: SkinColors = null, update_colors: bool = false) -> void:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		return
	var meta := load_slot_meta(slot)
	if meta.is_empty():
		return

	# Слот открыт без load_save (например, сцена игры запущена из редактора): начинаем счёт сейчас
	if _session_started_ms < 0:
		_session_started_ms    = Time.get_ticks_msec()
		_session_base_playtime = int(meta.get("playtime_sec", 0))

	var now := int(Time.get_unix_time_from_system())
	meta["last_save_time"] = now
	meta["playtime_sec"]   = _session_base_playtime + int((Time.get_ticks_msec() - _session_started_ms) / 1000.0)
	if not meta.has("created_time"):
		meta["created_time"] = now  # старые слоты, созданные до появления пропусков
	if skin_index >= 0:
		meta["skin_index"] = skin_index
	if head_index >= 0:
		meta["head_index"] = head_index
	if update_colors:
		if colors != null:
			meta["colors"] = colors.to_dict()
		else:
			meta.erase("colors")
	_write_json(_meta_path(slot), meta)

## Создаёт новый слот. Если такое имя уже занято — добавляет _1, _2 …
## Возвращает имя созданного слота или "" при ошибке.
func create_new_save(player_name: String, location: String, skin_index: int = 0, head_index: int = 0, colors: SkinColors = null) -> String:
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		push_error("[SaveSystem] Cannot open SAVE_DIR")
		return ""

	var base   := _safe_name(player_name)
	var folder := base
	var n      := 1
	while dir.dir_exists(folder):
		folder = "%s_%d" % [base, n]
		n += 1

	_ensure_dir(SAVE_DIR + folder)
	_ensure_dir(SAVE_DIR + folder + "/worldsave")

	var now := int(Time.get_unix_time_from_system())
	var meta := {
		"player_name":   player_name,
		"location":      location,
		"created_time":  now,
		"last_save_time": now,
		"playtime_sec":  0,
		"skin_index":    skin_index,
		"head_index":    head_index,
	}
	if colors != null:
		meta["colors"] = colors.to_dict()
	if not _write_json(_meta_path(folder), meta):
		push_error("[SaveSystem] Failed to write meta for slot: %s" % folder)
		return ""

	return folder

## Загружает слот в Global (имя, скины, счётчик налёта) и запоминает текущий слот.
## Возвращает true при успехе.
func load_save(slot: String) -> bool:
	var data := load_slot_meta(slot)
	if data.is_empty():
		return false

	Global.player_name              = data.get("player_name", "Player")
	Global.player_skin_index        = int(data.get("skin_index", 0))
	Global.player_skin_head_index   = int(data.get("head_index", 0))
	SkinColors.current              = SkinColors.from_dict(data.get("colors"))  # null = оригинальные цвета
	Global.current_save_slot        = slot
	_session_started_ms             = Time.get_ticks_msec()
	_session_base_playtime          = int(data.get("playtime_sec", 0))
	Global.load_planets_data()
	return true

## Удаляет папку слота рекурсивно.
func delete_save(slot: String) -> void:
	_delete_dir_recursive(SAVE_DIR + slot)


# ─────────────────────────────────────────────────────────────────────────────
#  Данные игрока (здоровье, экипировка)
# ─────────────────────────────────────────────────────────────────────────────

## Сохраняет состояние узла Player в player_data.char.
func save_player(player: Node) -> bool:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		push_error("[SaveSystem] current_save_slot is empty — cannot save player")
		return false

	var data = {
		"stats": {
			"hp":         player.Entity_stats.current_health,
			"max_hp":     player.Entity_stats.max_health,
			"Corruption" : player.corruption,
			"hunger_data" : player.hunger,
		},
		"equipment": {
			"equipped_item": player.get_node("GUI/HUD/Inventory/HotBar").selected_index,
		},
		"timestamp": Time.get_datetime_string_from_system(),
	}
	if not _write_json(_player_path(slot), data):
		return false
	# Актуализируем «пропуск»: время входа, налёт и внешний вид (PlayerSkin – источник правды)
	var skin := player.get_node_or_null("Skin") as PlayerSkin
	touch_slot_meta(
		skin.skin_index if skin != null else -1,
		skin.head_inex  if skin != null else -1,
		skin.colors if skin != null else null,
		skin != null
	)
	return true

## Загружает состояние игрока из player_data.char.
func load_player(player: Node) -> bool:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		push_warning("[SaveSystem] current_save_slot is empty — skipping load_player")
		return false

	var data := _read_json(_player_path(slot))
	if data.is_empty():
		push_warning("[SaveSystem] No player save found for slot: %s" % slot)
		return false

	if data.has("stats"):
		var s: Dictionary = data["stats"]
		player.Entity_stats.current_health = s.get("hp",     player.Entity_stats.max_health)
		player.Entity_stats.max_health     = s.get("max_hp", player.Entity_stats.max_health)
		player.corruption                  = s.get("Corruption", player.corruption)
		player.hunger                      = s.get("hunger_data",100)

	if data.has("equipment"):
		var e: Dictionary = data["equipment"]
		player.get_node("GUI/HUD/Inventory/HotBar").selected_index = e.get("equipped_item", 0)

	return true


# ─────────────────────────────────────────────────────────────────────────────
#  Мировые сиды (world seeds)
# ─────────────────────────────────────────────────────────────────────────────

## Сохраняет словарь сидов мира.
func save_world_seeds(master_seed: int, world_seed: String, location_seeds: Dictionary) -> bool:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		push_error("[SaveSystem] current_save_slot is empty — cannot save seeds")
		return false

	var data := {
		"master_seed":     master_seed,
		"world_seed":      world_seed,
		"location_seeds":  location_seeds,
		"player_name":     Global.player_name,
		"version":         "1.0",
	}
	return _write_json(_seeds_path(slot), data)

## Загружает сохранённые сиды мира.
## Возвращает словарь с ключами "master_seed", "world_seed", "location_seeds"
## или пустой словарь если файла нет.
func load_world_seeds() -> Dictionary:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		return {}
	return _read_json(_seeds_path(slot))


# ─────────────────────────────────────────────────────────────────────────────
#  Добытые ресурсы (harvested)
# ─────────────────────────────────────────────────────────────────────────────

## Сохраняет словарь добытых позиций: { "location_id": [{x,y}, …] }
func save_harvested(harvested_positions: Dictionary) -> bool:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		push_error("[SaveSystem] current_save_slot is empty — cannot save harvested")
		return false
	return _write_json(_harvested_path(slot), harvested_positions)

## Загружает словарь добытых позиций.
func load_harvested() -> Dictionary:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		return {}
	return _read_json(_harvested_path(slot))


# ─────────────────────────────────────────────────────────────────────────────
#  Планеты (PlanetData)
# ─────────────────────────────────────────────────────────────────────────────

## Сохраняет прогресс всех планет в planets.json.
func save_planets(planets: Array) -> bool:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		push_error("[SaveSystem] current_save_slot is empty — cannot save planets")
		return false

	var list: Array = []
	for planet in planets:
		if planet is PlanetData:
			list.append(planet.to_dict())

	var data := {
		"planets": list,
		"version": "2.0",
	}
	return _write_json(_planets_path(slot), data)

## Загружает список сохранённых планет (массив словарей PlanetData.to_dict()).
## Возвращает пустой массив, если файла нет или он повреждён.
func load_planets() -> Array:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		return []
	var data := _read_json(_planets_path(slot))
	return data.get("planets", [])


# ─────────────────────────────────────────────────────────────────────────────
#  Полное удаление всех сохранений (отладка / "новая игра")
# ─────────────────────────────────────────────────────────────────────────────

func delete_all_saves() -> void:
	_delete_dir_recursive(SAVE_DIR)
	_ensure_dir(SAVE_DIR)
	print("[SaveSystem] All save data deleted")


# ─────────────────────────────────────────────────────────────────────────────
#  Приватные утилиты — JSON и файловая система
# ─────────────────────────────────────────────────────────────────────────────

func _write_json(path: String, data: Dictionary) -> bool:
	_ensure_dir(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveSystem] Cannot write: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] Cannot read: %s" % path)
		return {}
	var json := JSON.new()
	var err   := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("[SaveSystem] JSON parse error in: %s" % path)
		return {}
	var result = json.get_data()
	if result is Dictionary:
		return result
	return {}

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := path + "/" + name
			if dir.current_is_dir():
				_delete_dir_recursive(full)
			else:
				dir.remove(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


# ─────────────────────────────────────────────────────────────────────────────
#  Профиль (общий для всех слотов)
# ─────────────────────────────────────────────────────────────────────────────

func _load_profile() -> void:
	if _profile_loaded:
		return
	_profile = _read_json(PROFILE_PATH)
	_profile_loaded = true

## Значение из общего профиля. Числа из JSON приходят как float — приводите через int().
func get_profile_value(key: String, default: Variant = null) -> Variant:
	_load_profile()
	return _profile.get(key, default)

## Записывает значение в профиль (на диск только если оно изменилось).
func set_profile_value(key: String, value: Variant) -> void:
	_load_profile()
	if _profile.has(key) and _profile[key] == value:
		return
	_profile[key] = value
	_write_json(PROFILE_PATH, _profile)

## Сбрасывает профиль целиком (отладка / «новая игра»): обучение покажется снова.
func reset_profile() -> void:
	_profile = {}
	_profile_loaded = true
	_write_json(PROFILE_PATH, _profile)


# ─────────────────────────────────────────────────────────────────────────────
#  Достижения (по слотам)
# ─────────────────────────────────────────────────────────────────────────────

func _achievements_path(slot: String) -> String:
	return slot_dir(slot) + ACHIEVEMENTS_FILE

## Сохраняет прогресс достижений слота (пустой slot = текущий).
## Не пишет в удалённый слот, чтобы отложенное сохранение не воскресило папку.
func save_achievements(data: Dictionary, slot: String = "") -> bool:
	if slot.is_empty():
		slot = Global.current_save_slot
	if slot.is_empty() or not DirAccess.dir_exists_absolute(slot_dir(slot)):
		return false
	return _write_json(_achievements_path(slot), data)

## Загружает прогресс достижений слота. Пустой Dictionary, если файла нет.
func load_achievements(slot: String = "") -> Dictionary:
	if slot.is_empty():
		slot = Global.current_save_slot
	if slot.is_empty():
		return {}
	return _read_json(_achievements_path(slot))


# ─────────────────────────────────────────────────────────────────────────────
#  Инвентарь
# ─────────────────────────────────────────────────────────────────────────────

const INVENTORY_FILE := "inventory.save"

func _inventory_path(slot: String) -> String:
	return slot_dir(slot) + INVENTORY_FILE

## Сохраняет словарь данных инвентаря (собирается в InventorySaver).
func save_inventory(data: Dictionary) -> bool:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		push_error("[SaveSystem] current_save_slot is empty — cannot save inventory")
		return false
	return _write_json(_inventory_path(slot), data)

## Загружает словарь данных инвентаря.
## Возвращает пустой Dictionary если файла нет или произошла ошибка.
func load_inventory() -> Dictionary:
	var slot: String = Global.current_save_slot
	if slot.is_empty():
		return {}
	return _read_json(_inventory_path(slot))
