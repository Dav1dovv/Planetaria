# TradeItemEntry.gd
# Один товар в ассортименте торговца.
class_name TradeItemEntry
extends Resource

@export var item: ItemData
@export var price: int = 1          # цена покупки у торговца (за 1 шт.)
@export var stock: int = -1         # -1 = бесконечный запас, иначе кол-во в наличии
