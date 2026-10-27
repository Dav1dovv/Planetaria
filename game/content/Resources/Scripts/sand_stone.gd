extends Harvest_item
class_name SandStone


@export var harvest_action : HarvestAction


func _ready() -> void:
	super._ready()
	collected.connect(_on_collected)


func _on_collected() -> void:
	if harvest_action:
		harvest_action.execute(self)
