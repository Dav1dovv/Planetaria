extends CanvasLayer

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	Global.scene_manager.change_to_main_menu()


func _on_button_pressed() -> void:
	$Control/BlazionOg3/AnimationPlayer.play("Click")
