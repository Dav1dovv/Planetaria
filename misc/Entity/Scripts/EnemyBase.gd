@tool
extends Entity
class_name EnemyBase
## Базовый класс врагов: поиск игрока, зрение, полоска здоровья, смерть, стрельба.
## Наследники описывают только поведение: _ai(), _animate() и _get_attack_player().


@onready var hit_box : HitBox = $HitBox
@onready var health_bar: ProgressBar = $HealthBar
@onready var explosion: GPUParticles2D = $Explosion
@onready var drop: Dropper = $Drop

# Радиус поля зрения. При изменении в инспекторе круг в редакторе перерисовывается сразу
@export var line_of_sight : float = 30:
	set(value):
		line_of_sight = value
		queue_redraw()
# Если true — враг, однажды заметив игрока, преследует его и за пределами поля зрения
@export var continue_follow_target : bool = false
### when life less 33%, ennemy flee
@export var can_fear : bool = false
# Множитель скорости: move_speed из статов умножается на него
@export var speed_multiplier : float = 10

@export_group("Attack")
# Оружие/атака врага: урон, скорость анимации, снаряд, разброс и т.д.
@export var attack_parameter : equip_data
# Дистанция атаки / стрельбы (тоже рисуется в редакторе). Держи её не больше line_of_sight
@export var attack_range : float = 20:
	set(value):
		attack_range = value
		queue_redraw()
# Пауза (сек) после окончания анимации атаки до следующей. 0 — без паузы
@export var attack_cooldown : float = 0.5

@export_group("Shooting")
# Откуда вылетают снаряды. Если не задан — из центра врага
@export var muzzle : Marker2D
# Смещение точки прицеливания относительно позиции игрока (например (0, -8) — целиться в корпус)
@export var aim_offset : Vector2 = Vector2.ZERO

@export_group("nodes")
@export var skin : Node2D

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

# Идёт ли сейчас атака (как player.is_attack у игрока)
var is_attack : bool = false
var _attack_cooldown_left : float = 0.0

# Диагностика: был ли вызван shoot() за время текущей атаки и какие предупреждения уже выводились
var _shot_fired : bool = false
var _warned : Dictionary = {}


func _ready():
	# В редакторе игровую логику не запускаем
	if Engine.is_editor_hint():
		queue_redraw()
		return

	super._ready()
	target = get_tree().get_first_node_in_group("Player")

	if hit_box and attack_parameter:
		hit_box.equip = attack_parameter

	health_bar.visible = false
	health_bar.max_value = Entity_stats.max_health
	health_bar.value     = Entity_stats.max_health

	health_changed.connect(_on_health_changed)
	died.connect(_on_die)

	_setup()


# ─────────────────────────────────────────────────────────────────────────────
#  Методы для переопределения в наследниках
# ─────────────────────────────────────────────────────────────────────────────

## Дополнительная инициализация наследника (вызывается в конце _ready)
func _setup() -> void:
	pass

## Логика поведения: задать velocity и при необходимости запустить _attack().
## move_and_slide() и _animate() вызываются после неё в базовом классе.
func _ai(_delta: float, _distance: float) -> void:
	pass

## Обновление анимаций
func _animate() -> void:
	pass

## AnimationPlayer, в котором проигрывается анимация атаки
func _get_attack_player() -> AnimationPlayer:
	return null

## Рисовать ли круг дистанции атаки в редакторе
func _shows_attack_range() -> bool:
	return true


# ─────────────────────────────────────────────────────────────────────────────
#  Основной цикл
# ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)

	# Если игрока нет (не найден или удалён) — стоим на месте
	if not is_instance_valid(target):
		_warn_once("игрок не найден (нужен узел в группе Player)")
		velocity = Vector2.ZERO
		_animate()
		return

	var distance : float = global_position.distance_to(target.global_position)

	# Заметили игрока — запоминаем. Если преследование вне зоны видимости выключено — забываем
	if distance <= line_of_sight:
		target_detected = true
	elif not continue_follow_target:
		target_detected = false

	# Анимация атаки доиграла — заканчиваем атаку
	if is_attack and not _is_attacking():
		_finish_attack()

	_ai(delta, distance)

	move_and_slide()
	_animate()


func _draw() -> void:
	# Рисуем только в редакторе, в игре зоны не видны
	if not Engine.is_editor_hint() or not show_gizmos:
		return

	# Поле зрения: полупрозрачная заливка + контур
	draw_circle(Vector2.ZERO, line_of_sight, Color(sight_color, 0.12))
	draw_arc(Vector2.ZERO, line_of_sight, 0.0, TAU, 64, Color(sight_color, 0.8), 1.0)

	# Дистанция атаки
	if _shows_attack_range():
		draw_circle(Vector2.ZERO, attack_range, Color(attack_color, 0.15))
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(attack_color, 0.9), 1.0)


