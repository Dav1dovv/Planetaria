@tool
extends Sprite2D
class_name planet


func _ready() -> void:
	rotation = randf_range(-360,360)

@export var rotation_speed : float = 2
func _process(delta: float) -> void:
	rotate(rotation_speed * delta)
