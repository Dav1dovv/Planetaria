extends RapierArea2D


@export var new_spawn_config : CreatureConfig
@export var new_spawn_interval : float = 8.0
@export var new_spawn_variation : float = 5.0
@export var new_spawn_min : int = 1
@export var new_spawn_max : int = 3

var spawner : CreatureSpawner
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawner = get_tree().get_first_node_in_group("Spawner")



func _on_body_entered(body: Node2D) -> void:
	if  body.is_in_group("Player"):
		if not is_instance_valid(spawner):
			spawner = get_tree().get_first_node_in_group("Spawner") as CreatureSpawner
		if spawner == null or new_spawn_config == null:
			push_warning("Zone %s: нет спавнера или конфига" % name)
			return

	spawner.creatures.assign([new_spawn_config])  # зона задаёт весь пул
	spawner.base_spawn_interval = new_spawn_interval
	spawner.spawn_interval_variation = new_spawn_variation
	spawner.spawn_count_min = new_spawn_min
	spawner.spawn_count_max = new_spawn_max
	spawner.refresh()
