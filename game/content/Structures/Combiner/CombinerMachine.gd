## CombinerMachine.gd
## Стол-комбинатор в мире (корабль-хаб). Клик ЛКМ/RT по нему — главное действие игры —
## открывает окно комбинатора оружия слева от рюкзака.
extends Node2D
class_name CombinerMachine

@onready var interaction: interaction_area = $interaction_area


func _ready() -> void:
	interaction.interact = Callable(self, "_on_interact")


func _on_interact() -> void:
	if Global.inventory != null:
		Global.inventory.call_combiner()
