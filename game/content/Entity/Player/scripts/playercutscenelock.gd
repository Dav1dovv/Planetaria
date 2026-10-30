extends Node
class_name PlayerCutsceneLock

## Компонент игрока: «заморозка» на время катсцены.
## Включается через Player.is_in_cutscene (его же ставят треки анимации катсцены).
##
## Пока катсцена идёт:
##   • игрок не двигается, не бьёт, не взаимодействует (Player._input и _physics_process её игнорируют);
##   • весь интерфейс (HUD, хотбар, инвентарь, пауза, эффекты) скрыт и не принимает ввод;
##   • курсор мыши скрыт и ничего не подсвечивает.
## Когда катсцена закончилась — всё возвращается как было.

## Скрывать весь интерфейс игрока (GUI)
@export var hide_gui : bool = true
## Скрывать курсор мыши
@export var hide_mouse_cursor : bool = true

var _player : Player
var _locked : bool = false
var _prev_mouse_mode : Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_player = get_parent() as Player


func is_locked() -> bool:
	return _locked


func set_locked(value: bool) -> void:
	if value == _locked or _player == null:
		return
	_locked = value
	if value:
		_lock()
	else:
		_unlock()


func _lock() -> void:
	# 1) Останавливаем всё, что игрок делал в этот момент (как при респавне)
	_player.is_attack = false
	_player.velocity = Vector2.ZERO
	_player.movement.current_velocity = Vector2.ZERO
	_player.combat.is_lunging = false
	_player._hand.rotation = 0
	if _player.BodyAnimator:
		_player.BodyAnimator.play("Idle")
	if _player.HandAanimator:
		_player.HandAanimator.play("Idle")

	# 2) Закрываем открытые меню (инвентарь и т.п.)
	if Global.inventory != null and Global.inventory.has_method("close_any"):
		Global.inventory.close_any()

	# 3) Прячем интерфейс. PROCESS_MODE_DISABLED отключает и горячие клавиши в нём
	#    (инвентарь, хотбар, пауза), а не только рисование.
	if hide_gui and _player.gui != null:
		_player.gui.visible = false
		_player.gui.process_mode = Node.PROCESS_MODE_DISABLED

	# 4) Курсор: скрыт и «слепой» (ничего не подсвечивает и не нажимает)
	if hide_mouse_cursor:
		_prev_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		Cursor.detection_mode(true)


func _unlock() -> void:
	if hide_gui and _player.gui != null:
		_player.gui.visible = true
		_player.gui.process_mode = Node.PROCESS_MODE_INHERIT
		# Пока интерфейс «спал», показатели могли измениться — освежаем полосу здоровья
		_player.health_bar.update_value(_player.Entity_stats.current_health, _player.Entity_stats.max_health, _player.corruption)
	if hide_mouse_cursor:
		Input.mouse_mode = _prev_mouse_mode
		Cursor.detection_mode(false)


## Сцена закрылась посреди катсцены — возвращаем курсор, чтобы он не остался скрытым в меню.
func _exit_tree() -> void:
	if _locked and hide_mouse_cursor:
		Input.mouse_mode = _prev_mouse_mode
