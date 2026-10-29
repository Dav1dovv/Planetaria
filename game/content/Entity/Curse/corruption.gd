extends Node2D
class_name CorruptionOrb
## Левитирующее заражение — главная фишка Vehana. Собственная логика, без Creature.
##
## ИГРОВАЯ ИДЕЯ — «пинг-понг»:
##   HUNT      заражение плывёт к игроку; коснулось — заражает. Но по нему можно ударить.
##   DEFLECTED удар отбивает его «мячиком» в сторону удара (куда смотрит оружие). Оно
##             быстро угасает, пока летит, и ранит врагов, в которых попало.
##             Чем оно крупнее (чем раньше попал), тем больнее. Ударил ещё раз — «розыгрыш»:
##             жизнь продлевается, урон растёт.
##   Огонь лагеря взрывает его — взрыв ранит существ рядом (и цепляет соседние заражения).
##
## МАТЕМАТИКА ДВИЖЕНИЯ (всё — синусы и косинусы, поэтому хаос читаем):
##   позиция = база(t) + Лиссажу(t)
##   Лиссажу(t) = ( Ax·sin(ωx·t + φx),  Ay·cos(ωy·t + φy) )      ωx : ωy = 3 : 2
##   база(t)    — плавный снос; курс = угол_на_цель + A·sin(ω·t + φ)   (S-образная «змейка»)
##   скорость   = v · (1 + k·cos(Ω·t + ψ))                            (ритмичные «рывки»)
##   вертикаль  = A·sin(Ω·t) — покачивание над землёй, тень на земле дышит в такт.
##   Фазы φ, ψ у каждого заражения свои — стая выглядит живой, но каждая кривая простая.

signal deflected(by: Node)
signal exploded
signal dissolved

enum State { SPAWN, HUNT, DEFLECTED, DYING }

@export_group("Lifecycle")
## Сколько секунд живёт, пока охотится; последние fade_out_time секунд — угасание
@export var lifetime: float = 9.0
@export var fade_out_time: float = 1.6
## Длительность появления (всплывает из земли с «пружинкой»)
@export var spawn_time: float = 0.7
@export var hover_height: float = 9.0
## Одновременно живых заражений в мире (лишние растворяются при появлении)
@export var max_alive: int = 10

@export_group("Infection")
@export var infection_amount: float = 7.0
## Сразу после появления не заражает: игроку нужно мгновение, чтобы среагировать
@export var infect_delay: float = 0.5
## Заражает ли игрока уже отбитое заражение (по умолчанию нет — иначе пинг-понг наказывает)
@export var deflected_infects_player: bool = false
## Как часто одно заражение может заново заражать один и тот же ресурс (сек)
@export var resource_infect_interval: float = 1.0

@export_group("Damage (охота)")
## Урон существам, которых заражение задевает, пока охотится (раньше убивало на месте)
@export var hunt_damage: float = 10.0
@export var hunt_hit_cooldown: float = 0.8

@export_group("Hunt motion")
@export var sight_radius: float = 220.0
@export var hunt_speed: float = 46.0
@export var wander_speed: float = 22.0
@export var acceleration: float = 140.0
## Амплитуда «змейки» курса (рад) и её частота (рад/с)
@export_range(0.0, 1.5, 0.05) var weave_amplitude: float = 0.75
@export var weave_frequency: float = 2.2
## Глубина ритмичных рывков скорости (0 — ровный ход) и их частота
@export_range(0.0, 0.6, 0.05) var surge: float = 0.3
@export var surge_frequency: float = 1.7

@export_group("Levitation (Лиссажу)")
@export var wobble_amplitude: Vector2 = Vector2(12.0, 9.0)
## Частоты по осям, рад/с. Целое соотношение (3:2) = замкнутая понятная фигура
@export var wobble_frequency: Vector2 = Vector2(3.0, 2.0)
@export var bob_amplitude: float = 2.5
@export var bob_frequency: float = 2.6

