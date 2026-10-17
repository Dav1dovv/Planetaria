# input_hints.gd
## Определяет, чем игрок управляет СЕЙЧАС (клавиатура/мышь, геймпад, касание),
## и отдаёт подсказки на нужном языке с нужными кнопками.
##
## Зачем: подсказка «ESC — закрыть» бессмысленна на телефоне и неточна на геймпаде.
## Синглтон создаётся сам при первом обращении (автозагрузку в project.godot добавлять не нужно).
##
## Использование:
##   InputHints.bind_label(my_label, InputHints.close_hint)   # текст сам обновится при смене устройства/языка
##   if InputHints.is_touch(): ...
class_name InputHints
extends Node

signal device_changed(device: int)

enum Device { KEYBOARD, GAMEPAD, TOUCH }

const STICK_THRESHOLD := 0.5

static var _instance: InputHints

var _device: Device = Device.KEYBOARD


static func instance() -> InputHints:
	if _instance == null or not is_instance_valid(_instance):
		_instance = InputHints.new()
		_instance.name = "InputHints"
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.root.add_child.call_deferred(_instance)
	return _instance


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # работает и на паузе
	_device = Device.TOUCH if DisplayServer.is_touchscreen_available() else Device.KEYBOARD


func _input(event: InputEvent) -> void:
	var detected := _device
	# Эмулированные из касаний события мыши не считаем «мышью», иначе телефон мигал бы режимами
	var emulated := event.device == InputEvent.DEVICE_ID_EMULATION
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		detected = Device.TOUCH
	elif event is InputEventJoypadButton:
		detected = Device.GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_THRESHOLD:
			detected = Device.GAMEPAD
	elif (event is InputEventKey or event is InputEventMouseButton) and not emulated:
		detected = Device.KEYBOARD
	elif event is InputEventMouseMotion and not emulated:
		detected = Device.KEYBOARD

	if detected != _device:
		_device = detected
		device_changed.emit(_device)


func _notification(what: int) -> void:
	# Сменили язык – подсказки надо перечитать
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		device_changed.emit(_device)


# ─────────────────────────────────────────────────────────────────────────────
#  Публичный API
# ─────────────────────────────────────────────────────────────────────────────

static func device() -> Device:
	return instance()._device


static func is_touch() -> bool:
	return instance()._device == Device.TOUCH


## Привязывает Label к функции-провайдеру текста. Пустой текст = подсказка не нужна.
static func bind_label(label: Label, provider: Callable) -> void:
	var hub := instance()
	var update := func(_device_id: int = 0) -> void:
		if is_instance_valid(label):
			label.text = provider.call()
	update.call()
	hub.device_changed.connect(update)
	label.tree_exited.connect(func() -> void:
		if hub.device_changed.is_connected(update):
			hub.device_changed.disconnect(update))


## «ESC — закрыть» / «B — закрыть» / ничего (на телефоне виден ✕).
static func close_hint() -> String:
	match device():
		Device.GAMEPAD: return Loc.t("B — close")
		Device.TOUCH: return ""
		_: return Loc.t("ESC — close")


static func trade_hint() -> String:
	match device():
		Device.GAMEPAD: return Loc.t("A — buy / sell 1 pc.   |   B — close")
		Device.TOUCH: return Loc.t("Tap — buy / sell 1 pc.")
		_: return Loc.t("ЛКМ — купить / продать 1 шт.   |   ESC — закрыть")


static func save_screen_hint() -> String:
	match device():
		Device.GAMEPAD: return Loc.t("A - enter   |   Y - revoke   |   B - back")
		Device.TOUCH: return ""
		_: return Loc.t("Enter - enter   |   Del - revoke   |   Esc - back")
