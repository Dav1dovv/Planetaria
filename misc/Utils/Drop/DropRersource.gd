extends Resource
class_name DropResource

## Базовый предмет, который выпадает
@export var drop_item : ItemData
## Шанс того, что этот ресурс вообще выпадет (0.0 — никогда, 1.0 — всегда).
## Проверяется независимо для каждого ресурса в списке Dropper'а.
@export_range(0.0001, 1) var drop_chance : float = 0.5

## --- Настройка количества ---
## Сколько раз подряд "бросить" этот предмет отдельными стаками,
## если шанс drop_chance сработал. Если min == max — фиксированное число.
@export_range(1, 20, 1) var min_throws : int = 1
@export_range(1, 20, 1) var max_throws : int = 1

## Минимальное и максимальное число предметов в стаке за один бросок.
## Если min == max — количество фиксированное, рандом не участвует.
@export_range(1,100,1) var min_count : int = 1
@export_range(1,100,1) var max_count : int = 1

## Возвращает предмет, который реально пойдёт в дроп.
## Базовая реализация просто отдаёт drop_item как есть.
## Дочерние ресурсы (например DropWeaponResource) переопределяют
## этот метод, чтобы вернуть кастомизированную копию.
func get_item() -> ItemData:
	return drop_item

## Сколько отдельных бросков (стаков) этого предмета произойдёт.
func get_throws() -> int:
	if min_throws >= max_throws:
		return min_throws
	return randi_range(min_throws, max_throws)

## Сколько штук этого предмета кладём в один стак/бросок.
## Вся логика количества живёт здесь, Dropper её не трогает.
func get_amount() -> int:
	if min_count >= max_count:
		return min_count
	return randi_range(min_count, max_count)

## Сработал ли шанс выпадения для этого ресурса.
func rolls_drop() -> bool:
	return randf() <= drop_chance
