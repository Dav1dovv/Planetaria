extends HBoxContainer
class_name EffectDisplayUI
## Панель эффектов игрока (баффы / дебаффы / экипировка) — «статус-лента» под полоской здоровья.
##
## Принципы дизайна: игрок должен понять за полсекунды ЧТО это, ХОРОШО ЛИ это и СКОЛЬКО ОСТАЛОСЬ.
##  * Рамка по смыслу: зелёная — бафф, красная — дебафф (читается без иконки и без чтения текста),
##    приглушённая — «пока экипировано» (реликвии, аксессуары), они мельче и во втором ряду.
##  * Радиальная «заливка» по кругу показывает остаток времени, число под иконкой — секунды.
##  * Последние 3 секунды иконка мигает и тикает цифрой — «сейчас пропадёт».
##  * Событие = отклик: эффект наложили — иконка «выпрыгивает» со вспышкой, а рядом короткая подпись
##    («+ Ярость: Урон +30%»); стак вырос или эффект обновили — снова отклик; дебафф-урон тикает пульсом.
##  * Дебаффы всегда слева (первыми бросаются в глаза), потом баффы, потом экипировка.
##  * Наведи мышь — стилизованная подсказка с названием, описанием и оставшимся временем.
##
## API прежний: set_entity(entity), clear_effects(). player.gd и GUI.tscn менять не нужно.

enum Kind { BUFF, DEBUFF, PASSIVE }

const DEBUFF_TYPES := [
	Effect.EffectType.POISON, Effect.EffectType.BURN, Effect.EffectType.FREEZE,
	Effect.EffectType.BLEED, Effect.EffectType.CORRUPTION, Effect.EffectType.SLOW,
	Effect.EffectType.PANIC,
]

## Иконки по умолчанию, если у Effect не задан effect_icon (номер файла EffectN.png).
const TYPE_ICON := {
	Effect.EffectType.SPEED_BOOST: 1, Effect.EffectType.DAMAGE_BOOST: 2,
	Effect.EffectType.REGENERATION: 3, Effect.EffectType.DEFENSE_BOOST: 4,
	Effect.EffectType.INVISIBILITY: 5, Effect.EffectType.POISON: 6,
	Effect.EffectType.BURN: 7, Effect.EffectType.FREEZE: 8,
	Effect.EffectType.HEALTH_RESTORE: 9, Effect.EffectType.SLOW: 10,
	Effect.EffectType.BLEED: 11, Effect.EffectType.CORRUPTION: 12,
}
const ICON_PATH := "res://Assets/Textures/UI/Effects/Effect%d.png"

const WARN_TIME := 3.0    ## за сколько секунд до конца иконка начинает мигать
const TOAST_TIME := 2.4   ## сколько висит подпись о новом эффекте

## Класть панель под полоску здоровья (HUD/HealthBar). Выключи, если хочешь двигать узел вручную в сцене.
@export var follow_health_bar: bool = true
## Размер панели: 1.0 по умолчанию.
@export_range(0.5, 2.0, 0.1) var ui_scale: float = 1.0

var tracked_entity: Entity

var _slots: Dictionary = {}       # EffectType -> _Slot
var _stack: VBoxContainer
var _row_main: HBoxContainer      # баффы и дебаффы
var _row_passive: HBoxContainer   # экипировка (бесконечные эффекты)
var _toast: Label
var _toast_tween: Tween
var _h: float = 360.0
static var _icon_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_h = get_viewport().get_visible_rect().size.y
	_build()
	if follow_health_bar:
		_place.call_deferred()


func _build() -> void:
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", maxi(1, roundi(_h * 0.006 * ui_scale)))
	add_child(_stack)
	_row_main = _make_row()
	_row_passive = _make_row()
	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_size_override("font_size", maxi(6, roundi(_h * 0.026 * ui_scale)))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.modulate.a = 0.0
	_stack.add_child(_row_main)
	_stack.add_child(_row_passive)
	_stack.add_child(_toast)


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", maxi(1, roundi(_h * 0.006 * ui_scale)))
	return row


