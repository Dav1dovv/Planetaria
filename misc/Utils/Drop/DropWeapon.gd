extends DropResource
class_name DropWeaponResource

## change weapon durability value || 0 nothing to change || -1 Random
@export_range(-1, 500, 1) var new_durability: int = 100
## change weapon damage value || 0 nothing to change || -1 Random
@export_range(-1, 93, 1) var new_damage: int = 7

## Важно: рандомизация теперь происходит здесь, а не в _init(),
## потому что _init() у Resource вызывается один раз при загрузке
## .tres, а не при каждом дропе. get_item() вызывается Dropper'ом
## каждый раз заново, и мы дублируем drop_item, чтобы не портить
## общий (shared) ресурс.
func get_item() -> ItemData:
	if drop_item == null:
		return null

	var new_item: ItemData = drop_item.duplicate(true)

	if new_damage > 0:
		new_item.Damage = new_damage
	elif new_damage < 0:
		new_item.Damage = randi_range(7, 30)
	# new_damage == 0 -> ничего не меняем

	if new_durability > 0:
		new_item.durability = new_durability
	elif new_durability < 0:
		new_item.durability = randi_range(25, new_item.max_durability)
	# new_durability == 0 -> ничего не меняем

	return new_item
