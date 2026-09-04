@tool
extends RapierArea2D
class_name HurtBox


# NodePath вместо Node2D — безопасно в @tool режиме
@export var Path_to_stat : NodePath = NodePath("..")

func _init() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(5, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(4, true)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if get_parent().has_signal("health_changed"):
		get_parent().connect("health_changed", damaged)

func damaged(area) -> void:
	get_child(0).disabled = true
	await get_tree().create_timer(1).timeout
	get_child(0).disabled = false
