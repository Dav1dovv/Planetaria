extends Node2D

const need_tool = preload("uid://ky47smcnnrdj")
const CHEST_CLOSE = preload("uid://e6mf5rd80uw8")


@onready var interaction : interaction_area = $interaction_area
#@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var player = get_tree().get_first_node_in_group("Player")
var is_opened = false
var chest_lvl : int = 1
var need_key : bool = false
var need_count : int = 10
@export var is_hidden : bool = false
@export var is_random : bool = false

func _ready():
	interaction.interact = Callable(self, "open")
	if is_hidden: 
		$Sprite.visible = false
		$interaction_area/CollisionShape2D.disabled = true
	
	if is_random:
		randomize()
		need_count = randi_range(3,20)
		interaction.show_message = "X " + str(need_count)



func open():
	print("starting interaction with chest")
	if !is_opened:
		get_tree().paused = true
		$AnimationPlayer.play("Open")
		is_opened = true
		$interaction_area.queue_free()
	elif !is_opened and Global.inventory.has_total_item(need_tool,need_count):
		get_tree().paused = true
		$AnimationPlayer.play("Open")
		Global.inventory.remove_from_total(need_tool,need_count)
		is_opened = true
		$interaction_area.queue_free()
	else:
		$SFX.play()
		if need_tool != null:
			Global.hint(self,"you need " + need_tool.item_name)
		else:
			Global.hint(self,"this is bug")

func _on_timer_timeout() -> void:
	queue_free()


func Show_secret(area: Area2D) -> void:
	print("chest attack alert")
	if is_hidden: 
		$AnimationPlayer.play("Show")
		$RapierArea2D.queue_free()
		$Sprite.visible = true
		$interaction_area/CollisionShape2D.disabled = false
func finish_open():
	get_tree().paused = false
	

func _on_interaction_area_far() -> void:
	$SFX.stream = CHEST_CLOSE
	$SFX.play()
