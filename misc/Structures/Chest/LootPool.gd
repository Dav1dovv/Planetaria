class_name LootPool
extends Resource

@export var items: Array[ItemData]  # Список предметов (например, WeaponResource)
@export var weights: Array[float]   # Веса для каждого предмета
@export var min_items: int = 1      # Минимальное количество предметов для дропа
@export var max_items: int = 1      # Максимальное количество предметов для дропа

# Проверка валидности пула
func is_valid() -> bool:
	if items.is_empty() or weights.is_empty():
		return false
	if items.size() != weights.size():
		return false
	if min_items < 0 or max_items < min_items:
		return false
	return true

# Получение случайного предмета с учетом весов
func get_random_item() -> Resource:
	if not is_valid():
		return null
	
	var total_weight: float = 0.0
	for weight in weights:
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight: float = 0.0
	
	for i in range(items.size()):
		current_weight += weights[i]
		if random_value <= current_weight:
			return items[i]
	
	# На случай ошибок округления
	return items[items.size() - 1]
