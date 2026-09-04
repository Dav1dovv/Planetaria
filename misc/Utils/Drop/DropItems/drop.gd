extends RapierCharacterBody2D

const MAX_SPEED = 50.0
const ACCELERATION = 3
const COIN = preload("uid://b1pe4ord4bxue")

@onready var sprite = $Sprite2D
@onready var animationPlayer = $AnimationPlayer

@export var item : ItemData
var amount : int = 1
var can_pick : bool = false
var speed : float
var player #= get_tree().get_first_node_in_group("Player")

func _ready() -> void:
	# Инициализация параметров для эффекта появления
	scale = Vector2(0.1, 0.1)  # Начальный маленький масштаб
	rotation = randf_range(-0.3, 0.3)
	modulate.a = 1.0  # Дроп сразу видимый
	# Запуск эффекта появления через Tween
	_spawn_effect()


func _spawn_effect() -> void:
	var initial_position = global_position
	var throw_height = 30.0  # Высота выброса
	var random_x_offset = randf_range(-20, 20)  # Случайное горизонтальное смещение
	var up_duration = 0.22   # Время подлёта вверх
	var down_duration = 0.4  # Время падения + отскок

	# Отдельный Tween только для вертикали: вверх (плавно) -> вниз с реальным bounce-приземлением
	var tween_y = create_tween()
	tween_y.tween_property(self, "global_position:y", initial_position.y - throw_height, up_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_y.tween_property(self, "global_position:y", initial_position.y, down_duration)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Параллельный Tween для масштаба/разлёта/вращения — идёт одновременно с tween_y,
	# т.к. оба Tween'а создаются и стартуют в один и тот же кадр
	var tween_rest = create_tween()
	tween_rest.set_parallel(true)
	tween_rest.tween_property(self, "scale", Vector2.ONE, up_duration + down_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_rest.tween_property(self, "global_position:x", initial_position.x + random_x_offset, up_duration + down_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_rest.tween_property(self, "rotation", 0.0, up_duration + down_duration)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await tween_y.finished
	# Звук приземления (подключи AudioStreamPlayer2D с нужным звуком, если нужно)
	#$AudioStreamPlayer2D.play()


func update_drop(new_item: ItemData, new_amount: int = 1) -> void:
	item = new_item
	amount = new_amount
	$Sprite2D.texture = new_item.icon
	
	if new_item.item_name == "Coin":
		$SFX.stream = COIN
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
	player = null

func _on_pick_area_entered(area: Area2D) -> void:
	$SFX.play()
	if Global.inventory.can_add_item(item, amount):
		animationPlayer.play("Pick")
		Global.pickup_item(item, amount)
		#Global.developer_console.show_hint("+ %d %s" % [amount, item.item_name], 2.5, Color.WHITE_SMOKE)
		await animationPlayer.animation_finished
		queue_free()
	else:
		Global.hint(self,"your inventory is full")
		# Опционально: показать "Инвентарь полон!"
		# Global.developer_console.show_hint("Инвентарь полон!", 2.0, Color.RED)
		pass

#func exp_drop():
	#var exp = preload("res://Assets/Entity/drop_EXP.tscn")
	#var new_drop = exp.instantiate()
	#new_drop.global_position = global_position + Vector2(randf_range(-30,30),randf_range(-30,30))
	#get_parent().call_deferred("add_child",new_drop)


func _on_timer_timeout() -> void:
	$PickZone/CollisionShape2D.disabled = false
	$Pick/CollisionShape2D.disabled = false
