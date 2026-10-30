@icon("res://addons/at-icons/mesh/arrow_projectile.svg")
extends RapierCharacterBody2D
class_name Projectile
## Снаряд. «Пинг-понг» (настраивается на каждой сцене снаряда):
##  • РИКОШЕТ — max_bounces: 0 = уничтожается при первом контакте, N = N отскоков от
##    стен/существ/заражения, -1 = пока не кончится жизнь. Каждый отскок слегка
##    подкручивает пулю и усиливает урон (розыгрыш, как в пинг-понге).
##  • ОТБИВАНИЕ — пулю врага можно ударить оружием (ЛКМ): она летит туда, куда вы
##    целились, и бьёт уже врагов (включая стрелка).
##  • ПУЛИ ВРАГОВ бьют любых существ (hurts_all_creatures) и взрываются от огня
##    лагеря (explodes_in_fire).
##  • ЗАРАЖЕНИЕ — corruption_contact: пуля уничтожается или отскакивает от него
##    (то же у самого заражения: CorruptionOrb.bullet_contact).

# Сигнал попадания по цели — PlayerCombat использует его для эффектов оружия (on-hit)
signal hit_target(target: Node)
signal bounced(count: int)
signal deflected_by_player

@export var speed: float = 400.0
@export var lifetime: float = 5.0
@export var damage: float = 25.0

@export_enum("normal", "boomerang", "bomb") var projectile_type: String = "normal"
@export_enum("Player","Ennemy") var shot_target : String = "Player"

@export var explosion_radius: float = 80.0
@export var explode_on_hit: bool = true
@export var bomb_timer: float = 2.5
@export var homing_strength: float = 3.0      # Для бумеранга — сила притяжения при возврате
@export var max_travel_distance: float = 600.0  # Для бумеранга — когда начинать возвращаться

@export_group("Fade out")
## Длительность плавного исчезновения в конце жизни снаряда
@export var fade_duration: float = 0.4
## Замедлять ли снаряд во время исчезновения
@export var slow_down_on_fade: bool = true

@export_group("Collision layers")
## Слой HurtBox врагов — его видят пули игрока (shot_target = "Ennemy")
@export_range(1, 32) var enemy_hurtbox_layer : int = 5
## Слой HurtBox игрока — его видят пули врагов (shot_target = "Player").
## ВАЖНО: поставь номер слоя, на котором лежит HurtBox игрока
@export_range(1, 32) var player_hurtbox_layer : int = 6

@export_group("Ping-pong: рикошет")
## 0 — уничтожается при первом контакте; N — отскакивает N раз; -1 — без ограничения
@export var max_bounces: int = 0
## Стены: auto = пуля с рикошетом отскакивает, без рикошета — разбивается о стену;
## бомбы и бумеранги в auto стены игнорируют (как раньше). ignore/destroy/bounce — принудительно.
@export_enum("auto", "ignore", "destroy", "bounce") var wall_behavior: String = "auto"
## Слой стен (тайлы). Тела существ на нём же — они пропускаются автоматически
@export_flags_2d_physics var wall_mask: int = 1
## Отскакивать ли от существа после попадания (если отскоки остались)
@export var bounce_off_creatures: bool = true
## Скорость после отскока: 0.9 — теряет, 1.0 — сохраняет, >1 — ускоряется
@export_range(0.3, 1.5, 0.05) var bounce_energy: float = 0.9
## Прибавка урона за каждый отскок/отбивание
@export_range(0.0, 1.0, 0.05) var bounce_damage_gain: float = 0.15
## Подкрутка после отскока (рад/с, гаснет): пуля слегка заворачивает, как мяч с «винтом»
@export var bounce_spin: float = 1.2
## Случайный разброс угла отскока, градусы
@export var bounce_jitter_deg: float = 4.0
## Что делает пуля при касании заражения: уничтожается или отскакивает
@export_enum("destroy", "bounce") var corruption_contact: String = "destroy"
@export var sfx_bounce: AudioStream

