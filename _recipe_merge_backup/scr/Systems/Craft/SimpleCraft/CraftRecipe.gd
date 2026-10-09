## CraftRecipe.gd  —  теперь это АДАПТЕР, а не отдельный .tres файл.
## Рецепты строятся автоматически из полей ItemData (см. ItemDB.get_recipes()).
## Публичный API сохранён, чтобы CraftStation работал почти без изменений.
@icon("res://common/icons/helpcon2.png")
extends Resource
class_name CraftRecipe

enum Mode { CRAFT, REPAIR, DISASSEMBLE }

const StationRestriction = ItemData.StationRestriction
const CATEGORY_FOOD := 2

var mode: Mode = Mode.CRAFT
var recipe_name: String = ""
var description: String = ""
var category: int = 0
var required_smith_level: int = 1
var station_restriction: StationRestriction = StationRestriction.ANY

var result_item: ItemData
var result_amount: int = 1
var gold_cost: int = 0

var disassemble_target: ItemData
var repair_target: ItemData
var repair_amount: int = 0

var _ingredients: Array[Dictionary] = []
var _salvage: Array[Dictionary] = []

## Стабильный id для сохранений (вместо resource_path)
var id: String:
	get:
		var it := _owner_item()
		return "%d:%s" % [mode, it.item_name if it else ""]

func _owner_item() -> ItemData:
	match mode:
		Mode.CRAFT: return result_item
		Mode.REPAIR: return repair_target
		_: return disassemble_target

# ── Фабрики ──────────────────────────────────────────────────────
static func _to_dicts(list: Array[CraftIngredient]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ing in list:
		if ing and ing.item and ing.amount > 0:
			out.append({"item": ing.item, "amount": ing.amount})
	return out

static func from_craft(item: ItemData) -> CraftRecipe:
	var r := CraftRecipe.new()
	r.mode = Mode.CRAFT
	r.recipe_name = item.item_name
	r.description = item.description
	r.category = item.craft_category
	r.required_smith_level = item.craft_smith_level
	r.station_restriction = item.craft_station
	r.result_item = item
	r.result_amount = item.craft_amount
	r.gold_cost = item.craft_gold_cost
	r._ingredients = _to_dicts(item.craft_ingredients)
	return r

static func from_repair(item: ItemData) -> CraftRecipe:
	var r := CraftRecipe.new()
	r.mode = Mode.REPAIR
	r.recipe_name = "Ремонт: " + item.item_name
	r.description = item.description
	r.category = item.craft_category
	r.required_smith_level = item.craft_smith_level
	r.station_restriction = item.craft_station
	r.result_item = item
	r.repair_target = item
	r.repair_amount = item.repair_amount
	r.gold_cost = item.repair_gold_cost
	r._ingredients = _to_dicts(item.repair_ingredients)
	return r

static func from_salvage(item: ItemData) -> CraftRecipe:
	var r := CraftRecipe.new()
	r.mode = Mode.DISASSEMBLE
	r.recipe_name = "Разборка: " + item.item_name
	r.description = item.description
	r.category = item.craft_category
	r.required_smith_level = item.craft_smith_level
	r.station_restriction = item.craft_station
	r.disassemble_target = item
	r._salvage = _to_dicts(item.salvage)
	return r

# ── Логика (как была) ────────────────────────────────────────────
func get_ingredients() -> Array[Dictionary]:
	return _ingredients

func get_salvage_results() -> Array[Dictionary]:
	return _salvage

func can_craft(inventory: Inventory, gold_item: ItemData = null) -> bool:
	if not inventory:
		return false
	match mode:
		Mode.CRAFT, Mode.REPAIR:
			for ing in _ingredients:
				if not inventory.has_total_item(ing["item"], ing["amount"]):
					return false
			if gold_cost > 0 and gold_item:
				if not inventory.has_total_item(gold_item, gold_cost):
					return false
			return true
		Mode.DISASSEMBLE:
			return disassemble_target != null and inventory.has_total_item(disassemble_target, 1)
	return false

func get_missing(inventory: Inventory, gold_item: ItemData = null) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	match mode:
		Mode.CRAFT, Mode.REPAIR:
			for ing in _ingredients:
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

func max_craftable(inventory: Inventory, gold_item: ItemData = null) -> int:
	if mode != Mode.CRAFT:
		return 1
	var max_count := 9999
	for ing in _ingredients:
		if ing["amount"] > 0:
			max_count = mini(max_count, inventory.get_total_item_count(ing["item"]) / ing["amount"])
	if gold_cost > 0 and gold_item:
		max_count = mini(max_count, inventory.get_total_item_count(gold_item) / gold_cost)
	return max_count
