# inventoryslot.gd
extends TextureButton
class_name InventorySlot

var inventory: Inventory = null
var hotbar: Hotbar = null
var hotbar_index: int = -1

@export var active_slot: AtlasTexture
@export var unactive_slot: AtlasTexture

var item: ItemData = null
var ammount: int = 0

# ── Глобальный курсор ────────────────────────────────────────────
static var held_item:    ItemData = null
static var held_amount:  int      = 0
static var held_preview: Control  = null
static var _drag_started_this_frame: bool = false

@onready var _icon_node:  TextureRect      = get_node_or_null("Icon")
@onready var _count_node: Label            = get_node_or_null("Count")
@onready var _dur_bar:    TextureProgressBar = get_node_or_null("DurabilityBar")
@onready var _tip_node:   Node             = get_node_or_null("Tooltip")
@onready var _index_label: Label           = get_node_or_null("Label")

var _is_ready := false

func _ready() -> void:
	_is_ready = true
	if get_parent() is Hotbar:
		hotbar       = get_parent()
		hotbar_index = get_index()
	# Если данные были записаны до _ready — обновляем UI сейчас
	if item != null or ammount > 0:
		update_ui()

# ── Durability bar ────────────────────────────────────────────────
func _ensure_durability_bar() -> void:
	if _dur_bar:
		_dur_bar.visible = false

func _update_durability_bar() -> void:
	var bar := _dur_bar
	if not bar:
		return
	var has_dur := false
	var cur     := 0.0
	var maxd    := 1.0
	if item is equip_data:
		cur = float(item.get_durability()); maxd = float(item.max_durability); has_dur = true
	if has_dur:
		bar.min_value = 0.0
		bar.max_value = maxd
		bar.visible   = true
		bar.set_deferred("value", cur)
		var ratio := clampf(cur / maxd, 0.0, 1.0) if maxd > 0.0 else 0.0
		if   ratio > 0.6: bar.tint_progress = Color(0.2, 0.85, 0.2)
		elif ratio > 0.3: bar.tint_progress = Color(0.95, 0.75, 0.1)
		else:             bar.tint_progress = Color(0.9, 0.15, 0.15)
	else:
		bar.visible = false

# ── UI ───────────────────────────────────────────────────────────
func update_ui() -> void:
	# Если нода ещё не прошла _ready — откладываем
	if not _is_ready:
		call_deferred("update_ui")
		return

	if _icon_node:
		_icon_node.texture = item.icon if item else null

	if _count_node:
		# Предметы-счётчики (золото, опыт и т.п. — ItemData.is_counter_item = true)
		# не показывают цифру в обычном слоте инвентаря: их суммарное количество
		# и так видно в отдельном слоте-счётчике (GoldSlot / будущий XPSlot и т.д.)
		var is_counter := item != null and ("is_counter_item" in item) and item.is_counter_item
		_count_node.text = str(ammount) if (item and ammount > 1 and not is_counter) else ""

	if _index_label:
		_index_label.visible = (item == null)

	if _icon_node:
		_icon_node.scale = Vector2.ONE
		_icon_node.pivot_offset = _icon_node.size / 2.0
		_icon_node.modulate = Color.WHITE

	_update_durability_bar()
	_update_tooltip()

func _update_tooltip() -> void:
	var tip := _tip_node
	if not tip or not tip.has_method("set_data"):
		return
	if item:
		tip.set_data(item)
	else:
		tip.clear()

func activate_slot() -> void:
	texture_normal = active_slot
func disable_slot() -> void:
	texture_normal = unactive_slot

# ── Mouse events ─────────────────────────────────────────────────
const _HOVER_SCALE := 1.35

func _on_mouse_entered() -> void:
	if _tip_node:
		_tip_node.visible = (item != null)
	_update_drag_highlight()
	if item and _icon_node:
		_icon_node.pivot_offset = _icon_node.size / 2.0
		_icon_node.scale = Vector2.ONE * _HOVER_SCALE
		_icon_node.z_index = 1

func _on_mouse_exited() -> void:
	if _tip_node:
		_tip_node.visible = false
	modulate = Color.WHITE
	if _icon_node:
		_icon_node.scale = Vector2.ONE
		_icon_node.z_index = 0

