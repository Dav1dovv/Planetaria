extends RefCounted
class_name LootUtil

## Общие помощники для лута: создать предмет на земле (как это делает Dropper).

const DROP_SCENE := preload("uid://drqvpabe55ide")

const COIN: ItemData = preload("res://misc/Content/Items/Coin.tres")
const POTION: ItemData = preload("res://misc/Content/Items/HealthPotion.tres")
const WOOD: ItemData = preload("res://misc/Content/Items/Wood.tres")
const STONE: ItemData = preload("res://misc/Content/Items/Stone.tres")
const ARTEFACT_PIECE: ItemData = preload("res://misc/Content/Items/Artefact_Piece.tres")
const GOLD_ORE: ItemData = preload("res://misc/Content/Items/Gold_Ore.tres")
const CRYSTAL_SHARD: ItemData = preload("res://misc/Content/Items/Crystal_Shard.tres")
const LUCKY_STAR: ItemData = preload("res://misc/Content/Items/Potion_LuckyStar.tres")


## Положить на землю amount штук предмета рядом с pos (подбирается магнитом, как обычный дроп).
static func drop(item: ItemData, amount: int, pos: Vector2, spread: float = 10.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or item == null or amount <= 0:
		return
	var root: Node = tree.get_first_node_in_group("World")
	if root == null:
		root = tree.current_scene
	if root == null:
		return
	var new_drop = DROP_SCENE.instantiate()
	# .duplicate(): у каждого дропа свой Resource, как в Dropper.gd
	new_drop.update_drop(item.duplicate(), amount)
	new_drop.global_position = pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
	root.call_deferred("add_child", new_drop)
