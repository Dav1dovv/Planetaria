extends Node
class_name TutorialHints

## Ненавязчивое обучение «через действие»: подсказка исчезает, как только
## игрок сделал то, о чём она просит. Названия клавиш берутся из InputMap,
## так что подсказки не врут, если раскладку поменяли. F1 — пропустить.

const START_DELAY := 1.5
const STEP_TIMEOUT := 25.0
const DONE_FLASH := 0.7
const SKIP_KEY := KEY_F1

const STEP_IDS: Array[StringName] = [&"move", &"attack", &"interact", &"inventory"]

var _index: int = 0
## Сколько взаимодействий уже было к началу шага «взаимодействие»
var _interact_baseline: int = 0
var _step_time: float = 0.0
var _delay: float = START_DELAY
var _flash: float = 0.0
var _finished: bool = false

var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	_build_ui()
	_hide_panel()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)

	var h := get_viewport().get_visible_rect().size.y
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.8)
	style.set_corner_radius_all(int(h * 0.012))
	style.set_content_margin_all(h * 0.015)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_border_width_all(maxi(1, int(h * 0.003)))
	_panel.add_theme_stylebox_override("panel", style)

	# Якорь — центр низа экрана, панель растёт в стороны и вверх
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -h * 0.1
	_panel.offset_bottom = -h * 0.1
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_layer.add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", int(h * 0.035))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_panel.add_child(_label)


func _process(delta: float) -> void:
	if _finished:
		return

	# Подсказки живут только пока на сцене есть игрок (в меню — тишина)
	if get_tree().get_first_node_in_group("Player") == null:
		_hide_panel()
		_delay = START_DELAY
		_step_time = 0.0
		return
	if get_tree().paused:
		return
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			_show_step()
		return

	if Input.is_key_pressed(SKIP_KEY):
		_finish()
		return

	# Короткая «галочка» после выполнения шага
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_index += 1
			_step_time = 0.0
			if _index >= STEP_IDS.size():
				_finish()
			else:
				_show_step()
		return

	_step_time += delta
	if _is_step_done(STEP_IDS[_index]):
		_label.text = Loc.t("Great!")
		_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		_flash = DONE_FLASH
	elif _step_time > STEP_TIMEOUT:
		# Не получилось за 25 секунд — не мучаем, идём дальше
		_flash = 0.01


func _show_step() -> void:
	if _index >= STEP_IDS.size():
		return
	_interact_baseline = Cursor.interact_count
	_label.text = "%s   (%d/%d)" % [_step_text(STEP_IDS[_index]), _index + 1, STEP_IDS.size()]
	_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.visible = true


func _hide_panel() -> void:
	if _panel:
		_panel.visible = false


func _finish() -> void:
	_finished = true
	_hide_panel()


## Начать обучение заново (новый посетитель выставки).
func reset() -> void:
	_index = 0
	_step_time = 0.0
	_delay = START_DELAY
	_flash = 0.0
	_finished = false
	_hide_panel()


func _is_step_done(id: StringName) -> bool:
	match id:
		&"move":
			return _has_actions(["MoveLeft", "MoveRight", "MoveUp", "MoveDown"]) \
					and Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown").length() > 0.1
		&"attack":
			return InputMap.has_action("LMB") and Input.is_action_just_pressed("LMB")
		&"interact":
			# Шаг выполнен, когда игрок реально взаимодействовал с объектом (ЛКМ / RT по объекту)
			return Cursor.interact_count > _interact_baseline
		&"inventory":
			return InputMap.has_action("CallInventory") and Input.is_action_just_pressed("CallInventory")
	return true


func _step_text(id: StringName) -> String:
	match id:
		&"move":
			var keys := " ".join([_key("MoveUp"), _key("MoveLeft"), _key("MoveDown"), _key("MoveRight")])
			return Loc.t("%s — move") % keys
		&"attack":
			return Loc.t("%s — attack") % _key("LMB")
		&"interact":
			return Loc.t("%s on an object nearby — interact") % _key("LMB")
		&"inventory":
			return Loc.t("%s — inventory and crafting") % _key("CallInventory")
	return ""


func _has_actions(actions: Array) -> bool:
	for action in actions:
		if not InputMap.has_action(action):
			return false
	return true


## Человекочитаемое имя первой привязанной клавиши/кнопки действия.
func _key(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	# На геймпаде показываем кнопку контроллера (A/Cross/B, RT/R2/ZR...), а не клавишу
	if InputHints.device() == InputHints.Device.GAMEPAD:
		var glyph = ControllerGlyphs.action_label(action)
		if not glyph.is_empty():
			return glyph
	for event in InputMap.action_get_events(action):
		var text := event.as_text().replace(" (Physical)", "")
		text = text.replace("Left Mouse Button", Loc.t("LMB"))
		text = text.replace("Right Mouse Button", Loc.t("RMB"))
		return text
	return "?"
