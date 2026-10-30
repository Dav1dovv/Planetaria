extends Node2D
class_name Fire_collison

@export var effect_source : Effect

func something_enter(area: Area2D) -> void:
	if area.is_in_group("corruption"):
		# Заражение коснулось огня — взрыв ранит существ рядом (см. CorruptionOrb.explode)
		var orb := area.get_parent()
		if orb != null and orb.has_method("explode"):
			orb.explode()

	elif area.is_in_group("explosive_projectile"):
		# Пуля влетела в огонь — взрывается (см. Projectile.explode_from_fire)
		var bullet := area.get_parent()
		if bullet != null and bullet.has_method("explode_from_fire"):
			bullet.explode_from_fire()

	elif area.is_in_group("Ennemy") and !area.is_in_group("corruption"):
		#burn entities
		pass
	elif area.is_in_group("Player"):
		#burn player
		area.get_parent().apply_effect_instance(effect_source)
