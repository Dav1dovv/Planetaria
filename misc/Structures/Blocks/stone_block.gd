extends Harvest_item
class_name  Stone_block

var max_durability : int

func _ready() -> void:
	super._ready()
	max_durability = durability

func _process(delta: float) -> void:
	if durability <= max_durability / 3:
		$Sprite2D.frame = 3
	elif durability <= max_durability / 2:
		$Sprite2D.frame = 2
	elif durability <= max_durability -1:
		$Sprite2D.frame = 1
