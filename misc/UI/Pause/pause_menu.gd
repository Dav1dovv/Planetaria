extends Control

var is_opened : bool = false
var anotherMenuOpened : bool = false
@onready var option_menu: CanvasLayer = $OptionMenu

func resume():
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")
	await $AnimationPlayer.animation_finished
	#$MasterOptionsMenu.visible = false
	$Panel.visible = false
	visible = false
	Cursor.detection_mode(false)
	Global.is_opened_menu = false 
	is_opened = false
	
func pause():
	get_parent().layer = 5
	get_tree().paused = true
	$Panel.visible = true
	visible = true
	$AnimationPlayer.play("blur")
	
@warning_ignore("unused_parameter")
func _input(event: InputEvent) -> void:
	if Input.is_action_just_released("ui_escape") and !anotherMenuOpened:
			print(is_opened)
			if Global.is_opened_menu && !is_opened:
				return  # Запрещаем открывать, если уже открыто другое меню
			is_opened = !is_opened
			print(is_opened)
			Global.is_opened_menu = is_opened
			if !is_opened:
				get_parent().layer = 1
				resume()
			else:
				pause()
				

func _on_resume_pressed() -> void:
	get_parent().layer = 1
	resume()

func _on_exit_pressed() -> void:
	visible = false
	get_tree().paused = false
	Global.scene_manager.change_to_main_menu()
	Global.player_skin_head_index = 0
	Global.player_skin_index = 0
	Cursor.detection_mode(false)
	Global.is_opened_menu = false 
	is_opened = false

func _on_options_pressed() -> void:
	$Panel.visible = false
	option_menu.layer = 8
	option_menu.visible = true
	Global.is_opened_menu = true
	Global.is_opened_menu = true

func _notification(what):
	if !anotherMenuOpened:
		match what:
			#NOTIFICATION_APPLICATION_FOCUS_IN:
				#resume()
			NOTIFICATION_APPLICATION_FOCUS_OUT:
				pause()


func _on_option_menu_closed() -> void:
	$Panel.visible = true
