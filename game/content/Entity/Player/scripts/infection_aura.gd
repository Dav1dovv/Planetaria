extends GPUParticles2D
class_name InfectionAura
## Постоянная «аура» заражения вокруг игрока: фиолетовые искры кружат и поднимаются
## вверх. Чем выше порча (corruption / max_health), тем их больше, они крупнее, быстрее
## и темнее. Нет порчи — нет частиц; вылечился — аура плавно рассеивается.
##
## Создаётся из Player._ready() кодом (правок сцены не нужно). Уровень порчи
## читается раз в POLL секунд, поэтому работает и после загрузки сохранения,
## лечения и возрождения без отдельных сигналов.

## Игрок, за чьей порчей следим (ставит Player перед add_child)
var player: Node2D

const POLL := 0.15
## Скорость сглаживания видимого уровня (доля шкалы в секунду)
const SMOOTH := 0.8
const MAX_AMOUNT := 72

@export_group("Низкий уровень")
@export var calm_color: Color = Color(0.75, 0.35, 1.0)
@export var calm_radius: float = 10.0
@export var calm_scale: Vector2 = Vector2(1.0, 1.6)
@export var calm_velocity: float = 6.0
@export var calm_orbit: float = 0.10
@export var calm_amount_ratio: float = 0.10

@export_group("Высокий уровень")
@export var heavy_color: Color = Color(0.95, 0.08, 0.6)
@export var heavy_radius: float = 26.0
@export var heavy_scale: Vector2 = Vector2(1.8, 3.4)
@export var heavy_velocity: float = 20.0
@export var heavy_orbit: float = 0.45
## Форма кривой: <1 делает слабую порчу заметнее (10% порчи ≈ 19% «густоты»)
@export_range(0.3, 1.5, 0.05) var curve: float = 0.7

var _material: ParticleProcessMaterial
var _target_level: float = 0.0
var _level: float = 0.0
var _poll_left: float = 0.0


func _ready() -> void:
	amount = MAX_AMOUNT
	lifetime = 1.4
	local_coords = true          # аура едет вместе с игроком
	emitting = false
	position = Vector2(0.0, -10.0)
	z_index = 2

	_material = ParticleProcessMaterial.new()
	_material.particle_flag_disable_z = true
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_material.direction = Vector3(0.0, -1.0, 0.0)
	_material.spread = 140.0
	_material.gravity = Vector3(0.0, -18.0, 0.0)
	_material.damping_min = 2.0
	_material.damping_max = 6.0

	# Прозрачность: появились → яркие → растаяли
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	_material.color_ramp = ramp_tex
	process_material = _material

	_apply_level(0.0)


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL
		_target_level = _read_level()

	_level = move_toward(_level, _target_level, SMOOTH * delta)
	_apply_level(_level)


## 0..1: доля порчи от максимума здоровья; игрок мёртв — 0.
func _read_level() -> float:
	if not is_instance_valid(player) or not ("corruption" in player):
		return 0.0
	if "is_alive" in player and not player.is_alive:
		return 0.0
	var stats = player.get("Entity_stats")
	if stats == null or stats.max_health <= 0.0:
		return 0.0
	var corruption: float = player.corruption
	if corruption <= 0.0:
		return 0.0
	return pow(clampf(corruption / stats.max_health, 0.0, 1.0), curve)


func _apply_level(level: float) -> void:
	# Совсем нет порчи — частицы выключены, ничего не считаем и не рисуем
	var active := level > 0.01 or _target_level > 0.0
	if emitting != active:
		emitting = active
	if not active:
		return

	amount_ratio = lerpf(calm_amount_ratio, 1.0, level)
	speed_scale = lerpf(0.8, 1.5, level)
	_material.emission_sphere_radius = lerpf(calm_radius, heavy_radius, level)
	_material.scale_min = lerpf(calm_scale.x, heavy_scale.x, level)
	_material.scale_max = lerpf(calm_scale.y, heavy_scale.y, level)
	_material.initial_velocity_min = lerpf(calm_velocity * 0.3, heavy_velocity * 0.3, level)
	_material.initial_velocity_max = lerpf(calm_velocity, heavy_velocity, level)
	var orbit := lerpf(calm_orbit, heavy_orbit, level)
	_material.orbit_velocity_min = orbit * 0.5
	_material.orbit_velocity_max = orbit
	# Чем гуще порча, тем темнее и «злее» оттенок
	_material.color = calm_color.lerp(heavy_color, level)
