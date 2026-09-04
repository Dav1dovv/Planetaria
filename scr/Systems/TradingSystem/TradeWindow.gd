# TradeWindow.gd
# Простое окно торговли в стиле Fallout: слева инвентарь игрока (продажа по клику),
# справа товары торговца (покупка по клику). Золото отображается сверху.
extends Control
class_name TradeWindow

@export var trader_data: TraderData

var inventory: Inventory       # назначается в _ready, Global.inventory ещё не готов в @onready
var gold_slot: GoldSlot        # ссылка на GoldSlot для баланса/списания/начисления

# ── Ноды UI — подправь пути под свою сцену ────────────────────────
@onready var player_grid: GridContainer = $Panel/VBoxContainer/HBoxContainer/PlayerSide/ScrollContainer/GridContainer
@onready var trader_grid: GridContainer = $Panel/VBoxContainer/HBoxContainer/TraderSide/ScrollContainer/GridContainer
@onready var gold_label:  Label         = $Panel/VBoxContainer/GoldLabel
@onready var trader_name_label: Label   = $Panel/VBoxContainer/HBoxContainer/TraderSide/Label

const TRADE_SLOT_SCENE := preload("uid://dts1ot2trd001")

func _ready() -> void:
	visible = false
	# Ждём кадр, чтобы Inventory/GoldSlot успели зарегистрироваться
	await get_tree().process_frame
	inventory = Global.inventory
	gold_slot = get_tree().get_first_node_in_group("CoinSlot")

func open(p_trader_data: TraderData) -> void:
	trader_data = p_trader_data
	if not inventory:
		inventory = Global.inventory
	if not gold_slot:
		gold_slot = get_tree().get_first_node_in_group("CoinSlot")
	if trader_data is TravelingMerchantData:
		(trader_data as TravelingMerchantData).generate_stock()
	visible = true
	Cursor.detection_mode(true)
	refresh()

func close() -> void:
	visible = false
	Cursor.detection_mode(false)

# ─────────────────────────────────────────────────────────────────
#  ЗОЛОТО — через GoldSlot (группа "CoinSlot")
# ─────────────────────────────────────────────────────────────────
func _get_gold() -> int:
	if gold_slot:
		return gold_slot.get_balance()
	return 0

func _change_gold(delta: int) -> bool:
	if not gold_slot:
		return false
	if delta < 0:
		return gold_slot.spend(-delta)
	gold_slot.add(delta)
	return true

# ─────────────────────────────────────────────────────────────────
#  ОТРИСОВКА
# ─────────────────────────────────────────────────────────────────
func refresh() -> void:
	if trader_name_label:
		trader_name_label.text = (trader_data.trader_name if trader_data else "Торговец")

	_refresh_gold()
	_refresh_player_side()
	_refresh_trader_side()

func _refresh_gold() -> void:
	if gold_label:
		gold_label.text = "Золото: %d" % _get_gold()

func _refresh_player_side() -> void:
	_clear_grid(player_grid)
	if not inventory:
		return
	for slot_data in inventory.items:
		if not slot_data.item:
			continue
		if _is_gold_item(slot_data.item):
			continue  # золото не продаётся торговцу как обычный товар
		var slot := TRADE_SLOT_SCENE.instantiate() as TradeSlot
		player_grid.add_child(slot)
		var sell_price := _get_sell_price(slot_data.item)
		slot.set_data(slot_data.item, slot_data.amount, sell_price)
		slot.source_inventory_slot = slot_data
		slot.slot_clicked.connect(_on_player_slot_clicked)

func _refresh_trader_side() -> void:
	_clear_grid(trader_grid)
	if not trader_data:
		return
	for entry in trader_data.items:
		if not entry.item:
			continue
		if entry.stock == 0:
			continue
		if _is_gold_item(entry.item):
			continue  # золото не продаётся торговцем как обычный товар
		var slot := TRADE_SLOT_SCENE.instantiate() as TradeSlot
		trader_grid.add_child(slot)
		var display_amount := entry.stock if entry.stock >= 0 else 1
		slot.set_data(entry.item, display_amount, entry.price)
		slot.source_trade_entry = entry
		slot.slot_clicked.connect(_on_trader_slot_clicked)

func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

## "Базовая" цена предмета для расчёта продажи игроком.
## Предполагается поле item.price (int). Если его нет — используем 1.
func _get_base_price(item: ItemData) -> int:
	if "price" in item:
		return item.price
	return 1

func _get_sell_price(item: ItemData) -> int:
	var mult := trader_data.sell_multiplier if trader_data else 0.5
	return max(1, int(round(_get_base_price(item) * mult)))

## Является ли предмет "золотом" (валютой) — определяется через gold_slot.gold_item
func _is_gold_item(item: ItemData) -> bool:
	if not item or not gold_slot or not gold_slot.gold_item:
		return false
	if item == gold_slot.gold_item:
		return true
	return item.item_name == gold_slot.gold_item.item_name

# ─────────────────────────────────────────────────────────────────
#  ПОКУПКА (клик по товару торговца)
# ─────────────────────────────────────────────────────────────────
func _on_trader_slot_clicked(slot: TradeSlot) -> void:
	var entry := slot.source_trade_entry
	if not entry or not entry.item:
		return

	if _get_gold() < entry.price:
		_show_message("Недостаточно золота")
		return

	if not inventory.can_add_item(entry.item, 1):
		_show_message("Инвентарь полон")
		return

	if not _change_gold(-entry.price):
		return

	inventory.add_item(entry.item, 1)

	if entry.stock > 0:
		entry.stock -= 1
		if entry.stock == 0:
			trader_data.items.erase(entry)

	refresh()

# ─────────────────────────────────────────────────────────────────
#  ПРОДАЖА (клик по предмету игрока)
# ─────────────────────────────────────────────────────────────────
func _on_player_slot_clicked(slot: TradeSlot) -> void:
	var slot_data := slot.source_inventory_slot
	if not slot_data or not slot_data.item:
		return

	var item := slot_data.item
	var sell_price := _get_sell_price(item)

	# Снимаем 1 шт. из инвентаря
	slot_data.amount -= 1
	if slot_data.amount <= 0:
		slot_data.item = null
		slot_data.amount = 0
		slot_data.slot_node.item = null
	slot_data.slot_node.ammount = slot_data.amount
	slot_data.slot_node.update_ui()
	inventory.emit_signal("inventory_changed")

	_change_gold(sell_price)

	refresh()

# ─────────────────────────────────────────────────────────────────
#  ПРОЧЕЕ
# ─────────────────────────────────────────────────────────────────
func _show_message(text: String) -> void:
	print("[Trade] %s" % text)
	# Замени на свой UI-тултип/нотификацию при желании.

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
