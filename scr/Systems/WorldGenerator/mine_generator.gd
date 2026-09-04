extends Node
class_name RoomGenerator


@export var can_save: bool = false
## Название файла сохранения для этого данжа (например "dungeon_1", "cave_2")
@export var map_name: String = "dungeon_1"

@export_category("Rooms")
@export var start_rooms: Array[PackedScene]
@export var simple_rooms: Array[PackedScene]
@export var unique_rooms: Array[PackedScene]
@export var boss_room: PackedScene

@export_category("Layout")
## Расстояние между центрами комнат
@export var cell_size: Vector2 = Vector2(2000, 2000)
## Шанс (0.0–1.0) что simple-комната станет unique
@export var unique_chance: float = 0.25

const EMPTY_ID  = 0
const START_ID  = 1
const SIMPLE_ID = 2
const UNIQUE_ID = 3
const BOSS_ID   = 4

const GRID_SIZE = 3  # сетка 3x3

# Плоский массив типов комнат (индекс = row * GRID_SIZE + col)
var room: Array = []

# Ссылки на заспавненные узлы (та же индексация)
var room_nodes: Array = []


func _ready() -> void:
	_generate_layout()
	_spawn_rooms()
	if can_save:
		_save_map()
	print("Room layout: ", room)


# ─────────────────────────────────────────────
#  1. ГЕНЕРАЦИЯ СХЕМЫ
# ─────────────────────────────────────────────
func _generate_layout() -> void:
	room.resize(GRID_SIZE * GRID_SIZE)
	room.fill(EMPTY_ID)

	var center_pos: int = (GRID_SIZE * GRID_SIZE) / 2  # индекс 4 — центр

	# Стартовая комната — только верхний ряд (row 0: индексы 0, 1, 2)
	var start_candidates: Array = range(GRID_SIZE).filter(
		func(p): return p != center_pos
	)
	var start_pos: int = start_candidates.pick_random()
	room[start_pos] = START_ID

	# Босс — всегда в центре
	room[center_pos] = BOSS_ID

	# Остальные клетки — simple или unique
	for i in range(room.size()):
		if room[i] == EMPTY_ID:
			if unique_rooms.size() > 0 and randf() < unique_chance:
				room[i] = UNIQUE_ID
			else:
				room[i] = SIMPLE_ID


# ─────────────────────────────────────────────
#  2. СПАВН КОМНАТ
# ─────────────────────────────────────────────
func _spawn_rooms() -> void:
	room_nodes.resize(GRID_SIZE * GRID_SIZE)
	room_nodes.fill(null)

	for idx in range(room.size()):
		var scene: PackedScene = _scene_for(idx)
		if scene == null:
			continue

		var instance = scene.instantiate()
		add_child(instance)

		var col: int = idx % GRID_SIZE
		var row: int = idx / GRID_SIZE
		instance.position = Vector2(col * cell_size.x, row * cell_size.y)

		room_nodes[idx] = instance


func _scene_for(idx: int) -> PackedScene:
	match room[idx]:
		START_ID:
			return start_rooms.pick_random() if start_rooms.size() > 0 else null  # ← исправлено
		SIMPLE_ID:
			return simple_rooms.pick_random() if simple_rooms.size() > 0 else null
		UNIQUE_ID:
			return unique_rooms.pick_random() if unique_rooms.size() > 0 else null
		BOSS_ID:
			return boss_room
	return null

# ─────────────────────────────────────────────
#  3. СОХРАНЕНИЕ КАРТЫ
# ─────────────────────────────────────────────
func _save_map() -> void:
	var data: Dictionary = {
		"room": room,
		"grid_size": GRID_SIZE,
	}
	var save_dir: String = "user://Saves/" + Global.player_name
	var save_path: String = save_dir + "/" + map_name + ".json"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("Map saved to ", save_path)
