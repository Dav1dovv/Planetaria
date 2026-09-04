extends Resource
class_name stats

# Основные характеристики
@export var max_health: int = 100
var current_health: float

# Скорость
@export var base_move_speed: float = 2.0
var move_speed: float = 2.0

# Защита
@export var base_armor: float = 0.0  # Броня (каждая единица даёт % снижения урона)
var armor: float = 0.0

@export_range(0, 1, 0.01) var base_defense_modifier: float = 0.0
var defense_modifier: float = 0.0

# Урон
var base_damage_modifier: float = 0.0
var damage_modifier: float = 0.0

# Инициализация
func _init():
	reset_to_base_values()

# Сброс к базовым значениям
func reset_to_base_values() -> void:
	move_speed = base_move_speed
	defense_modifier = base_defense_modifier
	damage_modifier = base_damage_modifier
	armor = base_armor

# Сброс характеристик
func reset() -> void:
	current_health = max_health
	reset_to_base_values()

# Расчёт снижения урона от брони
# Формула: Снижение = Броня / (Броня + 100)
# Пример: 50 брони = 33% снижения, 100 брони = 50% снижения
func get_armor_reduction() -> float:
	if armor <= 0:
		return 0.0
	return armor / (armor + 100.0)

# Получить итоговое снижение урона
func get_total_damage_reduction() -> float:
	var armor_reduction = get_armor_reduction()
	var total = armor_reduction + defense_modifier
	return clamp(total, 0.0, 0.9)  # Максимум 90% снижения
