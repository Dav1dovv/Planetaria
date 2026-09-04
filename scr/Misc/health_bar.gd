extends ProgressBar
class_name health_bar

var max_health
var health
var delayed_tween: Tween
var curse_tween: Tween

@onready var curse_bar: ProgressBar = $CurseBar
@onready var heart_icon: TextureRect = $HeartIcon
@onready var corruption_effect: GPUParticles2D = $"Corruption Effect"
@onready var delayed_bar: ProgressBar = $DelayedBar 

func _ready() -> void:
	corruption_effect.emitting = false
	corruption_effect.visible = false

func update_value(new_value : float, new_max_value : float, curse : float) -> void:

	# Delayed bar
	if new_value < value:  # получили урон
		if delayed_tween:
			delayed_tween.kill()
		delayed_tween = create_tween()
		delayed_tween.tween_property(delayed_bar, "value", new_value, 0.6).set_delay(0.3)
	else:  # хил — сразу
		delayed_bar.value = new_value
	
	value = new_value

####CORUPTION CURSE
	if curse > 1:
		if curse_tween:
			curse_tween.kill()
		curse_tween = create_tween()
		curse_tween.tween_property(curse_bar, "value", curse, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if curse_bar.value >= 70:
			corruption_effect.visible = true
			corruption_effect.emitting = true
		else:
			corruption_effect.visible = false
			corruption_effect.emitting = false

####LIFE BAR HEALTH
	if new_max_value < max_value:
		max_value = new_max_value
	
	value = new_value



func _update_color() -> void:
	var ratio = value / max_value
	if ratio > 0.5:
		modulate = Color.GREEN
	elif ratio > 0.25:
		modulate = Color(1.0, 0.6, 0.0)  # оранжевый
	else:
		modulate = Color.RED


var pulse_tween: Tween

func _pulse_heart(active: bool) -> void:
	if pulse_tween:
		pulse_tween.kill()
	if active:
		pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(heart_icon, "scale", Vector2(1.2, 1.2), 0.3)
		pulse_tween.tween_property(heart_icon, "scale", Vector2(1.0, 1.0), 0.3)
	else:
		heart_icon.scale = Vector2.ONE
