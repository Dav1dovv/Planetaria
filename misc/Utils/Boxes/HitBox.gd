extends RapierArea2D
class_name HitBox

@export var equip : ItemData

func _init() -> void:
	set_collision_layer_value(1,false)
	set_collision_mask_value(1,false)
	set_collision_layer_value(4,true)
	set_collision_mask_value(5,true)