@export_group("Ping-pong")
## Сколько секунд живёт отбитое заражение (за это время оно полностью угасает)
@export var deflect_life: float = 1.8
@export var launch_speed: float = 150.0
## Добавка к скорости за единицу отбрасывания оружия (equip.knockback)
@export var launch_per_knockback: float = 12.0
@export var drag: float = 1.5
## 0 — летит строго «от игрока», 1 — строго туда, куда игрок целился
@export_range(0.0, 1.0, 0.05) var aim_precision: float = 0.85
@export var hop_height: float = 7.0
@export var hop_time: float = 0.28
## Во сколько раз гасится «змейка» у отбитого (летит почти ровно, с рябью)
@export_range(0.0, 1.0, 0.05) var deflected_wobble_scale: float = 0.45
@export_range(0.0, 1.0, 0.05) var wall_bounce_energy: float = 0.8
@export_flags_2d_physics var wall_mask: int = 1
## «Розыгрыш»: повторный удар продлевает жизнь и усиливает урон
@export var rally_extend: float = 0.5
@export var rally_bonus: float = 0.2
@export var rally_max: int = 5

@export_group("Damage (отбитое)")
@export var deflect_damage: float = 8.0
## Какая доля урона оружия игрока добавляется к урону отбитого заражения
@export_range(0.0, 2.0, 0.05) var weapon_damage_share: float = 0.5
## Множитель урона, когда оно почти угасло (при полном размере — 1.0)
@export_range(0.0, 1.0, 0.05) var min_damage_scale: float = 0.25
@export var hit_knockback: float = 3.0
## Сколько стойки врага снимает попадание (см. Entity.add_poise_damage)
@export var poise_damage: float = 30.0
@export var enemy_hit_cooldown: float = 0.5
## Доля оставшейся жизни, которую заражение теряет при попадании во врага
@export_range(0.0, 1.0, 0.05) var enemy_hit_life_loss: float = 0.35
@export_range(0.0, 1.0, 0.05) var enemy_bounce_energy: float = 0.6

@export_group("Explosion")
@export var explosion_damage: float = 24.0
@export var explosion_radius: float = 72.0
@export var explosion_knockback: float = 6.0
## Слой, на котором лежат HurtBox существ (16 = слой 5)
@export_flags_2d_physics var explosion_mask: int = 16
## Бьёт ли взрыв по игроку (у костра игрок обычно рядом — по умолчанию нет)
@export var damage_player: bool = false
@export var chain_reaction: bool = true
@export var chain_delay: float = 0.12
@export var shake_strength: float = 4.0

@export_group("Colors")
@export var hostile_color: Color = Color(1.0, 0.0, 1.0)
@export var hostile_core: Color = Color(0.0, 0.0, 1.0)
@export var friendly_color: Color = Color(0.35, 0.95, 1.0)
@export var friendly_core: Color = Color(1.0, 1.0, 1.0)

@export_group("Audio")
@export var sfx_spawn: AudioStream
@export var sfx_hit: AudioStream
@export var sfx_enemy_hit: AudioStream
@export var sfx_dissolve: AudioStream
@export var sfx_explode: AudioStream

## Кто отбил (читает Entity._resolve_attacker — враги запоминают обидчика)
var owner_player: Node2D = null
## 1.0 — полный размер, 0.0 — угасло. От него зависит урон отбитого и вид
var size_ratio: float = 1.0

const SPAWN_HIT_GRACE := 0.25
const MIN_VISUAL_SCALE := 0.35
const BODY_RADIUS := 6.0

var _state: State = State.SPAWN
var _t: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _wander_heading: float = 0.0
var _wobble_scale: float = 0.0
var _life_left: float = 0.0
var _deflect_left: float = 0.0
var _power: float = 0.0
var _rally: int = 0
var _hit_lock: float = 0.0
var _hop_t: float = 1.0
var _squash: Vector2 = Vector2.ONE
var _squash_tween: Tween
var _color_tween: Tween
var _poll_timer: float = 0.0
var _enemy_cd: Dictionary = {}
var _resource_cd: Dictionary = {}
var _player: Node2D = null
var _player_timer: float = 0.0
var _phase: Vector2 = Vector2.ZERO   # φx, φy Лиссажу
var _phase_weave: float = 0.0
var _phase_surge: float = 0.0
var _phase_bob: float = 0.0
var _friendly: bool = false

