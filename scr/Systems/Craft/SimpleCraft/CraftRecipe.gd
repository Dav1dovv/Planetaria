## CraftRecipe.gd
## Рецепт крафта, ремонта или разборки.
## Создаётся как отдельный .tres файл.
## Путь: res://misc/Content/Recipes/Craft/НазваниеРецепта.tres
@tool
@icon("res://common/icons/helpcon2.png")
extends Resource
class_name CraftRecipe

# ─────────────────────────────────────────────────────────────────
#  РЕЖИМ РЕЦЕПТА
# ─────────────────────────────────────────────────────────────────

enum Mode {
	CRAFT,       ## Обычный крафт: ресурсы → предмет
	REPAIR,      ## Ремонт: сломанный предмет + ресурсы → починенный
	DISASSEMBLE, ## Разборка: предмет → ресурсы (возврат материалов)
}

@export var mode: Mode = Mode.CRAFT

# ─────────────────────────────────────────────────────────────────
#  ОСНОВНАЯ ИНФОРМАЦИЯ
# ─────────────────────────────────────────────────────────────────

## Название рецепта (показывается в UI)
@export var recipe_name: String = ""

## Описание (тултип)
@export_multiline var description: String = ""

## Категория для фильтра
@export_enum("Weapons", "Pickaxe", "Food", "Materials", "Acsesories") var category: int = 0

## Индекс "Food" в @export_enum category выше.
## Рецепты с этой категорией автоматически доступны ТОЛЬКО в котле (см. CraftStation).
const CATEGORY_FOOD := 2

# ─────────────────────────────────────────────────────────────────
#  РЕЗУЛЬТАТ  (для CRAFT и REPAIR)
# ─────────────────────────────────────────────────────────────────

## Предмет-результат крафта / починенный предмет-шаблон
@export var result_item: ItemData
@export var result_amount: int = 1

# ─────────────────────────────────────────────────────────────────
#  ИНГРЕДИЕНТЫ  (для CRAFT и REPAIR)
# ─────────────────────────────────────────────────────────────────

## До трёх ресурсов на вход
@export var main_resource:      ItemData
@export var main_amount:        int = 1

@export var secondary_resource: ItemData
@export var secondary_amount:   int = 1

@export var third_resource:     ItemData
@export var third_amount:       int = 1

## Оплата в золоте (0 = бесплатно)
@export var gold_cost: int = 0

# ─────────────────────────────────────────────────────────────────
#  РАЗБОРКА  (для DISASSEMBLE)
# ─────────────────────────────────────────────────────────────────

## Предмет, который нужно разобрать
@export var disassemble_target: ItemData

## Что получается при разборке (до трёх позиций)
@export var salvage_resource_1: ItemData
@export var salvage_amount_1:   int = 1

@export var salvage_resource_2: ItemData
@export var salvage_amount_2:   int = 0

@export var salvage_resource_3: ItemData
@export var salvage_amount_3:   int = 0

# ─────────────────────────────────────────────────────────────────
#  РЕМОНТ  (для REPAIR)
# ─────────────────────────────────────────────────────────────────

## Целевой предмет, который чинит этот рецепт (совпадение по item_name)
## Если null — рецепт подходит для любого оружия/инструмента
@export var repair_target: ItemData

## Сколько прочности восстанавливается (0 = полный ремонт)
@export var repair_amount: int = 0

# ─────────────────────────────────────────────────────────────────
#  ДОСТУПНОСТЬ
# ─────────────────────────────────────────────────────────────────

@export var required_smith_level: int = 1

## Где доступен рецепт (не касается еды — она всегда только в котле, см. ниже).
enum StationRestriction {
	ANY,             ## Доступен и у кузнеца, и на верстаке
	SMITH_ONLY,      ## Только у кузнеца
	WORKBENCH_ONLY,  ## Только на верстаке
}
@export var station_restriction: StationRestriction = StationRestriction.ANY

# ─────────────────────────────────────────────────────────────────
#  ЛОГИКА ПРОВЕРКИ
# ─────────────────────────────────────────────────────────────────

## Все ингредиенты крафта/ремонта как [{item, amount}]
func get_ingredients() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if main_resource and main_amount > 0:
		result.append({"item": main_resource, "amount": main_amount})
	if secondary_resource and secondary_amount > 0:
		result.append({"item": secondary_resource, "amount": secondary_amount})
	if third_resource and third_amount > 0:
		result.append({"item": third_resource, "amount": third_amount})
	return result

## Все результаты разборки как [{item, amount}]
func get_salvage_results() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if salvage_resource_1 and salvage_amount_1 > 0:
		result.append({"item": salvage_resource_1, "amount": salvage_amount_1})
	if salvage_resource_2 and salvage_amount_2 > 0:
		result.append({"item": salvage_resource_2, "amount": salvage_amount_2})
	if salvage_resource_3 and salvage_amount_3 > 0:
		result.append({"item": salvage_resource_3, "amount": salvage_amount_3})
	return result

## Можно ли выполнить рецепт?
func can_craft(inventory: Inventory, gold_item: ItemData = null) -> bool:
	if not inventory:
		return false

	match mode:
		Mode.CRAFT, Mode.REPAIR:
			for ing in get_ingredients():
				if not inventory.has_total_item(ing["item"], ing["amount"]):
					return false
			if gold_cost > 0 and gold_item:
				if not inventory.has_total_item(gold_item, gold_cost):
					return false
			return true

		Mode.DISASSEMBLE:
			if not disassemble_target:
				return false
			return inventory.has_total_item(disassemble_target, 1)

	return false

## Чего не хватает для выполнения
func get_missing(inventory: Inventory, gold_item: ItemData = null) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []

	match mode:
		Mode.CRAFT, Mode.REPAIR:
			for ing in get_ingredients():
				var have := inventory.get_total_item_count(ing["item"])
				if have < ing["amount"]:
					missing.append({"item": ing["item"], "need": ing["amount"], "have": have})
			if gold_cost > 0 and gold_item:
				var have_gold := inventory.get_total_item_count(gold_item)
				if have_gold < gold_cost:
					missing.append({"item": gold_item, "need": gold_cost, "have": have_gold})

		Mode.DISASSEMBLE:
			if disassemble_target and not inventory.has_total_item(disassemble_target, 1):
				missing.append({"item": disassemble_target, "need": 1, "have": 0})

	return missing

## Максимальное количество крафтов подряд
func max_craftable(inventory: Inventory, gold_item: ItemData = null) -> int:
	var max_count := 9999
	match mode:
		Mode.CRAFT:
			for ing in get_ingredients():
				var have := inventory.get_total_item_count(ing["item"])
				if ing["amount"] > 0:
					max_count = mini(max_count, have / ing["amount"])
			if gold_cost > 0 and gold_item:
				var have_gold := inventory.get_total_item_count(gold_item)
				max_count = mini(max_count, have_gold / gold_cost)
		Mode.REPAIR, Mode.DISASSEMBLE:
			return 1  # Ремонт и разборка — всегда по одному
	return max_count
