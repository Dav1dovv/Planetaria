extends Node2D
class_name Fire_collison

@export var effect_source : Effect

func something_enter(area: Area2D) -> void:
	if area.is_in_group("corruption"):
		#explossioon
		pass
	
	elif area.is_in_group("Ennemy") and !area.is_in_group("corruption"):
		#burn entities
		pass
	elif area.is_in_group("Player"):
		#burn player
		area.get_parent().apply_effect_instance(effect_source)
