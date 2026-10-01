extends RapierArea2D

@export var effect : Effect

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.apply_effect_instance(effect)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.remove_effect_instance(effect)
