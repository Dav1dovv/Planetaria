extends Node
class_name PlayerHunger

signal hunger_changed(new_health: int)

var hunger: int = 100

@onready var player: Player = get_parent()
@onready var timer: Timer = Timer.new()

func _ready() -> void:
	add_child(timer)
	timer.wait_time = 6
	timer.timeout.connect(change_hunger)
	timer.paused = true
	timer.start()

func _process(delta: float) -> void:
	if player.velocity.length_squared() > 1.0:
		timer.paused = false
	else:
		timer.paused = true

func change_hunger() -> void:
	hunger -= 7
	hunger = max(hunger, 0)
	emit_signal("hunger_changed", hunger)
