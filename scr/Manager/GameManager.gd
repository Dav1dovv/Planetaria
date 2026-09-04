extends Node
class_name GameManager

# ═══════════════════════════════════════════════════════════════════════════════
#  GameManager — состояние активного мира (сид, заражение, harvested, спавн)
# ───────────────────────────────────────────────────────────────────────────────
#  Добавляется в каждую игровую сцену (WorlRoot, world_root и т.п.)
#  Состояние заражения берётся из SceneData при загрузке через SceneManager,
#  но может меняться во время игры (добыча заражённых ресурсов и т.д.)
# ═══════════════════════════════════════════════════════════════════════════════

signal world_ready

@export var world_seed: String = ""

## Находимся ли мы в шахте / под землёй
@export var is_underground: bool = false

## Биом / тип локации (для логики мира)
@export_enum("Desert", "Forest", "Thundra","Deep")
var biome: String = "Forest"


var activated_stations: int = 0
var last_saved_position: Array[Vector2]
var player: Node2D


func _ready() -> void:
	world_seed = Global.player_name
	add_to_group("World")
	add_to_group("Save")
	_initialize_seed_system()
	_load_harvested()
	emit_signal("world_ready")
	# Day/night управляется SceneManager через SceneData.is_underground,
	# но на случай если сцена открывается напрямую — применяем локальный флаг
	if Global.day_night:
		Global.day_night.start()
		Global.day_night.visible = not is_underground
	player = find_child("Player")


# ─────────────────────────────────────────────────────────────────────────────
#  Spawn / respawn
# ─────────────────────────────────────────────────────────────────────────────
#region Spawn
func respawn() -> void:
	
	Global.scene_manager.fade()
	player = get_tree().get_first_node_in_group("Player")
	player.respawn()
	Global.save()
	if last_saved_position.is_empty():
		get_tree().reload_current_scene()
		
	else:
		get_tree().call_group("Ennemy", "queue_free")
		Global.scene_manager.fade()
		player.respawn()
		player.position = last_saved_position.front()


func set_spawn_point(save_position: Vector2) -> void:
	last_saved_position.append(save_position)
	print("Player saved at: " + str(save_position))
#endregion


# ─────────────────────────────────────────────────────────────────────────────
#  Настройки мира — вызываются из SceneManager._apply_scene_settings()
# ─────────────────────────────────────────────────────────────────────────────


# ─────────────────────────────────────────────────────────────────────────────
#  Система сидов
# ─────────────────────────────────────────────────────────────────────────────
#region SEED SYSTEM
var master_seed: int = 0
var location_seeds: Dictionary = {}


func _initialize_seed_system() -> void:
	if not world_seed.is_empty():
		master_seed = world_seed.hash()
	else:
		randomize()
		master_seed = randi()
		world_seed  = str(master_seed)

	print("[GameManager] Master seed: %d (from: '%s')" % [master_seed, world_seed])
	_load_location_seeds()


func get_or_create_location_seed(location_id: String) -> int:
	if location_seeds.has(location_id):
		return location_seeds[location_id]
	var new_seed := _generate_location_seed(location_id)
	location_seeds[location_id] = new_seed
	_save_location_seeds()
	return new_seed


func _generate_location_seed(location_id: String) -> int:
	return (str(master_seed) + "_" + location_id).hash()


func set_location_seed(location_id: String, seed_value: int) -> void:
	location_seeds[location_id] = seed_value
	_save_location_seeds()


func get_all_location_seeds() -> Dictionary:
	return location_seeds.duplicate()


func reset_location_seed(location_id: String) -> void:
	if location_seeds.has(location_id):
		location_seeds.erase(location_id)
		_save_location_seeds()


func reset_all_location_seeds() -> void:
	location_seeds.clear()
	_save_location_seeds()


func _save_location_seeds() -> void:
	SaveLoad.save_world_seeds(master_seed, world_seed, location_seeds)


func _load_location_seeds() -> void:
	var data := SaveLoad.load_world_seeds()
	if data.is_empty():
		print("[GameManager] Starting with fresh world seeds")
		return

	if data.has("master_seed") and data["master_seed"] != master_seed:
		push_warning("[GameManager] Master seed mismatch — world may differ")

	if data.has("location_seeds"):
		location_seeds = data["location_seeds"]
		print("[GameManager] Loaded %d location seeds" % location_seeds.size())


func export_world_seed_string() -> String:
	return JSON.stringify({"world_seed": world_seed, "master_seed": master_seed})


func import_world_seed(seed_string: String) -> bool:
	var json := JSON.new()
	if json.parse(seed_string) != OK:
		push_error("[GameManager] Invalid seed string")
		return false
	var data = json.data
	if data.has("world_seed"):
		world_seed  = data["world_seed"]
		master_seed = world_seed.hash() if world_seed is String else data.get("master_seed", 0)
		reset_all_location_seeds()
		return true
	return false
#endregion


# ─────────────────────────────────────────────────────────────────────────────
#  Система добычи ресурсов (harvested)
# ─────────────────────────────────────────────────────────────────────────────
#region Harvested
var harvested_positions: Dictionary = {}


func register_harvested(loc_id: String, pos: Vector2) -> void:

	if not harvested_positions.has(loc_id):
		harvested_positions[loc_id] = []
	harvested_positions[loc_id].append({"x": pos.x, "y": pos.y})
	SaveLoad.save_harvested(harvested_positions)


func is_harvested(loc_id: String, pos: Vector2) -> bool:
	if not harvested_positions.has(loc_id):
		return false
	for entry in harvested_positions[loc_id]:
		if pos.distance_to(Vector2(entry["x"], entry["y"])) <= SaveLoad.HARVEST_SNAP:
			return true
	return false


func _load_harvested() -> void:
	var data := SaveLoad.load_harvested()
	if not data.is_empty():
		harvested_positions = data
		print("[GameManager] Loaded harvested positions for %d locations" % harvested_positions.size())
#endregion


func Die():
	Global.corruption += 10