@export_group("Ping-pong: отбивание оружием")
## Можно ли отбить пулю врага ударом оружия игрока
@export var deflectable: bool = true
## Во сколько раз зона «ракетки» шире самой пули (прощает неточность)
@export_range(1.0, 3.0, 0.1) var deflect_box_scale: float = 1.6
@export_range(0.0, 1.0, 0.05) var deflect_precision: float = 0.85
@export var deflect_speed_gain: float = 1.15
@export var max_speed: float = 520.0
## Какая доля урона оружия игрока добавляется к урону отбитой пули
@export_range(0.0, 2.0, 0.05) var deflect_damage_share: float = 0.5
## Сколько ещё живёт отбитая пуля
@export var deflect_lifetime: float = 1.8
@export var deflect_poise: float = 20.0
@export var friendly_tint: Color = Color(0.6, 1.4, 1.6)
@export var rally_cap: int = 5

@export_group("Пули врагов: урон всем и огонь")
## Пуля врага бьёт любых существ на пути, а не только игрока (после первого отскока —
## и самого стрелка). Действует на пули с shot_target = "Player"
@export var hurts_all_creatures: bool = true
## Взрывается, коснувшись огня лагеря (пули врагов; отбитые тоже)
@export var explodes_in_fire: bool = true
@export var fire_explosion_radius: float = 48.0
@export var fire_explosion_multiplier: float = 2.0

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var bomb_timer_node: Timer = $BombTimer
@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D          # ← Обязательно назови спрайт так в сцене!
@onready var hit_particles: GPUParticles2D = $HitParticles  # Опционально
@onready var explosion_particles: GPUParticles2D = $ExplosionParticles  # Опционально

## Стойкость, которую снимает попадание (ставит PlayerCombat из оружия; у вражеских = 0)
var poise_damage: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var owner_player: Node2D = null   # Player или враг, выстреливший снаряд
var start_position: Vector2
var has_returned: bool = false
var is_exploded: bool = false
var is_fading: bool = false

var _origin_hostile: bool = false      # изначально выпущена врагом
var _bounces_done: int = 0
var _rally: int = 0
var _bonus_damage: float = 0.0
var _spin: float = 0.0
var _owner_hittable: bool = false
var _deflect_lock: float = 0.0
var _radius: float = 4.0
var _sprite_scale: Vector2 = Vector2.ONE
var _squash_tween: Tween


func _ready() -> void:
	_origin_hostile = shot_target == "Player"
	if sprite:
		_sprite_scale = sprite.scale
	var shape_node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CircleShape2D:
		_radius = (shape_node.shape as CircleShape2D).radius

	# Настройка слоёв (пуля игрока)
	area.set_collision_layer_value(1, false)
	area.set_collision_layer_value(4, true)   # HitBox layer
	area.set_collision_mask_value(1, false)
	# Видим HurtBox своей цели: игрока (для пуль врагов) или врагов (для пуль игрока)
	var target_layer : int = player_hurtbox_layer if shot_target == "Player" else enemy_hurtbox_layer
	area.set_collision_mask_value(target_layer, true)    # HurtBox layer
	# Пуля врага бьёт и остальных существ (дружественный огонь)
	if _origin_hostile and hurts_all_creatures:
		area.set_collision_mask_value(enemy_hurtbox_layer, true)

	area.area_entered.connect(_on_area_entered)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	# Подключаем, только если сигнал ещё не подключён через редактор сцены
	if not lifetime_timer.timeout.is_connected(_on_lifetime_timer_timeout):
		lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	lifetime_timer.start()

	# Таймер для бомбы
	if projectile_type == "bomb":
		bomb_timer_node.wait_time = bomb_timer
		bomb_timer_node.one_shot = true
		bomb_timer_node.timeout.connect(_explode)
		bomb_timer_node.start()

	if _origin_hostile and deflectable and projectile_type != "boomerang":
		_create_deflect_box()
	if explodes_in_fire and _origin_hostile:
		_create_fire_sensor()


func get_poise_damage() -> float:
	return poise_damage


## Маркер для PlayerHitBox: удар по мячу не стирает прочность оружия.
func is_ping_pong_ball() -> bool:
	return true


