extends interaction_area
class_name Show_Child

@export var interact_object : Node

func _ready() -> void:
	interact = Callable(self,"_do")

func _do():
	interact_object.toogle()
