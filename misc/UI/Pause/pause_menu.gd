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

## Единая точка открытия: и ESC, и потеря фокуса окна идут через неё,
## поэтому состояние (is_opened / is_opened_menu) всегда совпадает с реальностью.
## Раньше потеря фокуса ставила игру на паузу, не взводя is_opened, и закрыть
## паузу получалось только со второго нажатия ESC.
func _open_pause() -> void:
	if is_opened:
		return
	is_opened = true
	Global.is_opened_menu = true
	pause()

func _close_pause() -> void:
	if not is_opened:
		return
	is_opened = false
	Global.is_opened_menu = false
	get_parent().layer = 1
	resume()

func _input(event: InputEvent) -> void:
	if anotherMenuOpened or not Global.is_escape_event(event):
		return
	if Global.esc_consumed_this_frame():
		return  # этот ESC уже закрыл инвентарь/настройки/планетарный выбор
	if option_menu.visible:
		return  # настройки закроются сами, а ESC вернёт в паузу
	if is_opened:
		_close_pause()
	elif not Global.is_opened_menu and event.is_action_pressed("ui_escape"):
		# Открывают паузу только Esc / Start. B на геймпаде (ui_cancel) — «назад»:
		# в бою он не должен выбрасывать игрока в меню. Поверх другого окна паузу не открываем.
		_open_pause()

func _on_resume_pressed() -> void:
	_close_pause()

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

func _notification(what):
	if anotherMenuOpened:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not Global.is_opened_menu:
				_open_pause()

func _on_option_menu_closed() -> void:
	$Panel.visible = true
