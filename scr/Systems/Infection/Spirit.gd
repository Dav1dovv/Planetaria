extends interaction_area
class_name SpiritAltar
## "Дух" — мгновенное полное очищение заражения за золото (GDD 3.3 "Заражение").
##
## Повесь этот скрипт на interaction_area (тот же класс, что у Door.gd/Interaction.gd) —
## например на алтарь/NPC-иконку "Дух", размещённую в деревне/у Синкера.

@export var cost: int = 50

func _ready() -> void:
	super._ready()
	interact = _on_interact
	show_message = "Дух — очистить заражение (%d золота)" % cost

func _on_interact() -> void:
	var p := get_tree().get_first_node_in_group("Player")
	if p == null or not p.has_method("full_cure_infection"):
		return

	if p.has_method("get_infection") and p.get_infection() <= 0.0:
		Global.hint(get_parent(), "Заражения нет")
		return

	var gold_slot: GoldSlot = null
	if Global.inventory:
		gold_slot = Global.inventory.gold_slot

	if gold_slot == null:
		push_warning("[Spirit] GoldSlot не найден — очищение отменено")
		return

	if gold_slot.spend(cost):
		p.full_cure_infection()
		Global.hint(get_parent(), "Заражение снято")
	else:
		Global.hint(get_parent(), "Не хватает золота (%d)" % cost)
