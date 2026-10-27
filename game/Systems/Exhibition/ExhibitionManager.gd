extends CanvasLayer
class_name ExhibitionManager

## «Режим выставки»: если посетитель ушёл от стенда — игра предупреждает,
## а затем возвращается в главное меню (сессия сбрасывается). Также показывает
## финальный экран. F10 — включить/выключить режим выставки.

## Через сколько секунд без ввода возвращаемся в меню
const IDLE_RESET_SEC := 150.0
## За сколько секунд до сброса показываем предупреждение
const IDLE_WARNING_SEC := 20.0
## Через сколько секунд финальный экран сам вернёт в меню
const FINALE_AUTO_RETURN_SEC := 45.0
const TOGGLE_KEY := KEY_F10

var exhibition_mode: bool = false

var _last_activity_ms: int = 0
var _warning_root: Control
var _warning_label: Label
var _finale_open: bool = false
var _returning: bool = false
var _tracker: SessionTracker


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_activity_ms = Time.get_ticks_msec()
	_tracker = Global.get_node_or_null("SessionTracker") as SessionTracker
	_build_warning()

	var celebrator := Global.get_node_or_null("QuestCelebrator") as QuestCelebrator
	if celebrator:
		celebrator.finale_reached.connect(_on_finale_reached)


func _build_warning() -> void:
	_warning_root = ColorRect.new()
	(_warning_root as ColorRect).color = Color(0.0, 0.0, 0.0, 0.7)
	_warning_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_root.visible = false
	add_child(_warning_root)
	_warning_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_warning_label = Label.new()
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_warning_label.add_theme_constant_override("outline_size", 6)
	_warning_root.add_child(_warning_label)
	_warning_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		exhibition_mode = not exhibition_mode
		_touch()
		GameJuice.toast(Loc.t("Exhibition mode: ")
				+ (Loc.t("ON") if exhibition_mode else Loc.t("OFF")))
		return
	if _is_activity(event):
		_touch()


func _is_activity(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return event.relative.length() > 3.0
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.3
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton or event is InputEventScreenTouch:
		return event.is_pressed()
	return false


func _touch() -> void:
	_last_activity_ms = Time.get_ticks_msec()
	_warning_root.visible = false


func _process(_delta: float) -> void:
	# Следим только за игрой: в меню (игрока нет) и на финальном экране — не считаем
	var in_game := get_tree().get_first_node_in_group("Player") != null
	if not exhibition_mode or _returning or _finale_open or not in_game:
		_touch()
		return

	# Реальное время (не зависит от time_scale и паузы)
	var idle := (Time.get_ticks_msec() - _last_activity_ms) / 1000.0
	var remaining := IDLE_RESET_SEC - idle

	if remaining <= IDLE_WARNING_SEC:
		var h := get_viewport().get_visible_rect().size.y
		_warning_label.add_theme_font_size_override("font_size", int(h * 0.05))
		_warning_label.text = Loc.t("Still there?\nThe game restarts in %d s\nPress any key to continue") % maxi(0, ceili(remaining))
		_warning_root.visible = true

	if remaining <= 0.0:
		_return_to_attract()


## Возврат в главное меню для следующего посетителя.
func _return_to_attract() -> void:
	if _returning:
		return
	var manager = Global.scene_manager
	if manager == null or manager.is_busy():
		return
	_returning = true
	_warning_root.visible = false

	get_tree().paused = false
	GameJuice.reset()
	Global.is_opened_menu = false
	if _tracker:
		_tracker.reset_session()
	for node_name in ["AchievementTracker", "EliteDirector", "EventDirector"]:
		var node := Global.get_node_or_null(node_name)
		if node != null and node.has_method("reset"):
			node.call("reset")
	var hints := Global.get_node_or_null("TutorialHints") as TutorialHints
	if hints:
		hints.reset()

	manager.change_to_main_menu()
	await get_tree().create_timer(3.0, true, false, true).timeout
	_returning = false
	_touch()


# ─────────────────────────────────────────────────────────────────────────────
#  Финал
# ─────────────────────────────────────────────────────────────────────────────
func _on_finale_reached(planet: PlanetData) -> void:
	if _finale_open:
		return
	_finale_open = true
	var screen := VictoryScreen.new()
	add_child(screen)
	var summary: Dictionary = _tracker.get_summary() if _tracker else {}
	screen.setup(planet, summary, exhibition_mode, FINALE_AUTO_RETURN_SEC)
	screen.continue_pressed.connect(_on_finale_closed)
	screen.menu_pressed.connect(_on_finale_menu)


func _on_finale_closed() -> void:
	_finale_open = false
	_touch()


func _on_finale_menu() -> void:
	_finale_open = false
	_return_to_attract()
