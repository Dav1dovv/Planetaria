extends CanvasLayer
class_name ObjectiveMarker

## Стрелка-указатель на цель: над целью на экране — покачивающаяся стрелка вниз,
## за краем экрана — стрелка у границы, указывающая направление.
## Использование: var id := marker.track(node, "Подпись"); marker.untrack(id)

const DEFAULT_COLOR := Color(1.0, 0.85, 0.3)
## Размер одного тайла в пикселях — для подписи расстояния в «метрах»
const TILE_SIZE := 16.0

var _targets: Dictionary = {}
var _next_id: int = 1
var _canvas: Control


func _ready() -> void:
	layer = 80
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_on_draw)


## Начать показывать стрелку на target. Возвращает id для untrack().
func track(target: Node2D, label: String = "", color: Color = DEFAULT_COLOR) -> int:
	var id := _next_id
	_next_id += 1
	_targets[id] = {"node": target, "label": label, "color": color}
	return id


func untrack(id: int) -> void:
	_targets.erase(id)


func clear() -> void:
	_targets.clear()


func _process(_delta: float) -> void:
	_canvas.visible = not _targets.is_empty() and get_tree().get_first_node_in_group("Player") != null
	if _canvas.visible:
		_canvas.queue_redraw()


func _on_draw() -> void:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var h := rect.size.y
	var canvas_xf := viewport.get_canvas_transform()
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	var font := ThemeDB.fallback_font
	var font_size := int(h * 0.03)
	var inner := rect.grow(-h * 0.08)
	var time := Time.get_ticks_msec() / 1000.0

	for id in _targets.keys():
		var entry: Dictionary = _targets[id]
		var node := entry["node"] as Node2D
		if not is_instance_valid(node):
			_targets.erase(id)
			continue
		var color: Color = entry["color"]
		var label: String = entry["label"]
		if player != null:
			label += "  " + Loc.t("%d m") % roundi(player.global_position.distance_to(node.global_position) / TILE_SIZE)

		var screen_pos := canvas_xf * node.global_position
		if inner.has_point(screen_pos):
			var bob := sin(time * 5.0) * h * 0.008
			var tip := screen_pos + Vector2(0.0, -h * 0.05 + bob)
			_draw_arrow(tip, Vector2.DOWN, h * 0.025, color)
			_draw_label(font, tip + Vector2(0.0, -h * 0.03), label, font_size, color, rect)
		else:
			var center := rect.size * 0.5
			var dir := (screen_pos - center).normalized()
			var half := inner.size * 0.5
			var limit_x := half.x / absf(dir.x) if absf(dir.x) > 0.001 else INF
			var limit_y := half.y / absf(dir.y) if absf(dir.y) > 0.001 else INF
			var edge_pos := center + dir * minf(limit_x, limit_y)
			_draw_arrow(edge_pos, dir, h * 0.03, color)
			_draw_label(font, edge_pos - dir * h * 0.065, label, font_size, color, rect)


func _draw_arrow(tip: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var side := dir.orthogonal()
	var points := PackedVector2Array([
		tip,
		tip - dir * size + side * size * 0.55,
		tip - dir * size * 0.65,
		tip - dir * size - side * size * 0.55,
	])
	_canvas.draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	_canvas.draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.9), 2.0)


func _draw_label(font: Font, pos: Vector2, text: String, font_size: int, color: Color, bounds: Rect2) -> void:
	if text.is_empty():
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var draw_pos := pos - Vector2(text_size.x * 0.5, 0.0)
	draw_pos.x = clampf(draw_pos.x, bounds.position.x + 4.0, bounds.end.x - text_size.x - 4.0)
	draw_pos.y = clampf(draw_pos.y, bounds.position.y + font_size, bounds.end.y - 4.0)
	_canvas.draw_string_outline(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color.BLACK)
	_canvas.draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
