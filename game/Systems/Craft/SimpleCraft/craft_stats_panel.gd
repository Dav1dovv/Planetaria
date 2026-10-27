# craft_stats_panel.gd
## Панель характеристик создаваемого оружия: таблица «значение / разница с лучшим оружием
## игрока того же типа», эффекты и вердикт «стоит ли крафтить».
## Только показывает; все расчёты делает WeaponStats.
class_name CraftStatsPanel
extends PanelContainer

const FONT_SIZE := 6

var _grid: GridContainer
var _label_cells: Array[Label] = []
var _value_cells: Array[Label] = []
var _delta_cells: Array[Label] = []
var _effects: Label
var _verdict: Label
var _versus: Label

# Последние данные – чтобы перерисовать панель при смене языка
var _item: equip_data
var _reference: equip_data


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = UIStyle.SCREEN_DEEP
	style.border_color = UIStyle.CYAN_DIM
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	style.anti_aliasing = false
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	add_child(box)

	# Ответ на вопрос «стоит ли крафтить» – первым и крупнее всего
	_verdict = _make_label(Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7)
	_verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict.clip_text = false  # с переносом строк обрезка схлопывает высоту подписи
	_verdict.custom_minimum_size = Vector2(0, 16)
	_verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_verdict)

	_versus = _make_label(UIStyle.METAL_MID, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_versus)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(1, 1, 1, 0.12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 0)
	box.add_child(_grid)

	_effects = _make_label(UIStyle.AMBER, HORIZONTAL_ALIGNMENT_LEFT)
	_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effects.clip_text = false
	_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_effects)


## Показать характеристики item; reference – лучшее оружие игрока того же типа (или null).
func show_stats(item: equip_data, reference: equip_data) -> void:
	_item = item
	_reference = reference
	_render()
	visible = true


func hide_stats() -> void:
	_item = null
	_reference = null
	visible = false


func _render() -> void:
	if _item == null:
		return
	var rows := WeaponStats.rows(_item, _reference)
	_ensure_cells(rows.size())
	for i in rows.size():
		var row: Dictionary = rows[i]
		_label_cells[i].text = Loc.t(row["label"])
		_value_cells[i].text = row["value"]
		_delta_cells[i].text = row["delta"]
		_delta_cells[i].add_theme_color_override("font_color", row["delta_color"])

	var effects := WeaponStats.effects_text(_item)
	_effects.text = effects
	_effects.visible = effects != ""

	var verdict := WeaponStats.verdict(_item, _reference)
	_verdict.text = verdict["text"]
	_verdict.add_theme_color_override("font_color", verdict["color"])
	_versus.text = verdict["versus"]
	_versus.visible = verdict["versus"] != ""


func _ensure_cells(count: int) -> void:
	while _label_cells.size() < count:
		var label := _make_label(UIStyle.METAL_LIGHT, HORIZONTAL_ALIGNMENT_LEFT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(label)
		_label_cells.append(label)

		var value := _make_label(UIStyle.CYAN_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size.x = 26
		_grid.add_child(value)
		_value_cells.append(value)

		var delta := _make_label(UIStyle.METAL_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
		delta.custom_minimum_size.x = 26
		_grid.add_child(delta)
		_delta_cells.append(delta)


func _make_label(color: Color, align: HorizontalAlignment, font_size: int = FONT_SIZE) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 0)
	return label


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _item != null:
		_render()
