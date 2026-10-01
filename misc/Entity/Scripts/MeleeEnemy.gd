@tool
extends Entity
class_name MeleeEnemy


@onready var hit_box : HitBox = $HitBox
#@onready var screen_not : optimizer = $optimize
@onready var health_bar: ProgressBar = $HealthBar
@onready var explosion: GPUParticles2D = $Explosion
@onready var drop: Dropper = $Drop

# Максимальное смещение точки, к которой идёт враг (в пикселях вокруг игрока)
@export var walk_offset : float = 2.5
# Как часто (в секундах) враг выбирает новое смещение. Чем больше, тем плавнее и «осознаннее» движение
@export var offset_interval : float = 1.0
# Радиус поля зрения. При изменении в инспекторе круг в редакторе перерисовывается сразу
@export var line_of_sight : float = 30:
	set(value):
		line_of_sight = value
		queue_redraw()
### when life less 35%, ennemy flee
@export var can_fear : bool = false
@export var attack_parameter : equip_data
# Радиус атаки (тоже рисуется в редакторе)
@export var attack_range : float = 20:
	set(value):
		attack_range = value
		queue_redraw()
# Пауза между ударами (сек) после окончания анимации атаки. 0 — бить сразу же, без паузы
@export var attack_cooldown : float = 0.5
# Множитель скорости: move_speed из статов умножается на него (раньше было "* 100")
@export var speed_multiplier : float = 10
# Если true — враг, однажды заметив игрока, преследует его и за пределами поля зрения
@export var continue_follow_target : bool = false

@export_group("nodes")
@export var skin : Node2D 
@export var body_anim : AnimationPlayer
@export var hand_anim : AnimationPlayer

@export_group("Debug Draw")
# Показывать ли зоны в редакторе
@export var show_gizmos : bool = true:
	set(value):
		show_gizmos = value
		queue_redraw()
@export var sight_color : Color = Color(1.0, 0.85, 0.2, 1.0):
	set(value):
		sight_color = value
		queue_redraw()
@export var attack_color : Color = Color(1.0, 0.2, 0.2, 1.0):
	set(value):
		attack_color = value
		queue_redraw()

var target
var target_detected : bool = false

# Идёт ли сейчас удар (как player.is_attack у игрока)
var is_attack : bool = false
var _attack_cooldown_left : float = 0.0

# Текущее смещение цели и таймер до выбора следующего
var _offset : Vector2 = Vector2.ZERO
var _offset_timer : float = 0.0

func _ready():
	# В редакторе игровую логику не запускаем
	if Engine.is_editor_hint():
		queue_redraw()
		return

	super._ready()
	hit_box.equip = attack_parameter
	target = get_tree().get_first_node_in_group("Player")

	# Случайный старт таймера, чтобы разные враги не меняли смещение одновременно
	_offset_timer = randf_range(0.0, offset_interval)

	health_bar.visible = false
	health_bar.max_value = Entity_stats.max_health
	health_bar.value     = Entity_stats.max_health
	
	health_changed.connect(_on_health_changed)
	died.connect(_on_die)

