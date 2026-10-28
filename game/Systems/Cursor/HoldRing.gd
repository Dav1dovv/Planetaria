## HoldRing.gd
## Круг у курсора, который заполняется, пока игрок удерживает кнопку взаимодействия
## (Interaction.hold_to_interact). Рисуется кодом, текстуры не нужны.
## Положение, размер и цвета правятся в Inspector на узле HoldRing в cursor.tscn.
extends Node2D
class_name HoldRing

@export_range(2.0, 40.0, 0.5) var radius: float = 7.0
@export_range(1.0, 8.0, 0.5) var width: float = 2.0
## Тёмная подложка — круг читается на любом фоне
@export var back_color: Color = Color(0.05, 0.08, 0.12, 0.75)
@export var track_color: Color = Color(0.36, 0.42, 0.45, 0.9)
@export var fill_color: Color = Color("45e6e6")
@export var done_color: Color = Color("6fe08a")
@export_range(12, 96) var points: int = 48

var _progress: float = 0.0
var _done: bool = false
var _tween: Tween


func _ready() -> void:
	visible = false


## Показывает круг и выставляет заполнение 0..1.
func set_progress(ratio: float) -> void:
	_kill_tween()
	_done = false
	_progress = clampf(ratio, 0.0, 1.0)
	scale = Vector2.ONE
	modulate.a = 1.0
	visible = true
	queue_redraw()


## completed = true — вспышка «готово»; false — круг быстро откатывается и исчезает.
func finish(completed: bool) -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	if completed:
		_done = true
		_progress = 1.0
		queue_redraw()
		_tween.set_parallel(true)
		_tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 0.0, 0.22)
		_tween.chain().tween_callback(hide)
	else:
		_tween.tween_method(_set_progress_silent, _progress, 0.0, 0.12)
		_tween.tween_callback(hide)


func _set_progress_silent(value: float) -> void:
	_progress = value
	queue_redraw()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, points, back_color, width + 2.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, points, track_color, width, true)
	if _progress > 0.001:
		var color := done_color if _done else fill_color
		draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * _progress, points, color, width, true)
