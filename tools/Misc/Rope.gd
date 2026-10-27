extends Node2D
class_name Rope

## Начальный объект (откуда тянется верёвка)
@export var point_a: Node2D
## Конечный объект (куда тянется верёвка)
@export var point_b: Node2D

## Максимальная длина верёвки (0 = без ограничений)
@export var max_length: float = 200.0
## Количество точек кривой (больше = плавнее провис)
@export var segments: int = 20
## Сила провиса (0 = прямая линия)
@export var sag: float = 40.0

@export_group("Внешний вид")
@export var rope_color: Color = Color(0.55, 0.35, 0.15)
@export var rope_width: float = 3.0

var _line: Line2D

func _ready() -> void:
	_line = Line2D.new()
	_line.default_color = rope_color
	_line.width = rope_width
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_line)

func _process(_delta: float) -> void:
	if not is_instance_valid(point_a) or not is_instance_valid(point_b):
		_line.clear_points()
		return

	var start := point_a.global_position
	var end   := point_b.global_position
	var dist  := start.distance_to(end)

	# Если объекты дальше max_length — обрезаем конец верёвки по длине
	if max_length > 0.0 and dist > max_length:
		var dir := (end - start).normalized()
		end = start + dir * max_length

	_update_line(start, end)

func _update_line(start: Vector2, end: Vector2) -> void:
	_line.clear_points()

	# Контрольная точка Безье — середина + смещение вниз (провис)
	var mid    := (start + end) * 0.5
	var ctrl   := mid + Vector2(0, sag)

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		# Квадратичная кривая Безье
		var point := _bezier(start, ctrl, end, t)
		_line.add_point(to_local(point))

static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var mt := 1.0 - t
	return mt * mt * p0 + 2.0 * mt * t * p1 + t * t * p2
