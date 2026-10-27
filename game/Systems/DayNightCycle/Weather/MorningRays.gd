## Эффект утренних солнечных лучей.
## Используется как standalone — WeatherSystem вызывает fade_in() / fade_out().
extends WeatherEffect

# Настройки лучей
@export var ray_count:    int   = 7
@export var ray_color:    Color = Color(1.0, 0.85, 0.4, 0.18)
@export var ray_width:    float = 120.0
@export var ray_speed:    float = 0.015   # скорость медленного вращения
@export var sway_amount:  float = 6.0     # покачивание ширины

var _rays:     Array[Polygon2D] = []
var _angles:   Array[float]     = []
var _sway_off: Array[float]     = []      # случайный offset для покачивания
var _length:   float            = 1400.0  # достаточно для любого экрана

func _ready() -> void:
	_build_rays()

func _build_rays() -> void:
	for i in ray_count:
		var poly := Polygon2D.new()
		poly.color = ray_color
		add_child(poly)
		_rays.append(poly)

		var angle := (TAU / ray_count) * i + randf_range(-0.15, 0.15)
		_angles.append(angle)
		_sway_off.append(randf_range(0.0, TAU))

	_update_rays()

func _process(delta: float) -> void:
	for i in ray_count:
		_angles[i] += ray_speed * delta
	_update_rays()

func _update_rays() -> void:
	for i in ray_count:
		var angle  := _angles[i]
		var sway   := sin(Time.get_ticks_msec() * 0.0003 + _sway_off[i]) * sway_amount
		var half_w := (ray_width + sway) * 0.5

		# Луч: вершина в центре экрана, расширяется вдаль
		var origin := get_viewport_rect().size * 0.5 * modulate.a  # подтягиваем к центру
		var dir    := Vector2(cos(angle), sin(angle))
		var perp   := dir.rotated(PI * 0.5)

		var tip  := origin
		var far  := origin + dir * _length
		var l    := far - perp * half_w
		var r    := far + perp * half_w

		_rays[i].polygon = PackedVector2Array([tip, l, r])
		_rays[i].position = get_viewport_rect().size * 0.5
