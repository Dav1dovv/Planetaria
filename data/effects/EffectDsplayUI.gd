extends HBoxContainer
class_name EffectDisplayUI
## Панель эффектов игрока (баффы / дебаффы / экипировка) — «статус-лента» под полоской здоровья.
## Сцена: misc/UI/Effects/effect_display.tscn. Заменяет старый узел EffectDisplay в GUI.tscn
## (дай новому узлу то же имя, что было у старого). API прежний: set_entity(), clear_effects().
##
## Принципы: игрок за полсекунды понимает ЧТО это, ХОРОШО ЛИ это и СКОЛЬКО ОСТАЛОСЬ.
##  * рамка: зелёная — бафф, красная — дебафф, серая — «пока экипировано» (второй ряд);
##  * круговая заливка и число секунд; мигание в последние секунды;
##  * наложили эффект — значок «выпрыгивает» и рядом короткая подпись; закончился — тоже подпись;
##  * дебаффы всегда левее баффов; наведи мышь — подсказка с описанием.
##
## ЧТО ГДЕ МЕНЯТЬ (без кода):
##  * размер/цвета значка — сцена effect_slot.tscn (корневой узел, инспектор);
##  * вид подсказки — сцена effect_tooltip.tscn;
##  * какая иконка какому типу эффекта, какие типы считаются дебаффами — настройки ниже;
##  * положение ленты — Follow Health Bar выкл. и перетащить узел, либо оставить под полоской здоровья.

@export_group("Положение")
## Класть ленту под полоску здоровья (узел HealthBar рядом в HUD). Выключи, чтобы двигать вручную.
@export var follow_health_bar: bool = true
@export var gap_below_bar: float = 3.0

@export_group("Сцены")
@export var slot_scene: PackedScene

@export_group("Правила")
## Эффекты этих типов считаются дебаффами (красная рамка, слева).
@export var debuff_types: Array[Effect.EffectType] = []
## Иконки по типу эффекта — используются, если у самого эффекта иконка не задана.
@export var type_icons: Dictionary[int, Texture2D] = {}

@export_group("Подпись о событии")
@export_range(0.5, 8.0, 0.1) var toast_time: float = 2.4
@export var ended_key: String = "%s ended"
@export var color_buff: Color = Color("6fe08a")
@export var color_debuff: Color = Color("e8454f")
@export var color_ended: Color = Color("94a3ab")

@onready var _row_main: HBoxContainer = %RowMain
@onready var _row_passive: HBoxContainer = %RowPassive
@onready var _toast: Label = %Toast

var tracked_entity: Entity

var _slots: Dictionary = {}   # EffectType -> EffectSlot
var _toast_tween: Tween


func _ready() -> void:
	_toast.modulate.a = 0.0
	if follow_health_bar:
		_place.call_deferred()


## Встаём слева-сверху, прямо под полоской здоровья.
func _place() -> void:
	var bar := get_node_or_null("../HealthBar") as Control
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	if bar != null:
		position = Vector2(bar.position.x, bar.position.y + bar.size.y + gap_below_bar)


# ─────────────────────────────────────────────────────────────────────────────
#  Привязка к существу
# ─────────────────────────────────────────────────────────────────────────────
func set_entity(entity: Entity) -> void:
	if tracked_entity and tracked_entity.effect_manager:
		var old := tracked_entity.effect_manager
		if old.effect_added.is_connected(_on_effect_added):
			old.effect_added.disconnect(_on_effect_added)
			old.effect_removed.disconnect(_on_effect_removed)
			old.effect_stacks_changed.disconnect(_on_stacks_changed)
	clear_effects()
	tracked_entity = entity
	if tracked_entity and tracked_entity.effect_manager:
		var manager := tracked_entity.effect_manager
		manager.effect_added.connect(_on_effect_added)
		manager.effect_removed.connect(_on_effect_removed)
		manager.effect_stacks_changed.connect(_on_stacks_changed)
		for active in manager.get_active_effects():
			_add_slot(active.effect, false)  # уже действующие — без анимации появления


