extends Creature
class_name Bee

var is_attacked : bool = false

func _on_death_timer_timeout() -> void:
	die()
	

func _on_hit_box_attacked() -> void:
	if is_attacked:
		return  # уже убегает — повторно не обрабатываем
	is_attacked = true
	drop.drop_resources.clear()
	$Skin/Sprite/Sting.visible = false
	$DeathTimer.start()

	# Не меняем behavior_type — пчела остаётся Aggressive,
	# но can_flee позволяет ей убежать.
	# Принудительно переключаем в FLEE прямо сейчас:
	can_flee = true
	if is_instance_valid(target):
		_enter_state(State.FLEE)
	else:
		# Игрок вне зоны видимости — просто бредём прочь от home
		_enter_state(State.WANDER)
