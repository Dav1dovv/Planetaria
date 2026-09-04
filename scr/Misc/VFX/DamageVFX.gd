extends VFX
class_name VFX_damage

@export var character : Node2D

func _hit_vfx(new_character : Node2D) -> void:
	_play_audio()
	_play_particles()
	if new_character == null:
		return
	else:
		character = new_character
	var tween = create_tween().set_parallel(true)
	tween.tween_property(character, "rotation", randf_range(-0.2, 0.2), 0.01)
	tween.tween_property(character, "scale", Vector2(0.4, 0.4), 0.01)
	await tween.tween_property(character, 'modulate', Color(18.892, 18.892, 18.892, 1.0), 0.1)
	tween.tween_property(character, "scale", Vector2(1.1, 1.1), 0.01)
	tween.tween_property(character, "rotation", 0.0, 0.1).set_delay(0.01)
	await tween.tween_property(character, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.02)
	tween.tween_property(character, 'modulate', Color(1.0, 1.0, 1.0, 1.0), 0.1)

	tween.tween_callback(vfx_finished.emit)


func _damage_vfx():
	_play_audio()
	_play_particles()
	var tween = create_tween()
	tween.tween_property(character, "rotation", randf_range(-0.2, 0.2), 0.1)
	await tween.tween_property(character, 'modulate', Color(3.705, 0.0, 0.0, 1.0), 0.1)
	tween.tween_property(character, 'modulate', Color.WHITE, 0.2)

	tween.tween_property(character, "rotation", 0.0, 0.1)


func _play_audio():
	if audio_player:
		audio_player.play()
	else:
		return