## Встаём слева-сверху, прямо под полоской здоровья.
func _place() -> void:
	var bar := get_node_or_null("../HealthBar") as Control
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	var gap := _h * 0.012
	if bar != null:
		position = Vector2(bar.position.x, bar.position.y + bar.size.y + gap)
	else:
		position = Vector2(_h * 0.02, _h * 0.14)


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
		var slot: _Slot = _slots.get(data.effect.effect_type)
		if slot != null:
			slot.update_state(data.time_left, data.stacks, delta)


# ─────────────────────────────────────────────────────────────────────────────
#  События менеджера эффектов
# ─────────────────────────────────────────────────────────────────────────────
func _on_effect_added(effect: Effect) -> void:
	if _slots.has(effect.effect_type):
		return
	var slot := _add_slot(effect, true)
	if slot.kind != Kind.PASSIVE:
		_show_toast(effect, slot.kind, true)


func _on_effect_removed(effect: Effect) -> void:
	var slot: _Slot = _slots.get(effect.effect_type)
	if slot == null:
		return
	_slots.erase(effect.effect_type)
	var kind := slot.kind
	slot.dismiss()
	if kind != Kind.PASSIVE:
		_show_toast(effect, kind, false)


func _on_stacks_changed(effect_type: int, _stacks: int) -> void:
	var slot: _Slot = _slots.get(effect_type)
	if slot != null:
		slot.pop(1.3)


func _add_slot(effect: Effect, animate: bool) -> _Slot:
	var kind := _kind_of(effect)
	var scale_k := maxi(1, roundi(_h * 0.045 * ui_scale / 16.0))
	if kind == Kind.PASSIVE and scale_k >= 3:
		scale_k -= 1  # на больших экранах экипировка мельче: она фон, а не событие
	var slot := _Slot.new(effect, kind, scale_k, _icon_for(effect))
	_slots[effect.effect_type] = slot
	(_row_passive if kind == Kind.PASSIVE else _row_main).add_child(slot)
	_resort()
	if animate:
		slot.pop(1.6)
	return slot


func _kind_of(effect: Effect) -> Kind:
	if effect.duration <= 0.0:
		return Kind.PASSIVE  # бесконечные эффекты = «пока экипировано»
	return Kind.DEBUFF if effect.effect_type in DEBUFF_TYPES else Kind.BUFF


## Дебаффы первыми, потом баффы — самое тревожное всегда слева.
func _resort() -> void:
	var index := 0
	for kind in [Kind.DEBUFF, Kind.BUFF]:
		for child in _row_main.get_children():
			if child is _Slot and child.kind == kind:
				_row_main.move_child(child, index)
				index += 1


func _icon_for(effect: Effect) -> Texture2D:
	if effect.effect_icon != null:
		return effect.effect_icon
	if effect.icon != null:
		return effect.icon
	var number: int = TYPE_ICON.get(effect.effect_type, 0)
	if number == 0:
		return null  # у слота есть запасной значок: цветной ромб с буквой
	var path := ICON_PATH % number
	if not _icon_cache.has(path):
		_icon_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[path]


# ─────────────────────────────────────────────────────────────────────────────
#  Подпись «что произошло»
# ─────────────────────────────────────────────────────────────────────────────
func _show_toast(effect: Effect, kind: Kind, added: bool) -> void:
	var title := Loc.t(effect.display_name)
	var text: String
	if not added:
		text = Loc.t("%s ended") % title
	else:
		var stat := _stat_line(effect)
		text = ("+ " if kind == Kind.BUFF else "- ") + title + (": " + stat if not stat.is_empty() else "")
	_toast.text = text
	var color := TerminalStyle.GREEN if kind == Kind.BUFF else TerminalStyle.RED
	if not added:
		color = TerminalStyle.GREY.lightened(0.35)
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## Строка «Урон +30%» — из готового тултипа эффекта (он уже локализован).
func _stat_line(effect: Effect) -> String:
	var parts := effect.get_tooltip_text().split("\n\n")
	if parts.size() < 2:
		return ""
	var stat := parts[1].strip_edges().split("\n")[0]
	return stat if stat.length() <= 24 else ""  # длинные описания в подпись не лезут — хватит названия


