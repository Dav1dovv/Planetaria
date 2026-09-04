extends HarvestAction
class_name SpawnAction

@export var spawn_item : Array[PackedScene]
@export_range(0.0, 50.0, 1.0) var scatter_radius : float = 10.0

func execute(harvestable: Node2D) -> void:
	var pos : Vector2 = harvestable.global_position
	var tree : SceneTree = harvestable.get_tree()
	if tree == null:
		return

	_spawn_item(pos, harvestable, tree)

func _spawn_item(pos: Vector2, harvestable: Node2D, tree: SceneTree) -> void:
	if spawn_item.is_empty():
		push_warning("SpawnAction: spawn_item пуст в ресурсе " + str(resource_path))
		return

	var scene = spawn_item.pick_random()
	var sp = scene.instantiate()

	var parent := harvestable.get_parent()
	if parent == null:
		return

	parent.add_child(sp)
	if sp is Node2D:
		sp.global_position = pos + Vector2(
			randf_range(-scatter_radius, scatter_radius),
			randf_range(-scatter_radius, scatter_radius)
		)
