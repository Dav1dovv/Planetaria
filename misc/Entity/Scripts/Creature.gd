extends Entity
class_name Creature

# ═══════════════════════════════════════════════════════════════
#  ENUMS
# ═══════════════════════════════════════════════════════════════

signal attack_finished

enum BehaviorType { Passive, Neutral, Aggressive, Special }

enum State {
	IDLE,     # стоит, ждёт
	WANDER,   # бродит случайно
	PATROL,   # идёт по точкам
	CHASE,    # преследует цель
	FLEE,     # убегает от цели
	HIDE,     # прячется на месте (панцирь, нора и т.п.) вместо бегства
	ATTACK,   # атакует
	STUNNED,  # оглушён
	DEAD,
}

# ═══════════════════════════════════════════════════════════════
#  EXPORTS
# ═══════════════════════════════════════════════════════════════

@export_category("Behavior")
## -1 = Пассивный  0 = Нейтральный  1 = Агрессивный
@export_range(-1.0, 1.0, 0.01) var behavior: float = 0.0
@export var can_flee: bool = false
## На каком % HP начинает убегать
@export_range(0.0, 1.0) var flee_threshold: float = 0.25
## Пугается от ЛЮБОГО удара, а не только на низком HP (для пугливых животных —
## корова, овца, улитка). Срабатывает прямо в on_hit(), где точно известен атакующий.
@export var flee_on_hit: bool = false

@export_category("Fear")
## Включить систему страха
@export var use_fear: bool = false
## Скорость накопления страха при получении урона (за 1 ед. урона)
@export var fear_per_damage: float = 0.05
## Страх нарастает, если цель ближе этого расстояния (пикселей)
@export var fear_proximity_radius: float = 60.0
## Скорость накопления страха от близости цели (ед./сек)
@export var fear_proximity_rate: float = 0.08
## Скорость затухания страха в секунду (когда угрозы нет)
@export var fear_decay_rate: float = 0.05
## Порог страха — выше этого существо переходит в FLEE
@export_range(0.0, 1.0) var fear_flee_threshold: float = 0.6
## При страхе ниже этого порога существо успокаивается и перестаёт убегать
@export_range(0.0, 1.0) var fear_calm_threshold: float = 0.25
## Существо не убегает от страха, а замирает/прячется на месте (панцирь улитки, нора и т.п.)
@export var hides_when_scared: bool = false
## Минимальное время в укрытии, прежде чем существо снова выглянет наружу
@export var hide_duration: float = 1.5
## На сколько меньше урона существо получает, пока прячется (0 = без защиты, 1 = неуязвимо)
@export_range(0.0, 1.0) var hide_damage_reduction: float = 0.0
## Звук испуга — проигрывается при входе в FLEE или HIDE
@export var fear_sound: AudioStream
## Небольшой случайный разброс высоты звука испуга, чтобы не звучало одинаково каждый раз
@export_range(0.0, 0.3) var fear_sound_pitch_variance: float = 0.08
## Множитель скорости при бегстве от страха (1.0 = обычная скорость, 1.6 = бежит в 1.6 раза быстрее)
@export var flee_speed_multiplier: float = 1.6

@export_category("Pack Alert")
## Название группы (Godot group), в которую записываются все существа одного вида/стаи.
## Удар по одному члену группы поднимает по тревоге всех остальных в радиусе pack_alert_radius.
## Оставь пустым, чтобы отключить (по умолчанию отключено, ничего не ломает).
@export var pack_group: String = ""
## Радиус, в котором сородичи услышат тревогу и среагируют на атакующего
@export var pack_alert_radius: float = 300.0

@export_category("Detection")
## Радиус слуха — замечает в любом направлении (стены не блокируют)
@export var hear_radius: float = 60.0
## Радиус зрения (длина конуса)
@export var sight_radius: float = 180.0
## Половина угла конуса зрения в градусах (60 → конус 120°)
@export var fov_half_angle: float = 60.0
## Проверять ли стены (raycast к игроку)
@export var use_los_check: bool = true
## Маска слоёв стен для LOS-raycast
@export var wall_collision_mask: int = 1
## Сколько секунд существо помнит о цели, потеряв прямой контакт (зашёл за угол и т.п.).
## Всё это время существо идёт к последней известной позиции, а не сразу сдаётся.
@export var memory_duration: float = 3.0

