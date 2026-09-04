## SettingsMenu.gd
## Прикрепи к CanvasLayer-сцене SettingsMenu.tscn.
## Открывается поверх игры. Закрывается по ESC или кнопке.
extends CanvasLayer

signal closed

# ──────────────────────────────────────────
#  УЗЛЫ  (уникальные имена через %)
# ──────────────────────────────────────────


# Звук
@onready var slider_master : HSlider  = %SliderMaster
@onready var slider_music  : HSlider  = %SliderMusic
@onready var slider_sfx    : HSlider  = %SliderSFX
@onready var check_mute    : CheckBox = %CheckMute
@onready var label_master  : Label    = %LabelMaster
@onready var label_music   : Label    = %LabelMusic
@onready var label_sfx     : Label    = %LabelSFX

# Графика
@onready var check_fullscreen  : CheckBox     = %CheckFullscreen
@onready var check_vsync       : CheckBox     = %CheckVsync
@onready var option_resolution : OptionButton = %OptionResolution

# Оптимизация
@onready var option_performance: OptionButton = %OptionPerformance
@onready var custom_panel: Control = %CustomPanel
@onready var slider_render_distance: HSlider  = %SliderRenderDistance
@onready var label_render_distance: Label     = %LabelRenderDistance
@onready var option_fps_limit: OptionButton   = %OptionFPSLimit
@onready var slider_chunk_batch: HSlider      = %SliderChunkBatch
@onready var label_chunk_batch: Label         = %LabelChunkBatch
@onready var slider_chunk_budget: HSlider     = %SliderChunkBudget
@onready var label_chunk_budget: Label        = %LabelChunkBudget

# Язык
@onready var option_language: OptionButton = %OptionLanguage

# Управление (контейнер, куда добавляются строки привязок)
@onready var keybinds_container: VBoxContainer = %KeybindsContainer

# Кнопки
@onready var btn_save  : Button = %BtnSave
@onready var btn_reset : Button = %BtnReset
@onready var btn_close : Button = %BtnClose

# ──────────────────────────────────────────
#  STATE
# ──────────────────────────────────────────

## Действие, ожидающее нажатия клавиши (rebind mode)
var _rebinding_action: String = ""

## Кнопки привязок клавиш: { action: Button }
var _keybind_buttons: Dictionary = {}

# ──────────────────────────────────────────
#  LIFECYCLE
# ──────────────────────────────────────────

func _ready() -> void:
	_build_resolution_options()
	_build_performance_options()
	_build_fps_options()
	_setup_custom_sliders()
	_build_language_options()
	_build_keybind_rows()
	_load_ui()
	_connect_signals()
	hide()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Закрыть по ESC (если не ждём клавишу)
	if event.is_action_pressed("ui_cancel"):
		if _rebinding_action.is_empty():
			_on_close()
		else:
			_cancel_rebind()
		get_viewport().set_input_as_handled()
		return

	# Перехватить нажатие клавиши для rebind
	if not _rebinding_action.is_empty() and event is InputEventKey and event.pressed:
		_finish_rebind(event as InputEventKey)
		get_viewport().set_input_as_handled()

# ──────────────────────────────────────────
#  PUBLIC
# ──────────────────────────────────────────

func open() -> void:
	_load_ui()
	show()

func close() -> void:
	_cancel_rebind()
	layer = -5
	hide()
	emit_signal("closed")

# ──────────────────────────────────────────
#  BUILD UI (один раз в _ready)
# ──────────────────────────────────────────

func _build_resolution_options() -> void:
	option_resolution.clear()
	for res: Vector2i in Global.setting_manager.RESOLUTIONS:
		option_resolution.add_item("%d × %d" % [res.x, res.y])

func _build_language_options() -> void:
	option_language.clear()
	for pair in Global.setting_manager.LANGUAGES:
		option_language.add_item(pair[1])  # отображаемое имя

func _build_performance_options() -> void:
	option_performance.clear()
	for level: String in Global.setting_manager.PERFORMANCE_LEVELS:
		var display_name: String = Global.setting_manager.PERFORMANCE_LEVEL_NAMES.get(level, level)
		option_performance.add_item(display_name)