# ── Подсветка слота под курсором во время drag ────────────────────
const _HL_VALID_SWAP  := Color(0.75, 1.0, 0.75)  # зелёный — обмен/перемещение
const _HL_VALID_STACK := Color(0.75, 0.85, 1.0)  # синий — стакается
const _HL_INVALID     := Color(1.0, 0.7, 0.7)    # красный — нельзя бросить

var _pending_split_amount: int = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
		if _icon_node:
			_icon_node.modulate = Color.WHITE
		if _pending_split_amount >= 0:
			if not get_viewport().gui_is_drag_successful():
				ammount += _pending_split_amount
				update_ui()
			_pending_split_amount = -1

func _update_drag_highlight() -> void:
	var data: Variant = get_viewport().gui_get_drag_data()
	if not (data is Dictionary) or not data.has("item"):
		modulate = Color.WHITE
		return

	var drag_item: ItemData = data.get("item", null)
	var src_slot: InventorySlotData = data.get("source_slot", null)
	var dst_slot := _get_slot_data()

	if not drag_item or not dst_slot or src_slot == dst_slot:
		modulate = Color.WHITE
		return

	if dst_slot.item:
		var inv_ref := inventory if inventory else (hotbar.get_node_or_null("../..") as Inventory if hotbar else null)
		var same := false
		if inv_ref and inv_ref.has_method("_is_same_item"):
			same = inv_ref._is_same_item(dst_slot.item, drag_item)
		elif dst_slot.item.item_name == drag_item.item_name:
			same = true
		if same and drag_item.stackable and dst_slot.amount < drag_item.max_count:
			modulate = _HL_VALID_STACK
		else:
			modulate = _HL_VALID_SWAP  # обмен местами — тоже валидно
	else:
		modulate = _HL_VALID_SWAP

# ── Drag & Drop ──────────────────────────────────────────────────
func _get_drag_data(_pos: Vector2) -> Variant:
	if not item:
		return null
	_drag_started_this_frame = true
	# Превью курсора — чуть крупнее слота, без сплошной подложки
	var preview := TextureRect.new()
	preview.texture             = item.icon
	preview.custom_minimum_size = Vector2(24, 24)
	preview.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	set_drag_preview(preview)

	# Затемняем иконку в исходном слоте, чтобы было видно, что предмет "взят"
	if _icon_node:
		_icon_node.modulate = Color(1, 1, 1, 0.35)

	# Shift зажат + стак > 1 → отделяем половину стака для переноса
	var drag_amount := ammount
	var is_split := false
	if Input.is_key_pressed(KEY_SHIFT) and item.stackable and ammount > 1:
		drag_amount = ammount / 2  # целочисленное деление, остаток остаётся в источнике
		var remaining := ammount - drag_amount
		ammount = remaining
		var src := _get_slot_data()
		if src:
			src.amount = remaining
		update_ui()
		is_split = true
		_pending_split_amount = drag_amount

	# Данные для drop-таргетов
	return {
		"item":        item,
		"amount":      drag_amount,
		"source_slot": _get_slot_data(),
		"split":       is_split,
	}

