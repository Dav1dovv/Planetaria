extends Node

## Автозагрузка «GamepadAim»: единая точка прицеливания для мыши и геймпада.
##
## ПРОБЛЕМА: игра целится мышью (get_global_mouse_position), у геймпада мыши нет.
## РЕШЕНИЕ: весь код спрашивает GamepadAim.aim_world() вместо мыши.
##  * мышь: возвращает позицию мыши в мире — поведение прежнее;
##  * геймпад: правый стик задаёт направление, точка прицела стоит рядом с игроком
##    в этом направлении (twin-stick). Отпустил стик — прицел остаётся.
##    Если стик не трогали, а идёшь левым — прицел плавно смотрит по ходу движения.
##  * автоприцел: враги, интерактивные объекты и ресурсы в узком конусе перед игроком
##    «примагничивают» прицел — иначе курсор-Area2D не попадёт в маленькую цель, и
##    наведение/подсветка/ЛКМ-взаимодействие на стике не работали бы.
##
## Переключение между мышью и геймпадом автоматическое: тронул мышь — мышь,
## нажал кнопку или двинул стик — геймпад. В режиме геймпада системный курсор
## скрыт и рисуется прицел-перекрестие (его цвет повторяет состояние курсора).

signal mode_changed(using_gamepad: bool)

## Расстояние от игрока до точки прицела без автоприцела (px мира)
const AIM_DISTANCE := 44.0
## Сглаживание движения прицела (больше = резче)
const SMOOTH := 22.0
## Через сколько секунд без правого стика прицел начинает следовать за движением
const IDLE_FOLLOW_DELAY := 0.6
## Насколько надо сдвинуть мышь, чтобы забрать управление у геймпада
const MOUSE_TAKEOVER_PX := 1.5
## Дальность автоприцела по группам (px от игрока). Нет группы — нет автоприцела.
const ASSIST_RANGE := {
	"Ennemy": 110.0,
	"CurseObject": 90.0,
	"interaction": 60.0,
	"Harvestable": 56.0,
}
## Половина угла конуса автоприцела (рад, ~38°)
const ASSIST_CONE := 0.66
## Враги важнее объектов: их расстояние «дешевле»
const ASSIST_PRIORITY := {"Ennemy": 0.6, "CurseObject": 0.7}

var using_gamepad: bool = false

var _aim_dir: Vector2 = Vector2.RIGHT
var _aim_world: Vector2 = Vector2.ZERO
var _last_stick_time: float = -100.0
var _fresh: bool = true
var _reticle: Node2D
var _target_state: String = "simple"
var _switch_layout: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # переключение устройства работает и на паузе
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_reticle = _Reticle.new()
	_reticle.visible = false
	layer.add_child(_reticle)

	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: refresh_platform_layout())
	refresh_platform_layout()


## Nintendo: «подтвердить» — правая кнопка, «назад» — нижняя (у Xbox/PlayStation наоборот).
## Godot называет кнопки по положению, поэтому на Switch меняем местами A и B у меню и диалогов
## (GDD: «меню читает платформу»). Вызывается при подключении геймпада.
func refresh_platform_layout() -> void:
	var want := ControllerGlyphs.family() == ControllerGlyphs.Family.SWITCH
	if want == _switch_layout:
		return
	_switch_layout = want
	for action in ["ui_accept", "ui_cancel", "dialogic_default_action"]:
		_swap_face_buttons(action)


func _swap_face_buttons(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	for event in events:
		var pad := event as InputEventJoypadButton
		if pad == null:
			InputMap.action_add_event(action, event)
			continue
		var swapped := pad.duplicate() as InputEventJoypadButton
		if pad.button_index == JOY_BUTTON_A:
			swapped.button_index = JOY_BUTTON_B
		elif pad.button_index == JOY_BUTTON_B:
			swapped.button_index = JOY_BUTTON_A
		InputMap.action_add_event(action, swapped)


## Мировая позиция прицела. Единственное место, откуда игра берёт «куда целимся».
func aim_world() -> Vector2:
	if using_gamepad:
		return _aim_world
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


## Направление прицела от игрока (для стрельбы и ударов).
func aim_direction() -> Vector2:
	return _aim_dir


func _input(event: InputEvent) -> void:
	var emulated := event.device == InputEvent.DEVICE_ID_EMULATION
	if event is InputEventMouseMotion and not emulated:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_TAKEOVER_PX:
			_set_gamepad(false)
	elif event is InputEventMouseButton and not emulated:
		_set_gamepad(false)
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_set_gamepad(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_set_gamepad(true)


func _set_gamepad(value: bool) -> void:
	if value == using_gamepad:
		return
	using_gamepad = value
	_fresh = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	if _reticle != null:
		_reticle.visible = false
	mode_changed.emit(value)


func _process(delta: float) -> void:
	if not using_gamepad:
		return

	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var playing := player != null and not get_tree().paused and not Global.is_opened_menu \
			and not DialogueLock.is_locked()
	_reticle.visible = playing
	if not playing:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var stick := Input.get_vector("AimLeft", "AimRight", "AimUp", "AimDown")
	if stick.length() > 0.01:
		_aim_dir = stick.normalized()
		_last_stick_time = now
	else:
		var move := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
		if move.length() > 0.3 and now - _last_stick_time > IDLE_FOLLOW_DELAY:
			_aim_dir = _aim_dir.slerp(move.normalized(), clampf(delta * 6.0, 0.0, 1.0))

	var target := player.global_position + _aim_dir * AIM_DISTANCE
	var assist := _find_assist(player)
	if assist != null:
		target = assist.global_position

	if _fresh:
		_aim_world = target
		_fresh = false
	else:
		_aim_world = _aim_world.lerp(target, 1.0 - exp(-SMOOTH * delta))

	_target_state = Cursor.get_state()
	var vp := get_viewport()
	_reticle.position = vp.get_canvas_transform() * _aim_world
	(_reticle as _Reticle).state = _target_state
	_reticle.queue_redraw()


## Ближайшая цель в конусе прицела: враги в приоритете.
func _find_assist(player: Node2D) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for group in ASSIST_RANGE:
		var max_range: float = ASSIST_RANGE[group]
		var priority: float = ASSIST_PRIORITY.get(group, 1.0)
		for node in get_tree().get_nodes_in_group(group):
			var n := node as Node2D
			if n == null or not n.is_visible_in_tree():
				continue
			var to := n.global_position - player.global_position
			var dist := to.length()
			if dist < 1.0 or dist > max_range:
				continue
			var angle := absf(_aim_dir.angle_to(to))
			if angle > ASSIST_CONE:
				continue
			var score := dist * priority + angle * 40.0
			if score < best_score:
				best_score = score
				best = n
	return best


## Перекрестие: 4 пиксельные чёрточки вокруг пустого центра.
class _Reticle extends Node2D:
	var state: String = "simple"

	func _draw() -> void:
		var c := Color(1, 1, 1, 0.9)
		match state:
			"fight", "deflect": c = Color(1.0, 0.4, 0.35, 0.95)
			"interact": c = Color(1.0, 0.85, 0.3, 0.95)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var from: Vector2 = d * 3.0
			var to: Vector2 = d * 6.0
			draw_line(from + Vector2(1, 1), to + Vector2(1, 1), Color(0, 0, 0, 0.6), 1.0)  # тень
			draw_line(from, to, c, 1.0)
