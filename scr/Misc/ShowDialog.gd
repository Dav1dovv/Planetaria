extends Node
class_name  show_dialog

@export var dialog_path : DialogueResource
@export var show_on_start : bool = false

func _ready() -> void:
	if show_on_start:
		DialogueManager.show_dialogue_balloon(dialog_path)
	
	
	
func start():
	DialogueManager.show_dialogue_balloon(dialog_path)
