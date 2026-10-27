extends Control
class_name EffectSlot
## Один значок эффекта в ленте (сцена effect_slot.tscn).
## Рамка по смыслу: бафф / дебафф / экипировка. Круговая заливка = прошедшее время,
## мигание в последние секунды, «выпрыгивание» при событиях, подсказка по наведению.
## Размер значка, цвета, пороги — в инспекторе. Подсказка — сцена effect_tooltip.tscn.

enum Kind { BUFF, DEBUFF, PASSIVE }

@export_group("Размер")
## Целый множитель пикселей иконки 16×16 (1 = 16px, 2 = 32px…).
@export_range(1, 6) var icon_scale: int = 1
## Воздух между иконкой и рамкой (в «пикселях иконки»).
@export_range(0, 4) var padding: int = 2
@export var font_size: int = 6

@export_group("Цвета")
@export var color_buff: Color = Color("6fe08a")
@export var color_debuff: Color = Color("e8454f")
@export var color_passive: Color = Color("6b7388")
@export var color_back: Color = Color(0.09, 0.1, 0.14, 0.9)
@export var color_pie: Color = Color(0, 0, 0, 0.55)
@export var color_warning: Color = Color("ffc857")
@export var color_stack_text: Color = Color("ffc857")

@export_group("Поведение")
## За сколько секунд до конца значок начинает мигать.
@export_range(0.0, 10.0, 0.5) var warn_time: float = 3.0
## Прозрачность значка «экипировано».
@export_range(0.2, 1.0, 0.05) var passive_alpha: float = 0.85
## Сцена подсказки при наведении мыши.
@export var tooltip_scene: PackedScene

var effect: Effect
var kind: Kind = Kind.BUFF

var _tex: Texture2D
var _time_left: float = 0.0
var _duration: float = 0.0
var _stacks: int = 1
var _age: float = 0.0
var _last_tick: int = 0
var _flash: float = 0.0
var _dismissing: bool = false


## Вызывается сразу после создания слота.
func setup(e: Effect, k: Kind, tex: Texture2D) -> void:
	effect = e
	kind = k
	_tex = tex
	_duration = e.duration
	_time_left = e.duration
	var side := float((16 + padding * 2) * icon_scale)
	custom_minimum_size = Vector2(side, side)
	if kind == Kind.PASSIVE:
		modulate.a = passive_alpha


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS  # чтобы работала подсказка по наведению
	tooltip_text = " "                        # содержимое строит _make_custom_tooltip


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func update_state(time_left: float, stacks: int, delta: float) -> void:
	if _duration > 0.0 and time_left > _time_left + 0.05:
		pop(1.25)  # эффект обновили — кивок иконкой
	_time_left = time_left
	_stacks = stacks
	_age += delta
	# Дебафф-урон тикает: короткий пульс в такт тику
	if kind == Kind.DEBUFF and effect.tick_interval > 0.0:
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
	if not _dismissing and _duration > 0.0 and _time_left > 0.0 and _time_left <= warn_time:
		modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 1000.0 * 9.0))
	elif not _dismissing:
		modulate.a = passive_alpha if kind == Kind.PASSIVE else 1.0
	queue_redraw()


func get_kind_color() -> Color:
	match kind:
		Kind.DEBUFF: return color_debuff
		Kind.BUFF: return color_buff
	return color_passive


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var border := get_kind_color()
	draw_rect(rect, color_back)

	var icon_size := Vector2(16.0, 16.0) * icon_scale
	var origin := ((size - icon_size) * 0.5).round()
	if _tex != null:
		draw_texture_rect(_tex, Rect2(origin, icon_size), false)
	else:  # нет иконки — ромб цвета частиц эффекта
		var c := size * 0.5
		var r := icon_size.x * 0.4
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]),
				effect.particle_color)

	# Радиальная заливка прошедшего времени: сектор растёт по часовой от 12 часов
	if kind != Kind.PASSIVE and _duration > 0.0:
		var elapsed := clampf(1.0 - _time_left / _duration, 0.0, 1.0)
		if elapsed > 0.002:
			_draw_pie(rect, elapsed)

	var width := maxf(1.0, float(icon_scale))
	draw_rect(rect.grow(-width * 0.5), border, false, width)
	if _flash > 0.0:
		draw_rect(rect, Color(1, 1, 1, 0.55 * _flash))

	var font := get_theme_default_font()
	# Время внизу по центру (у экипировки времени нет)
	if kind != Kind.PASSIVE and _time_left > 0.0:
		var label := "%dm" % int(_time_left / 60.0) if _time_left >= 60.0 else str(ceili(_time_left))
		var label_color := color_warning if _time_left <= warn_time else Color.WHITE
		var pos := Vector2(0.0, size.y - width * 1.5)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color.BLACK)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, label_color)

	# Счётчик стаков вверху справа
	if _stacks > 1:
		var txt := "x%d" % _stacks
		var spos := Vector2(0.0, font_size + width)
		draw_string_outline(font, spos, txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - width * 1.5, font_size, 4, Color.BLACK)
		draw_string(font, spos, txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - width * 1.5, font_size, color_stack_text)


func _draw_pie(rect: Rect2, fraction: float) -> void:
	var c := rect.get_center()
	var half := rect.size * 0.5
	var steps := maxi(6, int(fraction * 64.0))
	var pts := PackedVector2Array([c])
	for i in steps + 1:
		var a := -PI * 0.5 + TAU * fraction * float(i) / float(steps)
		var dir := Vector2(cos(a), sin(a))
		var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		pts.append(c + dir * t)
	draw_colored_polygon(pts, color_pie)


func _make_custom_tooltip(_for_text: String) -> Object:
	if tooltip_scene == null:
		return null
	var tip: EffectTooltip = tooltip_scene.instantiate()
	tip.setup(effect, kind, _time_left)
	return tip
