extends Harvestable

@export var Boss : PackedScene
@export_placeholder("Scare") var boss_name : String = ""

var message_1 := "Evil is awakening"
var message_2 := "one hit and "

# Переопределяем логику уничтожения из Harvestable
func _on_tree_exiting() -> void:
	_spawn_boss_delayed(0.1)  # задержка 2 секунды

func _spawn_boss_delayed(delay: float) -> void:
	print("Started spawn boss")
	if Boss == null:
		print("Boss not found")
		return

	var timer = Timer.new()
	get_parent().add_child(timer)  # добавляем к родителю, не к себе
	timer.wait_time = delay
	timer.one_shot = true
	timer.start()
	
	if durability <= durability / 2:
		print(message_1)
	elif durability <= durability /3:
		print(message_2)
	
	var boss_instance = Boss.instantiate()
	var spawn_pos = Vector2(
		global_position.x + randf_range(-5, 5),
		global_position.y + randf_range(-5, 5)
	)
	boss_instance.global_position = spawn_pos

	get_parent().get_parent().add_child(boss_instance)
	print("Boss spawned at : " + str(spawn_pos))
	timer.queue_free()
