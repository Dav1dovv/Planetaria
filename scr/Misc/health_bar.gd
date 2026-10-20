@icon("res://addons/at-icons/mesh/heart.svg")
extends ProgressBar
class_name health_bar
## Полоска жизни игрока. Рисуется целиком кодом (пиксель-арт, целые пиксели), поэтому
## дочерние узлы DelayedBar / CurseBar / HeartIcon больше не нужны — если они есть, скрипт их прячет.
##
## Что видит игрок (принцип «узнаёшь состояние, не читая цифры»):
##  * Сердце слева бьётся: спокойно при полном здоровье, всё чаще и тревожнее при низком.
##  * Получил урон — полоска вздрагивает и коротко вспыхивает, а потерянная часть остаётся
##    бледным «следом» и через долю секунды съедается: видно, СКОЛЬКО именно отняли.
##  * Вылечился — восстановленный кусок вспыхивает зелёным.
##  * Здоровье ≤ 25%: полоска пульсирует, сердце колотится, по краям экрана краснеет виньетка.
##  * Цифры «62/100» показываются в момент изменения и при низком здоровье, а не висят всегда.
##  * Проклятие (порча) — фиолетовая полоска вдоль нижнего края; ≥70% — запускаются частицы.
##  * Засечки на полоске = по 10 HP: сразу видно «сколько это в ударах».
##
## API прежний: update_value(текущее_здоровье, максимум, проклятие). player.gd менять не нужно.

enum NumberMode { AUTO, ALWAYS, NEVER }

@export var show_heart: bool = true
@export var number_mode: NumberMode = NumberMode.AUTO
## Ниже этой доли здоровья включается тревога (пульс, сердцебиение, виньетка).
@export_range(0.05, 0.6, 0.01) var low_hp_threshold: float = 0.25
@export var low_hp_vignette: bool = true
@export var fill_color: Color = Color(0.83, 0.0, 0.065)
@export var trail_color: Color = Color(1.0, 0.86, 0.62)
@export var heal_color: Color = Color(0.55, 1.0, 0.6)
@export var curse_color: Color = Color(0.62, 0.1, 0.72)

# Поля оставлены для совместимости со старым кодом
var max_health: float = 0.0
var health: float = 0.0

const HEART_ROWS: Array[String] = [
	".XX...XX.",
	"XXXX.XXXX",
	"XXXXXXXXX",
	"XXXXXXXXX",
	".XXXXXXX.",
	"..XXXXX..",
	"...XXX...",
	"....X....",
]
const FRAME := Color("12080c")
const BACK := Color("2b0b10")
const NUMBER_TIME := 2.5   ## сколько висят цифры после изменения

var _display: float = 0.0       ## то, что реально нарисовано (догоняет value при лечении)
var _trail: float = 0.0         ## «след» потерянного здоровья
var _trail_hold: float = 0.0
var _heal_from: float = 0.0
var _heal_flash: float = 0.0
var _hit_flash: float = 0.0
var _shake: float = 0.0
var _number_timer: float = 0.0
var _curse_target: float = 0.0
var _curse_display: float = 0.0
var _t: float = 0.0
var _first_update: bool = true
var _vignette: CanvasLayer
var _vignette_rect: TextureRect
var _vignette_alpha: float = 0.0
var _corruption_effect: Node


func _init() -> void:
	show_percentage = false  # встроенный текст ProgressBar раздувает минимальную высоту — он нам не нужен


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # чтобы виньетка корректно гасла на паузе
	show_percentage = false
	# Родную отрисовку ProgressBar отключаем — рисуем сами
	add_theme_stylebox_override("background", StyleBoxEmpty.new())
	add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	for legacy in ["DelayedBar", "CurseBar", "HeartIcon"]:
		var node := get_node_or_null(legacy) as CanvasItem
		if node:
			node.visible = false
	_corruption_effect = get_node_or_null("Corruption Effect")
	if _corruption_effect:
		_corruption_effect.set("emitting", false)
		_corruption_effect.set("visible", false)
	_display = value
	_trail = value
	if low_hp_vignette:
		_build_vignette()


## Красная виньетка по краям экрана: радиальный градиент, без шейдеров.
func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.7, 0.0, 0.03, 0.0), Color(0.75, 0.0, 0.04, 0.7)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 128
	tex.height = 128
	_vignette = CanvasLayer.new()
	_vignette.layer = 48
	_vignette.visible = false
	_vignette_rect = TextureRect.new()
	_vignette_rect.texture = tex
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.modulate.a = 0.0
	_vignette.add_child(_vignette_rect)
	add_child(_vignette)


