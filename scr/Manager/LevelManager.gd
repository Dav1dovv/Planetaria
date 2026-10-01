extends Node
class_name SceneManager

# ═══════════════════════════════════════════════════════════════════════════════
#  SceneManager — менеджер переходов между сценами
# ───────────────────────────────────────────────────────────────────────────────
#  Возможности:
#   • Переход с fade-анимацией и загрузочным сообщением
#   • Именованные точки спавна внутри сцены
#   • Точная установка позиции игрока ПОСЛЕ загрузки (без таймеров наугад)
#   • Опциональное сохранение перед переходом
#   • Автоматическая настройка мира через SceneData (музыка, day/night, и т.п.)
#   • Команды консоли: tp_scene, list_scenes
#   • Сигналы для подписки других систем (музыка, UI и т.д.)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Сигналы ───────────────────────────────────────────────────────────────────
## Выстреливает перед сменой сцены
signal scene_change_started(scene_data: SceneData)
## Выстреливает когда новая сцена полностью готова и игрок размещён
signal scene_change_finished(scene_data: SceneData)

# ── Константы ─────────────────────────────────────────────────────────────────
const MAIN_MENU := "res://Assets/Scenes/Menu/main_menu.tscn"

# ── Ноды ──────────────────────────────────────────────────────────────────────
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var message_label:    Label           = $CanvasLayer/ColorRect/Message

# ── Экспорты ──────────────────────────────────────────────────────────────────

## Реестр всех сцен. Создай SceneRegistry ресурс и назначь сюда.
@export var scene_registry: SceneRegistry

## Глобальные загрузочные подсказки (используются если у SceneData нет своих)
@export var loading_messages: Array[String] = [
	"Mineral warriors is dangerous",
	"Tree's is the best helpful instrument",
	"Forest's not so dangerous than tundra or desert",
]

## Минимальное время показа экрана загрузки (сек)
@export_range(0.0, 3.0, 0.1) var min_loading_time: float = 1.0


# ── Внутреннее состояние ──────────────────────────────────────────────────────
var _is_transitioning: bool = false
var _current_scene_data: SceneData = null


# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	if scene_registry == null:
		push_error("SceneManager: scene_registry не назначен! Назначь SceneRegistry ресурс в Инспекторе.")
	_register_commands()


func _register_commands() -> void:
	if not %DeveloperConsole:
		return
	var c := %DeveloperConsole
	c.register_command("list_scenes", _cmd_list_scenes, "Показать все доступные сцены")
	c.register_command("tp_scene",    _cmd_change_scene, "tp_scene [key] [x y | spawn_name]")


# ═══════════════════════════════════════════════════════════════════════════════
#  ПУБЛИЧНЫЙ API
# ═══════════════════════════════════════════════════════════════════════════════

## Основной переход между сценами.
##
## [param scene_key]  — ключ из SceneRegistry
## [param can_save]   — сохранить игру перед переходом
## [param spawn]      — куда поставить игрока после загрузки:
##                      • Vector2          → конкретная позиция
##                      • String           → имя ноды SpawnPoint в новой сцене
##                      • Vector2.ZERO     → не двигать (позиция по умолчанию)
func change_scene(scene_key: String, spawn = Vector2.ZERO) -> void:
	if _is_transitioning:
		push_warning("SceneManager: переход уже идёт, запрос проигнорирован.")
		return

	if scene_registry == null:
		push_error("SceneManager: scene_registry не назначен.")
		return

	var scene_data: SceneData = scene_registry.get_scene(scene_key)
	if scene_data == null:
		push_error("SceneManager: неизвестная сцена '%s'. Доступные: %s" % [
			scene_key, str(scene_registry.get_all_keys())
		])
		return

	get_tree().call_group("Save", "save_game")
	_is_transitioning = true
	emit_signal("scene_change_started", scene_data)
	# ── Обновляем состояние в Global ──────────────────────────────────────────
	Global.current_location = scene_key
	Cursor.detection_mode(true)

	# ── Fade IN ───────────────────────────────────────────────────────────────
	_update_message(scene_data)
	animation_player.play("Fade_In")
	await animation_player.animation_finished

	var load_start := Time.get_ticks_msec()

	# ── Смена сцены ───────────────────────────────────────────────────────────
	get_tree().change_scene_to_file(scene_data.scene_path)
	await get_tree().physics_frame

	# Добиваем минимальное время загрузки
	var elapsed := (Time.get_ticks_msec() - load_start) / 1000.0
	if elapsed < min_loading_time:
		await get_tree().create_timer(min_loading_time - elapsed).timeout

	# ── Применяем настройки мира из SceneData ─────────────────────────────────
	_apply_scene_settings(scene_data)

	# ── Позиционируем игрока ──────────────────────────────────────────────────
	_place_player(spawn)

	# ── Fade OUT ──────────────────────────────────────────────────────────────
	animation_player.play("Fade_out")
	await animation_player.animation_finished

	Cursor.detection_mode(false)
	_current_scene_data = scene_data
	_is_transitioning = false
	emit_signal("scene_change_finished", scene_data.music_key)
	$CanvasLayer/CanvasLayer2/Control/Label.text = scene_data.display_name
	$CanvasLayer/CanvasLayer2/Control/Label2.text = scene_data.display_name
	$CanvasLayer/CanvasLayer2/LabelAnim.play("Show")