# ─────────────────────────────────────────────────────────────────────────────
#  Атака (запуск и завершение анимации)
# ─────────────────────────────────────────────────────────────────────────────

func _attack() -> void:
	var attack_player := _get_attack_player()
	if not attack_player:
		_warn_once("не назначен AnimationPlayer атаки (hand_anim / anim) в инспекторе")
		return
	if not attack_parameter:
		_warn_once("не задан attack_parameter")
		return
	if not attack_player.has_animation(str(attack_parameter.play_anim)):
		_warn_once("в AnimationPlayer нет анимации '%s' (attack_parameter.play_anim)" % str(attack_parameter.play_anim))
		return

	_face(target.global_position.x - global_position.x)

	_shot_fired = false
	is_attack = true
	attack_player.speed_scale = attack_parameter.Atk_speed
	attack_player.play(str(attack_parameter.play_anim))


func _finish_attack() -> void:
	if not _shot_fired and attack_parameter and attack_parameter.projectile:
		_warn_once("анимация атаки закончилась, но shoot() не вызывался — добавь в неё Call Method Track с методом shoot()")
	is_attack = false
	_attack_cooldown_left = attack_cooldown
	var attack_player := _get_attack_player()
	if attack_player:
		attack_player.speed_scale = 1.0


func _is_attacking() -> bool:
	var attack_player := _get_attack_player()
	if not attack_player or not attack_parameter:
		return false
	return attack_player.is_playing() and attack_player.current_animation == str(attack_parameter.play_anim)


# ─────────────────────────────────────────────────────────────────────────────
#  Стрельба
# ─────────────────────────────────────────────────────────────────────────────

## Вызывается из анимации атаки (Call Method Track) в момент вылета снаряда.
func shoot() -> void:
	# Call Method Track срабатывает и при просмотре анимации в редакторе — там стрелять не нужно
	if Engine.is_editor_hint():
		return
	_shot_fired = true
	if not attack_parameter or not attack_parameter.projectile:
		_warn_once("в attack_parameter не задан projectile (сцена снаряда)")
		return
	if not is_instance_valid(target):
		return

	var origin : Vector2 = muzzle.global_position if muzzle else global_position
	var to_target : Vector2 = (target.global_position + aim_offset) - origin

	# Если цель почти в самом дуле — стреляем туда, куда смотрит враг
	var facing_x : float = -1.0 if (skin and skin.scale.x < 0.0) else 1.0
	var base_dir : Vector2 = to_target.normalized() if to_target.length() > 1.0 else Vector2(facing_x, 0.0)

	for i in attack_parameter.num_projectiles:
		var bullet := attack_parameter.projectile.instantiate() as Projectile
		if bullet == null:
			push_warning("EnemyBase: корневой узел сцены снаряда должен быть Projectile")
			return

		bullet.owner_player = self
		bullet.shot_target  = "Player"

		# Сначала в дерево, потом setup: иначе @onready-узлы снаряда ещё не готовы
		get_parent().add_child(bullet)
		bullet.setup(
			origin,
			base_dir.rotated((randf() - 0.5) * deg_to_rad(attack_parameter.spread_degrees)),
			attack_parameter.Damage,
			#attack_parameter.projectile_speed,
		)


## Предупреждение в консоль, один раз на каждый текст (чтобы не засорять вывод каждым кадром)
func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	push_warning("%s: %s" % [name, message])


# ─────────────────────────────────────────────────────────────────────────────
#  Движение
# ─────────────────────────────────────────────────────────────────────────────

func _get_speed() -> float:
	return Entity_stats.move_speed * speed_multiplier


func _is_scared() -> bool:
	return can_fear and Entity_stats.current_health <= Entity_stats.max_health / 3.0


## Идти к игроку. offset смещает точку цели (для «живого» движения)
func _move_to_target(offset: Vector2 = Vector2.ZERO) -> void:
	var direction : Vector2 = global_position.direction_to(target.global_position + offset)
	velocity = direction * _get_speed()
	_face(velocity.x)


## Убегать от игрока
func _move_away_from_target(speed_mult: float = 1.0) -> void:
	var direction : Vector2 = target.global_position.direction_to(global_position)
	velocity = direction * _get_speed() * speed_mult
	# Смотрим туда, куда реально движемся (при бегстве — от игрока)
	_face(velocity.x)


func _face(dir_x: float) -> void:
	if dir_x != 0 and skin:
		skin.scale.x = -1 if dir_x < 0 else 1


# ─────────────────────────────────────────────────────────────────────────────
#  Здоровье и смерть
# ─────────────────────────────────────────────────────────────────────────────

func _on_health_changed(new_health):
	health_bar.visible = true
	if new_health > 0:
		health_bar.value = new_health
	else:
		health_bar.visible = false


func _on_die():
	# Мёртвый враг не ходит и не атакует
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