@export_category("Movement")
var move_speed: float = 60.0
@export var wander_interval_min: float = 2.0
@export var wander_interval_max: float = 5.0
@export var wander_radius: float = 100.0
## Скорость поворота направления движения, рад/сек. Меньше = плавнее, но менее отзывчиво.
## Ограничивает, насколько быстро может измениться направление за кадр — убирает
## рывки/мигание влево-вправо у стен, где avoidance-вектор колеблется кадр к кадру.
@export var turn_speed: float = 12.0
## Точки патруля (Node2D / Marker2D)
@export var patrol_points: Array[NodePath] = []
## Лёгкое виляние из стороны в сторону при погоне за игроком — без этого
## существо идёт к цели идеальной прямой линией, что выглядит неестественно.
@export var chase_weave_enabled: bool = true
## Амплитуда виляния (пиксели смещения перпендикулярно направлению на цель)
@export var chase_weave_amplitude: float = 14.0
## Частота виляния (полных колебаний в секунду)
@export var chase_weave_frequency: float = 0.8

@export_category("Obstacle Avoidance")
## Дальность лучей для обхода стен
@export var ray_length: float = 40.0
## Сила отталкивания от стены
@export var avoidance_strength: float = 1.8

@export_category("Attack")
@export var attack_damage: float = 10.0
@export var attack_radius: float = 28.0
@export var attack_cooldown: float = 1.2

@export_category("Poise / Stagger")
## Сколько "стаггера" существо выдерживает до оглушения
@export var max_poise: float = 100.0
## Скорость восстановления poise в секунду (когда не бьют)
@export var poise_decay_rate: float = 15.0
## Задержка перед началом восстановления poise после последнего удара
@export var poise_decay_delay: float = 1.0
## Длительность стаггера при заполнении poise
@export var stagger_duration: float = 1.0
## Множитель урона по существу во время стаггера (окно "добивания")
@export var vulnerable_damage_multiplier: float = 1.5

@export_category("Animators")
@export var body_anim: AnimationPlayer
@export var hand_anim: AnimationPlayer

# ═══════════════════════════════════════════════════════════════
#  NODES
# ═══════════════════════════════════════════════════════════════

@onready var drop: Dropper        = $Drop
@onready var health_bar: ProgressBar = $HealthBar
@onready var explosion: GPUParticles2D = $Explosion

# RayCast2D создаются в коде — добавлять в сцену не нужно
var _rays: Array[RayCast2D] = []

# Углы лучей avoidance (локальные, градусы)
const RAY_ANGLES := [-60.0, -30.0, 0.0, 30.0, 60.0]

# ═══════════════════════════════════════════════════════════════
#  RUNTIME STATE
# ═══════════════════════════════════════════════════════════════

var behavior_type: BehaviorType
var current_state: State = State.IDLE
var target: Node2D = null
var home_position: Vector2
var _facing_dir: Vector2 = Vector2.RIGHT  # куда смотрит существо
var _current_move_dir: Vector2 = Vector2.RIGHT  # сглаженное направление движения (см. _move_toward)

var _wander_timer: float  = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _attack_timer: float  = 0.0
var _stun_timer: float    = 0.0
var _hide_timer: float    = 0.0
var _detect_timer: float  = 0.0  # throttle проверки игрока

## Кто ударил последним — записывается в on_hit() ДО проверки на смерть, поэтому
## доступен даже подклассам/сигналам, сработавшим уже после мгновенной гибели существа.
var last_attacker: Node2D = null

# Создаётся в коде — отдельный AudioStreamPlayer2D в сцене не нужен
var _fear_audio: AudioStreamPlayer2D

## Текущий уровень страха [0.0 – 1.0]
var fear_level: float = 0.0

## Текущий накопленный poise (стаггер)
var current_poise: float = 0.0
var _poise_decay_timer: float = 0.0

const DETECT_INTERVAL := 0.12   # проверка каждые ~120 мс

var _patrol_nodes: Array[Node2D] = []
var _patrol_index: int = 0

# ── Виляние при погоне ──────────────────────────────────────────
var _weave_time: float = 0.0
var _weave_seed: float = 0.0  # случайная фаза, чтобы все существа не виляли синхронно

