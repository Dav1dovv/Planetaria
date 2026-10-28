## CombinerSlot.gd
## Слот окна комбинатора. Наследует InventorySlot — поэтому иконка, счётчик, полоска
## прочности и подсказка-тултип работают «из коробки», а логику допуска решает станция.
##
## Как положить предмет:  перетащить из рюкзака/хотбара ИЛИ просто кликнуть по нему (A на геймпаде).
## Как вернуть:           клик по слоту.
extends InventorySlot
class_name CombinerSlot

signal clicked(slot: CombinerSlot)

## Номер слота: 0 — основа, 1–3 — добавки
@export var slot_index: int = 0

## Станция задаёт сама (CombinerStation)
var station: Node = null


func _ready() -> void:
	super._ready()
	pressed.connect(func() -> void: clicked.emit(self))


## Кладём/забираем предмет программно (станция).
func set_content(new_item: ItemData, new_amount: int = 1) -> void:
	item = new_item
	ammount = new_amount if new_item != null else 0
	update_ui()


func is_empty() -> bool:
	return item == null


## Мигнуть красным: «сюда это нельзя».
func flash_denied() -> void:
	var tween := create_tween()
	modulate = Color(1.0, 0.45, 0.45)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


# ── Перетаскивание: принимаем, но сами не отдаём (вернуть — кликом) ──
func _get_drag_data(_pos: Vector2) -> Variant:
	return null


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if station == null or not (data is Dictionary) or not data.has("item"):
		return false
	return station.call("can_place", self, data["item"])


func _drop_data(_pos: Vector2, data: Variant) -> void:
	if station != null:
		station.call("place_from_drag", self, data)
