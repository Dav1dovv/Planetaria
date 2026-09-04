## SettingsManager.gd
## Autoload-синглтон. Хранит, сохраняет и применяет все настройки игры.
## Project → Project Settings → Autoload → добавь как "SettingsManager"
extends Node
class_name SettingManager

# ──────────────────────────────────────────
#  CONSTANTS
# ──────────────────────────────────────────

const SETTINGS_PATH := "user://settings.cfg"

const BUS_MASTER := "Master"
const BUS_MUSIC  := "BGM"
const BUS_SFX    := "SFX"

## Доступные языки: [код TranslationServer, отображаемое имя]
const LANGUAGES := [
	["ru", "Русский"],
	["en", "English"],
]

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

## Пресеты оптимизации ("под устройство игрока"). Порядок важен — по нему
## строится OptionButton в меню (индекс = позиция в массиве). "custom" —
## особый уровень: значения для него не фиксированы в PERFORMANCE_TUNING,
## а собираются на лету из custom_* полей (см. get_performance_tuning()),
## которые игрок крутит вручную ползунками в меню.
const PERFORMANCE_LEVELS := ["low", "medium", "high", "custom"]

## Отображаемые имена уровней (для OptionButton).
const PERFORMANCE_LEVEL_NAMES := {
	"low"    : "Низкая (слабое устройство)",
	"medium" : "Средняя",
	"high"   : "Высокая (мощное устройство)",
	"custom" : "Своя",
}

## Конкретные значения, которые применяются на каждом уровне. Тут и общие
## движковые штуки (max_fps), и параметры генератора мира (WorldMapGenerator) —
## радиус подгрузки чанков, размер пачки на постройку, плотность ресурсов и
## декора травы. Ключи здесь ДОЛЖНЫ совпадать с именами @export-переменных
## в WorldMapGenerator.gd — WorldMapGenerator читает этот словарь напрямую
## через get_performance_tuning() и присваивает значения себе через set().
const PERFORMANCE_TUNING := {
	"low": {
		"max_fps"                 : 30,
		"stream_radius_chunks"    : 2,
		"max_chunks_per_batch"    : 6,
		"chunk_time_budget_ms"    : 2.0,
		"resources_per_chunk"     : 2,
		"resource_spawn_per_frame": 3,
		"grass_variation_chance"  : 0.05,
	},
	"medium": {
		"max_fps"                 : 60,
		"stream_radius_chunks"    : 3,
		"max_chunks_per_batch"    : 12,
		"chunk_time_budget_ms"    : 3.0,
		"resources_per_chunk"     : 4,
		"resource_spawn_per_frame": 6,
		"grass_variation_chance"  : 0.12,
	},
	"high": {
		"max_fps"                 : 0,   # 0 = без ограничения
		"stream_radius_chunks"    : 4,
		"max_chunks_per_batch"    : 20,
		"chunk_time_budget_ms"    : 4.0,
		"resources_per_chunk"     : 6,
		"resource_spawn_per_frame": 10,
		"grass_variation_chance"  : 0.18,
	},
}

## Ограничения (min, max) для ручных ползунков в режиме "Своя" — на них же
## опирается UI (SettingsMenu.gd), чтобы не дублировать цифры в двух местах.
const CUSTOM_STREAM_RADIUS_RANGE := Vector2i(1, 6)          # чанков вокруг игрока
const CUSTOM_MAX_CHUNKS_PER_BATCH_RANGE := Vector2i(2, 32)  # чанков в одном вызове отрисовки
const CUSTOM_CHUNK_TIME_BUDGET_RANGE := Vector2(0.5, 8.0)   # мс на стирание чанков за кадр

## Варианты лимита FPS для ручной настройки. 0 = без ограничения.
const CUSTOM_FPS_OPTIONS := [30, 60, 120, 144, 0]

## Действия, которые можно переназначить.
## Ключ — action из InputMap, значение — отображаемое имя.
const REBINDABLE_ACTIONS := {
	"move_up"     : "Вверх",
	"move_down"   : "Вниз",
	"move_left"   : "Влево",
	"move_right"  : "Вправо",
	"jump"        : "Прыжок",
	"interact"    : "Взаимодействие",
	"inventory"   : "Инвентарь",
	"pause"       : "Пауза",
}

