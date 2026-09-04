extends Area2D

const MOUSE_Arrow    = preload("res://Assets/Textures/UI/Cursors/Cursor1.png")
const MOUSE_Interact = preload("res://Assets/Textures/UI/Cursors/Cursor5.png")
const MOUSE_Shot     = preload("res://Assets/Textures/UI/Cursors/Cursor2.png")
const MOUSE_Attack   = preload("res://Assets/Textures/UI/Cursors/Cursor3.png")
const MOUSE_Gather   = preload("res://Assets/Textures/UI/Cursors/Cursor4.png")

# TODO: добавить текстуры для новых состояний курсора:
# const MOUSE_Gather_Corrupted_Weak   = preload("res://Assets/Textures/UI/Cursors/Cursor_GatherCorruptWeak.png")
# const MOUSE_Gather_Corrupted_Strong = preload("res://Assets/Textures/UI/Cursors/Cursor_GatherCorruptStrong.png")
# const MOUSE_Gather_Wrong_Tier       = preload("res://Assets/Textures/UI/Cursors/Cursor_GatherWrongTier.png")
# const MOUSE_Gather_Out_of_Range     = preload("res://Assets/Textures/UI/Cursors/Cursor_GatherOutOfRange.png")
# const MOUSE_Deflect                 = preload("res://Assets/Textures/UI/Cursors/Cursor_Deflect.png")
# Пока используем существующие с разным modulate

@export var help_label : Label

## Максимальное расстояние от игрока до объекта для добычи (в пикселях)
## 2 тайла × 16px = 32px. Если тайл другого размера — поменяй.
@export var harvest_range: float = 48.0

@onready var hint: Sprite2D = $Hint

var _player: Node = null
var _hotbar: Node = null
var _current_state: String = "simple"

# Отслеживаем что сейчас под курсором
var _overlapping_harvestable: Harvest_item = null
var _overlapping_enemy: bool = false
var _overlapping_interaction: Area2D = null
var _overlapping_curse: bool = false


func _init() -> void:
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(9, true)
	set_collision_mask_value(8, true)   # interaction (было)
	set_collision_mask_value(2, true)   # Harvestable layer — НОВОЕ
	set_collision_mask_value(6, true)   # Enemy HurtBox layer — НОВОЕ (проверь слой)


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("Player")
	_hotbar = get_tree().get_first_node_in_group("Hotbar")

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()
	_update_cursor_state()


## Единая точка входа для ПКМ-взаимодействия.
## Только курсор знает, какой именно объект сейчас под ним
## (_overlapping_interaction) — поэтому вызов идёт отсюда,
## а не из _input() каждого отдельного interaction_area.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("RMB"):
		if _overlapping_interaction != null and _overlapping_interaction.has_method("try_interact"):
			_overlapping_interaction.try_interact()


# ─── Обновление состояния ──────────────────────────────────────────────────────

func _update_cursor_state() -> void:
	var new_state: String = _determine_state()
	if new_state != _current_state:
		_current_state = new_state
		_apply_cursor_state(new_state)


func _determine_state() -> String:
	# 1. CurseObject рядом → deflect
	if _overlapping_curse:
		return "deflect"

	# 2. Враг → fight
	if _overlapping_enemy:
		return "fight"

	# 4. Interaction
	if _overlapping_interaction != null:
		return "interact"

	# 5. Default
	return "simple"


# ─── Применение курсора ────────────────────────────────────────────────────────

func _apply_cursor_state(state: String) -> void:
	match state:
		"simple":
			_set_cursor(MOUSE_Arrow, Color.WHITE)
			_clear_label()

		"fight":
			_set_cursor(MOUSE_Attack, Color.WHITE)
			_clear_label()

		"interact":
			_set_cursor(MOUSE_Interact, Color.WHITE)
			if _overlapping_interaction and _overlapping_interaction.get("show_message"):
				help_label.text = _overlapping_interaction.show_message

		"gather":
			# Кирка — можно добывать
			_set_cursor(MOUSE_Gather, Color.WHITE)
			_clear_label()

		"gather_corrupted_weak":
			# Кирка с тёмным свечением — можно, но получишь заражение
			_set_cursor(MOUSE_Gather, Color(0.8, 0.4, 0.9))
			help_label.text = "Заражённый объект"

		"gather_corrupted_strong":
			# Кирка красная + пульсация — опасно без защиты
			_set_cursor(MOUSE_Gather, Color(1.0, 0.2, 0.2))
			help_label.text = "Сильное заражение — нужна защита!"

		"gather_wrong_tier":
			# Кирка с трещиной — можно, но кирка ломается быстрее + CurseObject
			_set_cursor(MOUSE_Gather, Color(0.5, 0.5, 0.5))
			help_label.text = "Нужна кирка лучше (кирка сломается быстрее)"

		"gather_out_of_range":
			# Кирка полупрозрачная — слишком далеко
			_set_cursor(MOUSE_Gather, Color(1.0, 1.0, 1.0, 0.4))
			_clear_label()

		"deflect":
			# Меч — отбей проклятие!
			_set_cursor(MOUSE_Attack, Color(0.4, 0.0, 0.8))
			help_label.text = "Отбей!"


func _set_cursor(texture: Texture2D, color: Color) -> void:
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(0, 0))
	# Tint hint sprite чтобы показать цвет состояния
	hint.modulate = color


func _clear_label() -> void:
	if help_label:
		help_label.text = ""


# ─── Детекция area_entered / area_exited ──────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Harvestable"):
		_overlapping_harvestable = area as Harvest_item

	elif area.is_in_group("Ennemy"):
		_overlapping_enemy = true

	elif area.is_in_group("CurseObject"):
		_overlapping_curse = true

	elif area.is_in_group("interaction"):
		_overlapping_interaction = area
		if area.get("show_message"):
			help_label.text = area.show_message


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("Harvestable"):
		if _overlapping_harvestable == area:
			_overlapping_harvestable = null

	elif area.is_in_group("Ennemy"):
		_overlapping_enemy = false

	elif area.is_in_group("CurseObject"):
		_overlapping_curse = false

	elif area.is_in_group("interaction"):
		_overlapping_interaction = null
		_clear_label()

	hint.visible = false


# ─── Совместимость со старым API ──────────────────────────────────────────────

func Help_hint(Help_Texture) -> void:
	hint.visible = true
	hint.texture = Help_Texture


func change_curosr(type: String) -> void:
	match type:
		"interact":
			_apply_cursor_state("interact")
		"gather":
			_apply_cursor_state("gather")
		"fight":
			_apply_cursor_state("fight")
		"simple":
			_apply_cursor_state("simple")


func detection_mode(mode: bool) -> void:
	$CollisionShape2D.disabled = mode
	if mode:
		_apply_cursor_state("simple")