func _get_slot_data() -> InventorySlotData:
	if inventory:
		return inventory.get_slot_data_by_node(self)
	if hotbar:
		return hotbar.get_slot_data_by_node(self)
	return null

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("item"):
		return false
	return true          # Обычный слот принимает всё (броня тоже хранится в инвентаре)

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var src_slot: InventorySlotData = data.get("source_slot", null)
	var drag_item: ItemData         = data.get("item", null)
	var drag_amt: int               = data.get("amount", 1)
	var is_split: bool              = data.get("split", false)
	if not drag_item:
		return

	var dst_slot: InventorySlotData = _get_slot_data()
	if not dst_slot:
		return

	# Если это тот же слот — вернуть отщеплённый стак обратно
	if src_slot == dst_slot:
		if is_split and src_slot:
			src_slot.amount += drag_amt
			src_slot.slot_node.ammount = src_slot.amount
			src_slot.slot_node.update_ui()
		return

	var inv_ref := inventory if inventory else (hotbar.get_node_or_null("../..") as Inventory if hotbar else null)

	# Попытка стакнуть: dst уже имеет тот же предмет
	if dst_slot.item and src_slot:
		var same := false
		if inv_ref and inv_ref.has_method("_is_same_item"):
			same = inv_ref._is_same_item(dst_slot.item, drag_item)
		elif dst_slot.item.item_name == drag_item.item_name:
			same = true
		if same and drag_item.stackable:
			var space := drag_item.max_count - dst_slot.amount
			if space > 0:
				var moved: int = mini(drag_amt, space)
				dst_slot.amount += moved
				dst_slot.slot_node.ammount = dst_slot.amount
				dst_slot.slot_node.update_ui()

				if is_split:
					# Остаток не помещается — возвращаем непомещённую часть в источник
					var leftover := drag_amt - moved
					if leftover > 0:
						src_slot.amount += leftover
						src_slot.slot_node.ammount = src_slot.amount
						src_slot.slot_node.update_ui()
				else:
					src_slot.amount -= moved
					if src_slot.amount <= 0:
						src_slot.item = null
						src_slot.amount = 0
						src_slot.slot_node.item = null
					src_slot.slot_node.ammount = src_slot.amount
					src_slot.slot_node.update_ui()

				_emit_changed_signals(src_slot, dst_slot)
				return
		elif is_split:
			# Разный предмет, слот занят, сплит невозможен — возвращаем в источник
			src_slot.amount += drag_amt
			src_slot.slot_node.ammount = src_slot.amount
			src_slot.slot_node.update_ui()
			return

	# Сплит в пустой слот — просто кладём отщеплённую часть, источник не трогаем
	if is_split and not dst_slot.item:
		dst_slot.item   = drag_item.duplicate() if drag_item.stackable else drag_item
		dst_slot.amount = drag_amt
		dst_slot.slot_node.item    = dst_slot.item
		dst_slot.slot_node.ammount = drag_amt
		dst_slot.slot_node.update_ui()
		_emit_changed_signals(src_slot, dst_slot)
		return

	if is_split:
		# Занятый слот другим предметом и не стакается — вернуть в источник
		if src_slot:
			src_slot.amount += drag_amt
			src_slot.slot_node.ammount = src_slot.amount
			src_slot.slot_node.update_ui()
		return

	# Обмен местами
	var tmp_item   := dst_slot.item
	var tmp_amount := dst_slot.amount

	dst_slot.item   = drag_item
	dst_slot.amount = drag_amt
	dst_slot.slot_node.item    = drag_item
	dst_slot.slot_node.ammount = drag_amt
	dst_slot.slot_node.update_ui()

	if src_slot:
		src_slot.item   = tmp_item
		src_slot.amount = tmp_amount
		src_slot.slot_node.item    = tmp_item
		src_slot.slot_node.ammount = tmp_amount
		src_slot.slot_node.update_ui()

	_emit_changed_signals(src_slot, dst_slot)

func _on_gui_input(event: InputEvent) -> void:
	if _drag_started_this_frame:
		_drag_started_this_frame = false
		return

func _emit_changed_signals(src_slot: InventorySlotData, _dst_slot: InventorySlotData) -> void:
	# dst всегда принадлежит self — смотрим на self
	var dst_has_hotbar  := hotbar != null
	var dst_has_inv     := inventory != null

	# src может принадлежать другому контейнеру
	var src_has_hotbar  := false
	var src_has_inv     := false
	if src_slot and src_slot.slot_node:
		src_has_hotbar = src_slot.slot_node.hotbar != null
		src_has_inv    = src_slot.slot_node.inventory != null

	var need_inv := dst_has_inv or src_has_inv
	var need_hb  := dst_has_hotbar or src_has_hotbar

	# Шлём сигналы через правильные ноды
	if need_inv:
		var inv_node := inventory
		if not inv_node and src_slot and src_slot.slot_node:
			inv_node = src_slot.slot_node.inventory
		if inv_node:
			inv_node.emit_signal("inventory_changed")

	if need_hb:
		var hb_node := hotbar
		if not hb_node and src_slot and src_slot.slot_node:
			hb_node = src_slot.slot_node.hotbar
		if hb_node:
			hb_node.emit_signal("hotbar_changed")
			hb_node._recalculate_accessories()
			# Принудительно обновляем PlayerHitBox — предмет в руке
			hb_node._update_equip()
