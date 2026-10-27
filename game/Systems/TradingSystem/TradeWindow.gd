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

@onready var hint_label: Label = get_node_or_null("Panel/VBoxContainer/HintLabel")

var _detail_label: Label       # название и описание выбранного товара
var _detail_owner: TradeSlot

func _ready() -> void:
	visible = false
	if hint_label:
		InputHints.bind_label(hint_label, InputHints.trade_hint)
	_build_detail_label()
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
	# С геймпада/клавиатуры сразу есть за что взяться: фокус на первый товар
	if InputHints.device() == InputHints.Device.GAMEPAD:
		_focus_first_slot()

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
		gold_label.text = Loc.t("Золото: %d") % _get_gold()

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
		slot.highlighted.connect(_on_slot_highlighted)
		slot.unhighlighted.connect(_on_slot_unhighlighted)

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
		# Товар не по карману виден ещё до клика
		slot.set_affordable(_get_gold() >= entry.price)
		slot.slot_clicked.connect(_on_trader_slot_clicked)
		slot.highlighted.connect(_on_slot_highlighted)
		slot.unhighlighted.connect(_on_slot_unhighlighted)

## remove_child + queue_free: старые слоты пропадают сразу, а не в конце кадра,
## иначе в сетке на миг лежат и старые, и новые, и индексы/фокус плывут.
func _clear_grid(grid: GridContainer) -> void:
	_clear_detail()
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

# ─────────────────────────────────────────────────────────────────
#  СТРОКА ОПИСАНИЯ: что это за предмет и сколько стоит
# ─────────────────────────────────────────────────────────────────
func _build_detail_label() -> void:
	var box := get_node_or_null("Panel/VBoxContainer") as Control
	if box == null or hint_label == null:
		return
	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.custom_minimum_size = Vector2(0, 22)
	_detail_label.add_theme_font_size_override("font_size", 6)
	_detail_label.add_theme_color_override("font_color", Color("c8d0dc"))
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_detail_label)
	box.move_child(_detail_label, hint_label.get_index())

func _on_slot_highlighted(slot: TradeSlot) -> void:
	if _detail_label == null or slot.item == null:
		return
	_detail_owner = slot
	var title := slot.item.item_name
	if slot.amount > 1:
		title += "  x%d" % slot.amount
	_detail_label.text = "%s\n%s" % [title, slot.item.description]

func _on_slot_unhighlighted(slot: TradeSlot) -> void:
	if slot == _detail_owner:
		_clear_detail()

func _clear_detail() -> void:
	_detail_owner = null
	if _detail_label:
		_detail_label.text = ""

## Перерисовать окно и вернуть фокус на «тот же» слот. Без этого после каждой покупки
## фокус пропадал, и геймпадом/стрелками нельзя было купить две вещи подряд.
func _refresh_keep_focus(slot: TradeSlot) -> void:
	var grid := slot.get_parent() as GridContainer
	var index := slot.get_index()
	var had_focus := slot.has_focus()
	refresh()
	if had_focus and grid != null and grid.get_child_count() > 0:
		(grid.get_child(clampi(index, 0, grid.get_child_count() - 1)) as Control).grab_focus()

func _focus_first_slot() -> void:
	for grid in [trader_grid, player_grid]:
		if grid.get_child_count() > 0:
			(grid.get_child(0) as Control).grab_focus()
			return

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

	# .duplicate(): у каждой купленной вещи своя прочность, а запас торговца не изнашивается
	inventory.add_item(entry.item.duplicate(), 1)

	if entry.stock > 0:
		entry.stock -= 1
		if entry.stock == 0:
			trader_data.items.erase(entry)

	_refresh_keep_focus(slot)

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

	_refresh_keep_focus(slot)

# ─────────────────────────────────────────────────────────────────
#  ПРОЧЕЕ
# ─────────────────────────────────────────────────────────────────
## Сообщение игроку: баннер сверху и мигание золота (раньше текст уходил только в консоль,
## и игрок не понимал, почему клик «ничего не делает»).
func _show_message(text: String) -> void:
	GameJuice.banner(Loc.t(text), "", Color(1.0, 0.5, 0.4), 1.4)
	if gold_label:
		gold_label.modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property(gold_label, "modulate", Color.WHITE, 0.6)
