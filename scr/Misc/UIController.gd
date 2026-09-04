extends Control
class_name UI_Controller

func _init() -> void:
	connect("visibility_changed",update)

func update():
	if !visible:
		Global.is_opened_menu = false
	else:
		Global.is_opened_menu = true
