# PriceTierRule.gd
# Правило для одной ценовой категории странствующего торговца.
# Предметы берутся из общей папки res://scr/Resources/Items/ автоматически —
# попадание в категорию определяется по полю item.price.
class_name PriceTierRule
extends Resource

@export var tier_name: String = "Дешёвые"

## Предмет попадает в эту категорию, если его base price (ItemData.price)
## находится в этом диапазоне (включительно).
@export var base_price_min: int = 1
@export var base_price_max: int = 5

## Сколько случайных разных предметов из этой категории взять в ассортимент.
@export var pick_count: int = 2

## Множитель цены продажи относительно ItemData.price (для непредсказуемости).
## Финальная цена = item.price * random(price_mult_min, price_mult_max), не менее 1.
@export var price_mult_min: float = 0.8
@export var price_mult_max: float = 1.6

## Диапазон количества (stock) на позицию.
@export var stock_min: int = 1
@export var stock_max: int = 3
