extends Creature
class_name corruption

@export var corupt : int = 7

func _on_hit_box_area_entered(area: Area2D) -> void:
	print(area.get_parent().name)
	if area.get_parent().has_method("add_infection"):
		area.get_parent().add_infection(corupt)
		
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()