# ── Память о цели ──────────────────────────────────────────────
# Раньше потеря прямого контакта (LOS/слух/зрение) означала мгновенный
# сброс цели — из-за угла или на полсекунды из радиуса. Теперь существо
# "помнит" последнюю известную позицию memory_duration секунд.
var _has_direct_sense: bool = false
var _last_known_pos: Vector2 = Vector2.ZERO
var _memory_timer: float = 0.0

# ── ОПТИМИЗАЦИЯ: throttle вне экрана ─────────────────────────────
# Существо вне видимости не бегает по рейкастам/детекту/move_and_slide —
# это основная стоимость AI при большом кол-ве существ в открытом мире.
@onready var _screen_notifier: VisibleOnScreenEnabler2D = get_node_or_null("optimizer")
var _is_active: bool = true

# Кешируем квадраты радиусов — сравнение дистанций без sqrt (distance_to)
var _sight_radius_sq: float
var _hear_radius_sq: float
var _chase_giveup_sq: float
var _flee_giveup_sq: float
var _attack_radius_sq: float

# ═══════════════════════════════════════════════════════════════
#  INIT
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	super._ready()
	home_position = global_position
	_current_move_dir = _facing_dir
	move_speed = Entity_stats.move_speed * 10
	health_bar.visible = false
	health_bar.max_value = Entity_stats.max_health
	health_bar.value     = Entity_stats.max_health
	_weave_seed = randf_range(0.0, TAU)
	_resolve_behavior_type()
	_resolve_patrol_nodes()
	_build_rays()
	_cache_squared_radii()
	_setup_screen_throttle()
	_build_fear_audio()
	if pack_group != "":
		add_to_group(pack_group)
	_enter_state(_default_start_state())

## Отдельный AudioStreamPlayer2D для звука испуга — создаём в коде, чтобы не
## требовать ручной настройки во всех сценах существ.
func _build_fear_audio() -> void:
	_fear_audio = AudioStreamPlayer2D.new()
	add_child(_fear_audio)

func _play_fear_sound() -> void:
	if fear_sound == null or _fear_audio == null:
		return
	_fear_audio.stream = fear_sound
	_fear_audio.pitch_scale = 1.0 + randf_range(-fear_sound_pitch_variance, fear_sound_pitch_variance)
	_fear_audio.play()

## Квадраты радиусов считаем один раз — сравнение дистанций без sqrt
func _cache_squared_radii() -> void:
	_sight_radius_sq  = sight_radius * sight_radius
	_hear_radius_sq   = hear_radius * hear_radius
	_chase_giveup_sq  = (sight_radius * 1.6) * (sight_radius * 1.6)
	_flee_giveup_sq   = (sight_radius * 2.0) * (sight_radius * 2.0)
	_attack_radius_sq = attack_radius * attack_radius

## Подключаемся к уже существующему VisibleOnScreenEnabler2D ("optimizer" в сцене)
func _setup_screen_throttle() -> void:
	if _screen_notifier == null:
		return
	_screen_notifier.screen_entered.connect(func(): _is_active = true)
	_screen_notifier.screen_exited.connect(func(): _is_active = false)
	_is_active = _screen_notifier.is_on_screen()

func _resolve_behavior_type() -> void:
	if behavior < -0.33:
		behavior_type = BehaviorType.Passive
	elif behavior < 0.33:
		behavior_type = BehaviorType.Neutral
	else:
		behavior_type = BehaviorType.Aggressive

func _resolve_patrol_nodes() -> void:
	for path in patrol_points:
		var n = get_node_or_null(path)
		if n is Node2D:
			_patrol_nodes.append(n)

## Создаём 5 лучей один раз — они живут всё время жизни существа
func _build_rays() -> void:
	for angle_deg in RAY_ANGLES:
		var ray := RayCast2D.new()
		ray.collision_mask  = wall_collision_mask
		ray.exclude_parent  = true
		ray.enabled         = true
		# target_position обновляем динамически в _move_toward
		ray.target_position = Vector2.RIGHT * ray_length
		add_child(ray)
		_rays.append(ray)

func _default_start_state() -> State:
	if not _patrol_nodes.is_empty():
		return State.PATROL
	return State.WANDER

