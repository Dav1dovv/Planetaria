@icon("res://common/icons/helpcon2.png")
extends Resource
class_name ItemData

enum StationRestriction {
	ANY,             ## Доступен и у кузнеца, и на верстаке
	SMITH_ONLY,      ## Только у кузнеца
	WORKBENCH_ONLY,  ## Только на верстаке
}

@export var icon : Texture
@export_enum("Attack","Eating","Drink","Shoot") var play_anim : String = "Attack"
@export_placeholder("Wood,Stone,Clay") var item_name : String
@export_multiline var description : String
@export var count : int
@export var max_count : int = 99
@export var stackable : bool = true
@export var price : int = 3
## 0:"Обычное", 1:"Крепкое", 2:"Доброе", 3:"Отличное", 4:"Превосходное", 5:"Исключительное","Редкое"
@export_range(0,6,1) var quality: int = 0
## Если true — предмет считается "счётчиком" (золото, опыт, очки и т.п.):
## его количество показывается только в отдельном слоте-счётчике,
## а в обычных слотах инвентаря цифра стака скрывается.
@export var is_counter_item: bool = false

# ─────────────────────────────────────────────────────────────────
#  КРАФТ — как этот предмет СОЗДАЁТСЯ
# ─────────────────────────────────────────────────────────────────
@export_group("Crafting")
## Ингредиенты крафта. Пусто = предмет нельзя скрафтить.
@export var craft_ingredients: Array[CraftIngredient] = []
## Сколько штук получается за один крафт
@export var craft_amount: int = 1
## Оплата золотом (0 = бесплатно)
@export var craft_gold_cost: int = 0
@export_enum("Weapons", "Pickaxe", "Food", "Materials", "Acsesories") var craft_category: int = 0
@export var craft_smith_level: int = 1
@export var craft_station: StationRestriction = StationRestriction.ANY

# ─────────────────────────────────────────────────────────────────
#  РАЗБОРКА — что получается, если РАЗОБРАТЬ этот предмет
# ─────────────────────────────────────────────────────────────────
@export_group("Disassemble")
## Пусто = предмет нельзя разобрать
@export var salvage: Array[CraftIngredient] = []

# ─────────────────────────────────────────────────────────────────
#  РЕМОНТ — что нужно, чтобы ПОЧИНИТЬ этот предмет
# ─────────────────────────────────────────────────────────────────
@export_group("Repair")
## Пусто = ремонт недоступен
@export var repair_ingredients: Array[CraftIngredient] = []
@export var repair_gold_cost: int = 0
## Сколько прочности восстанавливается (0 = полный ремонт)
@export var repair_amount: int = 0

func has_craft_recipe() -> bool:
	return not craft_ingredients.is_empty()

func has_salvage_recipe() -> bool:
	return not salvage.is_empty()

func has_repair_recipe() -> bool:
	return not repair_ingredients.is_empty()

# ─────────────────────────────────────────────────────────────────
#  КАЧЕСТВО (без изменений)
# ─────────────────────────────────────────────────────────────────
## Quality влияет ТОЛЬКО на цену (price). Боевые параметры (Damage, эффекты и т.д.) не меняются.
const QUALITY_NAMES = ["Обычное", "Крепкое", "Доброе", "Отличное", "Превосходное", "Исключительное","Редкое"]
const QUALITY_PRICE_MULTIPLIER = [1.0, 1.5, 2.2, 3.5, 5.0, 8.0]

func apply_quality_multiplier(q: int) -> void:
	quality = q
	price = int(round(price * QUALITY_PRICE_MULTIPLIER[q]))
	description += "\n(Качество: " + QUALITY_NAMES[q] + ")" if not description.contains("Качество:") else ""
	print("Applied quality ", q, " (", QUALITY_NAMES[q], ") to ", item_name, " — new price: ", price)
