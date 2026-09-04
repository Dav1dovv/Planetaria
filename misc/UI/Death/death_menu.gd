extends Control

var player
var world

func _ready() -> void:
	player = get_parent().get_parent()
	world = get_tree().get_first_node_in_group("World")
	visible = false
	

func death():
	visible = true
	$AnimationPlayer.play("Blur")



func _on_main_menu_pressed() -> void:
	Global.scene_manager.change_to_main_menu()


func _on_revive_pressed() -> void:
	world.respawn()
	visible = false
	
