extends HBoxContainer
class_name EffectDisplayUI

# Префаб для отображения одного эффекта
const EFFECT_ICON_SCENE = preload("res://scr/Resources/effects/EffectIcon.tscn")  # Создайте этот файл

# Ссылка на entity
var tracked_entity: Entity

# Словарь отображаемых иконок {effect_type: Control}
var effect_icons: Dictionary = {}

func _ready():
	set_process(true)

# Установить отслеживаемую сущность
func set_entity(entity: Entity) -> void:
	if tracked_entity and tracked_entity.effect_manager:
		tracked_entity.effect_manager.effect_added.disconnect(_on_effect_added)
		tracked_entity.effect_manager.effect_removed.disconnect(_on_effect_removed)
	
	tracked_entity = entity
	
	if tracked_entity and tracked_entity.effect_manager:
		tracked_entity.effect_manager.effect_added.connect(_on_effect_added)
		tracked_entity.effect_manager.effect_removed.connect(_on_effect_removed)
		
		# Добавляем существующие эффекты
		for active_effect in tracked_entity.effect_manager.get_active_effects():
			_on_effect_added(active_effect.effect)

func _process(delta: float):
	if not tracked_entity or not tracked_entity.effect_manager:
		return
	
	# Обновляем таймеры на иконках
	for effect_type in effect_icons.keys():
		var icon = effect_icons[effect_type]
		var time_left = tracked_entity.effect_manager.get_effect_time_remaining(effect_type)
		
		if icon.has_node("Timer"):
			var timer_label = icon.get_node("Timer")
			if time_left > 0:
				timer_label.text = str(ceil(time_left))
			else:
				timer_label.text = ""

func _on_effect_added(effect: Effect) -> void:
	if effect_icons.has(effect.effect_type):
		return  # Иконка уже есть
	
	var icon = _create_effect_icon(effect)
	add_child(icon)
	effect_icons[effect.effect_type] = icon

func _on_effect_removed(effect: Effect) -> void:
	if not effect_icons.has(effect.effect_type):
		return
	
	var icon = effect_icons[effect.effect_type]
	icon.queue_free()
	effect_icons.erase(effect.effect_type)

func _create_effect_icon(effect: Effect) -> Control:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(48, 48)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	container.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Иконка эффекта
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(32, 32)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if effect.effect_icon:
		texture_rect.texture = effect.effect_icon
	elif effect.icon:
		texture_rect.texture = effect.icon
	else:
		# Создаём цветной квадрат если нет иконки
		var color_rect = ColorRect.new()
		color_rect.color = effect.particle_color
		color_rect.custom_minimum_size = Vector2(32, 32)
		vbox.add_child(color_rect)
	
	if texture_rect.texture:
		vbox.add_child(texture_rect)
	
	# Таймер
	var timer_label = Label.new()
	timer_label.name = "Timer"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(timer_label)
	
	# Тултип
	container.tooltip_text = effect.get_tooltip_text()
	
	# Анимация появления
	container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	
	return container

# Очистить все иконки
func clear_effects() -> void:
	for icon in effect_icons.values():
		icon.queue_free()
	effect_icons.clear()