func _build_fps_options() -> void:
	option_fps_limit.clear()
	for fps: int in Global.setting_manager.CUSTOM_FPS_OPTIONS:
		option_fps_limit.add_item("Без ограничения" if fps == 0 else "%d FPS" % fps)

## Границы ручных ползунков берём из SettingsManager (CUSTOM_*_RANGE), чтобы
## числа не расходились между кодом настроек и UI — правишь диапазон в одном месте.
func _setup_custom_sliders() -> void:
	var sm := Global.setting_manager

	slider_render_distance.min_value = sm.CUSTOM_STREAM_RADIUS_RANGE.x
	slider_render_distance.max_value = sm.CUSTOM_STREAM_RADIUS_RANGE.y
	slider_render_distance.step = 1

	slider_chunk_batch.min_value = sm.CUSTOM_MAX_CHUNKS_PER_BATCH_RANGE.x
	slider_chunk_batch.max_value = sm.CUSTOM_MAX_CHUNKS_PER_BATCH_RANGE.y
	slider_chunk_batch.step = 1

	slider_chunk_budget.min_value = sm.CUSTOM_CHUNK_TIME_BUDGET_RANGE.x
	slider_chunk_budget.max_value = sm.CUSTOM_CHUNK_TIME_BUDGET_RANGE.y
	slider_chunk_budget.step = 0.5

func _build_keybind_rows() -> void:
	for child in keybinds_container.get_children():
		child.queue_free()
	_keybind_buttons.clear()

	for action in Global.setting_manager.REBINDABLE_ACTIONS:
		var display_name: String = Global.setting_manager.REBINDABLE_ACTIONS[action]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = display_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 0)
		btn.pressed.connect(_on_rebind_pressed.bind(action, btn))
		_keybind_buttons[action] = btn

		row.add_child(lbl)
		row.add_child(btn)
		keybinds_container.add_child(row)

# ──────────────────────────────────────────
#  LOAD UI FROM SETTINGS
# ──────────────────────────────────────────

func _load_ui() -> void:
	var sm := Global.setting_manager

	# Звук
	slider_master.value       = sm.get_value("master_volume")
	slider_music.value        = sm.get_value("music_volume")
	slider_sfx.value          = sm.get_value("sfx_volume")
	check_mute.button_pressed = sm.get_value("mute_master")
	_update_volume_labels()

	# Графика
	check_fullscreen.button_pressed = sm.get_value("fullscreen")
	check_vsync.button_pressed      = sm.get_value("vsync")
	option_resolution.selected      = sm.get_value("resolution_index")

	# Оптимизация
	var perf_level: String = sm.get_value("performance_preset")
	option_performance.selected = Global.setting_manager.PERFORMANCE_LEVELS.find(perf_level)

	slider_render_distance.value = sm.get_value("custom_stream_radius_chunks")
	slider_chunk_batch.value     = sm.get_value("custom_max_chunks_per_batch")
	slider_chunk_budget.value    = sm.get_value("custom_chunk_time_budget_ms")
	option_fps_limit.selected    = Global.setting_manager.CUSTOM_FPS_OPTIONS.find(sm.get_value("custom_max_fps"))
	_update_custom_labels()
	custom_panel.visible = (perf_level == "custom")

	# Язык
	var lang: String = sm.get_value("language")
	var codes := Global.setting_manager.LANGUAGES.map(func(p): return p[0])
	option_language.selected = codes.find(lang)

	# Клавиши
	_refresh_keybind_labels()

# ──────────────────────────────────────────
#  CONNECT SIGNALS
# ──────────────────────────────────────────

