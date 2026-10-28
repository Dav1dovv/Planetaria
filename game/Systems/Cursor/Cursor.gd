extends Area2D

const MOUSE_Arrow    = preload("uid://bnmn8d5xrh1wr")
const MOUSE_Interact = preload("uid://2jtukj2d1js0")
const MOUSE_Shot     = preload("uid://h0bnf6q0joqn")
const MOUSE_Attack   = preload("uid://bkixmavj6n51q")
const MOUSE_Gather   = preload("uid://lw5xb5cynpia")

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

@export_group("Подсветка интерактивных объектов")
## Объект под курсором, до которого игрок достаёт, мягко «дышит» — это и есть подсказка «со мной можно»
@export var highlight_enabled: bool = true
@export_range(0.0, 0.8, 0.01) var highlight_strength: float = 0.25
@export_range(0.0, 20.0, 0.5) var highlight_pulse_speed: float = 6.0

@export_group("Совместимость")
## Старое управление: взаимодействие по ПКМ. По GDD взаимодействие — ЛКМ (RT), поэтому выключено.
@export var legacy_rmb_interact: bool = false

@onready var hint: Sprite2D = $Hint
## Круг заполнения при удержании (Interaction.hold_to_interact). Положение и вид правятся в cursor.tscn
@onready var hold_ring: HoldRing = $HoldRing

var _player: Node = null
var _hotbar: Node = null
var _current_state: String = "simple"

# Отслеживаем что сейчас под курсором
var _overlapping_harvestable: Harvest_item = null
var _overlapping_enemy: bool = false
var _overlapping_interaction: Area2D = null
var _overlapping_curse: bool = false

## Сколько раз игрок взаимодействовал с объектом (для обучения: «шаг выполнен»)
var interact_count: int = 0

var _highlighted: CanvasItem = null
var _highlight_base: Color = Color.WHITE
var _highlight_time: float = 0.0


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


func _process(delta: float) -> void:
	# Мышь или виртуальный прицел геймпада — решает GamepadAim
	global_position = GamepadAim.aim_world()
	_update_cursor_state()
	_update_highlight(delta)


## Единая точка входа для взаимодействия — вызывается из PlayerCombat на ЛКМ (RT).
## Только курсор знает, какой именно объект сейчас под ним (_overlapping_interaction),
## поэтому вызов идёт отсюда, а не из _input() каждого отдельного interaction_area.
##
## Возвращает true, если клик «потрачен» на взаимодействие — тогда удар не наносится.
## Враг или проклятие под курсором важнее объекта: бой не должен ломаться
## из-за NPC, случайно оказавшегося рядом.
func try_interact_primary() -> bool:
	if DialogueLock.is_locked() or Global.is_opened_menu:
		return false
	if _overlapping_enemy or _overlapping_curse:
		return false
	var target := _overlapping_interaction
	if target == null or not is_instance_valid(target) or not target.has_method("try_interact"):
		return false
	target.try_interact()
	# Объекты с удержанием засчитываются, когда круг заполнился (см. Interaction._complete_hold)
	if not target.get("hold_to_interact"):
		interact_count += 1
	return true


## Объект с зоной взаимодействия, который сейчас под курсором (или null).
func get_hovered_interaction() -> Area2D:
	if _overlapping_interaction != null and is_instance_valid(_overlapping_interaction):
		return _overlapping_interaction
	return null


## Interaction вызывает каждый кадр удержания: ratio 0..1.
func hold_progress(ratio: float) -> void:
	hold_ring.set_progress(ratio)


## Удержание закончилось: completed = круг заполнился, иначе — прервано.
func hold_end(completed: bool) -> void:
	hold_ring.finish(completed)


## Текущее состояние курсора: simple / fight / interact / deflect ... (для перекрестия геймпада)
func get_state() -> String:
	return _current_state


## Запасной вход для старого ПКМ-управления (выключен по умолчанию).
func _unhandled_input(event: InputEvent) -> void:
	if legacy_rmb_interact and event.is_action_released("RMB"):
		try_interact_primary()


# ─── Подсветка ────────────────────────────────────────────────────────────────

## Подсвечиваем только то, что игрок реально может сейчас использовать:
## объект под курсором + игрок в зоне досягаемости + нет диалога и врага под курсором.
func _update_highlight(delta: float) -> void:
	var wanted: CanvasItem = null
	if highlight_enabled and not DialogueLock.is_locked() and not _overlapping_enemy and not _overlapping_curse \
			and _overlapping_interaction != null and is_instance_valid(_overlapping_interaction) \
			and _overlapping_interaction.get("highlight") \
			and _overlapping_interaction.has_method("is_in_range") and _overlapping_interaction.is_in_range():
		wanted = _overlapping_interaction.get("highlight_target") as CanvasItem
		if wanted == null:
			wanted = _overlapping_interaction.get_parent() as CanvasItem

	if wanted != _highlighted:
		_clear_highlight()
		if wanted != null:
			_highlighted = wanted
			_highlight_base = wanted.modulate
			_highlight_time = 0.0

	if _highlighted != null:
		if not is_instance_valid(_highlighted):
			_highlighted = null
			return
		_highlight_time += delta * highlight_pulse_speed
		var k := 1.0 + highlight_strength * (0.6 + 0.4 * sin(_highlight_time))
		_highlighted.modulate = Color(_highlight_base.r * k, _highlight_base.g * k, _highlight_base.b * k, _highlight_base.a)


func _clear_highlight() -> void:
	if _highlighted != null and is_instance_valid(_highlighted):
		_highlighted.modulate = _highlight_base
	_highlighted = null


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
		hold_ring.finish(false)
		_clear_highlight()
		_apply_cursor_state("simple")
