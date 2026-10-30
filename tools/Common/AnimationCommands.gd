extends Node
class_name animation_commands

func fade():
	Global.scene_manager.fade(false)
	

func dialog(message : String):
	Global.developer_console.log_message(message, Color(0.09, 0.859, 0.984, 1.0))
	
func message():
	Global.developer_console.log_message("Start " + Global.player_name +  "'s Awakening
", Color(0.09, 0.859, 0.984, 1.0))


func _start_tutorial():
	Global.start_tutorial()