# ═════════════════════════════════════════════════════════════════════════════
#  Слот одного эффекта
# ═════════════════════════════════════════════════════════════════════════════
class _Slot extends Control:
	var effect: Effect
	var kind: int = 0
	var _tex: Texture2D
	var _k: int = 2                # целый масштаб пикселей иконки
	var _time_left: float = 0.0
	var _duration: float = 0.0
	var _stacks: int = 1
	var _age: float = 0.0
	var _last_tick: int = 0
	var _flash: float = 0.0
	var _dismissing: bool = false

	func _init(e: Effect, k_kind: int, scale_k: int, tex: Texture2D) -> void:
		effect = e
		kind = k_kind
		_k = scale_k
		_tex = tex
		_duration = e.duration
		_time_left = e.duration
		var side := 16.0 * scale_k + 4.0 * scale_k  # иконка + рамка с воздухом
		custom_minimum_size = Vector2(side, side)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_PASS  # чтобы работала подсказка по наведению
		tooltip_text = " "                        # содержимое строит _make_custom_tooltip
		if kind == EffectDisplayUI.Kind.PASSIVE:
			modulate.a = 0.85

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			pivot_offset = size * 0.5

	func update_state(time_left: float, stacks: int, delta: float) -> void:
		if _duration > 0.0 and time_left > _time_left + 0.05:
			pop(1.25)  # эффект обновили (выпили второе зелье) — кивок иконкой
		_time_left = time_left
		_stacks = stacks
		_age += delta
		# Дебафф-урон тикает: короткий пульс в такт тику
		if kind == EffectDisplayUI.Kind.DEBUFF and effect.tick_interval > 0.0:
			var n := int(_age / maxf(effect.tick_interval, 0.1))
			if n > _last_tick:
				_last_tick = n
				pop(1.15)

	## «Выпрыгивание» иконки со вспышкой.
	func pop(strength: float = 1.4) -> void:
		if _dismissing:
			return
		pivot_offset = size * 0.5
		_flash = 1.0
		scale = Vector2.ONE * strength
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.24) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func dismiss() -> void:
		_dismissing = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2.ONE * 0.4, 0.18)
		tw.tween_property(self, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(queue_free)

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 3.5)
		if not _dismissing and _duration > 0.0 and _time_left > 0.0 and _time_left <= EffectDisplayUI.WARN_TIME:
			modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 1000.0 * 9.0))
		elif not _dismissing:
			modulate.a = 0.85 if kind == EffectDisplayUI.Kind.PASSIVE else 1.0
		queue_redraw()

	func _color() -> Color:
		match kind:
			EffectDisplayUI.Kind.DEBUFF: return TerminalStyle.RED
			EffectDisplayUI.Kind.BUFF: return TerminalStyle.GREEN
		return TerminalStyle.STEEL

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var border := _color()
		draw_rect(rect, Color(TerminalStyle.METAL_DARK, 0.9))

		# Иконка (целым масштабом — пиксели остаются чёткими)
		var icon_size := Vector2(16.0, 16.0) * _k
		var origin := ((size - icon_size) * 0.5).round()
		if _tex != null:
			draw_texture_rect(_tex, Rect2(origin, icon_size), false)
		else:
			var c := size * 0.5
			var r := icon_size.x * 0.4
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]),
					effect.particle_color)

		# Радиальная заливка прошедшего времени: сектор растёт по часовой от 12 часов
		if kind != EffectDisplayUI.Kind.PASSIVE and _duration > 0.0:
			var elapsed := clampf(1.0 - _time_left / _duration, 0.0, 1.0)
			if elapsed > 0.002:
				_draw_pie(rect, elapsed, Color(0, 0, 0, 0.55))

		# Рамка и вспышка
		var width := maxf(1.0, float(_k))
		draw_rect(rect.grow(-width * 0.5), border, false, width)
		if _flash > 0.0:
			draw_rect(rect, Color(1, 1, 1, 0.55 * _flash))

		var font := get_theme_default_font()
		var fs := maxi(6, roundi(size.x * 0.3))

		# Время (внизу по центру). У экипировки — знак «∞»
		var label := ""
		var label_color := Color.WHITE
		if kind == EffectDisplayUI.Kind.PASSIVE:
			label = ""
		elif _time_left > 0.0:
			label = "%dm" % int(_time_left / 60.0) if _time_left >= 60.0 else str(ceili(_time_left))
			if _time_left <= EffectDisplayUI.WARN_TIME:
				label_color = TerminalStyle.AMBER
		if not label.is_empty():
			var pos := Vector2(0.0, size.y - width * 1.5)
			draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 4, Color.BLACK)
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, label_color)

		# Счётчик стаков (вверху справа)
		if _stacks > 1:
			var txt := "x%d" % _stacks
			var spos := Vector2(0.0, fs + width)
			draw_string_outline(font, spos, txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - width * 1.5, fs, 4, Color.BLACK)
			draw_string(font, spos, txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - width * 1.5, fs, TerminalStyle.AMBER)

	func _draw_pie(rect: Rect2, fraction: float, color: Color) -> void:
		var c := rect.get_center()
		var half := rect.size * 0.5
		var steps := maxi(6, int(fraction * 64.0))
		var pts := PackedVector2Array([c])
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * fraction * float(i) / float(steps)
			var dir := Vector2(cos(a), sin(a))
			# луч от центра до границы квадрата — чтобы сектор не вылезал за рамку
			var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
			pts.append(c + dir * t)
		draw_colored_polygon(pts, color)

	## Подсказка в стиле корабельных терминалов.
	func _make_custom_tooltip(_for_text: String) -> Object:
		var h := get_viewport().get_visible_rect().size.y
		var panel := PanelContainer.new()
		var style := TerminalStyle.screen_style(h, _color())
		style.set_content_margin_all(h * 0.012)
		panel.add_theme_stylebox_override("panel", style)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", int(h * 0.006))
		panel.add_child(box)

		var tag := Loc.t("BUFF")
		if kind == EffectDisplayUI.Kind.DEBUFF:
			tag = Loc.t("DEBUFF")
		elif kind == EffectDisplayUI.Kind.PASSIVE:
			tag = Loc.t("EQUIPPED")

		# «Длительность» убираем: ниже живой счётчик «осталось»
		var duration_line := (Loc.t("\nДлительность: %.1f сек") % effect.duration).strip_edges()
		var lines: PackedStringArray = []
		for line in effect.get_tooltip_text().split("\n"):
			if line.strip_edges() != duration_line:
				lines.append(line)
		var title := Label.new()
		title.text = "%s  [%s]" % [lines[0], tag]
		title.add_theme_font_size_override("font_size", maxi(7, roundi(h * 0.028)))
		title.add_theme_color_override("font_color", _color())
		box.add_child(title)

		var body := Label.new()
		body.text = "\n".join(lines.slice(1)).strip_edges()
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(h * 0.4, 0.0)
		body.add_theme_font_size_override("font_size", maxi(6, roundi(h * 0.024)))
		body.add_theme_color_override("font_color", TerminalStyle.TEXT)
		box.add_child(body)

		if kind != EffectDisplayUI.Kind.PASSIVE and _time_left > 0.0:
			var left := Label.new()
			left.text = Loc.t("Time left: %d s") % ceili(_time_left)
			left.add_theme_font_size_override("font_size", maxi(6, roundi(h * 0.024)))
			left.add_theme_color_override("font_color", TerminalStyle.AMBER)
			box.add_child(left)
		return panel
