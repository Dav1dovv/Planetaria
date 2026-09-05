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

# ── Модификаторы от эффектов (баффы/дебаффы) ──────────────────────────────
# Каждый активный эффект добавляет своё значение (в долях, напр. 0.2 = +20%)
# в отдельный список, а не в одну переменную — так несколько источников
# (два разных баффа, экипировка + зелье) не затирают друг друга и снимаются
# независимо, даже если совпадают по величине.
var _speed_modifiers: Array[float] = []
var _damage_modifiers: Array[float] = []
var _defense_modifiers: Array[float] = []

# Инициализация
func _init():
	reset_to_base_values()

# Сброс к базовым значениям
func reset_to_base_values() -> void:
	_speed_modifiers.clear()
	_damage_modifiers.clear()
	_defense_modifiers.clear()
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

# Множитель исходящего урона (учитывать там, где считается урон оружия/атаки)
func get_damage_multiplier() -> float:
	return 1.0 + damage_modifier


# ── Скорость ───────────────────────────────────────────────────────────────
## percent — доля от base_move_speed, напр. 0.3 = +30% скорости, -0.4 = -40%
func add_speed_modifier(percent: float) -> void:
	_speed_modifiers.append(percent)
	_recalculate_speed()

## ВАЖНО: снимать тем же значением, которым баф был наложен (Effect.value) —
## EffectManager делает это автоматически.
func remove_speed_modifier(percent: float) -> void:
	_speed_modifiers.erase(percent)
	_recalculate_speed()

func _recalculate_speed() -> void:
	var bonus := 0.0
	for m in _speed_modifiers:
		bonus += m
	move_speed = base_move_speed * maxf(0.0, 1.0 + bonus)


# ── Урон ───────────────────────────────────────────────────────────────────
func add_damage_modifier(percent: float) -> void:
	_damage_modifiers.append(percent)
	_recalculate_damage()

func remove_damage_modifier(percent: float) -> void:
	_damage_modifiers.erase(percent)
	_recalculate_damage()

func _recalculate_damage() -> void:
	var bonus := base_damage_modifier
	for m in _damage_modifiers:
		bonus += m
	damage_modifier = bonus


# ── Защита ─────────────────────────────────────────────────────────────────
func add_defense_modifier(percent: float) -> void:
	_defense_modifiers.append(percent)
	_recalculate_defense()

func remove_defense_modifier(percent: float) -> void:
	_defense_modifiers.erase(percent)
	_recalculate_defense()

func _recalculate_defense() -> void:
	var bonus := base_defense_modifier
	for m in _defense_modifiers:
		bonus += m
	defense_modifier = bonus
