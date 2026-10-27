# inventory_ux.gd
## Надстройка над инвентарём и хотбаром: удобство и обратная связь, логику слотов НЕ трогает.
## Подключение — одна строка в Inventory._ready() (в конце):   add_child(InventoryUX.new())
##
## ХОТБАР (виден всегда):
##  * номера клавиш 1–9 видны на всех слотах, а не только на пустых;
##  * выбранный слот подсвечен пульсирующей рамкой — в том числе сразу при старте
##    (раньше первый слот не подсвечивался, пока игрок не переключится);
##  * название выбранного предмета всплывает над хотбаром при выборе и пропадает через пару секунд;
##  * слот коротко вспыхивает, когда в него положили предмет или добавили в стак;
##  * прочность ≤ 25% — красная пульсирующая рамка и «!»: оружие сломается, ещё не поздно починить;
##  * все 24 слота заняты — над хотбаром мигает «FULL» (раньше предметы терялись молча).
## ИНВЕНТАРЬ:
##  * цвет редкости под иконкой (серый → голубой → фиолетовый → … → золотой) — ценное видно сразу;
##  * счётчик заполнения «12/15» (янтарный от 80%, красный когда полно);
##  * кнопка «Sort»: склеивает стаки и раскладывает по типу, редкости и имени;
##  * Shift+клик по слоту — быстро перенести стак между инвентарём и хотбаром;
##  * подсказка по скрытым приёмам (Shift+клик, Shift+перетаскивание = половина стака, мусорка).
class_name InventoryUX
extends Node

## Цвета редкости — те же, что в Tooltip.gd (индекс = item.quality).
const QUALITY_COLORS: Array[Color] = [
	Color("9e9e9e"), Color("5cc2ff"), Color("9b6bff"), Color("ff5ca0"),
	Color("ff9d3c"), Color("ffd24c"), Color("ffd24c"),
]
const NAME_TIME := 2.2          ## сколько висит название выбранного предмета
const FLASH_TIME := 0.35        ## вспышка слота при получении предмета
const LOW_DURABILITY := 0.25    ## порог тревоги по прочности
const REFRESH_PERIOD := 0.25    ## как часто пересчитываем бейджи/счётчик (подстраховка к сигналам)

const COL_AMBER := UIStyle.AMBER
const COL_RED := UIStyle.RED
const COL_DIM := UIStyle.METAL_LIGHT
const TERMINAL_THEME: Theme = preload("res://common/Themes/terminal_theme.tres")

var _inv: Inventory
var _hotbar: Hotbar
var _overlay: _HudOverlay
var _capacity: Label
var _hint: Label
var _sort_button: Button
var _since_refresh: float = 0.0


func _ready() -> void:
	_inv = get_parent() as Inventory
	if _inv == null:
		push_warning("InventoryUX: добавляй этот узел ребёнком Inventory")
		return
	_hotbar = _inv.hotbar

	_overlay = _HudOverlay.new(self)
	_inv.add_child(_overlay)
	_inv.move_child(_overlay, _hotbar.get_index() + 1)  # поверх хотбара, под окнами инвентаря

	_build_inventory_widgets()

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
	# Виджеты окна инвентаря показываем только когда открыт именно инвентарь (не кузнец / торговец)
	var show_widgets := _inv.is_opened and _inv.inventory.is_visible_in_tree()
	_hint.visible = show_widgets
	_capacity.visible = show_widgets
	_sort_button.visible = show_widgets


