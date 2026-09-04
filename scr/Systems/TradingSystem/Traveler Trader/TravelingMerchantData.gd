# TravelingMerchantData.gd
# Странствующий торговец: ассортимент собирается случайно из ВСЕХ предметов
# в папке res://scr/Resources/Items/, разбитых по ценовым категориям
# (PriceTierRule, на основе ItemData.price). Каждый вызов generate_stock()
# даёт новый случайный набор товаров и цен — торговец непредсказуем.
class_name TravelingMerchantData
extends TraderData

## Папка с предметами (как в Inventory._load_all_items)
@export var items_folder: String = "res://misc/Content/Items/"

## Ценовые категории. Например: "Дешёвые" 1-5, "Средние" 6-30, "Редкие" 31+
@export var tiers: Array[PriceTierRule] = []

## Не предлагать определённые предметы по имени (опционально).
## Если пусто — берутся все ItemData из папки.
@export var exclude_item_names: Array[String] = []

## Предмет-валюта (GoldSlot.gold_item) — автоматически исключается из ассортимента,
## чтобы торговец не продавал золото как обычный товар. Необязательно, но удобно.
@export var gold_item: ItemData

## Сгенерировать новый случайный ассортимент в items (перезаписывает старый).
func generate_stock() -> void:
	items.clear()

	var all_items := _load_all_items()
	if all_items.is_empty():
		return

	for tier in tiers:
		# Берём предметы, попадающие в диапазон базовой цены этой категории
		var candidates: Array[ItemData] = []
		for it in all_items:
			if it.price >= tier.base_price_min and it.price <= tier.base_price_max:
				if exclude_item_names.has(it.item_name):
					continue
				if gold_item and it.item_name == gold_item.item_name:
					continue
				candidates.append(it)

		if candidates.is_empty():
			continue

		candidates.shuffle()

		var count: int = min(tier.pick_count, candidates.size())
		for i in range(count):
			var src_item := candidates[i]
			var entry := TradeItemEntry.new()
			entry.item = src_item

			var mult: float = randf_range(tier.price_mult_min, tier.price_mult_max)
			entry.price = max(1, int(round(src_item.price * mult)))

			entry.stock = randi_range(tier.stock_min, tier.stock_max)
			items.append(entry)

# ─────────────────────────────────────────────────────────────────
#  Сканирование папки предметов
# ─────────────────────────────────────────────────────────────────
func _load_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	var dir := DirAccess.open(items_folder)
	if not dir:
		push_warning("TravelingMerchantData: не удалось открыть %s" % items_folder)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var res: Resource = load(items_folder.path_join(file_name))
			if res is ItemData:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result
