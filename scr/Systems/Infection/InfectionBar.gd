extends ProgressBar
class_name InfectionBar
## Полоска заражения для HUD — GDD 3.3 "Заражение" ("Заполняет отдельную
## шкалу поверх жизни"). Отдельный виджет от health_bar/curse_bar.
##
## Как подключить: добавь ProgressBar (min=0, max=100) в HUD рядом с
## HealthBar, повесь этот скрипт — дальше само подпишется на игрока.

@export var color_low:    Color = Color(0.55, 0.35, 0.75)   # 0-49%
@export var color_medium: Color = Color(0.65, 0.15, 0.85)   # 50-79%
@export var color_high:   Color = Color(0.85, 0.0, 0.55)    # 80-100%

var _tween: Tween

func _ready() -> void:
	min_value = 0.0
	max_value = 100.0

	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	var infection = player.get_node_or_null("PlayerInfection")
	if infection == null:
		return

	infection.infection_changed.connect(_on_infection_changed)
	_on_infection_changed(infection.infection)


func _on_infection_changed(new_value: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "value", new_value, 0.3)
	_update_color(new_value)


func _update_color(v: float) -> void:
	var c := color_low
	if v >= 80.0:
		c = color_high
	elif v >= 50.0:
		c = color_medium
	modulate = c