# ─────────────────────────────────────────────────────────────────────────────
#  Виджеты окна инвентаря
# ─────────────────────────────────────────────────────────────────────────────
func _build_inventory_widgets() -> void:
	var panel: Control = _inv.inventory

	_capacity = Label.new()
	_capacity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capacity.add_theme_font_size_override("font_size", 7)
	panel.add_child(_capacity)
	_capacity.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 6)

	_sort_button = Button.new()
	_sort_button.text = "Sort"
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sort_button.theme = TERMINAL_THEME
	_sort_button.theme_type_variation = &"TerminalButton"
	_sort_button.add_theme_font_size_override("font_size", 7)
	_sort_button.pressed.connect(sort_inventory)
	panel.add_child(_sort_button)
	_sort_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)

	# Подсказка — на общем затемнении под окном, рядом с «ESC — close»
	_hint = Label.new()
	_hint.text = "Shift+click - quick move  |  Shift+drag - split stack  |  Drag to bin - discard"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate = Color(1, 1, 1, 0.55)
	_hint.add_theme_font_size_override("font_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dim := _inv.get_node("Panel")
	dim.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	_hint.position += Vector2(0, -34)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH


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
	_capacity.text = "%s %d/%d" % [Loc.t("Bag"), used, total]
	var color := COL_DIM
	if used >= total:
		color = COL_RED
	elif used >= int(ceil(total * 0.8)):
		color = COL_AMBER
	_capacity.add_theme_color_override("font_color", color)
	_sort_button.text = Loc.t("Sort")
	_sort_button.disabled = used < 2


## Цветная подложка под иконкой — используем уже существующий в слоте (скрытый) узел Border.
func _paint_rarity(data: InventorySlotData) -> void:
	var border := data.slot_node.get_node_or_null("Border") as ColorRect
	if border == null:
		return
	var q: int = data.item.quality if data.item != null else 0
	border.visible = data.item != null and q > 0
	border.z_index = 0  # со z=-1 подложка пряталась за тёмной панелью окна инвентаря
	if border.visible:
		border.color = Color(QUALITY_COLORS[clampi(q, 0, QUALITY_COLORS.size() - 1)], 0.34)


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
	if _quick_move(src, targets) == 0:
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


# ─────────────────────────────────────────────────────────────────────────────
#  Общие помощники
# ─────────────────────────────────────────────────────────────────────────────
func _sync(data: InventorySlotData) -> void:
	data.slot_node.item = data.item
	data.slot_node.ammount = data.amount
	data.slot_node.update_ui()


func _emit_changed() -> void:
	_inv.emit_signal("inventory_changed")
	_hotbar.emit_signal("hotbar_changed")
	_hotbar._recalculate_accessories()
	_hotbar._update_equip()


# ═════════════════════════════════════════════════════════════════════════════
#  Слой поверх хотбара
# ═════════════════════════════════════════════════════════════════════════════
class _HudOverlay extends Control:
	var ux: InventoryUX
	var _t: float = 0.0
	var _name_timer: float = 0.0
	var _last_selected: int = -1
	var _last_item: ItemData = null
	var _last_amount: int = 0
	var _last_amounts: Array = []     # что лежало в слотах в прошлом кадре
	var _flash: Dictionary = {}       # индекс слота -> оставшееся время вспышки
	var _deny: Dictionary = {}        # индекс слота -> время красной вспышки

	func _init(owner_ux: InventoryUX) -> void:
		ux = owner_ux
		top_level = true  # рисуем в глобальных координатах экрана, не завися от родителя
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_fit()
		get_viewport().size_changed.connect(_fit)

	func _fit() -> void:
		position = Vector2.ZERO
		size = get_viewport_rect().size

	func deny(slot: InventorySlot) -> void:
		_deny[slot.hotbar_index if slot.hotbar != null else -1] = 0.3

	func _process(delta: float) -> void:
		_t += delta
		_name_timer = maxf(0.0, _name_timer - delta)
		for key in _flash.keys():
			_flash[key] -= delta
			if _flash[key] <= 0.0:
				_flash.erase(key)
		for key in _deny.keys():
			_deny[key] -= delta
			if _deny[key] <= 0.0:
				_deny.erase(key)
		_track_changes()
		queue_redraw()

	## Замечаем: сменился выбранный слот / предмет в нём / в слот что-то положили.
	func _track_changes() -> void:
		var hotbar := ux._hotbar
		if hotbar == null or hotbar.slots.is_empty():
			return
		var selected := hotbar.selected_index
		var data := hotbar.slots[selected]
		if selected != _last_selected or data.item != _last_item or data.amount != _last_amount:
			if data.item != null:
				_name_timer = InventoryUX.NAME_TIME
			_last_selected = selected
			_last_item = data.item
			_last_amount = data.amount
		if _last_amounts.size() != hotbar.slots.size():
			_last_amounts.resize(hotbar.slots.size())
			_last_amounts.fill(-1)
		for i in hotbar.slots.size():
			var now := hotbar.slots[i].amount if hotbar.slots[i].item != null else 0
			var before: int = _last_amounts[i]
			if before >= 0 and now > before:
				_flash[i] = InventoryUX.FLASH_TIME  # положили предмет или добавили в стак
			_last_amounts[i] = now

	func _draw() -> void:
		var hotbar := ux._hotbar
		if hotbar == null or not hotbar.is_visible_in_tree() or hotbar.slots.is_empty():
			return
		var font := get_theme_default_font()
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var bar_rect := Rect2()

		for i in hotbar.slots.size():
			var data := hotbar.slots[i]
			var r := data.slot_node.get_global_rect()
			bar_rect = r if i == 0 else bar_rect.merge(r)
			var selected := i == hotbar.selected_index
			if selected:
				r = r.grow(0.6)

			# Вспышка получения предмета
			if _flash.has(i):
				draw_rect(r.grow(-1.0), Color(1, 1, 1, 0.5 * (_flash[i] / InventoryUX.FLASH_TIME)))

			# Низкая прочность: красная пульсирующая рамка и «!»
			var item := data.item
			if item is equip_data and item.max_durability > 0 and not item.consumable:
				var ratio := float(item.get_durability()) / float(item.max_durability)
				if ratio <= InventoryUX.LOW_DURABILITY:
					var a := 0.55 + 0.45 * pulse
					draw_rect(r.grow(0.3), Color(InventoryUX.COL_RED, a), false, 1.0)
					_text(font, "!", Vector2(r.end.x - 4.0, r.position.y + 6.0), 7, Color(InventoryUX.COL_RED, a))

			# Не вышло перенести (нет места)
			if _deny.has(i):
				draw_rect(r, Color(InventoryUX.COL_RED, 0.5 * (_deny[i] / 0.3)))

			# Выбранный слот: янтарная пульсирующая рамка + уголки
			if selected:
				var edge := Color(InventoryUX.COL_AMBER, 0.6 + 0.4 * pulse)
				draw_rect(r.grow(0.4), edge, false, 1.0)

			# Номер клавиши — на всех слотах, где лежит предмет (на пустых он уже есть в слоте)
			if item != null:
				var col := InventoryUX.COL_AMBER if selected else Color(1, 1, 1, 0.75)
				_text(font, str(i + 1), Vector2(r.position.x + 1.5, r.position.y + 5.5), 5, col)

		_draw_name(hotbar, bar_rect, font)
		_draw_full(hotbar, bar_rect, font, pulse)

	func _draw_name(hotbar: Hotbar, bar_rect: Rect2, font: Font) -> void:
		if _name_timer <= 0.0 or ux._inv.is_opened:
			return  # при открытом окне инвентаря название не нужно — есть тултипы
		var data := hotbar.slots[hotbar.selected_index]
		if data.item == null:
			return
		var alpha := clampf(_name_timer / 0.6, 0.0, 1.0)
		var q := clampi(data.item.quality, 0, InventoryUX.QUALITY_COLORS.size() - 1)
		var title := Loc.t(data.item.item_name)
		if data.amount > 1 and not data.item.is_counter_item:
			title += "  x%d" % data.amount
		var cx := bar_rect.get_center().x
		var y := bar_rect.position.y - 5.0
		_text(font, title, Vector2(cx, y), 7, Color(InventoryUX.QUALITY_COLORS[q], alpha), true)
		if data.item is equip_data:
			var sub := "%s %d" % [Loc.t("DMG"), data.item.Damage]
			_text(font, sub, Vector2(cx, y - 8.0), 5, Color(InventoryUX.COL_DIM, alpha), true)

	func _draw_full(hotbar: Hotbar, bar_rect: Rect2, font: Font, pulse: float) -> void:
		if not ux.is_everything_full():
			return
		_text(font, Loc.t("FULL"), Vector2(bar_rect.end.x + 4.0, bar_rect.get_center().y + 3.0), 7,
				Color(InventoryUX.COL_RED, 0.55 + 0.45 * pulse))

	## Текст с чёрной обводкой; centered — по центру вокруг x.
	func _text(font: Font, text: String, pos: Vector2, fs: int, color: Color, centered: bool = false) -> void:
		var align := HORIZONTAL_ALIGNMENT_LEFT
		var width := -1.0
		if centered:
			align = HORIZONTAL_ALIGNMENT_CENTER
			width = 200.0
			pos.x -= 100.0
		draw_string_outline(font, pos, text, align, width, fs, 3, Color(0, 0, 0, color.a))
		draw_string(font, pos, text, align, width, fs, color)
