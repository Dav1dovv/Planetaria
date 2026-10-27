extends RapierCharacterBody2D

const MAX_SPEED = 50.0
const ACCELERATION = 3

@onready var sprite = $Sprite2D
@onready var animationPlayer = $AnimationPlayer

var can_pick : bool = false
var speed : float
var player #= get_tree().get_first_node_in_group("Player")

func _ready() -> void:
	# Инициализация параметров для эффекта появления
	scale = Vector2(0.1, 0.1)  # Начальный маленький масштаб
	rotation = 0
	modulate.a = 1.0  # Дроп сразу видимый
	# Запуск эффекта появления через корутину
	_spawn_effect()
	

func _spawn_effect() -> void:
	var duration = 0.7  # Длительность эффекта
	var elapsed = 0.0
	var bounce_factor = 1.3  # Максимальное превышение масштаба для bounce-эффекта
	var initial_position = global_position  # Сохраняем начальную позицию
	var throw_height = 30.0  # Высота выброса
	var random_x_offset = randf_range(-20, 20)  # Случайное горизонтальное смещение
	
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t = elapsed / duration
		
		# Косинусная интерполяция
		var t_cosine = (cos(PI * t) + 1.0) / 2.0
		
		# Эффект выброса: движение вверх и обратно
		var throw_progress = sin(t * PI)  # Синусоидальное движение вверх и вниз
		global_position.y = initial_position.y - throw_height * throw_progress
		global_position.x = initial_position.x + random_x_offset * (1.0 - t_cosine)  # Горизонтальное затухание
		
		# Интерполяция для масштаба с bounce-эффектом
		var scale_progress = 1.0 - t_cosine
		var scale_bounce = 1.0 + sin(t * PI) * bounce_factor * t_cosine
		var new_scale = lerp(0.1, 1.0, scale_progress) * scale_bounce
		scale = Vector2(new_scale, new_scale)
		
		# Вращение с косинусной интерполяцией
		var rotation_progress = sin(t * PI * 2) * t_cosine * 0.4
		rotation = rotation_progress
		
		await get_tree().create_timer(get_process_delta_time()).timeout
	
	# Финальные значения
	global_position = initial_position  # Возвращаем на исходную позицию
	scale = Vector2(1.0, 1.0)
	rotation = 0
	# Воспроизведение звука приземления (подключи аудиоресурс)
	#$AudioStreamPlayer2D.play()  # Убедись, что у ноды есть AudioStreamPlayer2D с файлом "drop_sound"

func _process(delta: float) -> void:
	if can_pick == true:
		speed = lerp(speed, MAX_SPEED, ACCELERATION * delta)
		velocity = global_position.direction_to(player.global_position) * speed
		
		move_and_slide()
		#move_and_collide(velocity)

func _on_pick_zone_body_entered(body: Node2D) -> void:
	print("true")
	can_pick = true
	player = body

func _on_pick_zone_body_exited(body: Node2D) -> void:
	can_pick = false

func _on_pick_area_entered(area: Area2D) -> void:
	$SFX.play()
	player.heal(10)
	#await animationPlayer.animation_finished
	queue_free()



func _on_timer_timeout() -> void:
	$PickZone/CollisionShape2D.disabled = false
	$Pick/CollisionShape2D.disabled = false