# ──────────────────────────────────────────
#  DEFAULTS
# ──────────────────────────────────────────

const DEFAULTS := {
	# Звук
	"master_volume" : 1.0,
	"music_volume"  : 0.8,
	"sfx_volume"    : 1.0,
	"mute_master"   : false,

	# Графика
	"fullscreen"       : false,
	"vsync"            : true,
	"resolution_index" : 0,

	# Оптимизация / производительность
	"performance_preset" : "medium",
	# Ручные значения для уровня "custom" — стартуют как копия "medium",
	# чтобы переключение на "Свою" не было резким скачком параметров.
	"custom_stream_radius_chunks" : 3,
	"custom_max_fps"              : 60,
	"custom_max_chunks_per_batch" : 12,
	"custom_chunk_time_budget_ms" : 3.0,

	# Язык
	"language" : "ru",
}

# ──────────────────────────────────────────
#  STATE
# ──────────────────────────────────────────

## Текущие настройки (звук, графика, язык)
var data: Dictionary = {}

## Переназначенные клавиши: { action: scancode }
var keybinds: Dictionary = {}

signal settings_changed

# ──────────────────────────────────────────
#  LIFECYCLE
# ──────────────────────────────────────────

func _ready() -> void:
	load_settings()
	apply_all()

# ──────────────────────────────────────────
#  PUBLIC API
# ──────────────────────────────────────────

func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
	data[key] = value
	_apply(key, value)
	settings_changed.emit()

## Возвращает словарь конкретных числовых настроек для ТЕКУЩЕГО уровня
## оптимизации (см. PERFORMANCE_TUNING). Используется системами, которым
## нужно подстроиться под устройство игрока — например WorldMapGenerator
## читает отсюда stream_radius_chunks/resources_per_chunk и т.п.
## Уровень "custom" собирается ОТДЕЛЬНО: базой берётся "medium" (для тех
## параметров, что игроку вручную не выставляются — плотность ресурсов,
## частота их спавна), а 4 ручных параметра (radius/fps/batch/budget)
## перезаписываются из custom_* полей, которые крутит сам игрок в меню.
func get_performance_tuning() -> Dictionary:
	var level: String = get_value("performance_preset")
	if level == "custom":
		var tuning: Dictionary = PERFORMANCE_TUNING["medium"].duplicate()
		tuning["max_fps"]              = get_value("custom_max_fps")
		tuning["stream_radius_chunks"] = get_value("custom_stream_radius_chunks")
		tuning["max_chunks_per_batch"] = get_value("custom_max_chunks_per_batch")
		tuning["chunk_time_budget_ms"] = get_value("custom_chunk_time_budget_ms")
		return tuning
	return PERFORMANCE_TUNING.get(level, PERFORMANCE_TUNING["medium"])

func save_settings() -> void:
	var cfg := ConfigFile.new()

	# Основные настройки
	for key in DEFAULTS:
		cfg.set_value(_section(key), key, get_value(key))

	# Привязки клавиш
	for action in keybinds:
		cfg.set_value("Keybinds", action, keybinds[action])

	if cfg.save(SETTINGS_PATH) != OK:
		push_error("SettingsManager: не удалось сохранить настройки")

func load_settings() -> void:
	data     = DEFAULTS.duplicate()
	keybinds = _default_keybinds()

	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	for key in DEFAULTS:
		if cfg.has_section_key(_section(key), key):
			data[key] = cfg.get_value(_section(key), key)

	for action in REBINDABLE_ACTIONS:
		if cfg.has_section_key("Keybinds", action):
			keybinds[action] = cfg.get_value("Keybinds", action)

func reset_to_defaults() -> void:
	data     = DEFAULTS.duplicate()
	keybinds = _default_keybinds()
	apply_all()
	save_settings()
	settings_changed.emit()

func apply_all() -> void:
	for key in data:
		_apply(key, data[key])
	_apply_keybinds()

# ──────────────────────────────────────────
#  KEYBINDS
# ──────────────────────────────────────────

