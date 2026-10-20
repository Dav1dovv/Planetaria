extends Control
class_name PlanetRow
## Строка списка направлений в консоли выбора планеты (сцена planet_row.tscn).
## Размер строки — в инспекторе (Custom Minimum Size), шрифты и цвета — группы ниже.

signal selected
signal activated

@export_group("Текст")
@export var font_size: int = 9
@export var sub_font_size: int = 7
@export var padding: float = 7.0

@export_group("Цвета")
@export var color_text: Color = Color("c9f7f7")
@export var color_dimmed: Color = Color("5d6b73")
@export var color_sub: Color = Color("1f7f86")
@export var color_selected_fill: Color = Color(0.27, 0.9, 0.9, 0.16)
@export var color_selected_bar: Color = Color("45e6e6")
@export var color_hover_fill: Color = Color(0.27, 0.9, 0.9, 0.07)
@export var color_separator: Color = Color(0.12, 0.5, 0.52, 0.35)

# Данные строки заполняет консоль
var title: String = ""
var sub_text: String = ""
var right_text: String = ""
var right_color: Color = Color("45e6e6")
var led: Color = Color("6fe08a")
var dimmed: bool = false
var is_selected: bool = false

var _hover: bool = false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(value: bool) -> void:
	_hover = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		selected.emit()
		if mb.double_click:
			activated.emit()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if is_selected:
		draw_rect(rect, color_selected_fill)
		draw_rect(Rect2(0.0, 0.0, 2.0, size.y), color_selected_bar)
	elif _hover:
		draw_rect(rect, color_hover_fill)
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), color_separator)

	var font := get_theme_default_font()
	draw_circle(Vector2(padding * 1.6, size.y * 0.5), 2.5, led)
	var text_x := padding * 3.2
	draw_string(font, Vector2(text_x, size.y * 0.46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			color_dimmed if dimmed else color_text)
	draw_string(font, Vector2(text_x, size.y * 0.84), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_font_size, color_sub)
	draw_string(font, Vector2(0.0, size.y * 0.56), right_text, HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - padding, font_size, right_color)
