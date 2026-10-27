extends Control
class_name PlanetViewer
## Витрина планеты: картинка из атласа на «голографической» подставке.
## Пиксели рисуются целым масштабом (×2, ×3…), поэтому остаются чёткими.
## Всё включается/выключается галочками и числами в инспекторе.

@export_group("Картинка")
## Атлас с планетами (область планеты задаётся в PlanetInfo.icon_region).
@export var atlas: Texture2D
## Какую долю меньшей стороны занимает планета.
@export_range(0.2, 1.0, 0.05) var size_ratio: float = 0.7
## Амплитуда «парения» в пикселях и скорость.
@export_range(0.0, 4.0, 0.5) var bob_amount: float = 1.0
@export_range(0.0, 5.0, 0.1) var bob_speed: float = 1.6

@export_group("Элементы")
@export var show_projector: bool = true
@export var show_glow: bool = true
@export var show_orbit: bool = true
@export var show_scan_line: bool = true
@export var show_corners: bool = true
@export_range(0.0, 3.0, 0.1) var orbit_speed: float = 0.7
@export_range(0.0, 2.0, 0.05) var scan_speed: float = 0.4

@export_group("Цвета")
@export var color_scan: Color = Color("45e6e6")
@export var color_moon: Color = Color("c9f7f7")
@export var color_projector: Color = Color("6b7388")
@export var color_projector_dark: Color = Color("171923")
@export var color_offline: Color = Color("5d6b73")

var _tint: Color = Color.WHITE
var _offline: bool = false
var _icon: Rect2i = Rect2i(0, 0, 32, 32)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_planet(icon: Rect2i, tint: Color, offline: bool) -> void:
	_icon = icon
	_tint = color_offline if offline else tint
	_offline = offline
	queue_redraw()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if atlas == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var c := size * 0.5 - Vector2(0.0, size.y * 0.03)
	var target := minf(size.x, size.y) * size_ratio
	var k := maxi(1, int(target / maxf(_icon.size.x, _icon.size.y)))
	var dst_size := Vector2(_icon.size * k)
	var r := dst_size.x * 0.5
	var line_w := maxf(1.0, r * 0.015)

	var flicker := 1.0
	if _offline:
		flicker = 0.4 + 0.3 * absf(sin(t * 17.0))  # нет сигнала — картинка мерцает

	if show_projector:
		var base_y := c.y + r * 1.25
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - r * 0.35, base_y), Vector2(c.x + r * 0.35, base_y),
			Vector2(c.x + r, c.y + r * 0.7), Vector2(c.x - r, c.y + r * 0.7)]), Color(_tint, 0.08))
		draw_rect(Rect2(c.x - r * 0.5, base_y, r, r * 0.09), color_projector)
		draw_rect(Rect2(c.x - r * 0.3, base_y + r * 0.09, r * 0.6, r * 0.05), color_projector_dark)

	if show_glow:
		for i in 4:
			draw_circle(c, r * (1.5 - i * 0.12), Color(_tint, 0.035 * flicker))

	var sa := t * orbit_speed
	var moon := c + Vector2(cos(sa) * r * 1.38, sin(sa) * r * 0.42)
	if show_orbit:
		var pts := PackedVector2Array()
		for i in 49:
			var a := i * TAU / 48.0
			pts.append(c + Vector2(cos(a) * r * 1.38, sin(a) * r * 0.42))
		draw_polyline(pts, Color(_tint, 0.3 * flicker), line_w)
		draw_circle(moon, maxf(2.0, r * 0.07), Color(color_moon, 0.9 * flicker))

	# Сама планета (парение целыми пикселями, чтобы не мылить пиксель-арт)
	var bob := roundf(sin(t * bob_speed) * bob_amount)
	var origin := (c - dst_size * 0.5 + Vector2(0.0, bob)).round()
	var tint := Color.WHITE if not _offline else Color(0.45, 0.5, 0.55)
	draw_texture_rect_region(atlas, Rect2(origin, dst_size), Rect2(_icon), Color(tint, flicker))

	if show_orbit and sin(sa) > 0.0:
		draw_circle(moon, maxf(2.0, r * 0.07), Color(color_moon, 0.95 * flicker))

	if show_scan_line:
		var dy := -r + fmod(t * scan_speed, 1.0) * 2.0 * r
		var half_w := sqrt(maxf(0.0, r * r - dy * dy))
		draw_line(Vector2(c.x - half_w, c.y + dy + bob), Vector2(c.x + half_w, c.y + dy + bob),
				Color(color_scan, 0.5 * flicker), line_w * 1.5)

	if show_corners:
		var m := r * 1.7
		var arm := r * 0.28
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := c + Vector2(sx * m, sy * m * 0.8)
				corner.x = clampf(corner.x, line_w * 3.0, size.x - line_w * 3.0)
				corner.y = clampf(corner.y, line_w * 3.0, size.y - line_w * 3.0)
				draw_line(corner, corner + Vector2(-sx * arm, 0.0), Color(color_scan, 0.55), line_w)
				draw_line(corner, corner + Vector2(0.0, -sy * arm), Color(color_scan, 0.55), line_w)
