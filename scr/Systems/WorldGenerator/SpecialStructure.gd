@tool
extends Resource
class_name SpecialStructure

## Ресурс для определения специальных структур (лагери, данжи и т.д.)

enum StructureType {
	CAMP,      # Лагерь
	DUNGEON,   # Данж
	CUSTOM     # Пользовательский тип
}

@export var structure_name: String = "Special Structure"
@export var structure_type: StructureType = StructureType.CAMP
@export var custom_type_name: String = ""  # Для CUSTOM типа

@export_category("Spawning")
@export var generation_item: Generation  # Объект для спавна
@export_range(0, 20) var max_instances: int = 3  # Максимальное количество в мире
@export var min_distance_from_player: float = 400.0  # Минимальная дистанция от игрока
@export var min_distance_between_same_type: float = 800.0  # Минимальная дистанция между структурами одного типа
@export var min_distance_between_any: float = 300.0  # Минимальная дистанция до любых других специальных структур
@export var exclusion_radius: float = 200.0  # Радиус, в котором не будут появляться обычные объекты

@export_category("Priority")
@export_range(0, 100) var spawn_priority: int = 50  # Приоритет спавна (выше = раньше генерируется)
@export_range(0.0, 1.0) var spawn_chance: float = 1.0  # Шанс появления (0.0-1.0)