@onready var _skin: Node2D = $Skin
@onready var _glow: Sprite2D = $Skin/Glow
@onready var _core: Sprite2D = $Skin/Core
@onready var _hurt_box: Area2D = $HurtBox
@onready var _hit_box: Area2D = $HitBox
@onready var _fire_sensor: Area2D = $FireSensor
@onready var _shadow: Node2D = get_node_or_null("Shadow")
@onready var _light: PointLight2D = get_node_or_null("Light")
@onready var _wisps: GPUParticles2D = get_node_or_null("Skin/Wisps")
@onready var _spawn_fx: CPUParticles2D = get_node_or_null("SpawnFX")
@onready var _burst_fx: CPUParticles2D = get_node_or_null("BurstFX")
@onready var _explosion: Node2D = get_node_or_null("Explosion")

var _light_energy: float = 0.7


func _ready() -> void:
	add_to_group("corruption_orb")
	_phase = Vector2(randf() * TAU, randf() * TAU)
	_phase_weave = randf() * TAU
	_phase_surge = randf() * TAU
	_phase_bob = randf() * TAU
	_wander_heading = randf() * TAU
	_life_left = lifetime
	if _light:
		_light_energy = _light.energy

	_hit_box.area_entered.connect(_on_hit_box_area_entered)
	_fire_sensor.monitorable = true
	_recolor(false, true)

	# Заражённый ресурс создаёт заражение своим ребёнком — выносим в мир,
	# чтобы оно пережило разрушение ресурса и не ехало вместе с ним.
	var parent := get_parent()
	_base_pos = global_position + Vector2.from_angle(randf() * TAU) * 6.0
	if parent != null and parent.is_in_group("Harvestable") and parent.get_parent() != null:
		reparent.call_deferred(parent.get_parent(), true)

	# Планета излечена или в мире слишком много заражения — тихо растворяемся
	if not InfectionCleanup.is_infection_active() or _count_alive() > max_alive:
		dissolve(true)
		return

	if _spawn_fx:
		_spawn_fx.restart()
	_play(sfx_spawn, 1.0 + randf_range(-0.1, 0.1))
	_update_visuals()


# ═════════════════════════════════════════════════════════════════════
#  ЦИКЛ
# ═════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		return
	_t += delta
	_hit_lock = maxf(0.0, _hit_lock - delta)
	_hop_t += delta
	_player_timer -= delta

	match _state:
		State.SPAWN:
			_tick_spawn()
		State.HUNT:
			_tick_hunt(delta)
		State.DEFLECTED:
			_tick_deflected(delta)

	if _state == State.DYING:
		return

	_move_base(delta)
	global_position = _base_pos + _wobble_offset()
	_update_visuals()

	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = 0.1
		_poll_overlaps()


func _tick_spawn() -> void:
	_wobble_scale = clampf(_t / spawn_time, 0.0, 1.0)
	if _t >= spawn_time:
		_state = State.HUNT


func _tick_hunt(delta: float) -> void:
	# Угасание в конце жизни: размер, а с ним и свет, плавно уходят в ноль
	_life_left -= delta
	size_ratio = 1.0 if _life_left >= fade_out_time else clampf(_life_left / fade_out_time, 0.0, 1.0)
	if _life_left <= 0.0:
		dissolve()
		return

	var theta: float
	var speed: float
	var target := _get_player()
	var to_target := Vector2.ZERO
	var hunting := false
	if target != null:
		to_target = target.global_position - _base_pos
		hunting = to_target.length() < sight_radius

	if hunting:
		# Курс на игрока + S-образная змейка (синус поперёк курса)
		theta = to_target.angle() + weave_amplitude * sin(weave_frequency * _t + _phase_weave)
		speed = hunt_speed
	else:
		# Без цели: медленный дрейф, курс покачивается синусом
		theta = _wander_heading + 0.9 * sin(0.5 * _t + _phase_weave)
		speed = wander_speed
	# Ритмичные рывки: скорость пульсирует косинусом — момент для удара читается
	speed *= 1.0 + surge * cos(surge_frequency * _t + _phase_surge)

	_velocity = _velocity.move_toward(Vector2.from_angle(theta) * speed, acceleration * delta)
	_wobble_scale = move_toward(_wobble_scale, size_ratio, delta * 3.0)


