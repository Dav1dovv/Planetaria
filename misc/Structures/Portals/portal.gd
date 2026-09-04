extends Node2D

const CRYSTAL = preload("uid://dm7ru2a5fnwfi")
## payment for teleport | 0 rnadom value | 
@export_range(0,50,2) var need_crystal_count : int = 20
@onready var interaction: interaction_area = $interaction
@export var scenes : Array[String] = ["Forest","Desert","Forest1"]
@export var cant_teleport :bool = false


func _ready() -> void:
	if cant_teleport:
		interaction.queue_free()
	if need_crystal_count == 0:
		need_crystal_count = randi_range(10,50)
	
	interaction.show_message = "X" + str(need_crystal_count) + "teleport"
	interaction.interact = Callable(self, "teleport")
	

func teleport():
	if Global.inventory.has_total_item(CRYSTAL,need_crystal_count):
		Global.scene_manager.change_scene(scenes.pick_random(),Vector2.ZERO)
	else:
		print("Not enough resources")
