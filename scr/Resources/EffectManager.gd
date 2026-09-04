extends Node
class_name EffectManager

var character
var effects := {
	"Warm" : false,
	"Burn" : false,
	"Freeze" : false,
	"Possion" : false,
	"Bleeding" : false,
	"Lucky" : false,
	"Invisibility" : false,
	"DamageBoost" : false,
	"DeffenseBoost" : false,
	"BonusLife" : false,
	"Regeneration" : false,
	
	
	}

func _ready() -> void:
	character = get_parent()

func apply_effect():
	pass
