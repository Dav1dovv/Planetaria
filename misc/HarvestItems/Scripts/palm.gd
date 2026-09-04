extends Harvest_item
class_name palm


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if $HurtBox: $HurtBox.queue_free()
	Dropper_component.drop_itm_by(1)