# ═══════════════════════════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if not _is_active:
		_tick_offscreen(delta)
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_stun_timer   = maxf(0.0, _stun_timer   - delta)
	_wander_timer = maxf(0.0, _wander_timer - delta)
	_detect_timer = maxf(0.0, _detect_timer - delta)

	# Проверка игрока — не каждый кадр, раз в DETECT_INTERVAL
	if _detect_timer <= 0.0:
		_detect_timer = DETECT_INTERVAL
		_check_for_target()

	# Цель есть, но прямого контакта сейчас нет — тратим "память" о ней.
	# Как только память истекает — теряем цель по-настоящему.
	if is_instance_valid(target) and not _has_direct_sense:
		_memory_timer = maxf(0.0, _memory_timer - delta)
		if _memory_timer <= 0.0:
			_lose_target()

	if use_fear:
		_tick_fear(delta)

	_tick_poise(delta)

	_tick_state(delta)

## Существо вне экрана: не гоняем детект/рейкасты/move_and_slide,
## но не даём таймерам "зависнуть", чтобы не было рывков при возврате в кадр.
func _tick_offscreen(delta: float) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	if use_fear:
		fear_level = maxf(0.0, fear_level - fear_decay_rate * delta)
	_tick_poise(delta)
	if current_state == State.STUNNED and _stun_timer <= 0.0:
		_enter_state(_default_start_state())

# ═══════════════════════════════════════════════════════════════
#  STATE MACHINE
# ═══════════════════════════════════════════════════════════════

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO
			_play_anim("Idle")
			_wander_timer = randf_range(wander_interval_min, wander_interval_max)
		State.WANDER:
			_pick_wander_target()
			_play_anim("Walk")
		State.PATROL:
			_play_anim("Walk")
		State.CHASE:
			_play_anim("Walk")
		State.FLEE:
			_play_anim("Walk")
			_play_fear_sound()
		State.HIDE:
			velocity = Vector2.ZERO
			# Если анимации "Hide" ещё нет в проекте — тихо остаётся на "Idle",
			# существо всё равно замирает и не двигается.
			_play_anim("Hide")
			_hide_timer = hide_duration
			_play_fear_sound()
		State.ATTACK:
			velocity = Vector2.ZERO
			_play_anim("Attack")
		State.STUNNED:
			velocity = Vector2.ZERO
			_play_anim("Stunned")
		State.DEAD:
			velocity = Vector2.ZERO
			_play_anim("Death")


func _tick_state(delta: float) -> void:
	match current_state:
		State.IDLE:    _tick_idle(delta)
		State.WANDER:  _tick_wander(delta)
		State.PATROL:  _tick_patrol(delta)
		State.CHASE:   _tick_chase(delta)
		State.FLEE:    _tick_flee(delta)
		State.HIDE:    _tick_hide(delta)
		State.ATTACK:  _tick_attack(delta)
		State.STUNNED: _tick_stunned(delta)

# ── IDLE ──────────────────────────────────────────────────────
func _tick_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if _wander_timer <= 0.0:
		_enter_state(State.WANDER if _patrol_nodes.is_empty() else State.PATROL)

# ── WANDER ────────────────────────────────────────────────────
func _tick_wander(delta: float) -> void:
	var arrived := _move_toward(_wander_target, delta)
	if arrived:
		_enter_state(State.IDLE)

# ── PATROL ────────────────────────────────────────────────────
func _tick_patrol(delta: float) -> void:
	if _patrol_nodes.is_empty():
		_enter_state(State.WANDER)
		return
	var pt := _patrol_nodes[_patrol_index].global_position
	if _move_toward(pt, delta):
		_patrol_index = (_patrol_index + 1) % _patrol_nodes.size()
		_enter_state(State.IDLE)

# ── CHASE ─────────────────────────────────────────────────────
func _tick_chase(delta: float) -> void:
	if not is_instance_valid(target):
		_lose_target(); return

	# Пока есть прямой контакт — обычная погоня + возможность атаки.
	# Без контакта — идём к последней известной точке, атаковать не пытаемся
	# (иначе существо будет "бить" сквозь стену туда, где цели уже нет).
	if _has_direct_sense:
		var dist_sq := global_position.distance_squared_to(target.global_position)
		if dist_sq > _chase_giveup_sq:
			_lose_target(); return
		if dist_sq <= _attack_radius_sq:
			_enter_state(State.ATTACK); return
		_move_toward(_get_chase_aim_point(target.global_position, delta), delta)
	else:
		var arrived := _move_toward(_last_known_pos, delta)
		if arrived:
			# Дошли до последнего места, где видели цель, но её там нет —
			# просто ждём (memory_timer тикает), может, снова заметим.
			velocity = Vector2.ZERO
			move_and_slide()

