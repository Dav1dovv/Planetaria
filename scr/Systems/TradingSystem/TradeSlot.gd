# TradeSlot.gd
# Простой слот для окна торговли: иконка + количество + цена.
# Клик по слоту = купить (если это товар торговца) или продать (если предмет игрока).
extends TextureButton
class_name TradeSlot

@onready var _icon_node:  TextureRect = get_node_or_null("Icon")
@onready var _count_node: Label       = get_node_or_null("Count")
@onready var _price_node: Label       = get_node_or_null("Price")

var item: ItemData = null
var amount: int = 0
var price: int = 0

## Источник данных, который этот слот отображает (для обратной связи в TradeWindow)
var source_inventory_slot: InventorySlotData = null  # для слотов игрока
var source_trade_entry: TradeItemEntry = null         # для слотов торговца

signal slot_clicked(slot: TradeSlot)

func _ready() -> void:
	pressed.connect(func(): emit_signal("slot_clicked", self))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()

func set_data(p_item: ItemData, p_amount: int, p_price: int) -> void:
	item   = p_item
	amount = p_amount
	price  = p_price
	_refresh()

func clear() -> void:
	set_data(null, 0, 0)
	source_inventory_slot = null
	source_trade_entry = null

func _refresh() -> void:
	if not is_inside_tree():
		return
	if _icon_node:
		_icon_node.texture = item.icon if item else null
	if _count_node:
		_count_node.text = str(amount) if (item and amount > 1) else ""
	if _price_node:
		_price_node.text = str(price) if item else ""
		_price_node.visible = item != null

func _on_mouse_entered() -> void:
	if item:
		modulate = Color(1.15, 1.15, 1.15)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
