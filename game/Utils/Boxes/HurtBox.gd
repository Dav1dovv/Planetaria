@tool
extends RapierArea2D
class_name HurtBox

signal damage_taken
# NodePath вместо Node2D — безопасно в @tool режиме
@export var Path_to_stat : NodePath = NodePath("..")

func _init() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(5, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(4, true)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if get_parent().has_signal("health_changed"):
		get_parent().connect("health_changed", damaged)

## Окно неуязвимости игрока после удара (враги берут invincibility_duration у себя)
const PLAYER_LOCK_TIME := 1.0

var _last_health: float = -1.0
var _lock_id: int = 0

func damaged(new_health) -> void:
	# health_changed приходит и при лечении — это не урон, окно не включаем
	var hp := float(new_health)
	var healed := _last_health >= 0.0 and hp >= _last_health
	_last_health = hp
	if healed:
		return

	var shape := get_child(0) as CollisionShape2D
	if shape == null:
		return

	# У врагов окно было фиксированной 1 секундой и «съедало» быстрые удары —
	# теперь оно равно их собственным i-frames (Entity.invincibility_duration).
	var parent := get_parent()
	var lock := PLAYER_LOCK_TIME
	if parent and not parent.is_in_group("Player") and "invincibility_duration" in parent:
		lock = maxf(float(parent.invincibility_duration), 0.05)

	# set_deferred: сигнал приходит изнутри физического запроса, прямое изменение запрещено
	shape.set_deferred("disabled", true)
	_lock_id += 1
	var my_id := _lock_id
	await get_tree().create_timer(lock).timeout
	if my_id == _lock_id and is_instance_valid(shape):
		shape.set_deferred("disabled", false)
	emit_signal("damage_taken")