func _draw() -> void:
	# Рисуем только в редакторе, в игре зоны не видны
	if not Engine.is_editor_hint() or not show_gizmos:
		return

	# Поле зрения: полупрозрачная заливка + контур
	draw_circle(Vector2.ZERO, line_of_sight, Color(sight_color, 0.12))
	draw_arc(Vector2.ZERO, line_of_sight, 0.0, TAU, 64, Color(sight_color, 0.8), 1.0)

	# Дистанция атаки
	draw_circle(Vector2.ZERO, attack_range, Color(attack_color, 0.15))
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(attack_color, 0.9), 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)

	# Если игрока нет (не найден или удалён) — стоим на месте
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		_animate()
		return

	var distance : float = global_position.distance_to(target.global_position)

	# Заметили игрока — запоминаем. Если преследование вне зоны видимости выключено — забываем
	if distance <= line_of_sight:
		target_detected = true
	elif not continue_follow_target:
		target_detected = false

	# Удар уже идёт: стоим на месте, пока не доиграет анимация атаки (как у игрока)
	if is_attack:
		if _is_attacking():
			velocity = Vector2.ZERO
			move_and_slide()
			_animate()
			return
		_finish_attack()

	if target_detected and _is_scared():
		# Мало здоровья — убегаем (даже если игрок в радиусе атаки)
		_move_to_player(delta)
	elif distance <= attack_range:
		# Игрок в радиусе атаки: останавливаемся, смотрим на него и бьём, когда пауза прошла
		velocity = Vector2.ZERO
		_face(target.global_position.x - global_position.x)
		if _attack_cooldown_left <= 0.0:
			_attack()
	elif target_detected:
		_move_to_player(delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_animate()


func _is_scared() -> bool:
	return can_fear and Entity_stats.current_health <= Entity_stats.max_health / 3


# ─────────────────────────────────────────────────────────────────────────────
#  Удар — по логике удара игрока (PlayerCombat.handle_input):
#  1) HitBox поворачивается к цели, 2) is_attack = true,
#  3) скорость анимации = Atk_speed, 4) запуск play_anim из оружия,
#  5) по окончании анимации is_attack сбрасывается.
# ─────────────────────────────────────────────────────────────────────────────

func _attack() -> void:
	if not hand_anim or not attack_parameter:
		return

	# Направление удара фиксируется на момент замаха — игрок может уклониться
	hit_box.look_at(target.global_position)
	_face(target.global_position.x - global_position.x)

	is_attack = true
	hand_anim.speed_scale = attack_parameter.Atk_speed
	hand_anim.play(str(attack_parameter.play_anim))


func _finish_attack() -> void:
	is_attack = false
	_attack_cooldown_left = attack_cooldown
	if hand_anim:
		hand_anim.speed_scale = 1.0


func _is_attacking() -> bool:
	if not hand_anim or not attack_parameter:
		return false
	return hand_anim.is_playing() and hand_anim.current_animation == str(attack_parameter.play_anim)


func _face(dir_x: float) -> void:
	if dir_x != 0 and skin:
		skin.scale.x = -1 if dir_x < 0 else 1


func _animate() -> void:
	var anim_name : String = "Walk" if velocity.length() > 0.0 else "Idle"

	if body_anim and body_anim.current_animation != anim_name:
		body_anim.play(anim_name)

	# Пока играет атака, не перебиваем её Walk/Idle
	if hand_anim and not _is_attacking() and hand_anim.current_animation != anim_name:
		hand_anim.play(anim_name)


func _move_to_player(delta: float) -> void:
	_update_offset(delta)

	# Единичный вектор направления к точке рядом с игроком (со смещением)
	var direction : Vector2 = global_position.direction_to(target.global_position + _offset)
	velocity = direction * Entity_stats.move_speed * speed_multiplier

	if _is_scared():
		velocity = -direction * Entity_stats.move_speed * speed_multiplier * 1.5
	else:
		velocity = direction * Entity_stats.move_speed * speed_multiplier

	# Разворачиваем спрайт в сторону фактического движения (при бегстве — от игрока)
	_face(velocity.x)
		

func _update_offset(delta: float) -> void:
	# Новое смещение выбираем не каждый кадр, а раз в offset_interval секунд —
	# так враг не дёргается, а идёт по плавной дуге
	_offset_timer -= delta
	if _offset_timer > 0.0:
		return

	# Случайная точка внутри круга радиусом walk_offset вокруг игрока
	_offset = Vector2.from_angle(randf() * TAU) * randf_range(0.0, walk_offset)
	_offset_timer = offset_interval * randf_range(0.7, 1.3)

func _on_health_changed(new_health):
	print("Current Health" + str(Entity_stats.current_health) + " Max Health " + str(Entity_stats.max_health) + "Scare Health value" + str(Entity_stats.max_health / 3) )
	health_bar.visible = true
	if new_health > 0:
		health_bar.value = new_health
	elif new_health <= 0:
		health_bar.visible = false

func _on_die():
	# Мёртвый враг не ходит и не бьёт (иначе _attack() обратится к уже удалённому hit_box)
	set_physics_process(false)
	velocity = Vector2.ZERO

	if is_instance_valid(hit_box):
		hit_box.queue_free()
	if explosion:
		explosion.restart()
		explosion.emitting = true
	if skin:
		skin.visible = false
	if drop:
		drop._drop_items()
	if is_in_group("Creature"):
		remove_from_group("Creature")

	await get_tree().create_timer(1.5).timeout
	queue_free()