## Точка прицеливания при погоне — смещаем target_pos перпендикулярно
## направлению на цель по синусоиде, чтобы существо не шло идеально прямой
## линией (выглядит роботизированно), а слегка "рыскало" из стороны в
## сторону, как живое. На подходе к цели виляние затухает, чтобы не мешать
## точному сближению перед атакой.
func _get_chase_aim_point(target_pos: Vector2, delta: float) -> Vector2:
	if not chase_weave_enabled:
		return target_pos

	_weave_time += delta

	var to_target := target_pos - global_position
	var dist := to_target.length()
	if dist < 1.0:
		return target_pos

	var dir  := to_target / dist
	var perp := Vector2(-dir.y, dir.x)

	# Затухание виляния вблизи цели — на расстоянии ~2.5 attack_radius
	# оно уже сходит на нет, иначе существо будет промахиваться мимо удара.
	var fade_dist := attack_radius * 2.5
	var fade := clampf(dist / fade_dist, 0.0, 1.0)

	var wobble := sin(_weave_time * chase_weave_frequency * TAU + _weave_seed) * chase_weave_amplitude * fade
	return target_pos + perp * wobble

# ── FLEE ──────────────────────────────────────────────────────
func _tick_flee(delta: float) -> void:
	if not is_instance_valid(target):
		_lose_target(); return
	var away := global_position + (global_position - target.global_position).normalized() * sight_radius
	_move_toward(away, delta, flee_speed_multiplier)
	if global_position.distance_squared_to(target.global_position) > _flee_giveup_sq:
		_lose_target()

