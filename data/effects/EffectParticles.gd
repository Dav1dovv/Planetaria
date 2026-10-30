extends Node2D
class_name EffectParticles
## Частицы эффектов (баффы, дебаффы, DoT) вокруг любого Entity — игрока и существ.
## Создаётся в Entity._ready(), слушает EffectManager, руками в сцену не добавляется.
##
## Что показываем:
##  • эффект наложили        → разовый всплеск частиц (burst), даже у мгновенного лечения;
##  • эффект действует       → постоянный «шлейф» своего характера (яд — пузырьки, ожог — искры
##                             вверх, скорость — след, защита — кольцо, заражение — фиолетовая дымка…);
##  • стаки                  → частиц больше;
##  • эффект кончается       → частицы гаснут за последнюю секунду, потом пропадают;
##  • «пока экипировано»     → артефакты и аксессуары дают приглушённый шлейф (×0.45), чтобы
##                             набор из пяти предметов не превращал героя в ёлку.
##
## ЧТО ГДЕ МЕНЯТЬ:
##  • у эффекта задан Effect.particle (PackedScene) — используется ОН вместо встроенного;
##  • у эффекта задан Effect.particle_color (не белый) — красит встроенные частицы;
##  • характер частиц каждого типа — таблица STYLES ниже (цвет, форма, скорость, гравитация).

const PASSIVE_INTENSITY := 0.45
## За сколько секунд до конца эффекта частицы начинают гаснуть
const FADE_OUT_TIME := 1.2
const MAX_EMITTER_AMOUNT := 40

@export var particle_texture: Texture2D
## Центр тела относительно узла сущности (умножается на размер существа)
@export var center_offset: Vector2 = Vector2(0.0, -10.0)

