@icon("res://addons/at-icons/mesh/film_camera.svg")
extends Blaze_camera
class_name Blaze_Cinema_Cam

## Скорость перемещения (чем выше, тем быстрее)
@export var move_speed: float = 5.0

## Границы области для случайных точек
@export var area_min: Vector2 = Vector2(-500, -400)  # Левая-верхняя точка
@export var area_max: Vector2 = Vector2(500, 400)    # Правая-нижняя точка

## Текущая цель позиции
var target_position: Vector2 = Vector2.ZERO

## Таймер для автоматического перемещения (если нужен)
@export var auto_move_interval: float = 2.0  # Интервал в секундах

func _ready():
	# Начальная позиция - центр области
	target_position = Vector2(
		(area_min.x + area_max.x) / 2,
		(area_min.y + area_max.y) / 2
	)
	position = target_position
	
	limit_left = area_min.x
	limit_right = area_max.x
	limit_top = area_min.y
	limit_bottom = area_max.y
	# Настройка таймера для автоматического перемещения
	if auto_move_interval > 0:
		var timer = Timer.new()
		add_child(timer)
		timer.timeout.connect(_on_timer_timeout)
		timer.start(auto_move_interval)

func _process(delta):
	# Плавное перемещение к цели с помощью lerp
	if position != target_position:
		position = position.lerp(target_position, move_speed * delta)

	# Перемещение по нажатию клавиши (Space)
	if Input.is_action_just_pressed("ui_accept"):
		move_to_random_point()

# Функция для генерации и перемещения к случайной точке
func move_to_random_point():
	var new_position = Vector2(
		randf_range(area_min.x, area_max.x),
		randf_range(area_min.y, area_max.y)
	)
	var tween = create_tween()
	tween.tween_property(self, "position", new_position, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	target_position = new_position
	print("Перемещаюсь к точке: ", target_position)

# Обработчик таймера для автоматического перемещения
func _on_timer_timeout():
	move_to_random_point()
