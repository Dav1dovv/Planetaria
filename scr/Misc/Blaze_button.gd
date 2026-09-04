extends Button
class_name blaze_button

func _on_mouse_entered() -> void:
	$Hover.play()

func _on_pressed() -> void:
	if disabled:
		$Decline.play()
	else:
		$Accept.play()
