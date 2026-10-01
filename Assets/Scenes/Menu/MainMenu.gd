## MainMenu.gd
## Обновлённая версия — добавлен экран выбора режима (одиночная / мультиплеер)
## Всё остальное (сплеш, анимации, выход) работает как раньше.

extends ColorRect

# ── Сплеш ────────────────────────────────────────────────────────────────────
@onready var splash_label : Label = $CanvasLayer/TextureRect/SplashLabel
@onready var V_label: Label = $CanvasLayer/Interface/V_Label

var splash_json_path = "res://common/SplashTexts.json"
var splash_texts = []

# ── Панель выбора режима (новая) ──────────────────────────────────────────────
## Добавь узел Panel с именем "ModeSelectPanel" внутри CanvasLayer.
## Внутри него нужны три кнопки: SoloBtn, MultiBtn, ModeBackBtn
## Подробная структура описана в LOBBY_SCENE_STRUCTURE.md
@onready var solo_btn          : Button   = $CanvasLayer/Interface/VBoxContainer/VBoxContainer/SoloBtn
@onready var multi_btn         : Button   = $CanvasLayer/Interface/VBoxContainer/VBoxContainer/MultiBtn
#@onready var mode_back_btn     : Button   = $CanvasLayer/ModeSelectPanel/VBoxContainer/ModeBackBtn

# ── Существующие узлы ─────────────────────────────────────────────────────────
@onready var save_load_ui      : CanvasLayer = $SaveLoadUI   # твой существующий SaveLoadUI
## LobbyUI — добавь инстанс Lobby.tscn как дочерний к MainMenu, visible=false
@onready var lobby_ui          : CanvasLayer     = $Coop


# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	Cursor.detection_mode(false)
	load_splash_texts()
	set_random_splash_text()
	animate_splash()
	
	V_label.text = "V:" + str(ProjectSettings.get_setting("application/config/version"))
	# Скрываем всё кроме главного меню
	#mode_select_panel.visible = false
	save_load_ui.visible      = false
	#lobby_ui.visible          = false

	# Подключаем новые кнопки
	solo_btn.pressed.connect(_on_solo_pressed)
	multi_btn.pressed.connect(_on_multi_pressed)
	#mode_back_btn.pressed.connect(_on_mode_back_pressed)


# ═════════════════════════════════════════════════════════════════════════════
#  КНОПКИ ГЛАВНОГО МЕНЮ
# ═════════════════════════════════════════════════════════════════════════════

func _on_exit_pressed() -> void:
	$CanvasLayer/ConfirmationDialog.visible = true


# ═════════════════════════════════════════════════════════════════════════════
#  КНОПКИ ВЫБОРА РЕЖИМА
# ═════════════════════════════════════════════════════════════════════════════

func _on_solo_pressed() -> void:
	#mode_select_panel.visible = false
	$CanvasLayer.visible = false
	save_load_ui.visible      = true   # открываем как раньше — список сейвов


func _on_multi_pressed() -> void:
	#mode_select_panel.visible = false
	$CanvasLayer.visible = false
	lobby_ui.visible          = true   # открываем лобби с выбором сейва

# ═════════════════════════════════════════════════════════════════════════════
#  СУЩЕСТВУЮЩАЯ ЛОГИКА (не трогаем)
# ═════════════════════════════════════════════════════════════════════════════

func load_splash_texts():
	if FileAccess.file_exists(splash_json_path):
		var file = FileAccess.open(splash_json_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.get_data()
			if data is Array:
				splash_texts = data
			else:
				push_error("JSON root must be an array")
		else:
			push_error("Failed to parse JSON: " + json.get_error_message())
	else:
		push_error("Splash texts JSON file not found at: " + splash_json_path)
		splash_texts = ["Error loading splash texts!"]


func set_random_splash_text():
	if splash_texts.size() > 0:
		splash_label.text = splash_texts[randi() % splash_texts.size()]
	else:
		splash_label.text = "No splash texts available!"


func animate_splash():
	var tween = create_tween()
	splash_label.scale = Vector2(0.8, 0.8)
	tween.tween_property(splash_label, "scale", Vector2(1.0, 1.0), 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(splash_label, "scale", Vector2(0.9, 0.9), 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.set_loops()


func _on_confirmation_dialog_confirmed() -> void:
	get_tree().quit()


func _on_confirmation_dialog_canceled() -> void:
	$CanvasLayer/ConfirmationDialog.visible = false


func _on_options_pressed() -> void:
	$OptionMenu.open()


func _on_authors_pressed() -> void:
	pass

func _input(event: InputEvent) -> void:
	if Input.is_anything_pressed() and !$CanvasLayer/Interface.visible:
		$CanvasLayer/Label/AnimationPlayer.play("change")
		
