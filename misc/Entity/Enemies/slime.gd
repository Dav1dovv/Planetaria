extends Creature
class_name Slime

## Сколько раз слайм может "разозлиться" от удара, прежде чем эффект перестанет копиться
@export var max_agr_phase: int = 5

var agr_phase : int = 0


func _on_Damaged(new_health: float) -> void:
	# БАГ БЫЛ ЗДЕСЬ: "if agr_phase > 3" проверялось ДО инкремента, а agr_phase
	# стартует с 0 — условие никогда не выполнялось, и слайм никогда не злился.
	if agr_phase < max_agr_phase:
		agr_phase += 1

		# Каждый удар делает слайма агрессивнее (шаг 0.3, не 0.7 — иначе с первого же удара максимум)
		behavior = clampf(behavior + 0.3, -1.0, 1.0)
		Entity_stats.move_speed += 1.5
		$Skin/AnimationPlayer.speed_scale += 0.2
		$HitBox.equip.Damage += 1
		_resolve_behavior_type()

	# Если стал агрессивным и видит игрока — немедленно атаковать
	if behavior_type == BehaviorType.Aggressive and is_instance_valid(target):
		if current_state not in [State.CHASE, State.ATTACK]:
			_enter_state(State.CHASE)
	elif behavior_type == BehaviorType.Aggressive:
		# Цели нет — ищем немедленно, не ждать следующего тика
		for player in get_tree().get_nodes_in_group("Player"):
			if player is Node2D and _can_sense(player):
				_acquire_target(player)
				break