func setup(
		start_pos: Vector2,
		dir: Vector2,
		dmg: float,
	) -> void:

	global_position = start_pos
	start_position = start_pos
	direction = dir
	damage = dmg

	# Сразу поворачиваем спрайт
	if sprite:
		sprite.rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if is_exploded:
		return
	_deflect_lock = maxf(0.0, _deflect_lock - delta)

	# === Бумеранг: прямо вперёд → разворот → возврат к игроку ===
	# Во время исчезновения бумеранг уже не наводится на игрока
	if projectile_type == "boomerang" and not is_fading:
		if not has_returned and global_position.distance_to(start_position) >= max_travel_distance:
			has_returned = true

		if has_returned and owner_player:
			# Летим прямо к текущей позиции игрока
			direction = (owner_player.global_position - global_position).normalized()

	# Подкрутка после отскока: курс плавно заворачивает и успокаивается
	if absf(_spin) > 0.01:
		direction = direction.rotated(_spin * delta)
		_spin *= exp(-2.5 * delta)

	# Стены: отскок или разрушение (до движения, чтобы не пролететь сквозь)
	var wall_mode := _wall_mode()
	if wall_mode != "ignore" and not is_fading:
		var step := direction * speed * delta
		if step.length_squared() > 0.0 and _handle_wall(step, wall_mode):
			return

	# Вычисляем скорость уже после изменения direction
	var vel = direction * speed

	# === Обновляем ротацию спрайта ===
	if sprite:
		if projectile_type == "boomerang":
			sprite.rotation += 5.0 * delta  # Крутится вокруг своей оси
		else:
			sprite.rotation = direction.angle()

	# Движение
	velocity = vel
	move_and_slide()


# ═════════════════════════════════════════════════════════════════════
#  СТОЛКНОВЕНИЯ
# ═════════════════════════════════════════════════════════════════════
func _on_area_entered(hit_area: Area2D) -> void:
	# Исчезающий снаряд уже не наносит урон
	if is_fading:
		return

	var victim := hit_area.get_parent()
	# Пули друг друга не трогают (зона «ракетки» тоже принадлежит пуле)
	if victim is Projectile:
		return

	# Не бьём своего владельца (пока он не стал законной целью после отскока)
	if victim == owner_player and not _owner_hittable:
		if projectile_type == "boomerang" and has_returned:
			# Поймали бумеранг — уничтожаем
			queue_free()
		return

	# Бумеранг на обратном пути не наносит урон повторно
	if projectile_type == "boomerang" and has_returned:
		return

	# Заражение: уничтожение или отскок — настраивается
	if hit_area.is_in_group("corruption"):
		_on_corruption_touch(victim)
		return

	if hit_area.is_in_group("Ennemy") or hit_area.is_in_group("Harvestable"):
		if projectile_type == "bomb" and explode_on_hit:
			_explode()
			return

	var friendly_fire := _origin_hostile and hurts_all_creatures and shot_target == "Player" \
			and hit_area.is_in_group("Ennemy") and not victim.is_in_group("NPC")
	if hit_area.is_in_group(shot_target) or friendly_fire:
		# Позицию берём до удара: цель может погибнуть и исчезнуть
		var victim_pos := _position_of(victim)
		victim.take_damage(_current_damage(), self)
		# Сообщаем о попадании (если цель не успела удалиться от урона)
		if is_instance_valid(victim):
			hit_target.emit(victim)
		_play_hit_effect()
		if projectile_type == "boomerang":
			has_returned = true
			return
		_after_contact(victim_pos, bounce_off_creatures)
	elif hit_area.is_in_group("Harvestable"):
		_play_hit_effect()
		if projectile_type == "boomerang":
			has_returned = true
			return
		_after_contact(_position_of(victim), true)
	elif projectile_type == "boomerang":
		# Бумеранг задел любой другой объект — возвращаемся
		_play_hit_effect()
		has_returned = true


## Контакт состоялся: отскочить, если разрешено и остались отскоки, иначе — уничтожиться.
func _after_contact(other_pos: Vector2, allow_bounce: bool) -> void:
	if allow_bounce and _can_bounce():
		var normal := (global_position - other_pos).normalized()
		if normal == Vector2.ZERO:
			normal = -direction
		_do_bounce(normal)
		return
	queue_free()


func _position_of(node: Node) -> Vector2:
	return (node as Node2D).global_position if node is Node2D else global_position


func _on_corruption_touch(orb: Node) -> void:
	var orb_pos := _position_of(orb)
	if orb.has_method("on_bullet_contact"):
		orb.on_bullet_contact(self)
	_play_hit_effect()
	if projectile_type == "boomerang":
		has_returned = true
		return
	_after_contact(orb_pos, corruption_contact == "bounce")


func _handle_wall(step: Vector2, mode: String) -> bool:
	var hit := PingPong.cast_wall(get_world_2d(), global_position,
			global_position + step + direction * _radius, wall_mask)
	if hit.is_empty():
		return false

	var normal: Vector2 = hit.normal
	if mode == "bounce" and _can_bounce():
		global_position = hit.position + normal * (_radius + 0.5)
		_do_bounce(normal)
		return true

	# Разбилась о стену
	global_position = hit.position
	_spark(hit.position, normal)
	_play_hit_effect()
	if projectile_type == "bomb":
		_explode()
	else:
		queue_free()
	return true