func _connect_signals() -> void:
	slider_master.value_changed.connect(func(v): Global.setting_manager.set_value("master_volume", v); _update_volume_labels())
	slider_music.value_changed.connect( func(v): Global.setting_manager.set_value("music_volume",  v); _update_volume_labels())
	slider_sfx.value_changed.connect(   func(v): Global.setting_manager.set_value("sfx_volume",    v); _update_volume_labels())
	check_mute.toggled.connect(         func(v): Global.setting_manager.set_value("mute_master",   v))

	check_fullscreen.toggled.connect(  func(v): Global.setting_manager.set_value("fullscreen",        v))
	check_vsync.toggled.connect(       func(v): Global.setting_manager.set_value("vsync",             v))
	option_resolution.item_selected.connect(func(i): Global.setting_manager.set_value("resolution_index", i))

	option_performance.item_selected.connect(_on_performance_selected)

	slider_render_distance.value_changed.connect(func(v):
		Global.setting_manager.set_value("custom_stream_radius_chunks", int(v))
		_update_custom_labels())
	slider_chunk_batch.value_changed.connect(func(v):
		Global.setting_manager.set_value("custom_max_chunks_per_batch", int(v))
		_update_custom_labels())
	slider_chunk_budget.value_changed.connect(func(v):
		Global.setting_manager.set_value("custom_chunk_time_budget_ms", v)
		_update_custom_labels())
	option_fps_limit.item_selected.connect(func(i):
		var fps: int = Global.setting_manager.CUSTOM_FPS_OPTIONS[i]
		Global.setting_manager.set_value("custom_max_fps", fps))

	option_language.item_selected.connect(_on_language_selected)

	btn_save.pressed.connect(_on_save)
	btn_reset.pressed.connect(_on_reset)
	btn_close.pressed.connect(_on_close)

# ──────────────────────────────────────────
#  HANDLERS — Звук / Графика
# ──────────────────────────────────────────

func _update_volume_labels() -> void:
	label_master.text = "%d%%" % roundi(slider_master.value * 100)
	label_music.text  = "%d%%" % roundi(slider_music.value  * 100)
	label_sfx.text    = "%d%%" % roundi(slider_sfx.value    * 100)

func _on_language_selected(index: int) -> void:
	var code: String = Global.setting_manager.LANGUAGES[index][0]
	Global.setting_manager.set_value("language", code)
	# Если используешь tr() — интерфейс обновится автоматически при следующем переходе
	# Для live-обновления текущей сцены можно вызвать:
	# get_tree().reload_current_scene()

func _on_performance_selected(index: int) -> void:
	var level: String = Global.setting_manager.PERFORMANCE_LEVELS[index]
	Global.setting_manager.set_value("performance_preset", level)
	custom_panel.visible = (level == "custom")
	# Ничего больше делать не нужно: set_value() применит max_fps сразу тут,
	# а WorldMapGenerator подхватит остальные параметры сам — он подписан
	# на settings_changed (см. WorldGenerator.gd, _apply_performance_preset()).

func _update_custom_labels() -> void:
	label_render_distance.text = "%d чанков" % int(slider_render_distance.value)
	label_chunk_batch.text     = "%d чанков/кадр" % int(slider_chunk_batch.value)
	label_chunk_budget.text    = "%.1f мс" % slider_chunk_budget.value

# ──────────────────────────────────────────
#  HANDLERS — Переназначение клавиш
# ──────────────────────────────────────────

func _on_rebind_pressed(action: String, btn: Button) -> void:
	if not _rebinding_action.is_empty():
		_cancel_rebind()

	_rebinding_action = action
	btn.text = "[ нажми клавишу... ]"
	btn.add_theme_color_override("font_color", Color.YELLOW)

func _finish_rebind(event: InputEventKey) -> void:
	if _rebinding_action.is_empty():
		return

	Global.setting_manager.rebind_action(_rebinding_action, event.keycode)
	_rebinding_action = ""
	_refresh_keybind_labels()

func _cancel_rebind() -> void:
	if _rebinding_action.is_empty():
		return
	_rebinding_action = ""
	_refresh_keybind_labels()

func _refresh_keybind_labels() -> void:
	for action in _keybind_buttons:
		var btn: Button = _keybind_buttons[action]
		btn.text = Global.setting_manager.get_key_label(action)
		btn.remove_theme_color_override("font_color")

# ──────────────────────────────────────────
#  HANDLERS — Кнопки
# ──────────────────────────────────────────

func _on_save() -> void:
	Global.setting_manager.save_settings()
	close()

func _on_reset() -> void:
	Global.setting_manager.reset_to_defaults()
	_load_ui()

func _on_close() -> void:
	close()
