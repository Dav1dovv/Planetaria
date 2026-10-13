extends Sprite2D

@export var Boss : PackedScene
@export_placeholder("Scare") var boss_name : String = ""
@onready var interaction: interaction_area = $interaction_area
const ARTEFACT_BOSS_CALLER = preload("uid://b63ly05pw5sp4")


func _ready() -> void:
	interaction.interact = Callable(self,"interact")

func interact():
	if Global.inventory.has_total_item(ARTEFACT_BOSS_CALLER,1):
		Global.inventory.remove_from_total(ARTEFACT_BOSS_CALLER,1)
		Global.developer_console.add_chat_message(" ",boss_name + " awakening",Color(0.52, 0.0, 0.0, 1.0))
		Global.developer_console.log_message(boss_name + " awakening",Color(0.52, 0.0, 0.0, 1.0))
		_spawn_boss_delayed(2)

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
	

	var boss_instance = Boss.instantiate()
	var spawn_pos = Vector2(
		global_position.x + randf_range(-5, 5),
		global_position.y + randf_range(-5, 5)
	)
	boss_instance.global_position = spawn_pos

	get_parent().get_parent().add_child(boss_instance)
	print("Boss spawned at : " + str(spawn_pos))
	timer.queue_free()
