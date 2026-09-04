# hot_bar.gd
extends HBoxContainer
class_name Hotbar

const SIZE = 9

@onready var player: Node = get_tree().get_first_node_in_group("Player")
var slots: Array[InventorySlotData] = []
var selected_index: int = 0
var active_accessories: Array[AccessoryData] = []

@export var equip_node: Node  # PlayerHitBox или кто у тебя экипирует

signal hotbar_changed

func _ready() -> void:
	Global.hotbar = self
	equip_node = get_tree().get_first_node_in_group("Equip")
	for child in get_children():
		if child is InventorySlot:
			var data = InventorySlotData.new()
			data.slot_node = child
			slots.append(data)
			child.hotbar = self
			child.hotbar_index = slots.size() - 1
			child.pressed.connect(_on_slot_pressed.bind(slots.size() - 1))
	
	#_load_or_default()
	_recalculate_accessories()
	select_slot(0)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		for i in range(1, 10):
			if event.keycode == KEY_1 + i - 1:
				select_slot(i - 1)
				return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(wrapi(selected_index - 1, 0, SIZE))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(wrapi(selected_index + 1, 0, SIZE))

func select_slot(index: int) -> void:
	var clamped := clampi(index, 0, SIZE - 1)
	if clamped == selected_index:
		return
	selected_index = clamped
	_update_highlight()
	_update_equip()
	emit_signal("hotbar_changed")

func _update_highlight() -> void:
	for i in SIZE:
		if i < slots.size():
			var slot = slots[i].slot_node
			if i == selected_index:
				slot.activate_slot()
			else:
				slot.disable_slot()

func _update_equip() -> void:
	if not equip_node: return
	var item: ItemData = slots[selected_index].item if selected_index < slots.size() else null
	equip_node.update_equip(item)

func _on_slot_pressed(index: int) -> void:
	select_slot(index)

func _is_same_item(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null: return false
	if a.resource_path != "" and a.resource_path == b.resource_path: return true
	if a.item_name == b.item_name and a.get_class() == b.get_class(): return true
	return false

func add_item(item_data: ItemData, amount: int = 1) -> bool:
	if amount <= 0: return false

	# Счётчики (золото/опыт/очки) никогда не занимают слот хотбара —
	# уходят напрямую в баланс через Inventory.
	if item_data.is_counter_item:
		var inv: Inventory = get_tree().get_first_node_in_group("Inventory")
		if inv:
			return inv.add_item(item_data, amount)
		return false

	var added_any := false
	var remaining := amount

	for slot_data in slots:
		if remaining <= 0: break
		if slot_data.item and _is_same_item(slot_data.item, item_data) and item_data.stackable:
			var space := item_data.max_count - slot_data.amount
			if space > 0:
				var add: int = mini(remaining, space)
				slot_data.amount += add
				slot_data.slot_node.item   = slot_data.item
				slot_data.slot_node.ammount = slot_data.amount
				slot_data.slot_node.update_ui()
				remaining -= add
				added_any = true

	for slot_data in slots:
		if remaining <= 0: break
		if slot_data.item == null:
			slot_data.item = item_data.duplicate() if item_data.stackable else item_data
			var add: int = mini(remaining, item_data.max_count)
			slot_data.amount = add
			slot_data.slot_node.item    = slot_data.item
			slot_data.slot_node.ammount = add
			slot_data.slot_node.update_ui()
			remaining -= add
			added_any = true

	if added_any:
		emit_signal("hotbar_changed")

	return added_any

func _recalculate_accessories() -> void:
	# Снимаем старые
	for acc in active_accessories:
		acc.deactivate(player)
	active_accessories.clear()
	
	# Применяем новые из всех слотов
	for slot_data in slots:
		if slot_data.item and slot_data.item is AccessoryData:
			var acc = slot_data.item as AccessoryData
			acc.activate(player)
			active_accessories.append(acc)
	
	print("Hotbar accessories recalculated: %d active" % active_accessories.size())

func get_slot_data_by_node(slot_node: InventorySlot) -> InventorySlotData:
	for data in slots:
		if data.slot_node == slot_node:
			return data
	return null

# Hotbar.gd — НАДЁЖНОЕ СОХРАНЕНИЕ
func _on_inventory_changed() -> void:
	_recalculate_accessories()
