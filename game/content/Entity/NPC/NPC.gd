extends Creature
class_name NPC

## Режимы поведения НПС
enum Mode { WANDER, PAUSE, PLAYER, CHAT }

@onready var interact_zone: interaction_area = $interaction_area

@export_enum("Weapon", "Baff", "combiner","nothing") var show_ui : String = "Weapon"
@export var player: Player

@export_group("Player reaction")
## Расстояние, на котором НПС останавливается и «хочет поговорить»
@export var awareness_radius: float = 80.0
## Расстояние, на котором НПС поворачивается лицом к игроку
@export var face_player_radius: float = 40.0

@export_group("Wander")
## Плавность разгона/торможения (больше = резче)
@export var acceleration: float = 160.0
## Сколько НПС стоит между прогулками (мин, макс), сек
@export var pause_time_range: Vector2 = Vector2(1.5, 5.0)
@export var arrive_distance: float = 4.0

@export_group("Separation")
## Расстояние, на котором НПС начинают отталкиваться друг от друга
@export var separation_radius: float = 24.0
@export var separation_strength: float = 0.8

@export_group("NPC chat")
## Дистанция, на которой НПС могут заметить друг друга и заговорить
@export var chat_radius: float = 48.0
## Шанс начать разговор при каждой проверке (раз в 0.5 сек)
@export_range(0.0, 1.0) var chat_chance: float = 0.35
## Пауза между разговорами (мин, макс), сек
@export var chat_cooldown_range: Vector2 = Vector2(8.0, 20.0)
## Длительность разговора (мин, макс), сек
@export var chat_duration_range: Vector2 = Vector2(3.0, 6.0)
## Как часто «говорящие» меняются репликами, сек
@export var chat_turn_time: float = 1.1
@export var bubble_offset: Vector2 = Vector2(0, -36)

var inventory

var _mode: Mode = Mode.PAUSE
var _home: Vector2
var _pause_left: float = 0.0
var _desired_velocity: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _anim_moving: bool = false

var _partner: NPC = null
var _chat_left: float = 0.0
var _chat_elapsed: float = 0.0
var _chat_parity: int = 0
var _last_turn: int = -1
var _chat_cooldown: float = 0.0
var _chat_check_timer: float = 0.0

var _bubble: Label

const _CHAT_SYMBOLS := ["...", "!", "?", "♪", "..."]


func _ready() -> void:
	super._ready()
	add_to_group("NPC")
	if !player:
		player = get_tree().get_first_node_in_group("Player")
	inventory = get_tree().get_first_node_in_group("Inventory")
	interact_zone.interact = Callable(self, "_Do")

	_home = global_position
	_create_bubble()
	# Случайный старт, чтобы НПС не двигались синхронно
	_chat_cooldown = randf_range(1.0, chat_cooldown_range.x)
	_go_pause(randf_range(0.0, 3.0))


## Вызывается по клику/взаимодействию (через interaction_area)
func _Do() -> void:
	match show_ui:
		"Weapon":
			Global.inventory.call_smith()
		"Baff":
			Global.inventory.call_cauldron()
		"combiner":
			Global.inventory.call_combiner()
		"nothing":
			pass


# ---------------------------------------------------------------------------
# Главный цикл
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		_hide_bubble()
		return

	_chat_cooldown = maxf(0.0, _chat_cooldown - delta)
	_update_player_awareness()

	match _mode:
		Mode.WANDER:
			_tick_wander(delta)
		Mode.PAUSE:
			_tick_pause(delta)
		Mode.PLAYER:
			_tick_player()
		Mode.CHAT:
			_tick_chat(delta)

	_apply_movement(delta)
	_update_animation_state()


# ---------------------------------------------------------------------------
# Реакция на игрока
# ---------------------------------------------------------------------------

func _update_player_awareness() -> void:
	if not is_instance_valid(player):
		return
	var dist_sq := global_position.distance_squared_to(player.global_position)
	var near := dist_sq <= awareness_radius * awareness_radius

	if near and _mode != Mode.PLAYER:
		if _mode == Mode.CHAT:
			_end_chat()
		_mode = Mode.PLAYER
		_desired_velocity = Vector2.ZERO
		_show_bubble("...")
	elif not near and _mode == Mode.PLAYER:
		_hide_bubble()
		_go_pause(randf_range(0.5, 1.5))


func _tick_player() -> void:
	_desired_velocity = Vector2.ZERO
	if not is_instance_valid(player):
		return
	var dist_sq := global_position.distance_squared_to(player.global_position)
	if dist_sq <= face_player_radius * face_player_radius:
		_face_towards(player.global_position)


# ---------------------------------------------------------------------------
# Прогулка и паузы
# ---------------------------------------------------------------------------

func _go_pause(duration: float = -1.0) -> void:
	_mode = Mode.PAUSE
	_pause_left = duration if duration >= 0.0 else randf_range(pause_time_range.x, pause_time_range.y)
	_desired_velocity = Vector2.ZERO
	_stuck_time = 0.0


func _go_wander() -> void:
	# Случайная точка вокруг «дома» — НПС гуляет рядом со своим местом
	var angle := randf() * TAU
	var dist := randf_range(wander_radius * 0.25, wander_radius)
	_wander_target = _home + Vector2.from_angle(angle) * dist
	_stuck_time = 0.0
	_mode = Mode.WANDER


func _tick_pause(delta: float) -> void:
	_desired_velocity = Vector2.ZERO
	_try_start_chat_periodically(delta)
	if _mode != Mode.PAUSE:
		return
	_pause_left -= delta
	if _pause_left <= 0.0:
		_go_wander()


