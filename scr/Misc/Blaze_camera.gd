@icon("res://addons/at-icons/mesh/video_camera.svg")
extends Camera2D
class_name Blaze_camera
## Камера со скриншотами.
## F2 - сделать скриншот сейчас, F3 - включить/выключить авто-режим.
## Из кода: set_auto_screenshot(true), toggle_auto_screenshot(), screenshot().

signal screenshot_taken(path: String)
signal auto_screenshot_changed(enabled: bool)

const SCREENSHOT_DIR := "user://Screenshots"

## Включён ли авто-режим (скриншот каждые auto_interval секунд).
@export var auto_screenshot: bool = true:
	set = set_auto_screenshot
@export_range(0.5, 600.0, 0.5, "suffix:s") var auto_interval: float = 5.0:
	set = set_auto_interval

@export_group("Hotkeys")
@export var screenshot_key: Key = KEY_F2
@export var toggle_auto_key: Key = KEY_F3

@export_group("Feedback")
## Белая вспышка после скриншота, чтобы игрок/разработчик ощутил "щёлк".
@export var show_flash: bool = true
@export_range(0.05, 1.0, 0.05, "suffix:s") var flash_duration: float = 0.25

var _timer: Timer
var _flash_rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	_ensure_dir()

	# Таймер ОБЯЗАТЕЛЬНО должен быть в дереве, иначе он не тикает.
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = auto_interval
	_timer.timeout.connect(screenshot)
	add_child(_timer)

	_setup_flash()
	_apply_auto_state()


# --- Публичный API ---------------------------------------------------------

func set_auto_screenshot(enabled: bool) -> void:
	if auto_screenshot == enabled:
		return
	auto_screenshot = enabled
	_apply_auto_state()
	auto_screenshot_changed.emit(enabled)


func toggle_auto_screenshot() -> void:
	set_auto_screenshot(not auto_screenshot)


func set_auto_interval(value: float) -> void:
	auto_interval = maxf(value, 0.1)
	if _timer:
		_timer.wait_time = auto_interval


func screenshot() -> void:
	if _busy: # защита от двух скриншотов за один кадр
		return
	_busy = true

	# Ждём, пока кадр полностью отрисуется.
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	var path := _next_path()
	var err := img.save_png(path)

	if err == OK:
		print("Screenshot saved: ", ProjectSettings.globalize_path(path))
		screenshot_taken.emit(path)
		_play_flash()
	else:
		push_error("Blaze_camera: не удалось сохранить скриншот (%s)" % error_string(err))

	_busy = false


# --- Ввод ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == screenshot_key:
		screenshot()
		get_viewport().set_input_as_handled()
	elif event.keycode == toggle_auto_key:
		toggle_auto_screenshot()
		get_viewport().set_input_as_handled()


# --- Внутреннее ------------------------------------------------------------

func _apply_auto_state() -> void:
	# Сеттер может сработать до _ready(), когда таймера ещё нет.
	if _timer == null:
		return
	if auto_screenshot:
		_timer.start(auto_interval)
	else:
		_timer.stop()
	print("Auto screenshot: ", "ON" if auto_screenshot else "OFF")


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SCREENSHOT_DIR):
		var err := DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
		if err != OK:
			push_error("Blaze_camera: не удалось создать папку скриншотов (%s)" % error_string(err))


## Имя по дате и времени: никогда не перезапишет старые файлы,
## даже если часть из них удалили.
func _next_path() -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/screenshot_%s.png" % [SCREENSHOT_DIR, stamp]
	var n := 1
	while FileAccess.file_exists(path):
		path = "%s/screenshot_%s_%d.png" % [SCREENSHOT_DIR, stamp, n]
		n += 1
	return path


func _setup_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color.WHITE
	_flash_rect.modulate.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash_rect)


## Вспышка рисуется ПОСЛЕ сохранения, поэтому в кадр не попадает.
func _play_flash() -> void:
	if not show_flash or _flash_rect == null:
		return
	var tween := create_tween()
	_flash_rect.modulate.a = 0.6
	tween.tween_property(_flash_rect, "modulate:a", 0.0, flash_duration)
