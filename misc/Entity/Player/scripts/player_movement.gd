extends Node
class_name PlayerMovement
## Компонент движения игрока.
## Отвечает за обычную ходьбу (ускорение/трение) и авто-ход после
## прохода через дверь (exit walk).
##
## Сюда же добавляй новые виды перемещения (дэш, рывок по канату и т.п.) —
## просто новый метод + флаг, который проверяется в process().

@export var standart_speed: float = 15.0
@export var slow_speed:     float = 8.0
@export var dash_speed:     float = 20.0

@export_range(0.01, 1.0, 0.01) var acceleration: float = 0.20
@export_range(0.01, 1.0, 0.01) var friction:     float = 0.45

## Текущая "плавная" скорость. Комбат (lunge) синхронизируется с ней
## через sync_after_lunge(), чтобы не было рывка при возврате к ходьбе.
var current_velocity: Vector2 = Vector2.ZERO

var _exit_walk_active:     bool    = false
var _exit_walk_timer:      float   = 0.0
var _exit_walk_direction:  Vector2 = Vector2.ZERO
var _exit_walk_speed_mult: float   = 0.7

@onready var player: Player = get_parent()


func process(delta: float) -> Vector2:
	## Вызывается из Player._physics_process() каждый физ. кадр (когда игрок
	## не в рывке). Возвращает итоговую velocity — Player сам присваивает
	## её своему velocity и делает move_and_slide().
	if _exit_walk_active:
		_update_exit_walk(delta)
	else:
		_move(delta)
	return current_velocity


func _move(delta: float) -> void:
	if Global.is_opened_menu:
		current_velocity = current_velocity.lerp(Vector2.ZERO, friction)
		return

	player.dir = Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").normalized()
	var target_velocity := player.dir * player.Entity_stats.move_speed * standart_speed

	if player.dir != Vector2.ZERO:
		current_velocity = current_velocity.lerp(target_velocity, acceleration)
	else:
		current_velocity = current_velocity.lerp(Vector2.ZERO, friction)

	_update_skin_facing(player.dir)


func _update_skin_facing(dir: Vector2) -> void:
	if player.is_attack:
		player.skin.scale.x = player.scale.x if player.mouse_pos.x > player.position.x else -player.scale.x
	elif dir.x > 0:
		player.skin.scale.x = 1
	elif dir.x < 0:
		player.skin.scale.x = -1


func sync_after_lunge(new_velocity: Vector2) -> void:
	## Вызывается из PlayerCombat.end_lunge(), чтобы плавная скорость
	## продолжилась с той, что была в момент окончания рывка.
	current_velocity = new_velocity


# ─────────────────────────────────────────────────────────────────────────────
#  Exit walk (автоход после перехода через дверь)
# ─────────────────────────────────────────────────────────────────────────────

func activate_exit_walk(direction: Vector2, duration: float, speed_mult: float) -> void:
	_exit_walk_direction  = direction
	_exit_walk_timer      = duration
	_exit_walk_speed_mult = speed_mult
	_exit_walk_active     = true


func try_resume_pending_exit_walk() -> void:
	## Вызывается из Player._ready(): если игрок только что зашёл через
	## дверь и остался отложенный exit walk в Global — подхватываем его.
	if Global.get("pending_exit_walk") and Global.pending_exit_walk["active"]:
		var d := Global.pending_exit_walk
		activate_exit_walk(d["direction"], d["duration"], d["speed_mult"])
		Global.pending_exit_walk["active"] = false


func _update_exit_walk(delta: float) -> void:
	_exit_walk_timer -= delta
	if _exit_walk_timer <= 0.0:
		_exit_walk_active = false
		return

	var target_vel := _exit_walk_direction * player.Entity_stats.move_speed \
		* standart_speed * _exit_walk_speed_mult
	current_velocity = current_velocity.lerp(target_vel, acceleration)

	if _exit_walk_direction.x > 0:
		player.skin.scale.x = 1
	elif _exit_walk_direction.x < 0:
		player.skin.scale.x = -1
