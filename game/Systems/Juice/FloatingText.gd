extends Label
class_name FloatingText

## Всплывающий текст, привязанный к точке мира.
## Рисуется в экранном пространстве (CanvasLayer) — шрифт остаётся чётким при
## любом зуме камеры, а позиция каждый кадр пересчитывается из мировой.

var _world_pos: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _life: float = 0.8
var _rise: float = 24.0
var _drift_x: float = 0.0
var _pop_scale: float = 1.5


## Вызывать ДО добавления в дерево.
func setup(world_pos: Vector2, message: String, color: Color, font_size: int,
		life: float = 0.8, rise: float = 24.0, pop_scale: float = 1.5) -> void:
	_world_pos = world_pos
	_life = maxf(life, 0.1)
	_rise = rise
	_pop_scale = pop_scale
	_drift_x = randf_range(-8.0, 8.0)

	text = message
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	add_theme_constant_override("outline_size", maxi(2, int(font_size * 0.2)))


func _ready() -> void:
	reset_size()
	pivot_offset = size * 0.5
	_update_transform(0.0)


func _process(delta: float) -> void:
	_age += delta
	var t := _age / _life
	if t >= 1.0:
		queue_free()
		return
	_update_transform(t)


func _update_transform(t: float) -> void:
	# "Поп": быстро сжимаемся от увеличенного размера к обычному
	var pop := clampf(_age / 0.12, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(_pop_scale, 1.0, pop)

	# Подъём с замедлением (ease-out), затухание — в последние 40% жизни
	var rise_offset := _rise * (1.0 - pow(1.0 - t, 2.0))
	modulate.a = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4

	var screen_pos := get_viewport().get_canvas_transform() * _world_pos
	position = screen_pos + Vector2(_drift_x * t, -rise_offset) - size * 0.5
