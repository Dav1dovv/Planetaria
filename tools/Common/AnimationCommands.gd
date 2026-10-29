extends Node
class_name animation_commands

func fade():
	Global.scene_manager.fade(false)
	

func dialog(message : String):
	Global.developer_console.log_message(message, Color(0.09, 0.859, 0.984, 1.0))
	
