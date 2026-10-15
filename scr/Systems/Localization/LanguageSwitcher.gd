extends CanvasLayer
class_name LanguageSwitcher

## Три кнопки «РУС / ENG / ՀԱՅ» в углу экрана. Видны только вне игры
## (в меню, на экране сохранений) — на выставке посетитель выбирает язык
## одним нажатием. Создаётся из Global, сцены править не нужно.

const BUTTONS: Array[Array] = [["ru", "РУС"], ["en", "ENG"], ["hy", "ՀԱՅ"]]

var _box: HBoxContainer
var _buttons: Dictionary = {}


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh()


func _build() -> void:
	var h := get_viewport().get_visible_rect().size.y
	_box = HBoxContainer.new()
	_box.add_theme_constant_override("separation", int(h * 0.008))
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.anchor_top = 0.0
	_box.anchor_bottom = 0.0
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.offset_right = -h * 0.02
	_box.offset_top = h * 0.02
	add_child(_box)

	var armenian: Font = null
	if ResourceLoader.exists(Loc.FONT_ARMENIAN):
		armenian = load(Loc.FONT_ARMENIAN) as Font

	for pair in BUTTONS:
		var code: String = pair[0]
		var button := Button.new()
		button.text = pair[1]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE  # не перехватываем навигацию меню
		button.add_theme_font_size_override("font_size", int(h * 0.03))
		if code == "hy" and armenian:
			button.add_theme_font_override("font", armenian)
		button.pressed.connect(_on_pressed.bind(code))
		_box.add_child(button)
		_buttons[code] = button


func _on_pressed(code: String) -> void:
	Loc.set_language(code)
	_refresh()


func _refresh() -> void:
	var current := Loc.get_language()
	for code: String in _buttons:
		(_buttons[code] as Button).set_pressed_no_signal(code == current)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _process(_delta: float) -> void:
	# Только вне игры и не во время загрузки сцены
	var in_game := get_tree().get_first_node_in_group("Player") != null
	var busy: bool = Global.scene_manager != null and Global.scene_manager.is_busy()
	_box.visible = not in_game and not busy
