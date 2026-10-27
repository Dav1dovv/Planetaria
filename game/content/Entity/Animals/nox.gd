extends Creature
class_name Nox

var player_in_fear_zone: bool = false

## Кого именно боимся — храним отдельно от общего "target", потому что общий target
## может быть сброшен обычной state-machine (потеря памяти/дистанции) пока игрок
## всё ещё физически стоит в Fearzone. Раньше _on_timer_timeout ссылался только
## на target и от этого переставал пугаться раньше времени.
var _feared_by: Node2D = null

func _on_fearzone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	_feared_by = body
	$Timer.start()
	player_in_fear_zone = true
	can_flee = true
	target = body
	_has_direct_sense = true
	_last_known_pos = body.global_position
	_memory_timer = memory_duration
	_enter_fear_response()

func _on_fearzone_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_fear_zone = false
		_feared_by = null
		$Timer.stop()


func _on_timer_timeout() -> void:
	if player_in_fear_zone and is_instance_valid(_feared_by):
		can_flee = true
		target = _feared_by
		_has_direct_sense = true
		_last_known_pos = _feared_by.global_position
		_memory_timer = memory_duration
		_enter_fear_response()
		$Timer.start()
