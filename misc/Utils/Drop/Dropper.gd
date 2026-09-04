extends Node
class_name Dropper

## Список ресурсов дропа (DropResource / DropWeaponResource / любые наследники).
## Каждый ресурс сам решает: выпадет ли он вообще (drop_chance), сколько раз
## отдельными стаками (throws) и сколько предметов в каждом стаке (amount).
@export var drop_resources : Array[DropResource]

const DROP = preload("uid://drqvpabe55ide")
const DROPED_HEART = preload("uid://ciane2i2vcc0q")


func _drop_items() -> void:
	var root = get_tree().get_first_node_in_group("World")
	if root == null:
		return
	if drop_resources.is_empty():
		return

	for res in drop_resources:
		if res == null:
			continue
		if not res.rolls_drop():
			continue

		var throws = res.get_throws()
		for i in throws:
			_spawn_drop(res, root)


func _spawn_drop(res: DropResource, root: Node) -> void:
	var item: ItemData = res.get_item()
	if item == null:
		print("Dropper: get_item() вернул null для ", res)
		return

	var amount := res.get_amount()

	var new_drop = DROP.instantiate()
	new_drop.update_drop(item, amount)

	new_drop.global_position = get_parent().global_position + Vector2(
		randf_range(-10.0, 10.0),
		randf_range(-10.0, 10.0)
	)
	root.call_deferred("add_child", new_drop)


func drop_bonus_heart() -> void:
	var root = get_tree().get_first_node_in_group("World")
	if root == null:
		return
	var new_drop = DROPED_HEART.instantiate()
	new_drop.global_position = get_parent().global_position + Vector2(
		randf_range(-10.0, 10.0),
		randf_range(-10.0, 10.0)
	)
	root.call_deferred("add_child", new_drop)

func drop_itm_by(indx : int):
	var root = get_tree().get_first_node_in_group("World")
	if root == null:
		return
	if drop_resources.is_empty():
		return



	for i in 3:
		_spawn_drop(drop_resources[indx], root)
