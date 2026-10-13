extends Resource
class_name PlanetData

@export_enum("Vehana","Morva","Rodus","Anelim") var Planet_Name : String = "Vehana"

## Базовые задания (есть у всех планет, меняется только количество): артефакты, ДНК и т.п.
@export var base_quests: Array[QuestData] = []
## Уникальные задания именно этой планеты: ресурс, союз с расой, доставка, помощь жителям
@export var unique_quests: Array[QuestData] = []

## Сколько заданий выполнено / всего — считаются автоматически
var explored_value: int:
	get: return get_completed_count()
var max_explore_value: int:
	get: return get_all_quests().size()


# ─────────────────────────────────────────────────────────────────────────────
#  Доступ к заданиям
# ─────────────────────────────────────────────────────────────────────────────

func get_all_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	result.append_array(base_quests)
	result.append_array(unique_quests)
	return result

func get_quest(quest_id: StringName) -> QuestData:
	for quest in get_all_quests():
		if quest.quest_id == quest_id:
			return quest
	return null

func get_completed_count() -> int:
	var count := 0
	for quest in get_all_quests():
		if quest.is_completed():
			count += 1
	return count

## Доля исследованности планеты: 0.0 … 1.0
func get_explore_ratio() -> float:
	var total := max_explore_value
	return 0.0 if total == 0 else float(get_completed_count()) / total


## Плавный прогресс исследования 0.0 … 1.0: учитывает и частично выполненные задания
## (например, 3/10 артефактов дают 0.3 вклада этого задания).
func get_progress_ratio() -> float:
	var quests := get_all_quests()
	if quests.is_empty():
		return 0.0
	var sum := 0.0
	for quest in quests:
		sum += float(quest.progress) / quest.target_amount
	return sum / quests.size()


# ─────────────────────────────────────────────────────────────────────────────
#  Прогресс
# ─────────────────────────────────────────────────────────────────────────────

## Добавляет прогресс конкретному заданию по его ID.
func add_progress(quest_id: StringName, amount: int = 1) -> bool:
	var quest := get_quest(quest_id)
	if quest == null:
		push_warning("[PlanetData] %s: quest not found: %s" % [Planet_Name, quest_id])
		return false
	return quest.add_progress(amount)

## Мгновенно выполняет задание (союз заключён, жители спасены и т.п.).
func complete_quest(quest_id: StringName) -> bool:
	var quest := get_quest(quest_id)
	if quest == null:
		push_warning("[PlanetData] %s: quest not found: %s" % [Planet_Name, quest_id])
		return false
	return quest.add_progress(quest.target_amount - quest.progress)

## Предмет подобран: прогресс получают задания COLLECT_ARTIFACTS / COLLECT_DNA /
## COLLECT_RESOURCE, у которых этот предмет есть в target_items.
func report_item_picked(item: ItemData, amount: int = 1) -> void:
	for quest in get_all_quests():
		if quest.is_completed():
			continue
		match quest.kind:
			QuestData.Kind.COLLECT_ARTIFACTS, QuestData.Kind.COLLECT_DNA, QuestData.Kind.COLLECT_RESOURCE:
				if quest.has_item(item):
					quest.add_progress(amount)

## Предмет доставлен в базу: прогресс получают задания DELIVER_ITEM
## с этим предметом и совпадающим destination_id.
func report_item_delivered(item: ItemData, destination_id: String, amount: int = 1) -> void:
	for quest in get_all_quests():
		if quest.kind == QuestData.Kind.DELIVER_ITEM and not quest.is_completed() \
				and quest.destination_id == destination_id and quest.has_item(item):
			quest.add_progress(amount)

## Событие по ID (союз с расой, помощь жителям): задание подходит,
## если его kind совпадает, а target_id пустой или такой же.
func report_event(kind: QuestData.Kind, target_id: String = "", amount: int = 1) -> void:
	for quest in get_all_quests():
		if quest.kind != kind or quest.is_completed():
			continue
		if quest.target_id.is_empty() or quest.target_id == target_id:
			quest.add_progress(amount)

## Сбрасывает прогресс планеты (новая игра / слот без сохранения).
func reset() -> void:
	for quest in get_all_quests():
		quest.reset()


# ─────────────────────────────────────────────────────────────────────────────
#  Сохранение / загрузка
# ─────────────────────────────────────────────────────────────────────────────

## Состояние планеты в виде словаря (пригодно для JSON).
## Сохраняем только прогресс, ключ — quest_id. Сами задания живут в инспекторе.
func to_dict() -> Dictionary:
	var quests_data := {}
	for quest in get_all_quests():
		quests_data[String(quest.quest_id)] = quest.to_dict()
	return {
		"planet_name": Planet_Name,
		"quests":      quests_data,
	}

## Применяет сохранённый прогресс. Задания, которых больше нет, игнорируются;
## новые задания (добавленные после сохранения) остаются с нулевым прогрессом.
func apply_dict(data: Dictionary) -> void:
	var saved: Dictionary = data.get("quests", {})
	for quest in get_all_quests():
		var key := String(quest.quest_id)
		if saved.has(key) and saved[key] is Dictionary:
			quest.apply_dict(saved[key])