func _wall_mode() -> String:
	if wall_behavior != "auto":
		return wall_behavior
	if projectile_type != "normal":
		return "ignore"
	return "bounce" if max_bounces != 0 else "destroy"


# ═════════════════════════════════════════════════════════════════════
#  ПИНГ-ПОНГ
# ═════════════════════════════════════════════════════════════════════
func _can_bounce() -> bool:
	if max_bounces != -1 and _bounces_done >= max_bounces:
		return false
	return speed * bounce_energy >= 25.0   # совсем вялая пуля не прыгает


## Отражение от поверхности с нормалью normal: энергия, подкрутка, урон, эффекты.
func _do_bounce(normal: Vector2) -> void:
	_bounces_done += 1
	_rally = mini(_rally + 1, rally_cap)
	_owner_hittable = true

	var reflected := direction.bounce(normal)
	if direction.dot(normal) > 0.0:
		reflected = normal            # уже удалялись — просто уводим по нормали
	direction = reflected.rotated(deg_to_rad(randf_range(-bounce_jitter_deg, bounce_jitter_deg))).normalized()
	speed = minf(speed * bounce_energy, max_speed)
	_spin = randf_range(-1.0, 1.0) * bounce_spin

	_spark(global_position, normal)
	_squash(1.5)
	_play(sfx_bounce, 1.0 + 0.08 * _rally)
	bounced.emit(_bounces_done)


## Удар оружия игрока (PlayerHitBox) по зоне «ракетки» пули врага.
func take_damage(hit_damage: float, damage_source: Node2D = null, _knockback_mod: float = 0.0) -> void:
	if not deflectable or is_exploded or is_fading or _deflect_lock > 0.0:
		return
	if projectile_type == "boomerang" or not PingPong.is_player_source(damage_source):
		return
	_deflect_lock = 0.12

	if shot_target != "Ennemy":
		# Первое отбивание: пуля переходит на сторону игрока
		shot_target = "Ennemy"
		owner_player = PingPong.resolve_player(damage_source)
		poise_damage = deflect_poise
		_retarget_to_enemies()
		if sprite:
			sprite.modulate = friendly_tint
		lifetime_timer.start(deflect_lifetime)
		deflected_by_player.emit()

	_owner_hittable = true
	_rally = mini(_rally + 1, rally_cap)
	_bonus_damage = hit_damage * deflect_damage_share
	direction = PingPong.aim_direction(damage_source, global_position, deflect_precision)
	speed = clampf(speed * deflect_speed_gain, 60.0, max_speed)
	_spin = 0.0

	_spark(global_position, -direction)
	_squash(1.6)
	_play(sfx_bounce, 1.1 + 0.1 * _rally)
	GameJuice.shake(1.5 + 0.3 * _rally, 0.08)
	Rumble.confirm(_rally >= 2)


func _current_damage() -> float:
	return (damage + _bonus_damage) * (1.0 + bounce_damage_gain * _rally)


func _retarget_to_enemies() -> void:
	var mask := area.collision_mask
	mask &= ~(1 << (player_hurtbox_layer - 1))
	mask |= 1 << (enemy_hurtbox_layer - 1)
	area.set_deferred("collision_mask", mask)


## Зона «ракетки»: на слое HurtBox врагов, чтобы PlayerHitBox её видел.
func _create_deflect_box() -> void:
	var box := Area2D.new()
	box.name = "DeflectBox"
	box.collision_layer = 1 << (enemy_hurtbox_layer - 1)
	box.collision_mask = 0
	box.monitoring = false
	box.add_to_group("Ennemy")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(_radius * deflect_box_scale, 8.0)
	shape.shape = circle
	box.add_child(shape)
	add_child(box)


## Датчик огня: слой, который видит зона костра (см. camp.gd).
func _create_fire_sensor() -> void:
	var sensor := Area2D.new()
	sensor.name = "FireSensor"
	sensor.collision_layer = 16384
	sensor.collision_mask = 0
	sensor.monitoring = false
	sensor.add_to_group("explosive_projectile")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(_radius, 3.0)
	shape.shape = circle
	sensor.add_child(shape)
	add_child(sensor)