## Назначить клавишу действию и применить сразу
func rebind_action(action: String, scancode: int) -> void:
	keybinds[action] = scancode
	_apply_single_keybind(action, scancode)
	settings_changed.emit()

## Получить читаемое имя текущей клавиши для действия
func get_key_label(action: String) -> String:
	var sc: int = keybinds.get(action, 0)
	if sc == 0:
		return "—"
	return OS.get_keycode_string(sc)

func _default_keybinds() -> Dictionary:
	var result := {}
	for action in REBINDABLE_ACTIONS:
		result[action] = _get_first_scancode(action)
	return result

func _get_first_scancode(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.keycode
	return 0

func _apply_keybinds() -> void:
	for action in keybinds:
		_apply_single_keybind(action, keybinds[action])

func _apply_single_keybind(action: String, scancode: int) -> void:
	if not InputMap.has_action(action) or scancode == 0:
		return
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = scancode
	InputMap.action_add_event(action, ev)

# ──────────────────────────────────────────
#  APPLY  (private)
# ──────────────────────────────────────────

func _apply(key: String, value: Variant) -> void:
	match key:
		"master_volume":
			_set_bus_volume(BUS_MASTER, value)
		"music_volume":
			_set_bus_volume(BUS_MUSIC, value)
			_sync_blaze_music(value)
		"sfx_volume":
			_set_bus_volume(BUS_SFX, value)
		"mute_master":
			var idx := AudioServer.get_bus_index(BUS_MASTER)
			if idx >= 0:
				AudioServer.set_bus_mute(idx, value)
		"fullscreen":
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if value
				else DisplayServer.WINDOW_MODE_WINDOWED
			)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
		"resolution_index":
			if not get_value("fullscreen"):
				var idx: int = clampi(value, 0, RESOLUTIONS.size() - 1)
				DisplayServer.window_set_size(RESOLUTIONS[idx])
		"performance_preset":
			# Общедвижковую часть (лимит FPS) применяем прямо тут, она не
			# привязана к конкретной сцене. Специфичные для генератора мира
			# параметры (радиус чанков, плотность ресурсов и т.д.) забирает
			# сам WorldMapGenerator через get_performance_tuning() — он
			# подписан на settings_changed и переприменяет их сам, так как
			# SettingsManager не обязан знать о конкретных игровых сценах.
			var tuning: Dictionary = get_performance_tuning()
			Engine.max_fps = tuning.get("max_fps", 60)
		"custom_stream_radius_chunks", "custom_max_fps", "custom_max_chunks_per_batch", "custom_chunk_time_budget_ms":
			# Эти 4 поля имеют смысл, только пока активен режим "custom" —
			# именно тогда их трогают ползунки в меню. Если игрок стоит на
			# готовом пресете, эти значения просто лежат про запас и никак
			# не влияют, пока он не переключится на "Свою".
			if get_value("performance_preset") == "custom":
				Engine.max_fps = get_value("custom_max_fps")
		"language":
			TranslationServer.set_locale(value)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))

## Синхронизация громкости с BlazeMusicManager
func _sync_blaze_music(volume: float) -> void:
	var blaze := _get_blaze()
	if blaze == null:
		return
	# BlazeMusicManager управляет громкостью через volume_db своих плееров.
	# Устанавливаем целевую громкость на активном плеере (_active).
	# Неактивный плеер управляется tween-ом при кроссфейде — он подхватит
	# целевую громкость через set_music_volume(), которую мы добавили в MusicManager.
	if blaze.has_method("set_music_volume"):
		blaze.set_music_volume(volume)

func _get_blaze() -> Node:
	var nodes := get_tree().get_nodes_in_group("MusicManager")
	return nodes[0] if not nodes.is_empty() else null

# ──────────────────────────────────────────
#  HELPERS
# ──────────────────────────────────────────

func _section(key: String) -> String:
	match key:
		"master_volume", "music_volume", "sfx_volume", "mute_master":
			return "Audio"
		"fullscreen", "vsync", "resolution_index":
			return "Graphics"
		"performance_preset", "custom_stream_radius_chunks", "custom_max_fps", "custom_max_chunks_per_batch", "custom_chunk_time_budget_ms":
			return "Performance"
		"language":
			return "Localization"
	return "General"