## Переход в главное меню с автосохранением.
func change_to_main_menu() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_update_message(null)
	Cursor.detection_mode(true)
	get_tree().call_group("Save", "save_game")

	animation_player.play("Fade_In")
	await animation_player.animation_finished

	get_tree().change_scene_to_file(MAIN_MENU)
	await get_tree().physics_frame

	animation_player.play("Fade_out")
	await animation_player.animation_finished

	Cursor.detection_mode(false)
	_current_scene_data = null
	_is_transitioning = false


## Простой fade без смены сцены (для cutscene или телепорта внутри сцены).
func fade(update_msg: bool = true) -> void:
	if update_msg:
		_update_message(_current_scene_data)
	animation_player.play("Fade_In")
	await animation_player.animation_finished
	animation_player.play("Fade_out")
	await animation_player.animation_finished


## Телепортирует игрока внутри текущей сцены без перехода.
func teleport_player(spawn) -> void:
	_place_player(spawn)


## Возвращает true если переход сейчас в процессе.
func is_busy() -> bool:
	return _is_transitioning


## Данные текущей активной сцены (null если не загружена через SceneManager).
func get_current_scene_data() -> SceneData:
	return _current_scene_data


# ═══════════════════════════════════════════════════════════════════════════════
#  ВНУТРЕННИЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════════

## Применяет настройки из SceneData к текущему состоянию мира.
func _apply_scene_settings(scene_data: SceneData) -> void:
	if Global.day_night:
		Global.day_night.visible = not scene_data.is_underground

	var gm := get_tree().get_first_node_in_group("World")
	if gm and gm.has_method("set_corruption_level"):
		gm.set_corruption_level(scene_data.corruption_level)  # убрали > 0

func _place_player(spawn) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return

	if spawn is String and spawn != "":
		var point := _find_spawn_point(spawn)
		if point:
			player.global_position = point.global_position
		else:
			push_warning("SceneManager: SpawnPoint '%s' не найден в сцене." % spawn)
	elif spawn is Vector2 and spawn != Vector2.ZERO:
		player.global_position = spawn


func _find_spawn_point(point_name: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("SpawnPoint"):
		if node.name == point_name:
			return node as Node2D
	return null


func _update_message(scene_data: SceneData) -> void:
	# Сначала берём подсказки из SceneData, если они есть
	if scene_data != null and not scene_data.loading_hints.is_empty():
		message_label.text = scene_data.loading_hints.pick_random()
		return
	# Иначе — глобальные
	if not loading_messages.is_empty():
		message_label.text = loading_messages.pick_random()


# ═══════════════════════════════════════════════════════════════════════════════
#  КОМАНДЫ КОНСОЛИ
# ═══════════════════════════════════════════════════════════════════════════════

func _cmd_change_scene(args: Array) -> String:
	if args.is_empty():
		return "Usage: tp_scene [key] [x y | spawn_name]"

	var key: String = args[0]
	if not scene_registry.has_scene(key):
		return "Неизвестная сцена '%s'. Доступные: %s" % [key, str(scene_registry.get_all_keys())]

	var spawn = Vector2.ZERO
	if args.size() == 3 and args[1].is_valid_float() and args[2].is_valid_float():
		spawn = Vector2(args[1].to_float(), args[2].to_float())
	elif args.size() == 2:
		spawn = args[1]

	change_scene(key, spawn)
	return "Переход в '%s'..." % key


func _cmd_list_scenes(args: Array) -> String:
	if scene_registry == null:
		return "scene_registry не назначен."
	var keys := scene_registry.get_all_keys()
	if keys.is_empty():
		return "Нет зарегистрированных сцен."
	var lines := ["Доступные сцены:"]
	for key: String in keys:
		var sd: SceneData = scene_registry.get_scene(key)
		lines.append("  • %-20s [%s] corruption=%d %s" % [
			key,
			sd.biome,
			sd.corruption_level,
			"(underground)" if sd.is_underground else ""
		])
	return "\n".join(lines)
