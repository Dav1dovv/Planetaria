extends Node2D
class_name TeleportChannel

## Заряд телепортера: живёт на игроке, пока идёт заряд, и сам удаляется.
## Создаётся через TeleportChannel.begin() — scene игрока править не нужно.
##
## Заряд прерывается, если: игрок получил урон, сменил предмет в руке, умер, а при
## interrupt_on_move ещё и пошёл. Предмет тратится только в момент успешного телепорта.

const NODE_NAME := "TeleportChannel"
const MOVE_EPSILON := 6.0

var _player: Player
var _data: TeleporterData
var _elapsed: float = 0.0
var _last_hp: float = 0.0
var _finished: bool = false
var _swirl: CPUParticles2D


## Можно ли сейчас запускать заряд. Показывает подсказку, если нельзя.
static func can_start(player: Player, data: TeleporterData) -> bool:
	if player.has_node(NODE_NAME):
		return false  # уже заряжается — второй клик игнорируем без подсказки
	if Global.current_location == data.destination_scene:
		Global.hint(player, Loc.t("You are already here"))
		return false
	return true


## Запускает заряд. Возвращает канал или null, если запуск невозможен.
static func begin(player: Player, data: TeleporterData) -> TeleportChannel:
	if not can_start(player, data):
		return null
	var channel := TeleportChannel.new()
	channel.name = NODE_NAME
	channel._player = player
	channel._data = data
	player.add_child(channel)
	channel._start()
	return channel


func _start() -> void:
	position = Vector2(0.0, 8.0)  # под ногами
	z_index = 5
	_last_hp = _player.Entity_stats.current_health
	if _data.interrupt_on_damage:
		_player.health_changed.connect(_on_health_changed)

	_play_sound(_data.charge_sound)
	_swirl = _make_swirl()
	add_child(_swirl)

	if _data.channel_time <= 0.0:
		_complete()
	else:
		GameJuice.toast(Loc.t("Teleporting..."), _data.effect_color, _data.channel_time)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	if not is_instance_valid(_player) or not _player.is_alive:
		_cancel(false)
		return
	if _player.hit_box == null or _player.hit_box.equip != _data:
		_cancel(true)  # убрал телепортер из руки
		return
	if _data.interrupt_on_move and _player.velocity.length() > MOVE_EPSILON:
		_cancel(true)
		return

	_elapsed += delta
	queue_redraw()
	if _elapsed >= _data.channel_time:
		_complete()


func _on_health_changed(new_health: float) -> void:
	if _finished:
		return
	if new_health < _last_hp - 0.001:
		_cancel(true)
	_last_hp = new_health


# ─────────────────────────────────────────────────────────────────────────────
#  Завершение
# ─────────────────────────────────────────────────────────────────────────────
func _complete() -> void:
	_finished = true
	_burst(36, 70.0)
	_play_sound(_data.teleport_sound)
	GameJuice.shake(2.0, 0.25)

	# Сначала списываем и сохраняем, потом уходим: сохранение должно видеть уже потраченный предмет
	if _data.consume_on_use:
		_player.hit_box.consume_one_from_selected_slot()
	Global.save()
	Global.scene_manager.change_scene(_data.destination_scene, Vector2.ZERO)
	_end()


func _cancel(show_message: bool) -> void:
	_finished = true
	if show_message:
		GameJuice.toast(Loc.t("Teleport interrupted"), Color(1.0, 0.45, 0.4))
		_burst(12, 30.0)
	_end()


func _end() -> void:
	if is_instance_valid(_player) and _player.health_changed.is_connected(_on_health_changed):
		_player.health_changed.disconnect(_on_health_changed)
	# Само имя освобождаем сразу, чтобы новый заряд можно было начать в тот же кадр
	name = "TeleportChannel_done"
	queue_free()


# ─────────────────────────────────────────────────────────────────────────────
#  Визуал: кольцо-прогресс под ногами и столб частиц
# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	if _data == null or _data.channel_time <= 0.0:
		return
	var progress := clampf(_elapsed / _data.channel_time, 0.0, 1.0)
	var radius := lerpf(20.0, 11.0, progress)
	var c := _data.effect_color
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(c, 0.25), 1.0)
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(c, 0.95), 2.0)


func _make_swirl() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.8
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2.UP
	p.spread = 15.0
	p.gravity = Vector2(0.0, -30.0)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 28.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.2
	p.color_ramp = _fade_ramp(_data.effect_color)
	return p


func _burst(amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color_ramp = _fade_ramp(_data.effect_color)
	p.z_index = 5
	# На сцену, а не на игрока: при смене сцены игрок уходит, вспышка должна догореть
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(p)
	p.global_position = global_position
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(color, 1.0), Color(color, 0.0)])
	return g


func _play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
