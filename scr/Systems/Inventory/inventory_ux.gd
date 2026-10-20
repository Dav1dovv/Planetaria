extends Node
class_name InventoryUX
## Надстройка над инвентарём и хотбаром (сцена misc/UI/InventoryUX/inventory_ux.tscn).
## Логику слотов НЕ трогает. ПОДКЛЮЧЕНИЕ БЕЗ КОДА: в редакторе открой Inventory.tscn →
## ПКМ по корневому узлу Inventory → «Instantiate Child Scene» → выбери inventory_ux.tscn. Всё.
##
## ХОТБАР (узел HotbarOverlay): номера клавиш, рамка выбранного слота, название предмета,
##   вспышка при получении, тревога при низкой прочности, «FULL» когда всё занято.
## ИНВЕНТАРЬ: цвет редкости под иконкой, счётчик «Bag 7/15» (CapacityLabel), кнопка «Sort» (SortButton),
##   Shift+клик — быстро перенести стак между инвентарём и хотбаром, подсказка (HintLabel).
##
## ЧТО ГДЕ МЕНЯТЬ (без кода):
##  * шрифты, цвета, стили кнопки и подписей — прямо в узлах сцены (Theme Overrides в инспекторе);
##  * что показывать на хотбаре и тайминги — настройки узла HotbarOverlay;
##  * где стоят счётчик, кнопка Sort и подсказка в окне инвентаря — группа «Положение» ниже;
##  * цвета редкости и тексты — группы ниже.

@export_group("Редкость")
## Цвет подложки под иконкой по качеству предмета (индекс = item.quality).
@export var quality_colors: Array[Color] = [
	Color("9e9e9e"), Color("5cc2ff"), Color("9b6bff"), Color("ff5ca0"),
	Color("ff9d3c"), Color("ffd24c"), Color("ffd24c"),
]
## Прозрачность подложки. 0 = выключить.
@export_range(0.0, 1.0, 0.02) var rarity_alpha: float = 0.34

@export_group("Положение виджетов в окне инвентаря")
@export var capacity_anchor: Control.LayoutPreset = Control.PRESET_TOP_LEFT
@export var capacity_margin: int = 6
@export var sort_anchor: Control.LayoutPreset = Control.PRESET_TOP_RIGHT
@export var sort_margin: int = 6
## Подсказка стоит над строкой «ESC — close»: смещение от нижнего центра экрана.
@export var hint_offset: Vector2 = Vector2(0, -46)

@export_group("Предупреждения заполнения")
## С какой доли заполнения счётчик становится янтарным.
@export_range(0.3, 1.0, 0.05) var warn_ratio: float = 0.8
@export var color_normal: Color = Color(0.62, 0.68, 0.76)
@export var color_warn: Color = Color(1.0, 0.85, 0.3)
@export var color_full: Color = Color(1.0, 0.32, 0.3)

@export_group("Тексты (ключи перевода)")
@export var bag_key: String = "Bag"
@export var sort_key: String = "Sort"
@export var full_key: String = "FULL"
@export var damage_key: String = "DMG"

@onready var _overlay: HotbarOverlay = %HotbarOverlay
@onready var _capacity: Label = %CapacityLabel
@onready var _sort_button: Button = %SortButton
@onready var _hint: Label = %HintLabel

const REFRESH_PERIOD := 0.25    ## как часто пересчитываем бейджи/счётчик (подстраховка к сигналам)

var _inv: Inventory
var _hotbar: Hotbar
var _since_refresh: float = 0.0


func _ready() -> void:
	_inv = get_parent() as Inventory
	if _inv == null:
		push_warning("InventoryUX: добавь эту сцену ребёнком узла Inventory")
		return
	_hotbar = _inv.hotbar

	# Оверлей — в Inventory сразу после хотбара (поверх него, под окнами инвентаря)
	_overlay.ux = self
	_overlay.reparent(_inv, false)
	_inv.move_child(_overlay, _hotbar.get_index() + 1)

	# Виджеты — в панель окна инвентаря
	var panel: Control = _inv.inventory
	_capacity.reparent(panel, false)
	_capacity.set_anchors_and_offsets_preset(capacity_anchor, Control.PRESET_MODE_MINSIZE, capacity_margin)
	_sort_button.reparent(panel, false)
	_sort_button.set_anchors_and_offsets_preset(sort_anchor, Control.PRESET_MODE_MINSIZE, sort_margin)
	_sort_button.pressed.connect(sort_inventory)
	# Подсказка — на общем затемнении под окном, рядом с «ESC — close»
	_hint.reparent(_inv.get_node("Panel"), false)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	_hint.position += hint_offset
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_inv.inventory_changed.connect(_refresh)
	_hotbar.hotbar_changed.connect(_refresh)
	for data in _inv.items:
		data.slot_node.pressed.connect(_on_slot_pressed.bind(data.slot_node))
	for data in _hotbar.slots:
		data.slot_node.pressed.connect(_on_slot_pressed.bind(data.slot_node))

	# select_slot(0) в Hotbar._ready ничего не делает (индекс уже 0) — подсветим первый слот сами
	_hotbar._update_highlight.call_deferred()
	_refresh.call_deferred()


func _process(delta: float) -> void:
	if _inv == null:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_PERIOD:
		_refresh()
	# Виджеты окна показываем только когда открыт именно инвентарь (не кузнец / торговец)
	var show_widgets := _inv.is_opened and _inv.inventory.is_visible_in_tree()
	_hint.visible = show_widgets
	_capacity.visible = show_widgets
	_sort_button.visible = show_widgets