# ── Таблица характеров ────────────────────────────────────────────────────────
# color    — цвет по умолчанию (перекрывается Effect.particle_color, если он не белый)
# amount   — частиц в постоянном шлейфе (0 — шлейфа нет, только всплеск)
# life     — время жизни частицы, сек
# shape    — "sphere" / "ring" / "box"        radius — размер зоны появления, px
# dir/spread — направление (Vector3) и разброс, градусы
# v        — скорость (min, max)   grav — гравитация (Vector3)   orbit — вращение вокруг тела
# scale    — размер частицы (min, max)   local — false: частицы остаются в мире (след за бегом)
# burst    — частиц во всплеске при наложении
const UP := Vector3(0.0, -1.0, 0.0)
const DOWN := Vector3(0.0, 1.0, 0.0)
const STYLES := {
	Effect.EffectType.HEALTH_RESTORE: {
		"color": Color(1.0, 0.35, 0.45), "amount": 0, "life": 0.9, "shape": "sphere", "radius": 12.0,
		"dir": UP, "spread": 55.0, "v": Vector2(14.0, 32.0), "grav": Vector3(0, -10, 0),
		"scale": Vector2(1.5, 3.0), "burst": 16 },
	Effect.EffectType.REGENERATION: {
		"color": Color(0.35, 1.0, 0.5), "amount": 10, "life": 1.3, "shape": "sphere", "radius": 12.0,
		"dir": UP, "spread": 40.0, "v": Vector2(6.0, 14.0), "grav": Vector3(0, -8, 0),
		"scale": Vector2(1.2, 2.4), "burst": 8 },
	Effect.EffectType.SPEED_BOOST: {
		"color": Color(0.6, 0.95, 1.0), "amount": 14, "life": 0.5, "shape": "sphere", "radius": 6.0,
		"dir": Vector3.ZERO, "spread": 180.0, "v": Vector2(0.0, 6.0), "grav": Vector3.ZERO,
		"scale": Vector2(1.0, 2.0), "local": false, "burst": 12 },
	Effect.EffectType.DAMAGE_BOOST: {
		"color": Color(1.0, 0.45, 0.15), "amount": 16, "life": 0.8, "shape": "sphere", "radius": 10.0,
		"dir": UP, "spread": 35.0, "v": Vector2(12.0, 34.0), "grav": Vector3(0, -30, 0),
		"scale": Vector2(1.2, 2.6), "burst": 14 },
	Effect.EffectType.DEFENSE_BOOST: {
		"color": Color(0.45, 0.7, 1.0), "amount": 12, "life": 1.4, "shape": "ring", "radius": 16.0,
		"dir": Vector3.ZERO, "spread": 180.0, "v": Vector2(0.0, 2.0), "grav": Vector3.ZERO,
		"orbit": 0.45, "scale": Vector2(1.5, 2.5), "burst": 16 },
	Effect.EffectType.MINING_SPEED_BOOST: {
		"color": Color(1.0, 0.8, 0.25), "amount": 8, "life": 0.5, "shape": "sphere", "radius": 12.0,
		"dir": Vector3.ZERO, "spread": 180.0, "v": Vector2(14.0, 32.0), "grav": Vector3(0, 30, 0),
		"scale": Vector2(1.0, 2.0), "burst": 10 },
	Effect.EffectType.INVISIBILITY: {
		"color": Color(0.8, 0.9, 1.0, 0.55), "amount": 12, "life": 1.6, "shape": "sphere", "radius": 14.0,
		"dir": UP, "spread": 180.0, "v": Vector2(2.0, 8.0), "grav": Vector3.ZERO,
		"scale": Vector2(1.0, 2.0), "burst": 14 },
	Effect.EffectType.COLD_IMMUNITY: {
		"color": Color(1.0, 0.6, 0.15), "amount": 10, "life": 1.1, "shape": "sphere", "radius": 10.0,
		"dir": UP, "spread": 30.0, "v": Vector2(8.0, 18.0), "grav": Vector3(0, -16, 0),
		"scale": Vector2(1.0, 2.2), "burst": 10 },
	Effect.EffectType.INFECTION_RESIST: {
		"color": Color(0.4, 0.6, 1.0), "amount": 10, "life": 1.5, "shape": "ring", "radius": 14.0,
		"dir": Vector3.ZERO, "spread": 180.0, "v": Vector2(0.0, 2.0), "grav": Vector3(0, -6, 0),
		"orbit": 0.3, "scale": Vector2(1.4, 2.4), "burst": 12 },
	Effect.EffectType.INVINCIBILITY: {
		"color": Color(1.0, 0.95, 0.6), "amount": 24, "life": 0.9, "shape": "ring", "radius": 14.0,
		"dir": Vector3.ZERO, "spread": 180.0, "v": Vector2(0.0, 6.0), "grav": Vector3.ZERO,
		"orbit": 0.8, "scale": Vector2(1.5, 3.0), "burst": 22 },
	Effect.EffectType.DOUBLE_LOOT: {
		"color": Color(1.0, 0.85, 0.3), "amount": 8, "life": 1.0, "shape": "sphere", "radius": 14.0,
		"dir": UP, "spread": 180.0, "v": Vector2(2.0, 10.0), "grav": Vector3(0, -6, 0),
		"scale": Vector2(1.2, 2.4), "burst": 10 },
	Effect.EffectType.POISON: {
		"color": Color(0.45, 0.9, 0.15), "amount": 10, "life": 1.4, "shape": "sphere", "radius": 10.0,
		"dir": UP, "spread": 25.0, "v": Vector2(4.0, 10.0), "grav": Vector3(0, -12, 0),
		"scale": Vector2(1.5, 3.0), "burst": 8 },
	Effect.EffectType.BURN: {
		"color": Color(1.0, 0.45, 0.05), "amount": 18, "life": 0.7, "shape": "sphere", "radius": 8.0,
		"dir": UP, "spread": 25.0, "v": Vector2(14.0, 34.0), "grav": Vector3(0, -40, 0),
		"scale": Vector2(1.5, 3.0), "burst": 12 },
	Effect.EffectType.FREEZE: {
		"color": Color(0.6, 0.85, 1.0), "amount": 10, "life": 1.5, "shape": "box", "radius": 14.0,
		"dir": DOWN, "spread": 20.0, "v": Vector2(2.0, 8.0), "grav": Vector3(0, 12, 0),
		"scale": Vector2(1.5, 2.8), "burst": 12 },
	Effect.EffectType.BLEED: {
		"color": Color(0.8, 0.05, 0.05), "amount": 8, "life": 0.8, "shape": "sphere", "radius": 8.0,
		"dir": DOWN, "spread": 40.0, "v": Vector2(4.0, 14.0), "grav": Vector3(0, 60, 0),
		"scale": Vector2(1.2, 2.2), "burst": 8 },
	Effect.EffectType.CORRUPTION: {
		"color": Color(0.7, 0.2, 0.9), "amount": 14, "life": 1.3, "shape": "sphere", "radius": 12.0,
		"dir": UP, "spread": 140.0, "v": Vector2(4.0, 12.0), "grav": Vector3(0, -14, 0),
		"orbit": 0.2, "scale": Vector2(1.2, 2.8), "burst": 14 },
	Effect.EffectType.SLOW: {
		"color": Color(0.6, 0.6, 0.65), "amount": 8, "life": 1.3, "shape": "sphere", "radius": 10.0,
		"dir": DOWN, "spread": 30.0, "v": Vector2(2.0, 6.0), "grav": Vector3(0, 14, 0),
		"scale": Vector2(1.5, 2.5), "burst": 6 },
	Effect.EffectType.PANIC: {
		"color": Color(1.0, 0.9, 0.2), "amount": 12, "life": 0.5, "shape": "sphere", "radius": 12.0,
		"dir": Vector3.ZERO, "spread": 180.0, "v": Vector2(20.0, 50.0), "grav": Vector3.ZERO,
		"orbit": 1.2, "scale": Vector2(1.0, 2.0), "burst": 10 },
}
const DEFAULT_STYLE := {
	"color": Color(1, 1, 1), "amount": 8, "life": 1.0, "shape": "sphere", "radius": 10.0,
	"dir": UP, "spread": 60.0, "v": Vector2(4.0, 12.0), "grav": Vector3(0, -8, 0),
	"scale": Vector2(1.2, 2.4), "burst": 8,
}