func _tick_deflected(delta: float) -> void:
	_deflect_left -= delta
	size_ratio = clampf(_deflect_left / deflect_life, 0.0, 1.0)
	if _deflect_left <= 0.0 or size_ratio < 0.06:
		dissolve()
		return
	# Мячик: скорость плавно гасится (экспонента), рябь Лиссажу остаётся
	_velocity *= exp(-drag * delta)
	_wobble_scale = move_toward(_wobble_scale, deflected_wobble_scale * size_ratio, delta * 4.0)


## Лиссажу: Ax·sin(ωx·t + φx), Ay·cos(ωy·t + φy)
func _wobble_offset() -> Vector2:
	return Vector2(
		wobble_amplitude.x * sin(wobble_frequency.x * _t + _phase.x),
		wobble_amplitude.y * cos(wobble_frequency.y * _t + _phase.y)
	) * _wobble_scale


func _move_base(delta: float) -> void:
	var step := _velocity * delta
	if step.length_squared() < 0.0001:
		return
	if wall_mask != 0:
		var query := PhysicsRayQueryParameters2D.create(
			_base_pos, _base_pos + step + step.normalized() * BODY_RADIUS, wall_mask)
		query.collide_with_areas = false
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var normal: Vector2 = hit.normal
			_velocity = _velocity.bounce(normal) * wall_bounce_energy
			_base_pos = hit.position + normal * BODY_RADIUS
			_wander_heading = _velocity.angle()
			if _velocity.length() > 20.0:
				_bounce_feel(normal)
			return
	_base_pos += step


# ═════════════════════════════════════════════════════════════════════
#  УДАР ИГРОКА / СНАРЯДА  (PlayerHitBox и Projectile зовут take_damage)
# ═════════════════════════════════════════════════════════════════════
func take_damage(damage: float, damage_source: Node2D = null, knockback_mod: float = 0.0) -> void:
	if _state == State.DYING or _hit_lock > 0.0 or _t < SPAWN_HIT_GRACE:
		return
	_hit_lock = 0.12

	var dir := _deflect_direction(damage_source)
	_power = deflect_damage + damage * weapon_damage_share

	if _state == State.DEFLECTED:
		# Розыгрыш: ещё удар — жизнь дольше, урон и скорость выше
		_rally = mini(_rally + 1, rally_max)
		_deflect_left = minf(deflect_life, _deflect_left + rally_extend)
	else:
		_state = State.DEFLECTED
		_deflect_left = deflect_life
		_rally = 0
		_recolor(true)

	size_ratio = clampf(_deflect_left / deflect_life, 0.0, 1.0)
	owner_player = _resolve_player(damage_source)
	_velocity = dir * (launch_speed + knockback_mod * launch_per_knockback) * (1.0 + 0.08 * _rally)
	_wander_heading = _velocity.angle()

	_hop()
	_squash_along(dir, 1.45)
	if _burst_fx:
		_burst_fx.restart()
	_play(sfx_hit, 1.0 + 0.1 * _rally)
	GameJuice.shake(1.5 + 0.3 * _rally, 0.08)
	Rumble.confirm(_rally >= 2)
	deflected.emit(damage_source)


## Куда полетит: смесь «куда целился игрок» и «прочь от удара».
func _deflect_direction(source: Node2D) -> Vector2:
	if source == null:
		return Vector2.from_angle(randf() * TAU)
	var away := (global_position - source.global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)

	var aim := away
	var projectile_dir = source.get("direction")
	if projectile_dir is Vector2 and projectile_dir != Vector2.ZERO:
		aim = (projectile_dir as Vector2).normalized()           # выстрел
	else:
		var holder: Object = source
		if holder.get("mouse_pos") == null and source.owner != null:
			holder = source.owner                                # PlayerHitBox → Player
		var mouse = holder.get("mouse_pos")
		if mouse is Vector2:
			var to_cursor: Vector2 = (mouse as Vector2) - source.global_position
			if to_cursor.length() > 1.0:
				aim = to_cursor.normalized()

	var dir := away.lerp(aim, aim_precision)
	return dir.normalized() if dir != Vector2.ZERO else aim