func _tick_wander(delta: float) -> void:
	var to_target := _wander_target - global_position
	if to_target.length() <= arrive_distance:
		_go_pause()
		return

	var dir := to_target.normalized()
	_desired_velocity = dir * move_speed
	if absf(dir.x) > 0.05:
		_set_skin_flip(dir.x)
	_facing_dir = dir

	# Застряли в стене/объекте — не долбимся, а отдыхаем и выбираем другую точку
	if velocity.length() < move_speed * 0.2:
		_stuck_time += delta
		if _stuck_time > 0.6:
			_go_pause(randf_range(0.3, 1.2))
	else:
		_stuck_time = 0.0

	_try_start_chat_periodically(delta)


# ---------------------------------------------------------------------------
# Движение: плавный разгон + расталкивание между НПС
# ---------------------------------------------------------------------------

func _apply_movement(delta: float) -> void:
	var target_vel := _desired_velocity + _get_separation() * move_speed * separation_strength
	velocity = velocity.move_toward(target_vel, acceleration * delta)
	move_and_slide()


func _get_separation() -> Vector2:
	var push := Vector2.ZERO
	var sep_sq := separation_radius * separation_radius
	for other in get_tree().get_nodes_in_group("NPC"):
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var d_sq := offset.length_squared()
		if d_sq > 0.0001 and d_sq < sep_sq:
			# Чем ближе сосед — тем сильнее отталкивание
			var strength := 1.0 - sqrt(d_sq) / separation_radius
			push += offset.normalized() * strength
		elif d_sq <= 0.0001:
			push += Vector2.from_angle(randf() * TAU)
	return push.limit_length(1.0)


# ---------------------------------------------------------------------------
# Разговоры между НПС (как в Terraria)
# ---------------------------------------------------------------------------

func _can_chat() -> bool:
	return (current_state != State.DEAD
			and _chat_cooldown <= 0.0
			and (_mode == Mode.WANDER or _mode == Mode.PAUSE))


func _try_start_chat_periodically(delta: float) -> void:
	if not _can_chat():
		return
	_chat_check_timer -= delta
	if _chat_check_timer > 0.0:
		return
	_chat_check_timer = 0.5
	if randf() > chat_chance:
		return

	var chat_sq := chat_radius * chat_radius
	for other in get_tree().get_nodes_in_group("NPC"):
		if other == self or not (other is NPC):
			continue
		if not other._can_chat():
			continue
		if global_position.distance_squared_to(other.global_position) <= chat_sq:
			var duration := randf_range(chat_duration_range.x, chat_duration_range.y)
			_begin_chat(other, duration, 0)
			other._begin_chat(self, duration, 1)
			return


func _begin_chat(other: NPC, duration: float, parity: int) -> void:
	_partner = other
	_mode = Mode.CHAT
	_chat_left = duration
	_chat_elapsed = 0.0
	_chat_parity = parity
	_last_turn = -1
	_desired_velocity = Vector2.ZERO
	_face_towards(other.global_position)


func _tick_chat(delta: float) -> void:
	_desired_velocity = Vector2.ZERO
	if not is_instance_valid(_partner) or _partner._partner != self:
		_finish_chat()
		return

	_face_towards(_partner.global_position)
	_chat_elapsed += delta
	_chat_left -= delta

	# Реплики по очереди: сначала говорит один, потом другой
	var turn := int(_chat_elapsed / chat_turn_time)
	if turn != _last_turn:
		_last_turn = turn
		if turn % 2 == _chat_parity:
			_show_bubble(_CHAT_SYMBOLS[randi() % _CHAT_SYMBOLS.size()])
		else:
			_hide_bubble()

	if _chat_left <= 0.0:
		_end_chat()


## Завершить разговор у обоих участников
func _end_chat() -> void:
	var p := _partner
	_finish_chat()
	if is_instance_valid(p) and p._partner == self:
		p._finish_chat()


func _finish_chat() -> void:
	_partner = null
	_chat_cooldown = randf_range(chat_cooldown_range.x, chat_cooldown_range.y)
	_hide_bubble()
	if _mode == Mode.CHAT:
		_go_pause(randf_range(0.3, 1.0))


# ---------------------------------------------------------------------------
# Визуал: поворот, облачко, анимации
# ---------------------------------------------------------------------------

func _face_towards(point: Vector2) -> void:
	var dir := point - global_position
	if dir.length_squared() < 0.0001:
		return
	_facing_dir = dir.normalized()
	if absf(dir.x) > 0.05:
		_set_skin_flip(dir.x)


func _set_skin_flip(dir_x: float) -> void:
	$Skin.scale.x = -1.0 if dir_x < 0.0 else 1.0


func _create_bubble() -> void:
	_bubble = Label.new()
	_bubble.custom_minimum_size = Vector2(24, 14)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.add_theme_font_size_override("font_size", 10)
	_bubble.add_theme_color_override("font_outline_color", Color.BLACK)
	_bubble.add_theme_constant_override("outline_size", 3)
	_bubble.position = bubble_offset - Vector2(12, 0)
	_bubble.z_index = 20
	_bubble.visible = false
	add_child(_bubble)


func _show_bubble(text: String) -> void:
	if _bubble:
		_bubble.text = text
		_bubble.visible = true


func _hide_bubble() -> void:
	if _bubble:
		_bubble.visible = false


## Меняем состояние Creature только при смене «идёт / стоит», а не каждый кадр
func _update_animation_state() -> void:
	var moving := _mode == Mode.WANDER
	if moving == _anim_moving:
		return
	_anim_moving = moving
	_enter_state(_walk_state() if moving else State.IDLE)


func _walk_state():
	for key in ["WALK", "MOVE", "RUN"]:
		if State.has(key):
			return State[key]
	return _default_start_state()
