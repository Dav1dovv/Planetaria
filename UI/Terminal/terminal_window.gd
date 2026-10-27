# terminal_window.gd
## Базовое окно для всех меню: металлический корпус, светодиод, заголовок и «экран».
## Всё, что вы добавите ребёнком экземпляра этой сцены, автоматически переедет в экран (Content).
class_name TerminalWindow
extends Control

signal closed

const _INTERNAL_NODE := "Center"

@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_title.text = value
@export var footer: String = "":
	set(value):
		footer = value
		if is_node_ready():
			_apply_footer()
## Цвет светодиода: янтарный — пауза/важно, красный — опасность.
@export var led_color: Color = Color("ffc857")
## Красный вариант экрана (смерть, критические окна).
@export var danger: bool = false

@onready var _title: Label = %Title
@onready var _footer: Label = %Footer
@onready var _screen: TerminalScreen = %Screen
@onready var _led: TerminalLed = %Led
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	# Дети, добавленные в сцене-экземпляре, переносим в слот Content.
	for child in get_children():
		if child.name != _INTERNAL_NODE:
			child.reparent(_content, false)
	_title.text = title
	_apply_footer()
	_led.color_on = led_color
	_led.color_off = led_color.darkened(0.7)
	if danger:
		_screen.theme_type_variation = &"TerminalScreenDanger"


## «Включает монитор» и отдаёт фокус первой кнопке (нужно для геймпада).
func open() -> void:
	show()
	_screen.boot()
	focus_first()


func close() -> void:
	hide()
	closed.emit()


func focus_first() -> void:
	for child in _content.get_children():
		var button := child as BaseButton
		if button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


func _apply_footer() -> void:
	_footer.text = footer
	_footer.visible = not footer.is_empty()