# ── HIDE ──────────────────────────────────────────────────────
## Существо замирает на месте (панцирь/нора) вместо того чтобы убегать.
## Не выглядывает, пока угроза совсем рядом, даже если таймер укрытия истёк —
## иначе оно будет вылезать прямо под ударом стоящего рядом игрока.
func _tick_hide(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	_hide_timer = maxf(0.0, _hide_timer - delta)

	if is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		if dist <= fear_proximity_radius:
			return  # угроза рядом — сидим и не высовываемся

	if _hide_timer <= 0.0:
		if not is_instance_valid(target) or fear_level <= fear_calm_threshold:
			_lose_target()

# ── ATTACK ────────────────────────────────────────────────────
func _tick_attack(_delta: float) -> void:
	if not is_instance_valid(target):
		_lose_target(); return
	if global_position.distance_squared_to(target.global_position) > _attack_radius_sq:
		_enter_state(State.CHASE); return
	if _attack_timer <= 0.0:
		_do_attack()
		_attack_timer = attack_cooldown

# ── STUNNED ───────────────────────────────────────────────────
func _tick_stunned(_delta: float) -> void:
	if _stun_timer <= 0.0:
		_enter_state(_default_start_state())

# ═══════════════════════════════════════════════════════════════
#  ДВИЖЕНИЕ + ОБХОД СТЕН
# ═══════════════════════════════════════════════════════════════

## Двигает существо к точке. Возвращает true если прибыли.
## Лучи собирают вектор отталкивания от стен и добавляют его к направлению.
## speed_multiplier — множитель скорости для этого вызова (например, паническое ускорение при FLEE).
func _move_toward(target_pos: Vector2, delta: float, speed_multiplier: float = 1.0) -> bool:
	var to_target := target_pos - global_position
	var dist      := to_target.length()
	if dist < 4.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return true

	var dir := to_target / dist

	# Обновляем лучи по текущему направлению движения
	var avoidance := Vector2.ZERO
	for i in _rays.size():
		var ray_dir := dir.rotated(deg_to_rad(RAY_ANGLES[i]))
		_rays[i].target_position = ray_dir * ray_length
		_rays[i].force_raycast_update()

		if _rays[i].is_colliding():
			var hit_point  := _rays[i].get_collision_point()
			var hit_normal := _rays[i].get_collision_normal()
			var hit_dist   := global_position.distance_to(hit_point)
			# Чем ближе препятствие — тем сильнее отталкивание
			var weight := 1.0 - clampf(hit_dist / ray_length, 0.0, 1.0)
			avoidance += hit_normal * weight

	var desired_dir := (dir + avoidance * avoidance_strength).normalized()

	# ── СГЛАЖИВАНИЕ НАПРАВЛЕНИЯ ────────────────────────────────
	# Раньше direction менялся мгновенно каждый кадр. Возле стен/углов
	# avoidance-вектор из лучей колеблется (то попал луч, то нет) —
	# из-за этого final_dir скакал влево-вправо, и существо/спрайт дёргались.
	# Теперь текущее направление плавно поворачивается к желаемому с
	# ограниченной угловой скоростью (turn_speed), а не телепортируется.
	var max_turn := turn_speed * delta
	var angle_diff := _current_move_dir.angle_to(desired_dir)
	var turn := clampf(angle_diff, -max_turn, max_turn)
	_current_move_dir = _current_move_dir.rotated(turn).normalized()

	var final_dir := _current_move_dir
	_facing_dir   = final_dir

	# Разворот спрайта по горизонтали — с мёртвой зоной по X, чтобы
	# спрайт не мигал влево-вправо при почти вертикальном движении
	# (final_dir.x колеблется около нуля)
	if absf(final_dir.x) > 0.15:
		$Skin.scale.x = -1.0 if final_dir.x < 0.0 else 1.0

	velocity = final_dir * move_speed * speed_multiplier
	move_and_slide()
	return false

# ═══════════════════════════════════════════════════════════════
#  ОБНАРУЖЕНИЕ ИГРОКА (чистая математика, без Area2D)
# ═══════════════════════════════════════════════════════════════

func _check_for_target() -> void:
	if behavior_type == BehaviorType.Passive:
		return

	# Уже есть цель — обновляем, помним мы её прямо сейчас или нет.
	# Само решение "сдаться" принимается в _physics_process по _memory_timer,
	# а не мгновенно здесь — иначе шаг за угол = мгновенный сброс погони.
	if is_instance_valid(target):
		_has_direct_sense = _can_sense(target)
		if _has_direct_sense:
			_last_known_pos = target.global_position
			_memory_timer = memory_duration
		return

	# Ищем нового кандидата в группе "Player"
	for player in get_tree().get_nodes_in_group("Player"):
		if player is Node2D and _can_sense(player):
			_acquire_target(player)
			return

## Слышим (круг) ИЛИ видим (конус + опционально LOS)
func _can_sense(body: Node2D) -> bool:
	var to_body := body.global_position - global_position
	var dist_sq := to_body.length_squared()

	# 1. Слух — простой круг, стены не блокируют
	if dist_sq <= _hear_radius_sq:
		return true

	# 2. За пределами зрения — не видим
	if dist_sq > _sight_radius_sq:
		return false

	# 3. Проверка угла конуса
	var angle_to_body := rad_to_deg(_facing_dir.angle_to(to_body.normalized()))
	if absf(angle_to_body) > fov_half_angle:
		return false

	# 4. Line-of-sight — нет ли стены между нами
	if use_los_check:
		return _has_line_of_sight(body.global_position)

	return true

## Один raycast напрямую к цели через PhysicsDirectSpaceState2D
func _has_line_of_sight(target_pos: Vector2) -> bool:
	var space  := get_world_2d().direct_space_state
	var query  := PhysicsRayQueryParameters2D.create(
		global_position, target_pos, wall_collision_mask
	)
	query.exclude = [self]
	return space.intersect_ray(query).is_empty()

# ═══════════════════════════════════════════════════════════════
#  TARGET MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _acquire_target(new_target: Node2D) -> void:
	target = new_target
	_has_direct_sense = true
	_last_known_pos = new_target.global_position
	_memory_timer = memory_duration
	if can_flee and _is_low_health():
		_enter_fear_response()
	elif behavior_type == BehaviorType.Aggressive:
		_enter_state(State.CHASE)
	# Neutral — ждёт удара, реагирует в on_hit()

## Единая точка входа реакции на испуг: прячется (HIDE) или убегает (FLEE) —
## в зависимости от hides_when_scared. Используй это вместо прямого
## _enter_state(State.FLEE), чтобы улитки и подобные существа тоже работали корректно.
func _enter_fear_response() -> void:
	if current_state in [State.DEAD, State.STUNNED]:
		return
	if hides_when_scared:
		_enter_state(State.HIDE)
	else:
		_enter_state(State.FLEE)

func _lose_target() -> void:
	target = null
	_has_direct_sense = false
	_memory_timer = 0.0
	_enter_state(State.WANDER if _patrol_nodes.is_empty() else State.PATROL)

# ═══════════════════════════════════════════════════════════════
#  ATTACK
# ═══════════════════════════════════════════════════════════════

## Переопредели в подклассе для уникальной атаки
func _do_attack() -> void:
	if not is_instance_valid(target):
		return
	if hand_anim.has_animation("Attack"): 
		hand_anim.play("Attack")
	elif body_anim.has_animation("Attack"):
		body_anim.play("Attack")
	
	emit_signal("attack_finished")

# ═══════════════════════════════════════════════════════════════
#  HIT / STATUS EFFECTS
# ═══════════════════════════════════════════════════════════════

## Вызови после take_damage чтобы существо среагировало на удар
## attacker      — кто ударил (для мгновенной мести, даже если цель ещё не была замечена)
## is_critical   — был ли удар критическим (крит наносит +50% poise-урона)
## poise_damage  — сколько стаггера наносит удар (берётся из оружия игрока)
## damage_amount — сколько реального урона получено (для страха; раньше сюда
##                 по ошибке подставлялся attack_damage существа, а не входящий урон)
func on_hit(attacker: Node2D = null, is_critical: bool = false, poise_damage: float = 0.0, damage_amount: float = 0.0) -> void:
	if attacker != null:
		last_attacker = attacker

	add_fear_from_damage(damage_amount)

	if poise_damage > 0.0 and current_state != State.DEAD:
		add_poise_damage(poise_damage * (1.5 if is_critical else 1.0))

	# Тревога стаи рассылается ДО проверки на смерть — иначе существо, убитое
	# с одного удара, не успевает никого предупредить (current_state уже DEAD).
	if pack_group != "" and attacker != null and attacker.is_in_group("Player"):
		_alert_pack(attacker)

	if current_state == State.DEAD:
		return

	# Если по существу ударили из засады (цели ещё не было — например, попали
	# из-за пределов радиуса обнаружения), существо должно запомнить обидчика.
	# Раньше это пропускалось для Passive — из-за этого пассивные животные (корова,
	# овца, улитка) никогда не узнавали, от кого убегать, и FLEE у них ломался
	# в тот же кадр (см. _tick_flee: нет target — мгновенный выход из FLEE).
	if not is_instance_valid(target) and attacker != null and attacker.is_in_group("Player"):
		_acquire_target(attacker)

	# Уже убегает/прячется или оглушено — не выдёргиваем обратно в погоню повторным
	# ударом, иначе Neutral существо будет дёргаться между FLEE и CHASE на каждый урон.
	if behavior_type == BehaviorType.Neutral and \
	   current_state not in [State.CHASE, State.ATTACK, State.FLEE, State.HIDE, State.STUNNED]:
		if is_instance_valid(target):
			_enter_state(State.CHASE)

	if can_flee and (flee_on_hit or _is_low_health()):
		_enter_fear_response()

func apply_stun(duration: float) -> void:
	_stun_timer = duration
	_enter_state(State.STUNNED)

# ═══════════════════════════════════════════════════════════════
#  PACK ALERT — «если ударить одного, вся стая бросается на игрока»
# ═══════════════════════════════════════════════════════════════

## Рассылает тревогу всем сородичам в группе pack_group в радиусе pack_alert_radius.
## Вызывается из on_hit() ДО проверки на смерть, поэтому срабатывает даже
## при мгновенном убийстве одним ударом.
func _alert_pack(attacker: Node2D) -> void:
	for member in get_tree().get_nodes_in_group(pack_group):
		if member == self or not (member is Creature):
			continue
		if member.current_state == State.DEAD:
			continue
		if global_position.distance_squared_to(member.global_position) <= pack_alert_radius * pack_alert_radius:
			member._receive_pack_alert(attacker)

## Реакция на тревогу от сородича. Aggressive/Neutral — бросаются в погоню.
## Passive (если умеют убегать) — пугаются и убегают/прячутся вместе со всеми,
## а не лезут в драку.
func _receive_pack_alert(attacker: Node2D) -> void:
	if current_state == State.DEAD or not is_instance_valid(attacker):
		return
	if behavior_type == BehaviorType.Passive:
		if can_flee:
			_acquire_target(attacker)
			_enter_fear_response()
		return
	_acquire_target(attacker)
	_enter_state(State.CHASE)

# ═══════════════════════════════════════════════════════════════
#  FEAR SYSTEM
# ═══════════════════════════════════════════════════════════════

## Вызывается каждый кадр когда use_fear = true
func _tick_fear(delta: float) -> void:
	if is_instance_valid(target):
		# Страх нарастает от близости угрозы
		var dist := global_position.distance_to(target.global_position)
		if dist <= fear_proximity_radius:
			var proximity_factor := 1.0 - (dist / fear_proximity_radius)
			fear_level = minf(1.0, fear_level + fear_proximity_rate * proximity_factor * delta)
	else:
		# Нет угрозы — страх постепенно уходит
		fear_level = maxf(0.0, fear_level - fear_decay_rate * delta)

	_apply_fear_state()

## Проверяет пороги и при необходимости меняет состояние
func _apply_fear_state() -> void:
	if current_state == State.DEAD or current_state == State.STUNNED:
		return
	if fear_level >= fear_flee_threshold:
		if current_state != State.FLEE and current_state != State.HIDE:
			_enter_fear_response()
	elif (current_state == State.FLEE or current_state == State.HIDE) and fear_level <= fear_calm_threshold:
		# Успокоился — возвращаемся к обычному поведению
		if is_instance_valid(target) and behavior_type == BehaviorType.Aggressive:
			_enter_state(State.CHASE)
		else:
			_lose_target()

## Добавляет страх при получении урона. Вызови из take_damage / on_hit.
func add_fear_from_damage(damage: float) -> void:
	if not use_fear:
		return
	fear_level = minf(1.0, fear_level + damage * fear_per_damage)

# ═══════════════════════════════════════════════════════════════
#  POISE / STAGGER SYSTEM
# ═══════════════════════════════════════════════════════════════

## Во время стаггера существо открыто — по нему проходит усиленный урон.
## Во время HIDE (панцирь/нора) — наоборот, урон может быть снижен (hide_damage_reduction).
func get_incoming_damage_multiplier() -> float:
	if current_state == State.STUNNED:
		return vulnerable_damage_multiplier
	if current_state == State.HIDE:
		return 1.0 - hide_damage_reduction
	return 1.0

## Затухание poise, если существо не получало ударов последние poise_decay_delay сек
func _tick_poise(delta: float) -> void:
	if current_state == State.DEAD:
		return
	if _poise_decay_timer > 0.0:
		_poise_decay_timer -= delta
		return
	if current_poise > 0.0:
		current_poise = maxf(0.0, current_poise - poise_decay_rate * delta)

## Вызывается из on_hit при каждом ударе. При заполнении — стаггер.
func add_poise_damage(amount: float) -> void:
	if current_state == State.DEAD or max_poise <= 0.0:
		return
	current_poise += amount
	_poise_decay_timer = poise_decay_delay
	if current_poise >= max_poise:
		current_poise = 0.0
		_trigger_stagger()

func _trigger_stagger() -> void:
	apply_stun(stagger_duration)

# ═══════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════

func _pick_wander_target() -> void:
	var angle := randf_range(0.0, TAU)
	var dist  := randf_range(20.0, wander_radius)
	_wander_target = home_position + Vector2(cos(angle), sin(angle)) * dist

func _is_low_health() -> bool:
	return Entity_stats.current_health / Entity_stats.max_health <= flee_threshold

func _play_anim(anim_name: String) -> void:
	if body_anim and body_anim.has_animation(anim_name):
		body_anim.play(anim_name)
	elif hand_anim and hand_anim.has_animation(anim_name):
		hand_anim.play(anim_name)

# ═══════════════════════════════════════════════════════════════
#  ENTITY SIGNAL CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_health_changed(new_health: float) -> void:
	health_bar.visible = true
	if new_health > 0:
		health_bar.value = new_health
	elif new_health <= 0:
		health_bar.visible = false
	

func _on_died() -> void:
	_enter_state(State.DEAD)
	if $HitBox:
		explosion.restart()
		explosion.emitting = true
		$Skin.visible = false
		$HitBox.queue_free()
	if drop:
		drop._drop_items()
	if is_in_group("Creature"):
		remove_from_group("Creature")
		
	await get_tree().create_timer(1.5).timeout
	queue_free()
