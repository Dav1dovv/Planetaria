extends Node
class_name SaveLoadSystem

#   user://Saves/{slot}/save_data.json      — мета-данные слота (имя, скин)
#   user://Saves/{slot}/player_data.char    — здоровье, экипировка
#   user://Saves/{slot}/worldsave/world_seeds.json
#   user://Saves/{slot}/worldsave/harvested.json

# ─────────────────────────────────────────────────────────────────────────────
#  Константы путей
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_DIR        := "user://Saves/"
const SLOT_META_FILE  := "save_data.json"
const PLAYER_FILE     := "player_data.char"
const SEEDS_FILE      := "worldsave/world_seeds.json"
const HARVESTED_FILE  := "worldsave/harvested.json"

# Расстояние «склейки» добытых позиций (0 = точное совпадение)
const HARVEST_SNAP: float = 0.0


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

## Создаёт новый слот. Если такое имя уже занято — добавляет _1, _2 …
## Возвращает имя созданного слота или "" при ошибке.
func create_new_save(player_name: String, skin_index: int, head_index: int, location: String) -> String:
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

	var meta := {
		"player_name": player_name,
		"skin_index":  skin_index,
		"head_index":  head_index,
		"location":    location,
	}
	if not _write_json(_meta_path(folder), meta):
		push_error("[SaveSystem] Failed to write meta for slot: %s" % folder)
		return ""

	return folder

## Загружает слот в Global (имя, скины) и запоминает текущий слот.
## Возвращает true при успехе.
func load_save(slot: String) -> bool:
	var data := load_slot_meta(slot)
	if data.is_empty():
		return false

	Global.player_name              = data.get("player_name", "Player")
	#Global.player_skin_index        = data.get("skin_index", 0)
	#Global.player_skin_head_index   = data.get("head_index", 0)
	Global.current_save_slot        = slot
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
			#"head_index": player.get_node("Skin").head_inex,
			#"skin_index": player.get_node("Skin").skin_index,
			"global_corruption" : Global.corruption,
			"hunger_data" : player.hunger,
			"infection" : player.get_infection()
		},
		"equipment": {
			"equipped_item": player.get_node("GUI/HUD/Inventory/HotBar").selected_index,
		},
		"timestamp": Time.get_datetime_string_from_system(),
	}
	return _write_json(_player_path(slot), data)

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
		#Global.player_skin_index           = s.get("skin_index", 0)
		#Global.player_skin_head_index      = s.get("head_index",  0)
		Global.corruption                  = s.get("global_corruption",Global.corruption)
		player.get_node("Skin").update_skin()
		player.hunger                      = s.get("hunger_data",100)
		if player.infection:
			player.infection.infection     = s.get("infection", 0.0)

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
