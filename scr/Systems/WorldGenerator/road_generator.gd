extends Node2D
class_name RoadGeneration

# Экспорт параметров спавна в редакторе
@export var objects_to_spawn : Array[PackedScene]
@export var min_objects : int = 5
@export var max_objects : int = 15
@export var spawn_objects_enabled : bool = true
@export var object_spawn_probabilities : Array[float] = []

# Группа параметров для размеров зоны спавна объектов
@export_group("Spawn Zone Size for Objects")
@export var object_spawn_area_size : Vector2 = Vector2(10, 10)
@export var object_spawn_zone_margin : float = 1.0

# Группа параметров для случайного поворота и масштаба
@export_group("Random Transform Settings")
@export var random_rotation_enabled : bool = true
@export var random_scale_enabled : bool = true
@export var min_scale : float = 0.5
@export var max_scale : float = 1.5

# Параметры уровня мира
@export var world_level : int = 1
@export var level_scale_multiplier : float = 0.2

# Минимальное расстояние между объектами
@export var min_distance_between_objects : float = 1.0

func _ready():
	randomize()
	if spawn_objects_enabled:
		max_objects = randi_range(7,18)
		spawn_objects()


func spawn_objects():
	spawn_generic(objects_to_spawn, object_spawn_probabilities, min_objects, max_objects, object_spawn_area_size, object_spawn_zone_margin)

func spawn_generic(prefabs: Array[PackedScene], probabilities: Array[float], min_count: int, max_count: int, area_size: Vector2, zone_margin: float, is_enemy: bool = false):
	var number_of_objects : int = randi() % (max_count - min_count + 1) + min_count
	var positions : Array[Vector2] = []
	for i in range(number_of_objects):
		var spawn_position : Vector2
		while true:
			var random_x : float = randf_range(-area_size.x / 2 + zone_margin, area_size.x / 2 - zone_margin)
			var random_y : float = randf_range(-area_size.y / 2 + zone_margin, area_size.y / 2 - zone_margin)
			spawn_position = Vector2(random_x, random_y)
			
			var can_spawn = true
			for pos in positions:
				if pos.distance_to(spawn_position) < min_distance_between_objects:
					can_spawn = false
					break

			if can_spawn:
				positions.append(spawn_position)
				break

		var prefab = select_random_prefab(prefabs, probabilities)
		if prefab:
			var new_spawn = prefab.instantiate()
			new_spawn.position = spawn_position
			if is_enemy:
				new_spawn.add_to_group("enemies")
			if random_rotation_enabled:
				new_spawn.rotation = randf_range(0, PI * 2)
			if random_scale_enabled:
				var uniform_scale = randf_range(min_scale, max_scale)
				#if is_enemy:
					#var level_scale = 1.0 + (world_level - 1) * level_scale_multiplier
					##uniform_scale *= level_scale
				new_spawn.scale = Vector2(uniform_scale, uniform_scale)
			add_child(new_spawn)

func select_random_prefab(prefabs: Array[PackedScene], probabilities: Array[float]) -> PackedScene:
	if prefabs.size() != probabilities.size():
		return null

	var total_prob = 0.0
	for prob in probabilities:
		total_prob += prob

	var random_value = randf() * total_prob
	var cumulative_prob = 0.0

	for i in range(prefabs.size()):
		cumulative_prob += probabilities[i]
		if random_value < cumulative_prob:
			return prefabs[i]

	return null
