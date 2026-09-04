extends Node2D

@onready var interaction: interaction_area = $Interaction

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interaction.interact = Callable(self, "activate")


func activate():
	Global.inventory.call_cauldron()
