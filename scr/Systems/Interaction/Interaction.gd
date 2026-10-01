extends RapierArea2D
class_name interaction_area

signal far

@export_multiline var show_message : String = "interact"
@export var icon_help : Texture2D
var is_in_zone = false
var player
var interact: Callable = func():
	pass
# Исправлено: connect сигналов перенесён из _init() в _ready(),
# так как в _init нода ещё не добавлена в дерево сцены
func _init() -> void:
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(8, true)
	set_collision_mask_value(9, true)
	add_to_group("interaction")

func _ready() -> void:
	# Исправлено: подключение сигналов перенесено сюда
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)

## Вызывается ТОЛЬКО курсором (Cursor.gd), когда именно этот объект
## реально находится под курсором в момент отпускания ПКМ.
## Больше не полагаемся на локальный is_in_zone + глобальный _input —
## это и вызывало срабатывание у всех объектов сразу, если area_exited
## терялся из-за быстрого перемещения курсора (телепорт мыши каждый кадр).
func try_interact() -> void:
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) >= 60:
		Global.hint(get_parent(), "you're too far")
		emit_signal("far")
	else:
		interact.call()


func _on_area_entered(area: Area2D) -> void:
	print("mouse_entered")  # Исправлено: опечатка "mouse_enetered" → "mouse_entered"
	Cursor.Help_hint(icon_help)
	is_in_zone = true


func _on_area_exited(area: Area2D) -> void:
	print("mouse_exited")
	Input.set_custom_mouse_cursor(Global.MOUSE_Arrow, Input.CURSOR_ARROW, Vector2(0, 0))
	is_in_zone = false
	Cursor.Help_hint(null)