func _resolve_player(source: Node) -> Node2D:
	if source == null:
		return _get_player()
	if source.is_in_group("Player"):
		return source as Node2D
	if source.owner != null and source.owner.is_in_group("Player"):
		return source.owner as Node2D
	return _get_player()


## Стойка, которую отбитое заражение снимает у врага (читает Entity).
func get_poise_damage() -> float:
	return poise_damage * lerpf(0.4, 1.0, size_ratio)


## Текущий урон отбитого: растёт с «розыгрышем», падает по мере угасания.
func current_damage() -> float:
	return _power * (1.0 + rally_bonus * _rally) * lerpf(min_damage_scale, 1.0, size_ratio)


# ═════════════════════════════════════════════════════════════════════
#  КОНТАКТЫ
# ═════════════════════════════════════════════════════════════════════
func _on_hit_box_area_entered(area: Area2D) -> void:
	_handle_overlap(area, true)


func _poll_overlaps() -> void:
	# Страховка: перекрытие, возникшее, пока контакт был запрещён (появление, кулдаун)
	if _state != State.HUNT and _state != State.DEFLECTED:
		return
	for area in _hit_box.get_overlapping_areas():
		_handle_overlap(area, false)


func _handle_overlap(area: Area2D, _fresh: bool) -> void:
	if area.get_parent() == self or area.is_in_group("corruption"):
		return
	if _state != State.HUNT and _state != State.DEFLECTED:
		return

	if area.is_in_group("Harvestable"):
		# Касание ресурса заражает его — в любом состоянии, как в старой версии
		_infect_resource(area)
	elif area.is_in_group("Player"):
		if _state == State.HUNT or deflected_infects_player:
			_infect(area.get_parent())
	elif area.is_in_group("Ennemy"):
		if _state == State.DEFLECTED:
			_hit_enemy(area.get_parent())
		else:
			_hit_enemy_hunting(area.get_parent())


func _infect_resource(area: Area2D) -> void:
	if not area.has_method("add_infection"):
		return
	var id := area.get_instance_id()
	if _resource_cd.get(id, -1.0) > _t:
		return
	_resource_cd[id] = _t + resource_infect_interval
	area.add_infection(infection_amount)


## Охотящееся заражение задевает существо: урон без отскока, заражение продолжает путь.
func _hit_enemy_hunting(target: Node) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var id := target.get_instance_id()
	if _enemy_cd.get(id, -1.0) > _t:
		return
	_enemy_cd[id] = _t + hunt_hit_cooldown
	target.take_damage(hunt_damage, self, hit_knockback)


func _infect(victim: Node) -> void:
	if _t < spawn_time + infect_delay or victim == null or not victim.has_method("add_infection"):
		return
	victim.add_infection(infection_amount)
	dissolve()


func _hit_enemy(target: Node) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var id := target.get_instance_id()
	if _enemy_cd.get(id, -1.0) > _t:
		return
	_enemy_cd[id] = _t + enemy_hit_cooldown

	target.take_damage(current_damage(), self, hit_knockback)
	_play(sfx_enemy_hit, 1.0 + 0.1 * _rally)

	# Отскок от врага, как шарик от ракетки: энергия и жизнь падают
	var away := (global_position - (target as Node2D).global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)
	_velocity = away * maxf(_velocity.length() * enemy_bounce_energy, 60.0)
	_deflect_left *= 1.0 - enemy_hit_life_loss
	_hop()
	_squash_along(away, 1.35)
	if _burst_fx:
		_burst_fx.restart()
	if _deflect_left < 0.15:
		dissolve()