## Вызывает костёр, когда пуля влетела в огонь.
func explode_from_fire() -> void:
	if not explodes_in_fire or is_exploded or is_fading:
		return
	_explode(fire_explosion_radius, fire_explosion_multiplier)


func _explode(radius_override: float = -1.0, damage_multiplier: float = 0.8) -> void:
	if is_exploded:
		return
	is_exploded = true
	var radius := explosion_radius if radius_override < 0.0 else radius_override

	# Отключаем коллизию и движение
	set_physics_process(false)
	area.set_deferred("monitoring", false)
	if sprite:
		sprite.visible = false

	# Частицы взрыва
	if explosion_particles:
		explosion_particles.emitting = true

	# AOE урон: все существа, ресурсы, а для пуль врага — ещё и игрок
	var bodies = get_tree().get_nodes_in_group("Creature")
	bodies.append_array(get_tree().get_nodes_in_group("Harvestable"))
	if shot_target == "Player":
		bodies.append_array(get_tree().get_nodes_in_group("Player"))

	var damaged: Dictionary = {}
	for body in bodies:
		if body == owner_player or body.is_in_group("NPC") or damaged.has(body):
			continue  # не бьём себя, мирных жителей и не бьём дважды
		if global_position.distance_to(body.global_position) <= radius:
			if body.has_method("take_damage"):
				damaged[body] = true
				body.take_damage(_current_damage() * damage_multiplier, self)
				# Эффекты оружия (огонь молотова, лёд колбы) — на каждую задетую цель
				if shot_target == "Ennemy" and is_instance_valid(body):
					hit_target.emit(body)
			elif body.has_method("Harvest"):
				body.Harvest(_current_damage() * damage_multiplier, 1, false)

	# Удаляем через время (чтобы частицы доиграли)
	await get_tree().create_timer(1.0).timeout
	queue_free()


# ═════════════════════════════════════════════════════════════════════
#  ЭФФЕКТЫ
# ═════════════════════════════════════════════════════════════════════
func _play_hit_effect() -> void:
	if hit_particles and is_instance_valid(hit_particles) and hit_particles.get_parent() == self:
		hit_particles.emitting = true
		hit_particles.reparent(get_parent())  # Чтобы частицы остались в мире


## Искры отскока: короткий веер от поверхности.
func _spark(pos: Vector2, normal: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 7
	sparks.lifetime = 0.25
	sparks.direction = normal
	sparks.spread = 55.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 95.0
	sparks.damping_min = 80.0
	sparks.damping_max = 140.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color = friendly_tint if shot_target == "Ennemy" and _origin_hostile else Color(1.0, 0.9, 0.6)
	sparks.global_position = pos
	parent.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


## Сплющить спрайт вдоль полёта и пружинисто вернуть форму — «мячик» от ракетки.
func _squash(amount: float) -> void:
	if sprite == null:
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	sprite.scale = _sprite_scale * Vector2(amount, 1.0 / amount)
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", _sprite_scale, 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _play(stream: AudioStream, pitch: float) -> void:
	if stream == null or get_tree().current_scene == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.max_distance = 260.0
	if AudioServer.get_bus_index(&"SFX") != -1:
		player.bus = &"SFX"
	get_tree().current_scene.add_child(player)
	player.global_position = global_position
	player.play()
	player.finished.connect(player.queue_free)


# Плавное исчезновение: гасим спрайт (и опционально замедляем), потом удаляем
func _fade_out() -> void:
	if is_fading or is_exploded:
		return
	is_fading = true

	# Снаряд больше не должен наносить урон, пока тает
	area.set_deferred("monitoring", false)
	area.set_deferred("monitorable", false)
	for child in get_children():
		if child is Area2D and child != area:
			child.set_deferred("monitorable", false)   # «ракетка» и датчик огня тоже гаснут

	var tween := create_tween().set_parallel(true)

	# Плавно гасим спрайт
	if sprite:
		tween.tween_property(sprite, "modulate:a", 0.0, fade_duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Плавно замедляем (опционально)
	if slow_down_on_fade:
		tween.tween_property(self, "speed", 0.0, fade_duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Удаляем после окончания анимации
	tween.chain().tween_callback(queue_free)


# Таймер жизни
func _on_lifetime_timer_timeout() -> void:
	if projectile_type == "bomb" and not is_exploded:
		_explode()
	else:
		_fade_out()
