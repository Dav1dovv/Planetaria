extends VisibleOnScreenEnabler2D
class_name optimizer

@export var hide_objects: Array[Node]

func _ready() -> void:
	# _ready вместо _init — на момент _init сигналы/сцена ещё не готовы
	screen_entered.connect(_on_screen)
	screen_exited.connect(_on_off_screen)
	_on_off_screen()  # по умолчанию скрыто, пока не попадёт в кадр

func _on_screen() -> void:
	for obj in hide_objects:
		if obj:
			obj.visible = true

func _on_off_screen() -> void:
	for obj in hide_objects:
		if obj:
			obj.visible = false
