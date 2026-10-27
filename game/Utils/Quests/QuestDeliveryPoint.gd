extends interaction_area
class_name QuestDeliveryPoint

## Точка доставки для заданий DELIVER_ITEM — в том числе «Дефицит»: ресурс с другой
## планеты нужен здесь. Игрок взаимодействует (ПКМ, как с любым объектом) — предметы
## из инвентаря уходят в задание, прогресс растёт.
##
## КАК НАСТРОИТЬ (в редакторе, без кода):
##  1. Узел с этим скриптом + дочерний CollisionShape2D (как у SceneChanger).
##  2. destination_id — тот же, что в задании (поле Destination Id у QuestData).
##  3. Текст подсказки при наведении — поле Show Message (оно унаследовано).
##
## «Дефицит» собирается из тех же частей, что и обычная доставка: в задании
## target_items = ресурс ДРУГОЙ планеты, а точка доставки стоит на этой.
## Это возвращает игрока на пройденные планеты (минимум, но больше).

## Пусто = текущая планета
@export var planet_name: String = ""
@export var destination_id: String = ""


func _ready() -> void:
	super._ready()
	interact = Callable(self, "_deliver")


func _deliver() -> void:
	var planet := Global.get_planet(planet_name if not planet_name.is_empty() else Global.current_location)
	var inventory = Global.inventory
	if planet == null or inventory == null:
		return

	var delivered := 0
	for quest in planet.get_all_quests():
		if quest.kind != QuestData.Kind.DELIVER_ITEM or quest.is_completed() \
				or quest.destination_id != destination_id:
			continue
		for item in quest.target_items:
			if item == null:
				continue
			# Сдаём ровно столько, сколько нужно заданию, а не весь стак
			var amount := mini(inventory.get_total_item_count(item), quest.target_amount - quest.progress)
			if amount <= 0:
				continue
			if inventory.remove_from_total(item, amount):
				Global.report_item_delivered(planet.Planet_Name, item, destination_id, amount)
				delivered += amount
				GameJuice.floating_text(global_position + Vector2(0.0, -16.0),
						"-%d %s" % [amount, Loc.t(item.item_name)], Color(1.0, 0.85, 0.3), 1.0, 0.9, 18.0, 1.4)

	if delivered <= 0:
		Global.hint(get_parent(), Loc.t("Nothing to deliver"))