# ─────────────────────────────────────────────────────────────────────────────
#  Публичный API (тот же, что был)
# ─────────────────────────────────────────────────────────────────────────────
func update_value(new_value: float, new_max_value: float, curse: float) -> void:
	# Максимум теперь меняется в обе стороны (раньше бар умел только уменьшаться,
	# и прибавка к макс. здоровью не растягивала шкалу).
	if new_max_value > 0.0 and not is_equal_approx(new_max_value, max_value):
		max_value = new_max_value
	var old := value

	if _first_update:
		# Самое первое значение (старт игры / загрузка) — просто показать, без вспышек «лечения»
		_display = new_value
		_trail = new_value
		_first_update = false
		old = new_value

	if new_value < old - 0.001:  # урон
		_trail = maxf(_trail, old)
		_trail_hold = 0.3
		var hit := (old - new_value) / maxf(max_value, 1.0)
		_hit_flash = 1.0
		_shake = clampf(0.3 + hit * 4.0, 0.3, 1.0)  # сильный удар — сильнее тряска
		_number_timer = NUMBER_TIME
	elif new_value > old + 0.001:  # лечение
		_heal_from = old
		_heal_flash = 1.0
		_number_timer = NUMBER_TIME

	value = new_value
	health = new_value
	max_health = max_value

	_curse_target = clampf(curse, 0.0, 100.0)
	if _corruption_effect:
		var active := _curse_target >= 70.0
		_corruption_effect.set("visible", active)
		_corruption_effect.set("emitting", active)
	queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
#  Анимация
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_t += delta

	# Урон видно сразу, лечение «наливается» за ~0.25 с
	if value < _display:
		_display = value
	else:
		_display += (value - _display) * minf(1.0, delta * 9.0)

	if _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		_trail += (_display - _trail) * minf(1.0, delta * 3.5)
	_trail = maxf(_trail, _display)

	_hit_flash = maxf(0.0, _hit_flash - delta * 6.0)
	_heal_flash = maxf(0.0, _heal_flash - delta * 2.2)
	_shake = maxf(0.0, _shake - delta * 4.0)
	_number_timer = maxf(0.0, _number_timer - delta)
	_curse_display += (_curse_target - _curse_display) * minf(1.0, delta * 4.0)

	_update_vignette(delta)
	queue_redraw()


func _ratio(v: float) -> float:
	return clampf(v / maxf(max_value, 1.0), 0.0, 1.0)


func _is_low() -> bool:
	return value > 0.0 and _ratio(value) <= low_hp_threshold


func _update_vignette(delta: float) -> void:
	if _vignette_rect == null:
		return
	var target := 0.0
	if low_hp_vignette and _is_low() and not get_tree().paused:
		var danger := 1.0 - _ratio(value) / low_hp_threshold  # 0 на границе, 1 при нуле
		var rate := lerpf(1.0, 2.2, danger)
		target = 0.3 + 0.3 * (0.5 + 0.5 * sin(_t * TAU * rate))
	_vignette_alpha += (target - _vignette_alpha) * minf(1.0, delta * 6.0)
	_vignette.visible = _vignette_alpha > 0.01
	_vignette_rect.modulate.a = _vignette_alpha


