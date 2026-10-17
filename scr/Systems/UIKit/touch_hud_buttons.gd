# touch_hud_buttons.gd
## Две кнопки на HUD для телефона: «инвентарь» и «меню/пауза». На клавиатуре это I и Esc,
## на сенсорном экране этих клавиш нет, и без кнопок до меню не добраться.
## Кнопки не знают ничего об окнах: они посылают те же действия, что и клавиши,
## поэтому вся логика открытия/закрытия остаётся в одном месте.
##
## Видны только при сенсорном управлении и только когда нет открытых окон
## (внутри окон есть свой ✕).
class_name TouchHudButtons
extends Control

## Показывать и на ПК (для отладки раскладки).
@export var force_visible: bool = false

const ACTION_MENU      := &"ui_cancel"
const ACTION_INVENTORY := &"CallInventory"
const MARGIN := 6.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var menu := _TouchButton.new(_TouchButton.Icon.MENU)
	var bag := _TouchButton.new(_TouchButton.Icon.BAG)
	menu.pressed.connect(_send.bind(ACTION_MENU))
	bag.pressed.connect(_send.bind(ACTION_INVENTORY))
	add_child(menu)
	add_child(bag)
	_place_top_right(menu, 0)
	_place_top_right(bag, 1)


func _place_top_right(button: Control, slot: int) -> void:
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_right = -MARGIN - slot * (_TouchButton.HIT + 2.0)
	button.offset_left = button.offset_right - _TouchButton.HIT
	button.offset_top = MARGIN
	button.offset_bottom = MARGIN + _TouchButton.HIT


func _process(_delta: float) -> void:
	var window_open: bool = Global.is_opened_menu or get_tree().paused
	visible = (force_visible or InputHints.is_touch()) and not window_open


## Нажатие + отпускание действия, как если бы игрок нажал клавишу.
func _send(action: StringName) -> void:
	for pressed_state in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed_state
		Input.parse_input_event(ev)


class _TouchButton extends Control:
	signal pressed

	enum Icon { MENU, BAG }

	const VISUAL := 22.0
	const HIT := 28.0

	var _icon: Icon
	var _down := false

	func _init(icon: Icon) -> void:
		_icon = icon
		custom_minimum_size = Vector2(HIT, HIT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

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
		var edge := Color("7fe9ee") if _down else Color("aab3c2")
		draw_rect(rect, edge)
		draw_rect(rect.grow(-1), Color(0.18, 0.22, 0.3, 0.95) if _down else Color(0.07, 0.08, 0.12, 0.85))
		var c := rect.get_center().floor()
		var ink := Color("e8ecf3")
		match _icon:
			Icon.MENU:
				for y in [-4, 0, 4]:
					draw_rect(Rect2(c + Vector2(-5, y - 1), Vector2(10, 2)), ink)
			Icon.BAG:
				draw_rect(Rect2(c + Vector2(-2, -6), Vector2(4, 2)), ink)       # ручка
				draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 9)), ink)      # корпус
				draw_rect(Rect2(c + Vector2(-3, 0), Vector2(6, 2)), Color(0.07, 0.08, 0.12))  # карман
