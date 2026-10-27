@tool
extends Control
class_name TerminalBolts
## Винты по четырём углам корпуса — чтобы консоль выглядела железом, а не плашкой.

@export var inset: float = 4.0
@export var radius: float = 2.0
@export var color_body: Color = Color("171923")
@export var color_edge: Color = Color("6b7388")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for corner in [Vector2(inset, inset), Vector2(size.x - inset, inset),
			Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)]:
		draw_circle(corner, radius, color_body)
		draw_arc(corner, radius, 0.0, TAU, 12, color_edge, 1.0)
		draw_line(corner + Vector2(-radius, 0.0) * 0.6, corner + Vector2(radius, 0.0) * 0.6, color_edge, 1.0)
