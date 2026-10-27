extends Control
class_name HotbarOverlay
## Слой поверх хотбара (узел HotbarOverlay в сцене inventory_ux.tscn). Рисует:
##  номера клавиш на заполненных слотах, рамку выбранного слота, вспышку при получении предмета,
##  тревогу при низкой прочности, название выбранного предмета над хотбаром, «FULL» когда всё занято.
## Каждую часть можно выключить, цвета/размеры/тайминги — в инспекторе.

@export_group("Что показывать")
@export var show_digits: bool = true
@export var show_selection: bool = true
@export var show_item_name: bool = true
@export var show_flash: bool = true
@export var show_low_durability: bool = true
@export var show_full_warning: bool = true

@export_group("Тайминги")
## Сколько секунд висит название выбранного предмета.
@export_range(0.5, 6.0, 0.1) var name_time: float = 2.2
@export_range(0.1, 1.0, 0.05) var flash_time: float = 0.35
## Прочность (доля 0–1), ниже которой слот предупреждает.
@export_range(0.0, 1.0, 0.05) var low_durability: float = 0.25

@export_group("Шрифты")
@export var digit_size: int = 5
@export var name_size: int = 7
@export var sub_size: int = 5
@export var mark_size: int = 7

@export_group("Цвета")
@export var color_selected: Color = UIStyle.AMBER
@export var color_warning: Color = UIStyle.RED
@export var color_dim: Color = UIStyle.METAL_LIGHT
@export var color_digit: Color = Color(1, 1, 1, 0.75)

var ux: InventoryUX

var _t: float = 0.0
var _name_timer: float = 0.0
var _last_selected: int = -1
var _last_item: ItemData = null
var _last_amount: int = 0
var _last_amounts: Array = []
var _flash: Dictionary = {}
var _deny: Dictionary = {}


func _ready() -> void:
	top_level = true  # рисуем в глобальных координатах экрана, не завися от родителя
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## Слот не принял стак (нет места) — мигнёт красным.
func deny(slot: InventorySlot) -> void:
	for i in ux._hotbar.slots.size():
		if ux._hotbar.slots[i].slot_node == slot:
			_deny[i] = 0.3


func _process(delta: float) -> void:
	if ux == null or ux._hotbar == null:
		return
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
	if hotbar.slots.is_empty():
		return
	var selected := hotbar.selected_index
	var data := hotbar.slots[selected]
	if selected != _last_selected or data.item != _last_item or data.amount != _last_amount:
		if data.item != null:
			_name_timer = name_time
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
			_flash[i] = flash_time
		_last_amounts[i] = now


func _draw() -> void:
	if ux == null:
		return
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

		if show_flash and _flash.has(i):
			draw_rect(r.grow(-1.0), Color(1, 1, 1, 0.5 * (_flash[i] / flash_time)))

		var item := data.item
		if show_low_durability and item is equip_data and item.max_durability > 0 and not item.consumable:
			var ratio := float(item.get_durability()) / float(item.max_durability)
			if ratio <= low_durability:
				var a := 0.55 + 0.45 * pulse
				draw_rect(r.grow(0.3), Color(color_warning, a), false, 1.0)
				_text(font, "!", Vector2(r.end.x - 4.0, r.position.y + 6.0), mark_size, Color(color_warning, a))

		if _deny.has(i):
			draw_rect(r, Color(color_warning, 0.5 * (_deny[i] / 0.3)))

		if show_selection and selected:
			draw_rect(r.grow(0.4), Color(color_selected, 0.6 + 0.4 * pulse), false, 1.0)

		if show_digits and item != null:
			var col := color_selected if selected else color_digit
			_text(font, str(i + 1), Vector2(r.position.x + 1.5, r.position.y + 5.5), digit_size, col)

	if show_item_name:
		_draw_name(hotbar, bar_rect, font)
	if show_full_warning:
		_draw_full(bar_rect, font, pulse)


func _draw_name(hotbar: Hotbar, bar_rect: Rect2, font: Font) -> void:
	if _name_timer <= 0.0 or ux._inv.is_opened:
		return  # при открытом окне инвентаря название не нужно — есть тултипы
	var data := hotbar.slots[hotbar.selected_index]
	if data.item == null:
		return
	var alpha := clampf(_name_timer / 0.6, 0.0, 1.0)
	var q := clampi(data.item.quality, 0, ux.quality_colors.size() - 1)
	var title := Loc.t(data.item.item_name)
	if data.amount > 1 and not data.item.is_counter_item:
		title += "  x%d" % data.amount
	var cx := bar_rect.get_center().x
	var y := bar_rect.position.y - 5.0
	_text(font, title, Vector2(cx, y), name_size, Color(ux.quality_colors[q], alpha), true)
	if data.item is equip_data:
		_text(font, "%s %d" % [Loc.t(ux.damage_key), data.item.Damage], Vector2(cx, y - 8.0), sub_size,
				Color(color_dim, alpha), true)


func _draw_full(bar_rect: Rect2, font: Font, pulse: float) -> void:
	if not ux.is_everything_full():
		return
	_text(font, Loc.t(ux.full_key), Vector2(bar_rect.end.x + 4.0, bar_rect.get_center().y + 3.0), mark_size,
			Color(color_warning, 0.55 + 0.45 * pulse))


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
