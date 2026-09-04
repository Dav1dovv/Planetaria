# Generation.gd (без изменений)
extends Resource
class_name Generation

@export var Generation_scene : PackedScene
@export_range(0.001,1) var spawn_weight : float = 1

@export_group("random_settings")
@export var Generation_random_versions : Array[PackedScene]
@export var random_scales : Dictionary = {
	"Standart" : Vector2(1,1),
	"Middle" : Vector2(1.5,1.5),
	"Big": Vector2(2,2)
	}
@export_range(0.5,5,0.1) var random_rotation_degress : float = 0
