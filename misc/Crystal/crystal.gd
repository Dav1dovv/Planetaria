extends Node2D

@onready var interaction: interaction_area = $interaction

func _ready() -> void:
	interaction.interact = Callable(self, "go_ship")


func go_ship():
	print("clicked")
	Global.scene_manager.change_scene("Ship",Vector2.ZERO) 
