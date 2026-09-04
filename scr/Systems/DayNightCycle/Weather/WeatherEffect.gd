## Базовый скрипт для всех сцен погодных эффектов.
## Повесь на корневую ноду каждого эффекта (rain.tscn, fog.tscn и т.д.)
extends Control
class_name WeatherEffect

var fade_duration: float = 3.0

# ── публичный API ────────────────────────────────────────────────────────────

func fade_in() -> void:
	_set_alpha(0.0)
	_set_emitting(true)
	var tw := create_tween()
	for t in _collect_targets():
		tw.parallel().tween_method(t.set_alpha.bind(), 0.0, t.max_alpha, fade_duration)
	await tw.finished


func fade_out() -> void:
	var tw := create_tween()
	for t in _collect_targets():
		tw.parallel().tween_method(t.set_alpha.bind(), t.max_alpha, 0.0, fade_duration)
	await tw.finished
	_set_emitting(false)
	queue_free()


# ── сбор целей для анимации ───────────────────────────────────────────────────

func _collect_targets() -> Array:
	var out := []
	_walk(self, out)
	return out


func _walk(node: Node, out: Array) -> void:
	if node is ColorRect:
		out.append(ColorRectTarget.new(node))
	elif node is Polygon2D:
		out.append(Polygon2DTarget.new(node))
	elif node is GPUParticles2D or node is CPUParticles2D:
		out.append(ParticlesTarget.new(node))
	for child in node.get_children():
		_walk(child, out)


func _set_alpha(a: float) -> void:
	for t in _collect_targets():
		t.set_alpha(a)


func _set_emitting(value: bool) -> void:
	_set_emitting_recursive(self, value)


func _set_emitting_recursive(node: Node, value: bool) -> void:
	if node is GPUParticles2D or node is CPUParticles2D:
		node.emitting = value
	for child in node.get_children():
		_set_emitting_recursive(child, value)


# ── обёртки для разных типов нод ─────────────────────────────────────────────

class ColorRectTarget:
	var node: ColorRect
	var max_alpha: float
	func _init(n: ColorRect) -> void:
		node = n
		max_alpha = n.color.a
	func set_alpha(a: float) -> void:
		var c := node.color; c.a = a; node.color = c


class Polygon2DTarget:
	var node: Polygon2D
	var max_alpha: float
	func _init(n: Polygon2D) -> void:
		node = n
		max_alpha = n.color.a
	func set_alpha(a: float) -> void:
		var c := node.color; c.a = a; node.color = c


class ParticlesTarget:
	var node: Node
	var max_alpha: float = 1.0
	func _init(n: Node) -> void:
		node = n
	func set_alpha(a: float) -> void:
		node.modulate.a = a
