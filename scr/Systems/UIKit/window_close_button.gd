# window_close_button.gd
## Крестик закрытия окна в пиксельном стиле. Всегда на виду: игрок не должен гадать,
## как выйти из меню. Видимая часть небольшая, а зона нажатия большая (палец, не курсор).
class_name WindowCloseButton
extends Control

signal pressed

const VISUAL := 16.0   ## размер нарисованной кнопки
const HIT    := 28.0   ## размер зоны нажатия

const C_FILL   := Color(0.07, 0.08, 0.12, 0.92)
const C_EDGE   := Color("aab3c2")
const C_HOT    := Color("ff5360")

var _hover := false
var _down := false


func _init() -> void:
	custom_minimum_size = Vector2(HIT, HIT)
	size = Vector2(HIT, HIT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE  # не перехватываем фокус у геймпадной навигации
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(value: bool) -> void:
	_hover = value
	if not value:
		_down = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_down = true
	else:
		var was_down := _down
		_down = false
		if was_down and Rect2(Vector2.ZERO, size).has_point(mb.position):
			pressed.emit()
	queue_redraw()


func _draw() -> void:
	var inset := ((size - Vector2(VISUAL, VISUAL)) / 2.0).floor()
	var rect := Rect2(inset, Vector2(VISUAL, VISUAL))
	var accent := C_HOT if (_hover or _down) else C_EDGE
	var fill := C_HOT.darkened(0.45) if _down else (C_HOT.darkened(0.7) if _hover else C_FILL)
	draw_rect(rect, accent)
	draw_rect(rect.grow(-1), fill)
	# «×» с линией в 2 пикселя
	var c := rect.get_center().floor()
	var ink := Color.WHITE if (_hover or _down) else Color("e8ecf3")
	for i in range(-3, 4):
		draw_rect(Rect2(c + Vector2(i, i), Vector2(2, 2)), ink)
		draw_rect(Rect2(c + Vector2(i, -i), Vector2(2, 2)), ink)
