extends Resource
class_name QuestData

## Одно задание планеты. Настраивается целиком в инспекторе.
## Прогресс (progress) — рантайм-состояние, в .tres не сохраняется.

signal progress_changed(quest: QuestData)
signal completed(quest: QuestData)

## Тип задания — по нему игровой код сообщает о событиях (см. PlanetData.report_event).
enum Kind {
	COLLECT_ARTIFACTS, ## Найти артефакты планеты (базовое)
	COLLECT_DNA,       ## Собрать ДНК существ (базовое)
	COLLECT_RESOURCE,  ## Собрать уникальный ресурс
	ALLIANCE,          ## Найти расу и заключить союз
	DELIVER_ITEM,      ## Доставить предмет в базу
	HELP_LOCALS,       ## Помочь жителям (например, от террора)
	KILL_ENEMY,        ## Убить моба (target_id = ID моба, X = сколько убить)
}

@export var quest_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.COLLECT_ARTIFACTS
## Сколько нужно набрать (для заданий «сделать один раз» оставь 1)
@export_range(1, 999) var target_amount: int = 1
## Предметы, которые засчитываются (артефакты / ДНК / ресурс / предмет доставки).
## Сравнение идёт по item_name, так что дубликаты (.duplicate()) тоже подходят.
@export var target_items: Array[ItemData] = []
## ID расы или события (для ALLIANCE и HELP_LOCALS)
@export var target_id: String = ""
## ID базы назначения (только для DELIVER_ITEM)
@export var destination_id: String = ""

var progress: int = 0


## Входит ли предмет в список засчитываемых.
func has_item(item: ItemData) -> bool:
	if item == null:
		return false
	for target in target_items:
		if target and target.item_name == item.item_name:
			return true
	return false

func is_completed() -> bool:
	return progress >= target_amount

## Добавляет прогресс. Возвращает true, если задание только что выполнено.
func add_progress(amount: int = 1) -> bool:
	if is_completed() or amount <= 0:
		return false
	progress = mini(progress + amount, target_amount)
	progress_changed.emit(self)
	if is_completed():
		completed.emit(self)
		return true
	return false

## Текст счётчика для UI: "3/10"
func get_progress_text() -> String:
	return "%d/%d" % [progress, target_amount]

func reset() -> void:
	progress = 0
	progress_changed.emit(self)

func to_dict() -> Dictionary:
	return {"progress": progress}

func apply_dict(data: Dictionary) -> void:
	# JSON отдаёт числа как float — приводим к int
	progress = clampi(int(data.get("progress", 0)), 0, target_amount)
	progress_changed.emit(self)
