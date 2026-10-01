@icon("res://addons/at-icons/mesh/door.svg")
@tool
extends RapierArea2D
class_name Door

enum data_action {load_data, save_data}

@export var scene_name   : String
@export var player_spawn  : String
@export var action        : data_action = data_action.save_data

## Направление, в котором игрок должен двигаться для прохода.
@export_enum("Left","Right","Up","Down") var move_direction : String = "Left"
## Используй нормализованные значения: (0,-1)=вверх, (0,1)=вниз, (-1,0)=влево, (1,0)=вправо
var required_direction: Vector2 = Vector2.DOWN

## Как долго (сек) игрок автоматически идёт после перехода
@export_range(0.1, 3.0, 0.05) var exit_walk_duration: float = 0.5

## Скорость автохода после перехода (множитель стандартной скорости)
@export_range(0.1, 2.0, 0.05) var exit_walk_speed_mult: float = 0.7

# ── Внутреннее состояние ──────────────────────────────────────────
var _player_inside: Node2D = null   # игрок сейчас в зоне
var _waiting: bool = false           # ждём подтверждения

func _init() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(11, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(3, true)
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)

func _ready() -> void:
	match move_direction:
		"Left":
			required_direction = Vector2.LEFT
		"Right":
			required_direction = Vector2.RIGHT
		"Up":
			required_direction = Vector2.UP
		"Down":
			required_direction = Vector2.DOWN


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	_player_inside = body
	_waiting = true


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		_waiting = false


func _physics_process(_delta: float) -> void:
	if not _waiting or _player_inside == null:
		return

	# ── Проверяем ввод ───────────────────────────────────────────
	var dir := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")

	var move_match := false
	if required_direction != Vector2.ZERO and dir != Vector2.ZERO:
		# Совпадение если dot > 0.7 (~45°)
		move_match = dir.dot(required_direction.normalized()) > 0.7

	var rmb_pressed := Input.is_action_just_pressed("RMB")

	if move_match or rmb_pressed:
		_waiting = false
		_trigger_transition()


func _trigger_transition() -> void:
	var player := _player_inside   # сохраняем ссылку до смены сцены

	# ── Определяем направление выхода ────────────────────────────
	# required_direction — это направление входа; выход — то же самое
	var exit_dir := required_direction.normalized() if required_direction != Vector2.ZERO else Vector2.DOWN

	## ── Сохранение и смена сцены ─────────────────────────────────
	if action == data_action.save_data:
		Global.save_last_data()
		Global.save()
	var scene_key := scene_name
	var spawn     = player_spawn if not player_spawn.is_empty() else Vector2.ZERO

	if scene_key == "Previous":
		scene_key = Global.last_location
		if action == data_action.load_data:
			spawn = Global.last_position

	# Передаём направление автохода в SceneManager / Player после загрузки
	if player and player.has_method("queue_exit_walk"):
		player.queue_exit_walk(exit_dir, exit_walk_duration, exit_walk_speed_mult)

	Global.scene_manager.change_scene(scene_key, spawn)