# ═════════════════════════════════════════════════════════════════════
#  РОЖДЕНИЕ / УГАСАНИЕ / РАЗРУШЕНИЕ
# ═════════════════════════════════════════════════════════════════════
## Растворение: вспышка, схлопывание в точку, облачко частиц.
func dissolve(silent: bool = false) -> void:
	if _state == State.DYING:
		return
	_state = State.DYING
	_disable_contacts()
	dissolved.emit()

	var tween := create_tween().set_parallel(true)
	if silent:
		tween.tween_property(_skin, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(queue_free)
		return

	_play(sfx_dissolve, 1.0 + randf_range(-0.08, 0.08))
	_emit_detached(_burst_fx)
	var start_scale := _skin.scale
	tween.tween_property(_skin, "scale", start_scale * 1.25, 0.08).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_skin, "scale", Vector2.ZERO, 0.22) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(_skin, "modulate:a", 0.0, 0.3)
	if _light:
		tween.parallel().tween_property(_light, "energy", 0.0, 0.3)
	if _shadow:
		tween.parallel().tween_property(_shadow, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


## Взрыв от огня лагеря: урон существам рядом, цепная реакция, вспышка и тряска.
func explode() -> void:
	if _state == State.DYING or _t < 0.1:
		return
	_state = State.DYING
	_disable_contacts()
	exploded.emit()

	var scale_by_size := lerpf(0.6, 1.0, size_ratio)
	var radius := explosion_radius * scale_by_size
	_apply_explosion_damage(radius, explosion_damage * lerpf(0.5, 1.0, size_ratio))

	_play_explosion_fx(radius)
	_play(sfx_explode, randf_range(0.9, 1.1))
	var player := _get_player()
	if player != null:
		var closeness := clampf(1.0 - global_position.distance_to(player.global_position) / 400.0, 0.0, 1.0)
		GameJuice.shake(shake_strength * closeness, 0.25)

	_skin.visible = false
	if _shadow:
		_shadow.visible = false
	if _light:
		_light.enabled = false
	# Дать детям доиграть эффект — сам узел живёт ещё мгновение
	get_tree().create_timer(0.1).timeout.connect(queue_free)


func _apply_explosion_damage(radius: float, damage: float) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = explosion_mask
	query.collide_with_bodies = false
	query.collide_with_areas = true

	var hit_targets: Dictionary = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 48):
		var area := result.collider as Area2D
		if area == null or area.get_parent() == self:
			continue
		var target := area.get_parent()
		if target == null or hit_targets.has(target):
			continue

		if area.is_in_group("corruption"):
			# Цепная реакция: соседнее заражение взрывается чуть позже
			hit_targets[target] = true
			if chain_reaction and target.has_method("explode"):
				get_tree().create_timer(chain_delay).timeout.connect(
					func() -> void:
						if is_instance_valid(target):
							target.explode())
			continue
		if area.is_in_group("Player") and not damage_player:
			continue
		if not (area.is_in_group("Ennemy") or area.is_in_group("Player")):
			continue
		if not target.has_method("take_damage"):
			continue

		hit_targets[target] = true
		var falloff := lerpf(1.0, 0.4, clampf(global_position.distance_to((target as Node2D).global_position) / radius, 0.0, 1.0))
		target.take_damage(damage * falloff, self, explosion_knockback)


func _play_explosion_fx(radius: float) -> void:
	if _explosion == null:
		return
	_explosion.reparent(get_tree().current_scene, true)
	var flash := _explosion.get_node_or_null("Flash") as Sprite2D
	var sparks := _explosion.get_node_or_null("Sparks") as CPUParticles2D
	var light := _explosion.get_node_or_null("Light") as PointLight2D
	var tween := _explosion.create_tween().set_parallel(true)
	if flash and flash.texture:
		var full := (radius * 2.0) / float(flash.texture.get_width())
		flash.scale = Vector2.ONE * full * 0.2
		flash.modulate.a = 0.9
		tween.tween_property(flash, "scale", Vector2.ONE * full, 0.22) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(flash, "modulate:a", 0.0, 0.4).set_delay(0.05)
	if sparks:
		sparks.restart()
	if light:
		light.energy = 2.0
		tween.tween_property(light, "energy", 0.0, 0.45)
	tween.chain().tween_interval(0.9)
	tween.chain().tween_callback(_explosion.queue_free)


func _disable_contacts() -> void:
	_hurt_box.set_deferred("monitorable", false)
	_hit_box.set_deferred("monitoring", false)
	_fire_sensor.set_deferred("monitorable", false)


