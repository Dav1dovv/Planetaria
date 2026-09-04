# daynightcycle.gd — СЛУЧАЙНЫЕ, но 100% надёжные события
extends CanvasModulate
class_name DayNightCycle

signal day_changed
signal phase_changed(is_night: bool)  # ← ДОБАВЛЕНО

enum Phase { DAY, MIDDAY, NIGHT }
enum Season { Yanuaris, Kardus, Tirena, Vallis, Lira, Eikhon, Verda, Morva }
enum Event { NONE, FULL_CELESTE, FULL_MORVA }

@export var active: bool = true

@export var day_color: Color = Color.WHITE
@export var midday_color: Color = Color(0.8, 0.8, 1.0)
@export var day_to_mid_minutes: float = 5.0
@export var mid_to_night_minutes: float = 5.0
@export var night_to_day_minutes: float = 5.0

@export_category("Shaft")
@export var shaft_color: Color = Color(0.5, 0.5, 0.5)

@export_category("Случайные события")
@export_range(4, 10) var celeste_min_days: int = 5
@export_range(4, 10) var celeste_max_days: int = 7
@export_range(20, 40) var morva_min_days: int = 27
@export_range(20, 40) var morva_max_days: int = 30

@export var days_per_season: int = 20

# 8 фаз луны
const MOON_PHASE_COLORS := [
	Color(0.145, 0.075, 0.441),
	Color(0.18,  0.12,  0.48),
	Color(0.20,  0.16,  0.55),
	Color(0.22,  0.20,  0.60),
	Color(0.231, 0.243, 0.714),  # полнолуние
	Color(0.22,  0.20,  0.60),
	Color(0.20,  0.16,  0.55),
	Color(0.18,  0.12,  0.48)
]

const FULL_CELESTE_COLOR := Color(0.871, 0.204, 0.0)
const FULL_MORVA_COLOR   := Color(0.415, 0.001, 0.515)

var second: float = 60.0
var current_phase: Phase = Phase.DAY
var current_day: int = 1
var current_season: Season = Season.Yanuaris
var current_event: Event = Event.NONE
var is_overworld: bool = true
var moon_phase: int = 0

var next_celeste_day: int = 0
var next_morva_day:   int = 0

@onready var timer: Timer = $Timer


func _ready() -> void:
	add_to_group("day_night_cycle")
	if Engine.is_editor_hint():
		return
	
	_plan_next_celeste()
	_plan_next_morva()
	
	%DeveloperConsole.register_command("time_speed", _cmd_time_speed, "time_speed <sec>")
	%DeveloperConsole.register_command("events", _cmd_events, "Показать ближайшие события")
	%DeveloperConsole.register_command("tick_speed", _cmd_tick_speed, "tick_speed <scale>")
	if active:
		start()


func _cmd_events(_args) -> String:
	return "Next Celeste: день %d\nNext Morva:   день %d\nСегодня: день %d" % [next_celeste_day, next_morva_day, current_day]

func _cmd_tick_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		Engine.time_scale = args[0].to_float()
		return "time_scale = %.2f" % Engine.time_scale
	return "Usage: tick_speed <value>"

func _cmd_time_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		second = clampf(args[0].to_float(), 1.0, 600.0)
		if timer.is_stopped(): start()
		return "Время: %.1f сек = 1 игровой час" % second
	return "Использование: time_speed 30"


func start() -> void:
	timer.wait_time = _get_current_phase_duration()
	timer.start()
	_update_color_immediate()
	_check_season()


func _get_current_phase_duration() -> float:
	return [day_to_mid_minutes, mid_to_night_minutes, night_to_day_minutes][current_phase] * second


func _on_timer_timeout() -> void:
	if not is_overworld: return
	advance_phase()


func advance_phase() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	match current_phase:
		Phase.DAY:
			current_phase = Phase.MIDDAY
			tween.tween_property(self, "color", midday_color, 1.0)
		
		Phase.MIDDAY:
			current_phase = Phase.NIGHT
			moon_phase = (moon_phase + 1) % 8
			_check_and_trigger_events()
			emit_signal("phase_changed", true)  # ← ДОБАВЛЕНО
			tween.tween_property(self, "color", _get_night_color(), 1.5)
		
		Phase.NIGHT:
			current_phase = Phase.DAY
			current_day += 1
			emit_signal("day_changed")
			emit_signal("phase_changed", false)  # ← ДОБАВЛЕНО
			
			print("День %d | Луна %d/7 | Событие: %s | Сезон: %s" % [
				current_day, moon_phase,
				Event.keys()[current_event] if current_event != Event.NONE else "—",
				Season.keys()[current_season]
			])
			
			_check_season()
			tween.tween_property(self, "color", day_color, 1.5)
	
	timer.wait_time = _get_current_phase_duration()
	timer.start()


func _check_and_trigger_events() -> void:
	current_event = Event.NONE
	
	if current_day == next_celeste_day:
		current_event = Event.FULL_CELESTE
		_plan_next_celeste()
		print("FULL CELESTE!")
	
	if current_day == next_morva_day:
		current_event = Event.FULL_MORVA
		_plan_next_morva()
		print("FULL MORVA!")


func _plan_next_celeste() -> void:
	var days_ahead = randi_range(celeste_min_days, celeste_max_days)
	next_celeste_day = current_day + days_ahead

func _plan_next_morva() -> void:
	var days_ahead = randi_range(morva_min_days, morva_max_days)
	next_morva_day = current_day + days_ahead


func _get_night_color() -> Color:
	if current_event == Event.FULL_CELESTE:
		return FULL_CELESTE_COLOR
	if current_event == Event.FULL_MORVA:
		return FULL_MORVA_COLOR
	return MOON_PHASE_COLORS[moon_phase]


func _check_season() -> void:
	var new_season = (current_day - 1) / days_per_season
	if new_season != current_season:
		current_season = new_season % Season.size()
		print("Сезон → ", Season.keys()[current_season])


func _update_color_immediate() -> void:
	match current_phase:
		Phase.DAY:    color = day_color
		Phase.MIDDAY: color = midday_color
		Phase.NIGHT:  color = _get_night_color()


func change_world_state(in_shaft: bool) -> void:
	is_overworld = !in_shaft
	if in_shaft:
		timer.stop()
		create_tween().tween_property(self, "color", shaft_color, 0.8)
	else:
		current_day += 1
		moon_phase = (moon_phase + 1) % 8
		current_phase = Phase.DAY
		_check_and_trigger_events()
		emit_signal("day_changed")
		emit_signal("phase_changed", false)  # ← ДОБАВЛЕНО
		_check_season()
		_update_color_immediate()
		start()


func next_phase() -> void:
	if is_overworld:
		advance_phase()
