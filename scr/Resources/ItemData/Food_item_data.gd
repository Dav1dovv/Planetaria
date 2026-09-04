@icon("res://common/icons/helpcon1.png")
extends ItemData
class_name FoodData

@export_category("Food Data")
@export var eat_sound: AudioStream
## Массив настраиваемых эффектов
@export var effects: Array[Effect] = []
## Восстановление голода (если у вас есть система голода)  
@export var health_restore: float = 20.0  
@export var remove_corription : int = 0
## Свойство "очищение" (GDD 3.3 "Заражение") — снимает столько % заражения игрока.
## Отдельно от remove_corription (тот снимает проклятие/curse, другая система).
@export var cure_infection : float = 0.0

# Переопределение для еды: улучшаем hunger_restore и эффекты
func apply_quality_multiplier(q: int) -> void:
	super.apply_quality_multiplier(q)  # Базовый
	health_restore *= (1.0 + q * 0.3)  # Rare: +30%, Epic: +60%
	for effect in effects:
		if effect.has_method("scale_value"):  # Предполагаем, что Effect имеет scale_value(value_mult: float)
			effect.scale_value(1.0 + q * 0.3)  # Улучшаем эффекты (e.g., heal больше)
		else:
			effect.value *= (1.0 + q * 0.3)  # Если нет метода, напрямую
	print("Food quality ", q, " applied to ", item_name, ": Health_restore=", health_restore)
