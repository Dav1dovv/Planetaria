extends Node
class_name WeatherSystem

# ===================== ЭФФЕКТЫ =====================
@export var rain_effect:         PackedScene
@export var heavy_rain_effect:   PackedScene
@export var fog_effect:          PackedScene
@export var sandstorm_effect:    PackedScene
@export var clear_sky_effect:    PackedScene
@export var morning_rays_effect: PackedScene  # ← утренние лучи

# ===================== ШАНСЫ (%) =====================
@export_category("Шансы погоды")
@export_range(0, 100) var rain_chance: int = 30
@export_range(0, 100) var fog_chance:  int = 25

# ===================== ТАЙМЕР =====================
@export_range(5,  40)  var min_minutes: float = 12
@export_range(10, 60)  var max_minutes: float = 25

# ===================== FADE =====================
@export_range(0.5, 10.0) var fade_duration:      float = 3.0
## Сколько секунд держатся утренние лучи перед исчезновением
@export_range(10.0, 120.0) var morning_ray_hold: float = 40.0

# ===================== ВНУТРЕННЕЕ =====================
var _biome: String = ""
var _current_effect: WeatherEffect = null
var _timer := Timer.new()
var _transitioning: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("Weather")
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_change_weather)

	var gm := get_tree().get_first_node_in_group("World")
	_biome = gm.biome if gm and "biome" in gm else ""

	Global.day_night.phase_changed.connect(_on_phase_changed)

	if _biome != "" and Global.weather_state.has(_biome):
		_apply_weather(Global.weather_state[_biome])
	else:
		_change_weather()

	_start_timer()


func _start_timer() -> void:
	_timer.start(randf_range(min_minutes, max_minutes) * 60.0)


func _change_weather() -> void:
	if _transitioning:
		return

	var roll := randi_range(1, 100)
	var type: String
	if roll <= rain_chance / 3:
		type = "heavy_rain"
	elif roll <= rain_chance:
		type = "rain"
	elif roll <= rain_chance + fog_chance:
		type = "fog"
	else:
		type = "clear_night" if _is_night() else "clear"

	_save_weather(type)
	_apply_weather(type)
	_start_timer()


func _apply_weather(type: String) -> void:
	if _current_effect and is_instance_valid(_current_effect) \
			and _current_effect.get_meta("weather_type", "") == type:
		return

	_transitioning = true

	if _current_effect and is_instance_valid(_current_effect):
		await _current_effect.fade_out()
	_current_effect = null

	var scene := _scene_for(type)
	if scene:
		var node: WeatherEffect = scene.instantiate()
		node.set_meta("weather_type", type)
		node.fade_duration = fade_duration
		add_child(node)
		_current_effect = node
		await node.fade_in()

	_transitioning = false


func _scene_for(type: String) -> PackedScene:
	match type:
		"rain":         return rain_effect
		"heavy_rain":   return heavy_rain_effect
		"fog":          return fog_effect
		"sandstorm":    return sandstorm_effect
		"clear_night":  return clear_sky_effect
		"morning_rays": return morning_rays_effect
	return null


func _save_weather(type: String) -> void:
	if _biome != "":
		Global.weather_state[_biome] = type


func _is_night() -> bool:
	return Global.day_night and \
		Global.day_night.current_phase == Global.day_night.Phase.NIGHT


func force_weather(type: String) -> void:
	_save_weather(type.to_lower())
	_apply_weather(type.to_lower())


# Утро: NIGHT → DAY (phase_changed(false))
func _on_phase_changed(is_night: bool) -> void:
	Global._switch_bgm(&"Night" if is_night else &"Day")

	if not is_night and morning_rays_effect:
		_show_morning_rays()


func _show_morning_rays() -> void:
	if _transitioning:
		return
	_transitioning = true

	# Fade out текущей погоды если есть
	if _current_effect and is_instance_valid(_current_effect):
		await _current_effect.fade_out()
	_current_effect = null

	# Показываем лучи
	var node: WeatherEffect = morning_rays_effect.instantiate()
	node.set_meta("weather_type", "morning_rays")
	node.fade_duration = fade_duration
	add_child(node)
	_current_effect = node
	await node.fade_in()

	_transitioning = false

	# Держим лучи, потом убираем и восстанавливаем обычную погоду
	await get_tree().create_timer(morning_ray_hold).timeout

	if _current_effect and is_instance_valid(_current_effect) \
			and _current_effect.get_meta("weather_type", "") == "morning_rays":
		_transitioning = true
		await _current_effect.fade_out()
		_current_effect = null
		_transitioning = false

	# Запускаем обычную смену погоды
	_change_weather()