## Бейджи редкости, счётчик заполнения, доступность кнопки Sort.
func _refresh() -> void:
	_since_refresh = 0.0
	if _inv == null:
		return
	var used := 0
	for data in _inv.items:
		_paint_rarity(data)
		if data.item != null:
			used += 1
	for data in _hotbar.slots:
		_paint_rarity(data)

	var total := _inv.items.size()
	_capacity.text = "%s %d/%d" % [Loc.t(bag_key), used, total]
	var color := color_normal
	if used >= total:
		color = color_full
	elif used >= int(ceil(total * warn_ratio)):
		color = color_warn
	_capacity.add_theme_color_override("font_color", color)
	_sort_button.text = Loc.t(sort_key)
	_sort_button.disabled = used < 2


## Цветная подложка под иконкой — используем уже существующий в слоте (скрытый) узел Border.
func _paint_rarity(data: InventorySlotData) -> void:
	var border := data.slot_node.get_node_or_null("Border") as ColorRect
	if border == null:
		return
	var q: int = data.item.quality if data.item != null else 0
	border.visible = data.item != null and q > 0 and rarity_alpha > 0.0
	border.z_index = 0  # со z=-1 подложка пряталась за тёмной панелью окна инвентаря
	if border.visible:
		border.color = Color(quality_colors[clampi(q, 0, quality_colors.size() - 1)], rarity_alpha)


## Заняты ли все слоты (инвентарь + хотбар).
func is_everything_full() -> bool:
	for data in _inv.items:
		if data.item == null:
			return false
	for data in _hotbar.slots:
		if data.item == null:
			return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
#  Shift+клик — быстрый перенос между инвентарём и хотбаром
# ─────────────────────────────────────────────────────────────────────────────
func _on_slot_pressed(slot: InventorySlot) -> void:
	if not Input.is_key_pressed(KEY_SHIFT):
		return
	if not (_inv.is_opened and _inv.inventory.is_visible_in_tree()):
		return
	var from_hotbar := slot.hotbar != null
	var src := _hotbar.get_slot_data_by_node(slot) if from_hotbar else _inv.get_slot_data_by_node(slot)
	if src == null or src.item == null:
		return
	var targets: Array[InventorySlotData] = _inv.items if from_hotbar else _hotbar.slots
	if _quick_move(src, targets) == 0 and from_hotbar:
		_overlay.deny(slot)  # некуда класть — слот мигнёт красным


## Переносит стак в целевой контейнер: сначала доливает в такие же стаки, потом в пустые слоты.
## Возвращает, сколько штук удалось перенести.
func _quick_move(src: InventorySlotData, targets: Array[InventorySlotData]) -> int:
	var item := src.item
	var left := src.amount
	var moved := 0

	if item.stackable:
		for dst in targets:
			if left <= 0:
				break
			if dst.item != null and _inv._is_same_item(dst.item, item) and dst.amount < item.max_count:
				var add := mini(left, item.max_count - dst.amount)
				dst.amount += add
				_sync(dst)
				left -= add
				moved += add
	for dst in targets:
		if left <= 0:
			break
		if dst.item == null:
			var add := mini(left, item.max_count) if item.stackable else 1
			dst.item = item.duplicate() if item.stackable else item
			dst.amount = add
			_sync(dst)
			left -= add
			moved += add

	if moved > 0:
		src.amount = left
		if left <= 0:
			src.item = null
			src.amount = 0
		_sync(src)
		_emit_changed()
	return moved


# ─────────────────────────────────────────────────────────────────────────────
#  Сортировка
# ─────────────────────────────────────────────────────────────────────────────
## Склеивает стаки и раскладывает: снаряжение → аксессуары → еда → материалы,
## внутри группы по редкости (лучшее первым) и имени.
func sort_inventory() -> void:
	var stackable_totals: Dictionary = {}   # ключ -> {item, amount}
	var entries: Array[Dictionary] = []
	for data in _inv.items:
		if data.item == null:
			continue
		if data.item.stackable:
			var key := _inv._count_key(data.item)
			if stackable_totals.has(key):
				stackable_totals[key].amount += data.amount
			else:
				stackable_totals[key] = {"item": data.item, "amount": data.amount}
		else:
			entries.append({"item": data.item, "amount": data.amount})

	for entry in stackable_totals.values():  # режем суммы обратно на стаки по max_count
		var left: int = entry.amount
		var cap: int = maxi(1, entry.item.max_count)
		while left > 0:
			var part := mini(left, cap)
			entries.append({"item": entry.item, "amount": part})
			left -= part

	entries.sort_custom(_entry_less)

	for i in _inv.items.size():
		var data := _inv.items[i]
		if i < entries.size():
			data.item = entries[i].item
			data.amount = entries[i].amount
		else:
			data.item = null
			data.amount = 0
		_sync(data)
	_inv.emit_signal("inventory_changed")


func _entry_less(a: Dictionary, b: Dictionary) -> bool:
	var ra := _kind_rank(a.item)
	var rb := _kind_rank(b.item)
	if ra != rb:
		return ra < rb
	if a.item.quality != b.item.quality:
		return a.item.quality > b.item.quality
	if a.item.item_name != b.item.item_name:
		return a.item.item_name < b.item.item_name
	return a.amount > b.amount


func _kind_rank(item: ItemData) -> int:
	if item is equip_data:
		return 0
	if item is AccessoryData:
		return 1
	if item is FoodData:
		return 2
	return 3


func _sync(data: InventorySlotData) -> void:
	data.slot_node.item = data.item
	data.slot_node.ammount = data.amount
	data.slot_node.update_ui()


func _emit_changed() -> void:
	_inv.emit_signal("inventory_changed")
	_hotbar.emit_signal("hotbar_changed")
	_hotbar._recalculate_accessories()
	_hotbar._update_equip()
