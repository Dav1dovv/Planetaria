extends Control


@onready var label: Label = $HBoxContainer/Label

var player
func _ready() -> void:
	if !player:
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return
	return

func _process(delta: float) -> void:
	var fps = "FPS: " + str(Engine.get_frames_per_second()) + "/" + str("60.0")
	if player:
		var player_info = "Player info: \n"+ "player_name: "+ Global.player_name + "\n | head_skin_index: "  + str(Global.player_skin_head_index) + " | body_skin_index: " + str(Global.player_skin_index)
		label.text = fps + "\n"  + player_info + "Current location: " + Global.current_location + "\n " 
	else:
		label.text = fps + "\n" + "Current location: " + Global.current_location + "\n " 
	if Input.is_action_just_pressed("ui_debug"):
		visible = !visible
		

func update():
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return
	
