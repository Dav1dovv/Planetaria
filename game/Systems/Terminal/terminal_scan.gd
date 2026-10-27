@tool
extends Control
class_name TerminalScan
## Слой «старого монитора» поверх экрана терминала: строчная развёртка и ползущая светлая полоса.
## Кладётся ПОСЛЕДНИМ ребёнком экрана (тогда он лежит поверх содержимого). Мышь не ловит.
## Всё настраивается в инспекторе.

@export_group("Развёртка")
## Шаг строк в пикселях холста (480x270 → 2 хорошо смотрится).
@export_range(1.0, 8.0, 0.5) var step: float = 2.0
## Прозрачность тёмных строк.
@export_range(0.0, 0.6, 0.01) var line_alpha: float = 0.16

@export_group("Бегущая полоса")
@export var band_color: Color = Color(0.27, 0.9, 0.9, 0.05)
## Скорость: проходов экрана в секунду (0 = полоса выключена).
@export_range(0.0, 2.0, 0.05) var band_speed: float = 0.3
@export_range(1.0, 10.0, 0.5) var band_height_steps: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var y := 0.0
	while y < size.y:
		draw_rect(Rect2(0.0, y, size.x, maxf(1.0, step * 0.5)), Color(0, 0, 0, line_alpha))
		y += step
	if band_speed > 0.0:
		var t := fmod(Time.get_ticks_msec() / 1000.0 * band_speed, 1.0)
		draw_rect(Rect2(0.0, size.y * t, size.x, step * band_height_steps), band_color)
