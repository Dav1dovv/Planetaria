@tool
extends EnemyBase
class_name ContactEnemy
## Контактный враг (слизни и т.п.): идёт к игроку по прямой и наносит урон касанием.
## Урон от касания наносит HitBox (equip берётся из attack_parameter), поэтому его
## CollisionShape2D должна быть включена всегда, а не только в анимации.
##
## Один AnimationPlayer (anim): Walk / Idle и, если can_shoot = true, анимация атаки
## из attack_parameter.play_anim. Выстрел происходит в shoot() — вызови его
## Call Method Track'ом в этой анимации.


# Может ли враг ещё и стрелять (дальность — attack_range, пауза — attack_cooldown)
@export var can_shoot : bool = false:
	set(value):
		can_shoot = value
		queue_redraw()
# Останавливаться ли на время выстрела (пока играет анимация атаки)
@export var stop_while_shooting : bool = true

@export_group("animator")
@export var anim : AnimationPlayer


func _ai(_delta: float, distance: float) -> void:
	# Стрельба (необязательная): в зоне стрельбы, пауза прошла, не убегаем
	if can_shoot and target_detected and not is_attack and not _is_scared() \
			and distance <= attack_range and _attack_cooldown_left <= 0.0:
		_attack()

	# Идёт выстрел — при необходимости стоим на месте
	if is_attack and stop_while_shooting:
		velocity = Vector2.ZERO
		return

	if target_detected and _is_scared():
		# Мало здоровья — убегаем
		_move_away_from_target(1.5)
	elif target_detected:
		# Идём прямо на игрока, без смещения
		_move_to_target()
	else:
		velocity = Vector2.ZERO


func _get_attack_player() -> AnimationPlayer:
	return anim


func _shows_attack_range() -> bool:
	return can_shoot


func _animate() -> void:
	if not anim:
		return

	# Пока играет атака, не перебиваем её Walk/Idle
	if _is_attacking():
		return

	var anim_name : String = "Walk" if velocity.length() > 0.0 else "Idle"
	if anim.current_animation != anim_name:
		anim.play(anim_name)
