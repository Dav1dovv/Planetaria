extends Harvest_item

const SHININ_1 = preload("uid://dt3kmwwp04orp")
const SHININ_2 = preload("uid://bgul038d2vviw")
const SHININ_3 = preload("uid://c8umlrxs5p85e")

var shaders := [SHININ_1,SHININ_2,SHININ_3]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	if randf() < 0.2:
		$Sprite2D.material = shaders.pick_random()
