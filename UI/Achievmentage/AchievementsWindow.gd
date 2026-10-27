extends CanvasLayer
class_name AchievementsWindow

## Окно достижений. Внешний вид — в AchievementsWindow.tscn и AchievementRow.tscn
## (правится в редакторе без кода). Скрипт отвечает за открытие, паузу и данные.
##
## Подключение: Project Settings → Globals → Autoload → добавить СЦЕНУ
## AchievementsWindow.tscn с именем «AchievementsWindow».
## Открыть: клавиша J / нажатие правого стика, либо AchievementsWindow.toggle()
## (например, из меню паузы). Закрыть: Esc / B / J / кнопка. Пока окно открыто,
## игра стоит на паузе; если она уже была на паузе, после закрытия остаётся на ней.
## Прокрутка: колесо мыши, стрелки, D-pad или левый стик.

const ACTION := &"ShowAchievements"
const SCROLL_SPEED := 900.0

## Строка списка (AchievementRow.tscn)
@export var row_scene: PackedScene
## Сцена нарисована под эту высоту экрана; на другой окно масштабируется целиком.
@export var reference_height: float = 720.0
@export var auto_scale: bool = true

@onready var _root: Control = %Root
@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _counter: Label = %Counter
@onready var _total_bar: ProgressBar = %TotalBar
@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List
@onready var _close_button: Button = %CloseButton

var _open: bool = false
var _was_paused: bool = false
var _panel_base_size: Vector2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # работает и на паузе
	_register_input()
	_panel_base_size = _panel.custom_minimum_size
	_title.text = Loc.t("Achievements")
	_close_button.text = Loc.t("Close")
	_close_button.pressed.connect(close)
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()
	_root.hide()


## Если действия нет в Input Map — заводим по умолчанию (J и правый стик).
## Добавьте его в Project Settings → Input Map, чтобы переназначать.
func _register_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	InputMap.action_add_event(ACTION, pad)


## Масштабирует слой под высоту экрана и растягивает корень на весь вьюпорт.
func _fit_to_viewport() -> void:
	var vp := get_viewport().get_visible_rect().size
	var k := vp.y / reference_height if auto_scale else 1.0
	scale = Vector2(k, k)
	_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_root.size = vp / k
	# Панель не должна вылезать за экран на узких соотношениях сторон
	_panel.custom_minimum_size = _panel_base_size.min(_root.size * 0.92)


# ─────────────────────────────────────────────────────────────────────────────
#  Открытие / закрытие
# ─────────────────────────────────────────────────────────────────────────────

func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open:
		return
	var tracker := _get_tracker()
	if tracker == null:
		push_warning("[AchievementsWindow] AchievementTracker не найден (группа «AchievementTracker»)")
		return
	if row_scene == null:
		push_warning("[AchievementsWindow] не назначена row_scene")
		return
	_rebuild(tracker)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_open = true
	_root.show()
	_scroll.scroll_vertical = 0
	_close_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	_root.hide()
	get_tree().paused = _was_paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		# В меню (без игрока на сцене) горячая клавиша молчит
		if _open or get_tree().get_first_node_in_group("Player") != null:
			toggle()
			get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _open:
		return
	# Прокрутка с геймпада / клавиатуры
	var axis := Input.get_axis("ui_up", "ui_down")
	if absf(axis) > 0.1:
		_scroll.scroll_vertical += int(axis * SCROLL_SPEED * delta)


func _get_tracker() -> AchievementTracker:
	return get_tree().get_first_node_in_group("AchievementTracker") as AchievementTracker


## Перестраивает список по текущему состоянию трекера (при каждом открытии).
func _rebuild(tracker: AchievementTracker) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var done := tracker.get_unlocked_count()
	var total := tracker.get_total_count()
	_counter.text = "%d / %d" % [done, total]
	_total_bar.max_value = maxi(total, 1)
	_total_bar.value = done

	for entry in AchievementTracker.LIST:
		var id: StringName = entry[0]
		var row := row_scene.instantiate() as AchievementRow
		_list.add_child(row)
		row.setup(entry, tracker.is_unlocked(id), tracker.get_unlocked_time(id), tracker.get_progress(id))
