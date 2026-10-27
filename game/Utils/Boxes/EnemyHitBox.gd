extends HitBox
class_name entity_HitBox

signal attacked

@export var equip_sprite : Sprite2D

@export var random_weapons : Array[equip_data]

var stat : stats
var is_weapon : bool = true

func _ready() -> void:
	if get_parent().is_in_group("Ennemy"):
		stat = get_parent().Entity_stats
	if !random_weapons.is_empty():
		equip = random_weapons[randi() % random_weapons.size()]
	connect("area_entered",hit)
	if equip_sprite: update_equip(equip)

func hit(area:Area2D):
	if area.is_in_group("Player"):
		print("damaging to player")
		area.get_parent().take_damage(equip.Damage,self)
		emit_signal("attacked")
	
func update_equip(new_equip : ItemData):
	if equip_sprite == null:
		return
	print("updating equip sprite")
	equip = new_equip
	if equip is equip_data:
		#equip_sprite.offset = Vector2(-0.5,-4.5)
		#equip_sprite.scale = Vector2(1,1)
		#equip_sprite.rotation = 90
		equip_sprite.texture = equip.equiped_weapon_sprite
		is_weapon = true
	elif equip is ItemData:
		equip_sprite.offset = Vector2(0,0)
		equip_sprite.scale = Vector2(0.5,0.5)
		equip_sprite.rotation = 45
		equip_sprite.texture = equip.icon
		is_weapon = false
