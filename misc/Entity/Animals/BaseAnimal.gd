extends Creature
class_name SimpleAnimal


## Срабатывает на сигнал health_changed. У этого сигнала нет параметра "кто ударил",
## а порядок относительно Creature.on_hit() не гарантирован (health_changed может
## прийти раньше, чем on_hit() успеет записать target/last_attacker) — поэтому здесь
## НЕ полагаемся на них, а ищем ближайшего игрока напрямую. Это и было причиной,
## почему улитка/корова/овца не пугались или не прятались: threat оказывался невалиден,
## и существо уходило в WANDER вместо FLEE/HIDE.
func _on_Damaged(new_health: float) -> void:
	can_flee = true
	var threat := _nearest_player()
	if is_instance_valid(threat):
		target = threat
		_has_direct_sense = _can_sense(threat)
		_last_known_pos = threat.global_position
		_memory_timer = memory_duration
		_enter_fear_response()
	else:
		# Игрока рядом нет вообще (урон не от игрока) — просто отходим от дома.
		_enter_state(State.WANDER)

func _nearest_player() -> Node2D:
	var nearest: Node2D = null
	var best_dist_sq := INF
	for p in get_tree().get_nodes_in_group("Player"):
		if p is Node2D:
			var d := global_position.distance_squared_to(p.global_position)
			if d < best_dist_sq:
				best_dist_sq = d
				nearest = p
	return nearest
