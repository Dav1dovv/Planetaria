extends RefCounted
class_name GameJuice

## Статические помощники "сочности": цифры урона, баннеры, тосты,
## хит-стоп и тряска камеры. Автозагрузка не нужна — слой интерфейса
## создаётся лениво в корне дерева (см. JuiceLayer).

const FONT_TITLE := "res://Assets/Fonts/Conthrax-SemiBold.otf"
## Во время хит-стопа время почти замирает (не 0 — чтобы твины не залипали)
const HITSTOP_TIME_SCALE := 0.02

static var _layer: JuiceLayer
static var _title_font: Font
static var _title_font_loaded: bool = false

static var _hitstop_token: int = 0
static var _hitstop_active: bool = false
static var _saved_time_scale: float = 1.0

static var _shake_tween: Tween
static var _shake_cam: Camera2D
static var _shake_origin: Vector2


# ─────────────────────────────────────────────────────────────────────────────
#  Шрифт заголовков (армянские буквы подтягиваются через запасной шрифт, см. Loc)
# ─────────────────────────────────────────────────────────────────────────────
static func get_title_font() -> Font:
	if not _title_font_loaded:
		_title_font_loaded = true
		if ResourceLoader.exists(FONT_TITLE):
			_title_font = load(FONT_TITLE) as Font
	return _title_font


# ─────────────────────────────────────────────────────────────────────────────
#  Слой интерфейса
# ─────────────────────────────────────────────────────────────────────────────
static func get_layer() -> JuiceLayer:
	if is_instance_valid(_layer) and not _layer.is_queued_for_deletion():
		return _layer
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_layer = JuiceLayer.new()
	_layer.name = "JuiceLayer"
	# call_deferred: безопасно, даже если вызвали, пока корень "занят" загрузкой
	tree.root.add_child.call_deferred(_layer)
	return _layer


## Всплывающий текст в мировых координатах (урон, "+3 Wood", комбо).
static func floating_text(world_pos: Vector2, message: String, color: Color = Color.WHITE,
		size_mult: float = 1.0, life: float = 0.8, rise: float = 24.0, pop_scale: float = 1.5) -> void:
	var layer := get_layer()
	if layer:
		layer.spawn_floating_text(world_pos, message, color, size_mult, life, rise, pop_scale)


## Большая плашка по центру экрана (пробуждение босса, финал планеты).
static func banner(title: String, subtitle: String = "", color: Color = Color.WHITE, hold: float = 1.8) -> void:
	var layer := get_layer()
	if layer:
		layer.show_banner(title, subtitle, color, hold)


## Небольшое уведомление сверху (задание выполнено, подсказки).
static func toast(message: String, color: Color = Color.WHITE, hold: float = 2.6) -> void:
	var layer := get_layer()
	if layer:
		layer.show_toast(message, color, hold)


# ─────────────────────────────────────────────────────────────────────────────
#  Хит-стоп
# ─────────────────────────────────────────────────────────────────────────────
## Замораживает время на duration секунд (реального времени).
## Безопасен при наложении: время вернёт только последний из вызовов.
static func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if not _hitstop_active:
		_saved_time_scale = Engine.time_scale
		_hitstop_active = true
	_hitstop_token += 1
	var my_token := _hitstop_token
	Engine.time_scale = HITSTOP_TIME_SCALE
	# 4-й аргумент (ignore_time_scale) — таймер идёт по реальному времени
	await tree.create_timer(duration, true, false, true).timeout
	if my_token == _hitstop_token:
		Engine.time_scale = _saved_time_scale
		_hitstop_active = false


## Аварийный сброс (возврат в меню, смерть во время хит-стопа).
static func reset() -> void:
	_hitstop_token += 1
	_hitstop_active = false
	Engine.time_scale = 1.0


# ─────────────────────────────────────────────────────────────────────────────
#  Тряска камеры
# ─────────────────────────────────────────────────────────────────────────────
static func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var cam := tree.root.get_camera_2d()
	if cam == null:
		return

	# Повторная тряска: гасим старый твин, но "домашнюю" точку не теряем
	if is_instance_valid(_shake_tween) and _shake_tween.is_valid() and _shake_cam == cam:
		_shake_tween.kill()
	else:
		_shake_origin = cam.offset
	_shake_cam = cam

	var steps := maxi(2, int(duration / 0.03))
	_shake_tween = cam.create_tween()
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		var target := _shake_origin + Vector2(randf_range(-s, s), randf_range(-s, s))
		_shake_tween.tween_property(cam, "offset", target, 0.03)
	_shake_tween.tween_property(cam, "offset", _shake_origin, 0.04)
