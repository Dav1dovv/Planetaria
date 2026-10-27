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
var _affordable: bool = true

## Источник данных, который этот слот отображает (для обратной связи в TradeWindow)
var source_inventory_slot: InventorySlotData = null  # для слотов игрока
var source_trade_entry: TradeItemEntry = null         # для слотов торговца

signal slot_clicked(slot: TradeSlot)
## Слот «выбран» мышью или фокусом (стрелки/геймпад): окно показывает название и описание
signal highlighted(slot: TradeSlot)
signal unhighlighted(slot: TradeSlot)

const FOCUS_COLOR := Color("7fe9ee")

func _ready() -> void:
	pressed.connect(func(): emit_signal("slot_clicked", self))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	_refresh()

func set_data(p_item: ItemData, p_amount: int, p_price: int) -> void:
	item   = p_item
	amount = p_amount
	price  = p_price
	_refresh()

## Товар не по карману выглядит приглушённым ещё до клика.
func set_affordable(value: bool) -> void:
	_affordable = value
	modulate = _rest_color()

func _rest_color() -> Color:
	return Color(1, 1, 1, 1.0 if _affordable else 0.5)

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

## Рамка фокуса: без неё с клавиатуры/геймпада не видно, какой товар выбран.
func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), FOCUS_COLOR, false, 1.5)

func _on_focus_changed(gained: bool) -> void:
	queue_redraw()
	if not item:
		return
	if gained:
		highlighted.emit(self)
	else:
		unhighlighted.emit(self)

func _on_mouse_entered() -> void:
	if item:
		highlighted.emit(self)
		var c := _rest_color()
		modulate = Color(1.15, 1.15, 1.15, c.a)

func _on_mouse_exited() -> void:
	modulate = _rest_color()
	# Слот, на котором остался фокус, остаётся «выбранным» (стрелки/геймпад)
	if item and not has_focus():
		unhighlighted.emit(self)
