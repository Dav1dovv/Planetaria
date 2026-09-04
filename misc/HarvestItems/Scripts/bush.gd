extends Harvest_item
class_name bush

@export var berry_drp_rsc : DropResource
@export var blue_berry_drp_rsc : DropResource

func _ready() -> void:
	super._ready()
func Harvest(hit_strenght: float, tool_lvl: int, is_weapon: bool):
	if tool_lvl < harvest_tool_lvl:
		return

	match $Sprite2D.frame:
		0:
			if randf() < 0.03:
				Dropper_component.drop_bonus_heart()
		1:
			Dropper_component.drop_resources[0] = berry_drp_rsc
			Dropper_component._drop_items()
		2:
			Dropper_component.drop_resources[0] = blue_berry_drp_rsc
			Dropper_component._drop_items()

	$Sprite2D.visible = false

	if VFX_component != null:
		VFX_component._hit_vfx($Sprite2D)
		VFX_component._play_particles()
	await VFX_component.paricles_finished
	if gm and gm.has_method("register_harvested"):
		var loc_key := get_tree().current_scene.scene_file_path
		gm.register_harvested(loc_key, global_position)
	emit_signal("collected")
	queue_free()
