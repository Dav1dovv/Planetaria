# skin_color_picker.gd
## Выбор цветов внешнего вида: три вкладки (шлем / костюм / акцент), сетка из 16 цветов
## и кнопка «Оригинал» (вернуть цвета текстуры). Все элементы фокусируются, поэтому
## работает и мышью, и касанием, и клавиатурой/геймпадом.
##
## Не знает ничего про экран создания персонажа и умеет работать где угодно:
## на экране создания (с превью-пропуском), в мастерской на корабле (подключи
## colors_changed к PlayerSkin.set_colors).
##
##   var picker := SkinColorPicker.new()
##   picker.colors_changed.connect(player_skin.set_colors)   # null = оригинальные цвета
##   picker.set_colors(player_skin.colors)
class_name SkinColorPicker
extends VBoxContainer

## null = вернуть оригинальные цвета
signal colors_changed(new_colors: SkinColors)

enum Target { HELMET, SUIT, ACCENT }

const COLUMNS := 8
const SWATCH := 11
const GAP := 2

var colors: SkinColors = null
var target: Target = Target.HELMET

var _tabs: Array[_Chip] = []
var _swatches: Array[_Swatch] = []
var _reset: _Chip
var _enabled: bool = true


func _init() -> void:
	add_theme_constant_override("separation", 3)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", GAP)
	add_child(tab_row)
	var tab_width := (COLUMNS * SWATCH + (COLUMNS - 1) * GAP - 2 * GAP) / 3.0
	for t in [[Target.HELMET, "HELMET"], [Target.SUIT, "SUIT"], [Target.ACCENT, "ACCENT"]]:
		var chip := _Chip.new(t[1], Vector2(tab_width, 11))
		chip.activated.connect(_select_target.bind(t[0]))
		tab_row.add_child(chip)
		_tabs.append(chip)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	add_child(grid)
	for color in SkinColors.PRESETS:
		var swatch := _Swatch.new(color, SWATCH)
		swatch.activated.connect(_on_swatch.bind(color))
		grid.add_child(swatch)
		_swatches.append(swatch)

	_reset = _Chip.new("ORIGINAL", Vector2(COLUMNS * SWATCH + (COLUMNS - 1) * GAP, 10))
	_reset.activated.connect(_on_reset)
	add_child(_reset)

	_refresh()


# ─────────────────────────────────────────────────────────────────────────────
#  Публичный API
# ─────────────────────────────────────────────────────────────────────────────

## Показать текущие цвета (без сигнала). null = оригинальные.
func set_colors(value: SkinColors) -> void:
	colors = value.duplicate_colors() if value != null else null
	_refresh()


## Случайные цвета из пресетов (для кнопки RANDOM).
func randomize_colors() -> void:
	var presets := SkinColors.PRESETS
	colors = SkinColors.new(
		presets[randi() % presets.size()],
		presets[randi() % presets.size()],
		presets[randi() % presets.size()])
	_refresh()
	colors_changed.emit(colors)


## Выключает выбор, когда выбранный стиль не перекрашивается (готовый цветной скин).
func set_enabled(value: bool) -> void:
	_enabled = value
	modulate.a = 1.0 if value else 0.35
	var mode := Control.FOCUS_ALL if value else Control.FOCUS_NONE
	var filter := Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	for c in _tabs:
		c.focus_mode = mode
		c.mouse_filter = filter
	for s in _swatches:
		s.focus_mode = mode
		s.mouse_filter = filter
	_reset.focus_mode = mode
	_reset.mouse_filter = filter


func is_enabled() -> bool:
	return _enabled


# ─────────────────────────────────────────────────────────────────────────────
#  Внутреннее
# ─────────────────────────────────────────────────────────────────────────────

func _select_target(value: Target) -> void:
	target = value
	_refresh()


func _on_swatch(color: Color) -> void:
	if not _enabled:
		return
	if colors == null:
		colors = SkinColors.new()
	match target:
		Target.HELMET: colors.helmet = color
		Target.SUIT: colors.suit = color
		Target.ACCENT: colors.accent = color
	_refresh()
	colors_changed.emit(colors)


func _on_reset() -> void:
	if not _enabled:
		return
	colors = null
	_refresh()
	colors_changed.emit(null)


func _part_color() -> Color:
	if colors == null:
		return Color.TRANSPARENT
	match target:
		Target.HELMET: return colors.helmet
		Target.SUIT: return colors.suit
	return colors.accent


func _refresh() -> void:
	for i in _tabs.size():
		_tabs[i].selected = (i == int(target))
		_tabs[i].queue_redraw()
	var current := _part_color()
	for s in _swatches:
		s.selected = colors != null and s.color.is_equal_approx(current)
		s.queue_redraw()
	_reset.selected = (colors == null)
	_reset.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for c in _tabs:
			c.queue_redraw()
		if _reset != null:
			_reset.queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
#  Элементы: рисуем сами, чтобы тема проекта не раздувала размеры
# ─────────────────────────────────────────────────────────────────────────────

class _Clickable extends Control:
	signal activated

	var _hover := false
	var _down := false

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _set_hover(value: bool) -> void:
		_hover = value
		if not value:
			_down = false
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if mb.pressed:
				_down = true
			else:
				var was_down := _down
				_down = false
				if was_down and Rect2(Vector2.ZERO, size).has_point(mb.position):
					activated.emit()
			queue_redraw()
		elif event.is_action_pressed("ui_accept"):
			accept_event()
			activated.emit()


class _Swatch extends _Clickable:
	var color: Color
	var selected := false

	func _init(p_color: Color, p_size: int) -> void:
		super._init()
		color = p_color
		custom_minimum_size = Vector2(p_size, p_size)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color.WHITE if selected else Color(0, 0, 0, 0.55))
		draw_rect(r.grow(-1), color.lightened(0.15) if _hover else color)
		if selected:
			draw_rect(r.grow(-1), Color(0, 0, 0, 0.55), false, 1.0)
		if has_focus():
			draw_rect(r.grow(1), Color("7fe9ee"), false, 1.0)


class _Chip extends _Clickable:
	var text_key: String
	var selected := false

	func _init(p_key: String, p_size: Vector2) -> void:
		super._init()
		text_key = p_key
		custom_minimum_size = p_size

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var edge := Color("7fe9ee") if selected else Color("4a5266")
		var fill := Color("1f3a44") if selected else (Color("262c3a") if _hover else Color("151922"))
		draw_rect(r, edge)
		draw_rect(r.grow(-1), fill)
		var font := get_theme_default_font()
		var font_size := 5
		var label := Loc.t(text_key)
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		# Подпись не должна вылезать за чип: ужимаем шрифт
		while font_size > 3 and text_size.x > size.x - 3:
			font_size -= 1
			text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := floorf((size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
		draw_string(font, Vector2(floorf((size.x - text_size.x) / 2.0), baseline), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if selected else Color("aab3c2"))
		if has_focus():
			draw_rect(r.grow(1), Color("7fe9ee"), false, 1.0)
