# CreatureConfig.gd
extends Resource
class_name CreatureConfig

@export var creature_scene: PackedScene

@export_range(0.0, 10.0) var spawn_weight: float = 1.0

## Day = только днём, Night = только ночью, Both = всегда
@export_enum("Day", "Night", "Both") var spawn_phase: String = "Both"

@export_group("Conditions")
## Минимальный день для появления (0 = с самого начала)
@export var min_day: int = 0
## Максимальный лимит живых этого вида (0 = без лимита)
@export var max_alive: int = 0
## Только при конкретном событии (NONE = игнорируется)
@export_enum("NONE", "FULL_CELESTE", "FULL_MORVA") var required_event: String = "NONE"

@export_group("Variations")
## Рандомные варианты сцены (выбираются равновероятно вместе с creature_scene)
@export var variations: Array[PackedScene] = []

## Живые существа этого вида (считает спавнер, не трогай руками)
var _alive_count: int = 0


func get_random_scene() -> PackedScene:
	if variations.is_empty():
		return creature_scene
	var all_scenes: Array = [creature_scene] + variations
	return all_scenes[randi() % all_scenes.size()]


func can_spawn(is_night: bool, current_day: int, current_event: String) -> bool:
	# Проверка дня
	if current_day < min_day:
		return false
	# Проверка события
	if required_event != "NONE" and current_event != required_event:
		return false
	# Проверка лимита вида
	if max_alive > 0 and _alive_count >= max_alive:
		return false
	# Проверка фазы
	match spawn_phase:
		"Day":   return not is_night
		"Night": return is_night
		"Both":  return true
	return true