func clear_effects() -> void:
	for slot in _slots.values():
		if is_instance_valid(slot):
			slot.queue_free()
	_slots.clear()


func _process(delta: float) -> void:
	if tracked_entity == null or tracked_entity.effect_manager == null or _slots.is_empty():
		return
	for data in tracked_entity.effect_manager.get_active_effects():
		var slot: EffectSlot = _slots.get(data.effect.effect_type)
		if slot != null:
			slot.update_state(data.time_left, data.stacks, delta)


# ─────────────────────────────────────────────────────────────────────────────
#  События менеджера эффектов
# ─────────────────────────────────────────────────────────────────────────────
func _on_effect_added(effect: Effect) -> void:
	if _slots.has(effect.effect_type):
		return
	var slot := _add_slot(effect, true)
	if slot.kind != EffectSlot.Kind.PASSIVE:
		_show_toast(effect, slot.kind, true)


func _on_effect_removed(effect: Effect) -> void:
	var slot: EffectSlot = _slots.get(effect.effect_type)
	if slot == null:
		return
	_slots.erase(effect.effect_type)
	var kind := slot.kind
	slot.dismiss()
	if kind != EffectSlot.Kind.PASSIVE:
		_show_toast(effect, kind, false)


func _on_stacks_changed(effect_type: int, _stacks: int) -> void:
	var slot: EffectSlot = _slots.get(effect_type)
	if slot != null:
		slot.pop(1.3)


func _add_slot(effect: Effect, animate: bool) -> EffectSlot:
	var slot: EffectSlot = slot_scene.instantiate()
	slot.setup(effect, _kind_of(effect), _icon_for(effect))
	_slots[effect.effect_type] = slot
	(_row_passive if slot.kind == EffectSlot.Kind.PASSIVE else _row_main).add_child(slot)
	_resort()
	if animate:
		slot.pop(1.6)
	return slot


func _kind_of(effect: Effect) -> EffectSlot.Kind:
	if effect.duration <= 0.0:
		return EffectSlot.Kind.PASSIVE  # бесконечные эффекты = «пока экипировано»
	return EffectSlot.Kind.DEBUFF if effect.effect_type in debuff_types else EffectSlot.Kind.BUFF


## Дебаффы первыми, потом баффы — самое тревожное всегда слева.
func _resort() -> void:
	var index := 0
	for kind in [EffectSlot.Kind.DEBUFF, EffectSlot.Kind.BUFF]:
		for child in _row_main.get_children():
			if child is EffectSlot and child.kind == kind:
				_row_main.move_child(child, index)
				index += 1


func _icon_for(effect: Effect) -> Texture2D:
	if effect.effect_icon != null:
		return effect.effect_icon
	if effect.icon != null:
		return effect.icon
	return type_icons.get(effect.effect_type)  # null → у слота есть запасной ромб


# ─────────────────────────────────────────────────────────────────────────────
#  Подпись «что произошло»
# ─────────────────────────────────────────────────────────────────────────────
func _show_toast(effect: Effect, kind: EffectSlot.Kind, added: bool) -> void:
	var title := Loc.t(effect.display_name)
	var text: String
	var color: Color
	if added:
		var stat := _stat_line(effect)
		text = ("+ " if kind == EffectSlot.Kind.BUFF else "- ") + title + (": " + stat if not stat.is_empty() else "")
		color = color_buff if kind == EffectSlot.Kind.BUFF else color_debuff
	else:
		text = Loc.t(ended_key) % title
		color = color_ended
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(toast_time)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## Строка «Урон +30%» — из готового тултипа эффекта (он уже локализован).
func _stat_line(effect: Effect) -> String:
	var parts := effect.get_tooltip_text().split("\n\n")
	if parts.size() < 2:
		return ""
	var stat := parts[1].strip_edges().split("\n")[0]
	return stat if stat.length() <= 24 else ""  # длинные описания в подпись не лезут — хватит названия
