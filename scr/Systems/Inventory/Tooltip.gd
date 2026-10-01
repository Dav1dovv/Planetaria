extends Control

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBoxContainer/Name
@onready var desc_label: AutoSizeRichTextLabel = $Panel/VBoxContainer/Description

# ─────────────────────────────────────────────────────────────────────────
#  Позиционирование тултипа
# ─────────────────────────────────────────────────────────────────────────
@export var mouse_offset: Vector2 = Vector2(20, 20)   # смещение от курсора
@export var edge_margin: float = 12.0                  # отступ от края экрана
@export var follow_speed: float = 22.0                  # скорость "довода" при флипе (чем больше — тем резче)

var _position_initialized: bool = false

# ─────────────────────────────────────────────────────────────────────────
#  Цвета редкости (индекс = item.quality)
#  0 Обычный  1 Редкий  2 Магический  3 Мифический  4 Эпический  5 Легендарный
# ─────────────────────────────────────────────────────────────────────────
const RARITY_NAMES: Array[String] = [
	"Обычный", "Редкий", "Магический", "Мифический", "Эпический", "Легендарный"
]
const RARITY_COLORS: Array[String] = [
	"#9e9e9e", # Обычный    — серый
	"#5cc2ff", # Редкий     — голубой
	"#9b6bff", # Магический — фиолетовый
	"#ff5ca0", # Мифический — малиновый
	"#ff9d3c", # Эпический  — оранжевый
	"#ffd24c", # Легендарный — золотой
]

# ─── Цвета характеристик ───
const COLOR_LABEL           := "#7d7d7d"  # приглушённый цвет подписи ("Урон:", "Защита:")
const COLOR_DESC            := "#a8a8a8"  # цвет основного текста описания
const COLOR_DAMAGE          := "#ff6b6b"
const COLOR_DEFENSE         := "#5cc2ff"
const COLOR_LEVEL           := "#e0e0e0"
const COLOR_FOOD            := "#ffb55c"
const COLOR_DURABILITY_HIGH := "#6bdc6b"
const COLOR_DURABILITY_MID  := "#e6c93c"
const COLOR_DURABILITY_LOW  := "#ff5c5c"


func _ready() -> void:
	hide_tooltip()


func _notification(what: int) -> void:
	# Кто бы ни включил видимость (InventorySlot через hover, или show_tooltip()) —
	# при появлении тултип должен сразу "прыгнуть" к курсору, без подъезда издалека.
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_position_initialized = false


func _process(delta: float) -> void:
	if not visible:
		return
	var target := _calculate_target_position()
	if not _position_initialized:
		panel.global_position = target
		_position_initialized = true
	else:
		panel.global_position = panel.global_position.lerp(target, clamp(delta * follow_speed, 0.0, 1.0))


## Показать тултип с данными предмета
## amount — актуальное количество в слоте (item.count для этого не подходит,
## это поле ресурса и не отражает размер стака в слоте)
func set_data(item: ItemData, amount: int = 1) -> void:
	if not item:
		hide_tooltip()
		return

	name_label.text = item.item_name
	if amount > 1:
		name_label.text += " (x" + str(amount) + ")"
	name_label.add_theme_color_override("font_color", _rarity_color(item.quality))

	var bb := _format_rarity_tag(item.quality) + "\n"

	if item.description and item.description != "":
		bb += "[color=%s]%s[/color]\n" % [COLOR_DESC, item.description]

	bb += "\n"

	if item is equip_data:
		bb += _stat_line("DMG", str(item.Damage), COLOR_DAMAGE)
		bb += _stat_line("LVL", str(item.lvl), COLOR_LEVEL)
		if item.max_durability > 0:
			bb += _durability_line(item.get_durability(), item.max_durability)
	elif item is FoodData:
		bb += _stat_line("Restore", "%d" % item.health_restore, COLOR_FOOD)

	desc_label.text = bb
	# Видимость НЕ трогаем здесь — её включает/выключает InventorySlot
	# на mouse_entered / mouse_exited. set_data только обновляет контент.


func show_tooltip(item_name: String, text: String) -> void:
	name_label.text = item_name
	name_label.remove_theme_color_override("font_color")
	desc_label.text = text
	visible = true


func hide_tooltip() -> void:
	visible = false


func clear() -> void:
	hide_tooltip()


# ─────────────────────────────────────────────────────────────────────────
#  Внутреннее
# ─────────────────────────────────────────────────────────────────────────

func _rarity_color(quality: int) -> Color:
	var q: int = clamp(quality, 0, RARITY_COLORS.size() - 1)
	return Color(RARITY_COLORS[q])


func _format_rarity_tag(quality: int) -> String:
	var q: int = clamp(quality, 0, RARITY_NAMES.size() - 1)
	var rarity_name: String = RARITY_NAMES[q]
	var color: String = RARITY_COLORS[q]
	if q == RARITY_NAMES.size() - 1:
		# Легендарные предметы — лёгкая волна, чтобы притягивать взгляд
		return "[wave amp=14 freq=3][color=%s]%s[/color][/wave]" % [color, rarity_name]
	return "[color=%s]%s[/color]" % [color, rarity_name]


func _stat_line(stat_label: String, value: String, color: String) -> String:
	return "[color=%s]%s:[/color] [color=%s]%s[/color]\n" % [COLOR_LABEL, stat_label, color, value]


func _durability_line(current: int, max_dur: int) -> String:
	var ratio: float = float(current) / float(max_dur) if max_dur > 0 else 0.0
	var color: String = COLOR_DURABILITY_HIGH
	if ratio <= 0.25:
		color = COLOR_DURABILITY_LOW
	elif ratio <= 0.5:
		color = COLOR_DURABILITY_MID
	return _stat_line("Прочность", "%d / %d" % [current, max_dur], color)


func _calculate_target_position() -> Vector2:
	var area_size: Vector2 = get_viewport_rect().size
	var mouse_pos: Vector2 = get_global_mouse_position()
	var box_size: Vector2 = panel.size

	# Горизонталь: если справа не хватает места — показываем тултип слева от курсора
	var target_x: float = mouse_pos.x + mouse_offset.x
	if target_x + box_size.x + edge_margin > area_size.x:
		target_x = mouse_pos.x - mouse_offset.x - box_size.x
	target_x = clamp(target_x, edge_margin, max(edge_margin, area_size.x - box_size.x - edge_margin))

	# Вертикаль: если снизу не хватает места — показываем тултип над курсором
	var target_y: float = mouse_pos.y + mouse_offset.y
	if target_y + box_size.y + edge_margin > area_size.y:
		target_y = mouse_pos.y - mouse_offset.y - box_size.y
	target_y = clamp(target_y, edge_margin, max(edge_margin, area_size.y - box_size.y - edge_margin))

	return Vector2(target_x, target_y)