var _manager: EffectManager
var _entity: Entity
var _size_scale: float = 1.0
## EffectType → постоянный излучатель (GPUParticles2D) или своя сцена эффекта
var _emitters: Dictionary = {}

static var _alpha_ramp: GradientTexture1D
static var _shrink_curve: CurveTexture


func bind(entity: Entity) -> void:
	_entity = entity
	_manager = entity.effect_manager
	_size_scale = _estimate_size_scale(entity)
	position = center_offset * _size_scale
	z_index = 2
	set_process(false)

	_manager.effect_applied.connect(_on_effect_applied)
	_manager.effect_added.connect(_on_effect_added)
	_manager.effect_removed.connect(_on_effect_removed)
	_manager.effect_stacks_changed.connect(_on_stacks_changed)

	# Эффекты, уже активные на момент создания (загрузка, возрождение)
	for effect_type in _manager.active_effects.keys():
		_start_emitter(_manager.active_effects[effect_type].effect)


func _process(_delta: float) -> void:
	if _emitters.is_empty():
		set_process(false)
		return
	var alive: bool = _entity == null or not "is_alive" in _entity or _entity.is_alive
	for effect_type in _emitters.keys():
		var node = _emitters[effect_type]
		if not is_instance_valid(node):
			_emitters.erase(effect_type)
			continue
		if not node is GPUParticles2D:
			continue
		var particles := node as GPUParticles2D
		if not alive:
			particles.emitting = false
			continue
		particles.amount_ratio = _intensity(effect_type)


# ── Сигналы EffectManager ─────────────────────────────────────────────────────
func _on_effect_applied(effect: Effect) -> void:
	# Всплеск при каждом наложении (в том числе мгновенном и при обновлении длительности)
	if effect.particle == null:
		_spawn_burst(effect)


func _on_effect_added(effect: Effect) -> void:
	_start_emitter(effect)


func _on_effect_removed(effect: Effect) -> void:
	_stop_emitter(effect.effect_type)


func _on_stacks_changed(_effect_type: int, _stacks: int) -> void:
	pass  # интенсивность пересчитывается каждый кадр в _process (_intensity)


# ── Постоянный шлейф ──────────────────────────────────────────────────────────
func _start_emitter(effect: Effect) -> void:
	var effect_type := effect.effect_type
	_stop_emitter(effect_type, true)

	# Свой ассет эффекта: показываем его как есть
	if effect.particle != null:
		var custom := effect.particle.instantiate()
		add_child(custom)
		_emitters[effect_type] = custom
		return

	var style := _style_for(effect_type)
	if int(style.get("amount", 0)) <= 0:
		return
	var particles := _build_particles(effect, style, false)
	particles.amount = mini(int(ceil(int(style.amount) * clampf(_size_scale, 0.7, 2.0))), MAX_EMITTER_AMOUNT)
	particles.one_shot = false
	particles.explosiveness = 0.0
	add_child(particles)
	particles.emitting = true
	_emitters[effect_type] = particles
	particles.amount_ratio = _intensity(effect_type)
	set_process(true)


func _stop_emitter(effect_type: int, immediately: bool = false) -> void:
	if not _emitters.has(effect_type):
		return
	var node = _emitters[effect_type]
	_emitters.erase(effect_type)
	if not is_instance_valid(node):
		return
	if immediately:
		node.queue_free()
		return
	# Плавно: перестаём порождать новые частицы, старые доживают и узел убирается
	var life := 1.5
	if node is GPUParticles2D:
		node.emitting = false
		life = node.lifetime + 0.2
	get_tree().create_timer(life).timeout.connect(
		func() -> void:
			if is_instance_valid(node):
				node.queue_free())