# ─────────────────────────────────────────────────────────────────────────────
#  Отрисовка
# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var s := size
	var low := _is_low()
	var pulse := 0.5 + 0.5 * sin(_t * TAU * 2.0)  # 0..1, 2 раза в секунду

	# Тряска при уроне (целые пиксели — пиксель-арт не «плывёт»)
	var shake_offset := Vector2.ZERO
	if _shake > 0.0:
		shake_offset = Vector2(roundf(sin(_t * 90.0) * _shake * 1.6), roundf(cos(_t * 77.0) * _shake * 0.9))
	draw_set_transform(shake_offset)

	var heart_w := 0.0
	if show_heart:
		heart_w = _draw_heart(s, low)

	var outer := Rect2(heart_w, 0.0, s.x - heart_w, s.y)
	var inner := outer.grow(-1.0)
	var frame_color := FRAME.lerp(Color(0.9, 0.1, 0.12), pulse * 0.8) if low else FRAME
	draw_rect(outer, frame_color)
	draw_rect(inner, BACK)

	var fill_w := roundf(inner.size.x * _ratio(_display))
	var trail_w := roundf(inner.size.x * _ratio(_trail))

	# След потерянного здоровья
	if trail_w > fill_w:
		draw_rect(Rect2(inner.position.x + fill_w, inner.position.y, trail_w - fill_w, inner.size.y), trail_color)

	# Основная заливка: тон, светлая кромка сверху, тень снизу — объём в один пиксель
	if fill_w > 0.0:
		var base := fill_color.lerp(fill_color.lightened(0.35), pulse * 0.7) if low else fill_color
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), base)
		if inner.size.y >= 6.0:
			draw_rect(Rect2(inner.position, Vector2(fill_w, 1.0)), base.lightened(0.4))
			draw_rect(Rect2(inner.position.x, inner.end.y - 1.0, fill_w, 1.0), base.darkened(0.35))

	# Вспышка восстановленного куска
	if _heal_flash > 0.0:
		var from_x := roundf(inner.size.x * _ratio(_heal_from))
		if fill_w > from_x:
			draw_rect(Rect2(inner.position.x + from_x, inner.position.y, fill_w - from_x, inner.size.y),
					Color(heal_color, 0.85 * _heal_flash))

	# Засечки по 10 HP (на больших максимумах реже, чтобы не превращать бар в расчёску)
	var step := 10.0
	while max_value / step > 20.0:
		step *= 2.0
	var k := 1
	while k * step < max_value - 0.01:
		var tx := inner.position.x + roundf(inner.size.x * (k * step) / max_value)
		draw_rect(Rect2(tx, inner.position.y, 1.0, inner.size.y), Color(0, 0, 0, 0.28))
		k += 1

	# Проклятие: фиолетовая полоска вдоль нижнего края
	if _curse_display > 0.5:
		var ch := maxf(2.0, roundf(inner.size.y * 0.28))
		var cy := inner.end.y - ch
		draw_rect(Rect2(inner.position.x, cy, inner.size.x, ch), Color(0, 0, 0, 0.4))
		var cc := curse_color.lightened(0.25 * pulse) if _curse_display >= 70.0 else curse_color
		draw_rect(Rect2(inner.position.x, cy, roundf(inner.size.x * _curse_display / 100.0), ch), cc)

	# Белая вспышка удара
	if _hit_flash > 0.0:
		draw_rect(inner, Color(1, 1, 1, 0.6 * _hit_flash))

	_draw_numbers(inner, low)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_numbers(inner: Rect2, low: bool) -> void:
	var alpha := 0.0
	match number_mode:
		NumberMode.ALWAYS:
			alpha = 1.0
		NumberMode.AUTO:
			alpha = clampf(_number_timer * 2.0, 0.0, 1.0)
			if low:
				alpha = 1.0  # в опасности цифры нужны всегда
	if alpha <= 0.0:
		return
	var font := get_theme_default_font()
	var fs := maxi(6, roundi(size.y * 0.7))
	var text := "%d/%d" % [ceili(value), int(max_value)]
	var pos := Vector2(inner.position.x, inner.end.y - maxf(1.0, (inner.size.y - fs * 0.75) * 0.5))
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 2.0, fs, 4, Color(0, 0, 0, alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 2.0, fs, Color(1, 1, 1, alpha))


## Пиксельное сердце. Возвращает занятую ширину (сердце + зазор).
func _draw_heart(s: Vector2, low: bool) -> float:
	var px := maxi(1, int(s.y / 9.0))
	var w := 9 * px
	var h := 8 * px
	var origin := Vector2(1.0, roundf((s.y - h) * 0.5))

	# Сердцебиение: чаще, когда плохо
	var rate := lerpf(0.9, 2.6, 1.0 - _ratio(value))
	var phase := fmod(_t * rate, 1.0)
	var beat := exp(-phase * 8.0)  # резкий «удар» и затухание
	var dead := value <= 0.0
	if beat > 0.5 and not dead:
		origin.y -= float(px)  # подпрыгивает на целый пиксель

	var body := fill_color.lightened(0.15)
	if dead:
		body = Color(0.35, 0.35, 0.38)
	elif low:
		body = body.lerp(Color(1.0, 0.35, 0.3), beat)

	# Свечение удара: кольцо вокруг сердца
	if not dead and beat > 0.05:
		for dir in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			_heart_cells(origin + dir * px, px, Color(body, 0.25 * beat))
	# Тёмная обводка
	for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_heart_cells(origin + dir * px, px, FRAME)
	_heart_cells(origin, px, body)
	# Блик
	draw_rect(Rect2(origin + Vector2(1, 1) * px, Vector2(px, px)), body.lightened(0.5))
	draw_rect(Rect2(origin + Vector2(2, 1) * px, Vector2(px, px)), body.lightened(0.25))
	return float(w) + 3.0 * px


func _heart_cells(origin: Vector2, px: int, color: Color) -> void:
	for y in HEART_ROWS.size():
		var row := HEART_ROWS[y]
		for x in row.length():
			if row[x] == "X":
				draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), color)
