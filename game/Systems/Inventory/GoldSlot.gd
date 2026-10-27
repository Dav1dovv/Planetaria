# GoldSlot.gd
# Специальный слот только для денег (ItemData с именем gold_item_name).
# Отображает текущий баланс. НЕ принимает drag других предметов.
# Путь: res://scr/Systems/Inventory/GoldSlot.gd
extends TextureButton
class_name GoldSlot

## ItemData твоих монет — перетащи в Инспекторе
@export var gold_item: ItemData

## Максимум монет в одной пачке (должно совпадать с ItemData.max_count)
@export var max_stack: int = 9999

@onready var count_label: Label    = $Count
@onready var icon_rect: TextureRect = $Icon

# Текущий баланс (суммируется по всем слотам инвентаря)
var _balance: int = 0

# Ссылка устанавливается из inventory.gd
var inventory: Inventory = null

func _ready() -> void:
	if gold_item and icon_rect:
		icon_rect.texture = gold_item.icon
	# Ждём кадр — Inventory регистрирует себя в группе в своём _ready()
	await get_tree().process_frame
	inventory = get_tree().get_first_node_in_group("Inventory")
	if inventory:
		inventory.gold_slot = self
		inventory.inventory_changed.connect(_refresh)
	var hb = get_tree().get_first_node_in_group("Hotbar")
	if hb:
		hb.hotbar_changed.connect(_refresh)
	# Теперь вызываем refresh — inventory уже есть
	_refresh()

# ─── Обновить отображение ────────────────────────────────────────
func _refresh() -> void:
	if not gold_item or not inventory:
		_set_label(0)
		return
	_balance = inventory.get_counter_balance(gold_item)
	_set_label(_balance)

func _set_label(amount: int) -> void:
	if not count_label:
		return
	if amount >= 1000:
		count_label.text = "%.1fк" % (amount / 1000.0)
	else:
		count_label.text = str(amount)

# ─── Публичный API ───────────────────────────────────────────────

## Текущий баланс золота
func get_balance() -> int:
	return _balance

## Списать золото. Возвращает true если хватило.
func spend(amount: int) -> bool:
	if not inventory or not gold_item:
		return false
	if _balance < amount:
		return false
	inventory.remove_from_total(gold_item, amount)
	return true

## Добавить золото
func add(amount: int) -> void:
	if inventory and gold_item:
		inventory.add_item(gold_item.duplicate(), amount)

# ─── Drag-and-drop: только золото кладётся сюда ─────────────────
func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("item"):
		var item = data["item"]
		return item is ItemData and item.item_name == gold_item.item_name
	return false

func _drop_data(_pos: Vector2, data: Variant) -> void:
	# Золото просто остаётся в инвентаре — слот только для отображения.
	# Если нужно реализовать перетаскивание — добавь логику здесь.
	pass

# ─── Нельзя вытащить золото из этого слота кликом ───────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()   # Поглощаем клик — золото не берётся в курсор
