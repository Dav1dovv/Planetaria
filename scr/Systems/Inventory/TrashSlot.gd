# TrashSlot.gd
extends Control
class_name TrashSlot

@export var normal_texture:  Texture2D
@export var hover_texture:   Texture2D

@onready var icon: TextureRect = $Icon  # TextureRect внутри ноды для отображения иконки корзины
@onready var ui_trash_slot_sfx: AudioStreamPlayer = %UI_TrashSlot_SFX

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if icon and normal_texture:
		icon.texture = normal_texture

# ── Drag & Drop (встроенная система Godot) ───────────────────────

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	# Принимаем любой предмет из инвентаря/хотбара
	return data is Dictionary and data.has("item") and data["item"] != null

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var drag_item: ItemData = data.get("item", null)
	if not drag_item:
		return

	# Очищаем исходный слот
	var src: InventorySlotData = data.get("source_slot", null)
	if src:
		src.item              = null
		src.amount            = 0
		src.slot_node.item    = null
		src.slot_node.ammount = 0
		src.slot_node.update_ui()

		# Оповещаем нужный контейнер
		if src.slot_node.inventory:
			src.slot_node.inventory.emit_signal("inventory_changed")
		if src.slot_node.hotbar:
			src.slot_node.hotbar.emit_signal("hotbar_changed")
			src.slot_node.hotbar._recalculate_accessories()

	print("Удалено в мусорку: %s × %d" % [drag_item.item_name, data.get("amount", 1)])
	%UI_TrashSlot_SFX.play()
# ── Подсветка при наведении ──────────────────────────────────────

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		modulate = Color(1.3, 0.7, 0.7)
	elif what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE

func _on_mouse_entered() -> void:
	if icon and hover_texture:
		icon.texture = hover_texture
	modulate = Color(1.5, 0.8, 0.8)

func _on_mouse_exited() -> void:
	if icon and normal_texture:
		icon.texture = normal_texture
	modulate = Color.WHITE