## Доля от максимума: стаки усиливают, «экипировано» приглушает, конец таймера гасит.
func _intensity(effect_type: int) -> float:
	var active = _manager.active_effects.get(effect_type)
	if active == null:
		return 0.0
	var max_stacks := maxi(active.effect.max_stacks, 1)
	var stack_fraction := float(active.stacks) / float(max_stacks)
	var ratio := lerpf(0.6, 1.0, stack_fraction)
	if active.permanent:
		return ratio * PASSIVE_INTENSITY
	var remaining := _manager.get_effect_time_remaining(effect_type)
	if remaining > 0.0 and remaining < FADE_OUT_TIME:
		ratio *= remaining / FADE_OUT_TIME
	return clampf(ratio, 0.05, 1.0)


# ── Всплеск ───────────────────────────────────────────────────────────────────
func _spawn_burst(effect: Effect) -> void:
	var style := _style_for(effect.effect_type)
	var count := int(style.get("burst", 8))
	if count <= 0:
		return
	var particles := _build_particles(effect, style, true)
	particles.amount = mini(int(ceil(count * clampf(_size_scale, 0.7, 2.0))), MAX_EMITTER_AMOUNT)
	particles.one_shot = true
	particles.explosiveness = 1.0
	# Для экипированных предметов всплеск скромнее
	var active = _manager.active_effects.get(effect.effect_type)
	if active != null and active.permanent:
		particles.amount_ratio = 0.5
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


# ── Сборка частиц ─────────────────────────────────────────────────────────────
func _build_particles(effect: Effect, style: Dictionary, burst: bool) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.texture = particle_texture
	particles.lifetime = float(style.get("life", 1.0)) * (1.2 if burst else 1.0)
	particles.local_coords = bool(style.get("local", true))
	particles.randomness = 0.5

	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	var radius := float(style.get("radius", 10.0)) * _size_scale
	match String(style.get("shape", "sphere")):
		"ring":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			material.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
			material.emission_ring_height = 0.0
			material.emission_ring_radius = radius
			material.emission_ring_inner_radius = radius * 0.85
		"box":
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			material.emission_box_extents = Vector3(radius, radius * 0.6, 1.0)
		_:
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = radius

	var velocity: Vector2 = style.get("v", Vector2(4.0, 12.0))
	var spread := float(style.get("spread", 60.0))
	var direction: Vector3 = style.get("dir", UP)
	if burst:
		# Всплеск разлетается шире и быстрее шлейфа
		velocity *= 2.2
		spread = maxf(spread, 120.0)
		if direction == Vector3.ZERO:
			spread = 180.0
	material.direction = direction
	material.spread = spread
	material.initial_velocity_min = velocity.x
	material.initial_velocity_max = velocity.y
	material.gravity = style.get("grav", Vector3.ZERO)
	var orbit := float(style.get("orbit", 0.0))
	if orbit > 0.0:
		material.orbit_velocity_min = orbit * 0.5
		material.orbit_velocity_max = orbit
	var particle_scale: Vector2 = style.get("scale", Vector2(1.2, 2.4))
	material.scale_min = particle_scale.x
	material.scale_max = particle_scale.y
	material.scale_curve = _get_shrink_curve()
	material.color_ramp = _get_alpha_ramp()
	material.color = _color_for(effect, style)

	particles.process_material = material
	return particles


## Цвет: Effect.particle_color (если задан не белым) → иначе цвет характера.
func _color_for(effect: Effect, style: Dictionary) -> Color:
	var base: Color = style.get("color", Color.WHITE)
	if effect.particle_color != Color.WHITE:
		return Color(effect.particle_color, base.a)
	return base


func _style_for(effect_type: int) -> Dictionary:
	return STYLES.get(effect_type, DEFAULT_STYLE)


## Размер существа по его CollisionShape2D: у мелких частиц меньше, у больших — шире зона.
func _estimate_size_scale(entity: Node) -> float:
	var collision := entity.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return 1.0
	var extent := 8.0
	if collision.shape is CircleShape2D:
		extent = (collision.shape as CircleShape2D).radius
	elif collision.shape is RectangleShape2D:
		extent = (collision.shape as RectangleShape2D).size.length() * 0.5
	elif collision.shape is CapsuleShape2D:
		extent = (collision.shape as CapsuleShape2D).height * 0.5
	return clampf(extent / 8.0, 0.7, 2.5)


static func _get_alpha_ramp() -> GradientTexture1D:
	if _alpha_ramp == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_alpha_ramp = GradientTexture1D.new()
		_alpha_ramp.gradient = gradient
	return _alpha_ramp


static func _get_shrink_curve() -> CurveTexture:
	if _shrink_curve == null:
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.7))
		curve.add_point(Vector2(0.25, 1.0))
		curve.add_point(Vector2(1.0, 0.2))
		_shrink_curve = CurveTexture.new()
		_shrink_curve.curve = curve
	return _shrink_curve