# ═════════════════════════════════════════════════════════════════════
#  ВИД
# ═════════════════════════════════════════════════════════════════════
func _update_visuals() -> void:
	var p_spawn := clampf(_t / spawn_time, 0.0, 1.0)
	var spawn_scale := _ease_out_back(p_spawn)                       # «пружинка» появления
	var life_scale := lerpf(MIN_VISUAL_SCALE, 1.0, size_ratio)       # угасание = уменьшение
	var pulse := 1.0 + 0.06 * sin(7.0 * _t + _phase.x)               # «дыхание»
	_skin.scale = Vector2.ONE * spawn_scale * life_scale * pulse * _squash

	var bob := bob_amplitude * sin(bob_frequency * _t + _phase_bob)
	var hop := -hop_height * sin(PI * clampf(_hop_t / hop_time, 0.0, 1.0))
	var rise := (1.0 - spawn_scale) * hover_height                    # всплывает из земли
	var height_offset := bob + hop + rise
	_skin.position.y = height_offset

	var alpha := clampf(p_spawn * 2.0, 0.0, 1.0) * clampf(size_ratio * 1.6, 0.0, 1.0)
	if size_ratio < 0.35:
		alpha *= 0.75 + 0.25 * sin(45.0 * _t)                        # мерцание перед угасанием
	_skin.modulate.a = alpha

	if _shadow:
		# Тень на земле: чем выше шар, тем она меньше и бледнее
		var s := clampf(1.0 - height_offset * 0.04, 0.5, 1.2) * life_scale
		_shadow.scale = Vector2(s, s)
		_shadow.position.y = hover_height + 3.0
		_shadow.modulate.a = alpha
	if _light and _state != State.DYING:
		_light.energy = _light_energy * size_ratio * p_spawn
	if _wisps:
		_wisps.amount_ratio = clampf(size_ratio, 0.1, 1.0)


func _recolor(friendly: bool, instant: bool = false) -> void:
	_friendly = friendly
	var glow_color := friendly_color if friendly else hostile_color
	var core_color := friendly_core if friendly else hostile_core
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	if instant:
		_glow.self_modulate = glow_color
		_core.self_modulate = core_color
		if _light:
			_light.color = glow_color
		return
	_color_tween = create_tween().set_parallel(true)
	_color_tween.tween_property(_glow, "self_modulate", glow_color, 0.12)
	_color_tween.tween_property(_core, "self_modulate", core_color, 0.12)
	if _light:
		_color_tween.tween_property(_light, "color", glow_color, 0.12)
	if _wisps:
		_color_tween.tween_property(_wisps, "self_modulate",
			Color(0.4, 1.6, 1.8) if friendly else Color.WHITE, 0.12)
	if _burst_fx:
		_burst_fx.modulate = friendly_color if friendly else Color.WHITE


func _hop() -> void:
	_hop_t = 0.0


## Сплюснуть вдоль удара и пружинисто вернуть форму — «мячик» от ракетки.
func _squash_along(dir: Vector2, amount: float) -> void:
	var squashed := Vector2(amount, 1.0 / amount) if absf(dir.x) > absf(dir.y) \
		else Vector2(1.0 / amount, amount)
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash = squashed
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "_squash", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _bounce_feel(normal: Vector2) -> void:
	_hop()
	_squash_along(normal.orthogonal(), 1.25)


func _emit_detached(fx: CPUParticles2D) -> void:
	if fx == null:
		return
	fx.reparent(get_tree().current_scene, true)
	fx.restart()
	get_tree().create_timer(fx.lifetime + 0.3).timeout.connect(fx.queue_free)


static func _ease_out_back(x: float) -> float:
	const C1 := 1.70158
	const C3 := C1 + 1.0
	return 1.0 + C3 * pow(x - 1.0, 3.0) + C1 * pow(x - 1.0, 2.0)


# ═════════════════════════════════════════════════════════════════════
#  ПОМОЩНИКИ
# ═════════════════════════════════════════════════════════════════════
func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		if _player_timer > 0.0:
			return null
		_player_timer = 1.0
		_player = get_tree().get_first_node_in_group("Player") as Node2D
	return _player


func _count_alive() -> int:
	var alive := 0
	for orb in get_tree().get_nodes_in_group("corruption_orb"):
		if orb != self and orb is CorruptionOrb and orb._state != State.DYING:
			alive += 1
	return alive + 1


func _play(stream: AudioStream, pitch: float) -> void:
	if stream == null:
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
