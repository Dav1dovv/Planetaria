@tool
extends Control
class_name TerminalLed
## Мигающий индикатор на корпусе консоли.

@export var color_on: Color = Color("e8454f")
@export var color_off: Color = Color("e8454f").darkened(0.7)
## Период мигания и доля времени, пока горит.
@export_range(0.2, 5.0, 0.1) var period: float = 1.2
@export_range(0.05, 1.0, 0.05) var on_ratio: float = 0.66
@export_range(0.1, 0.5, 0.05) var radius_ratio: float = 0.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var on := fmod(Time.get_ticks_msec() / 1000.0, period) < period * on_ratio
	draw_circle(size * 0.5, minf(size.x, size.y) * radius_ratio, color_on if on else color_off)
