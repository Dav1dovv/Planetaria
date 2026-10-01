@tool
extends EnemyBase
class_name RangedEnemy
## Дальний враг: подходит на дистанцию attack_range, останавливается и стреляет.
## Сам выстрел происходит в методе shoot() — вызови его Call Method Track'ом
## в анимации атаки (hand_anim) в нужном кадре.


# Если игрок ближе этой дистанции — враг пятится (0 = не пятится)
@export var retreat_distance : float = 0.0
# Максимальное смещение точки, к которой идёт враг (в пикселях вокруг игрока)
@export var walk_offset : float = 2.5
# Как часто (в секундах) враг выбирает новое смещение
@export var offset_interval : float = 1.0

@export_group("animators")
@export var body_anim : AnimationPlayer
@export var hand_anim : AnimationPlayer

@export_group("shooting")
## Точка вылета снаряда. Помести Marker2D внутрь skin (на руку/оружие),
## чтобы он разворачивался вместе с врагом
@export var shot_marker : Marker2D
# Текущее смещение цели и таймер до выбора следующего
var _offset : Vector2 = Vector2.ZERO
var _offset_timer : float = 0.0


func _init() -> void:
	# Значения по умолчанию для дальнего врага: видит и стреляет дальше, чем ближний
	line_of_sight = 160.0
	attack_range = 120.0


func _setup() -> void:
	# Случайный старт таймера, чтобы разные враги не меняли смещение одновременно
	_offset_timer = randf_range(0.0, offset_interval)


func _ai(delta: float, distance: float) -> void:
	# Идёт выстрел — стоим на месте, пока не доиграет анимация
	if is_attack:
		velocity = Vector2.ZERO
		return

	if target_detected and _is_scared():
		# Мало здоровья — убегаем
		_move_away_from_target(1.5)
	elif target_detected and retreat_distance > 0.0 and distance < retreat_distance:
		# Игрок слишком близко — держим дистанцию
		_move_away_from_target()
	elif target_detected and distance <= attack_range:
		# В зоне стрельбы: останавливаемся, смотрим на игрока и стреляем, когда пауза прошла
		velocity = Vector2.ZERO
		_face(target.global_position.x - global_position.x)
		if _attack_cooldown_left <= 0.0:
			_attack()
	elif target_detected:
		_update_offset(delta)
		_move_to_target(_offset)
	else:
		velocity = Vector2.ZERO


func _get_attack_player() -> AnimationPlayer:
	return hand_anim


func _animate() -> void:
	var anim_name : String = "Walk" if velocity.length() > 0.0 else "Idle"

	if body_anim and body_anim.current_animation != anim_name:
		body_anim.play(anim_name)

	# Пока играет атака, не перебиваем её Walk/Idle
	if hand_anim and not _is_attacking() and hand_anim.current_animation != anim_name:
		hand_anim.play(anim_name)


func _update_offset(delta: float) -> void:
	# Новое смещение выбираем не каждый кадр, а раз в offset_interval секунд —
	# так враг не дёргается, а идёт по плавной дуге
	_offset_timer -= delta
	if _offset_timer > 0.0:
		return

	# Случайная точка внутри круга радиусом walk_offset вокруг игрока
	_offset = Vector2.from_angle(randf() * TAU) * randf_range(0.0, walk_offset)
	_offset_timer = offset_interval * randf_range(0.7, 1.3)
