# terminal_style.gd
## Общий визуальный язык «корабельного оборудования»: тёмный металл корпуса,
## бирюзовые экраны с развёрсткой, красные/зелёные индикаторы — как консоли на мостике.
## Все терминалы игры (задания, выбор планеты) берут цвета и рамки отсюда.
class_name TerminalStyle
extends RefCounted

const METAL      := Color("2a2e3b")   ## корпус
const METAL_DARK := Color("171923")
const STEEL      := Color("6b7388")   ## кромка корпуса
const SCREEN_BG  := Color("06161b")   ## тёмный экран
const CYAN       := Color("45e6e6")   ## активное, заголовки
const CYAN_DIM   := Color("1f7f86")   ## рамки экранов, второстепенное
const TEXT       := Color("c9f7f7")
const AMBER      := Color("ffc857")   ## предупреждение / акцент
const RED        := Color("e8454f")
const GREEN      := Color("6fe08a")
const GREY       := Color("5d6b73")   ## выключено / нет сигнала


## Размеры считаем от высоты вьюпорта, чтобы интерфейс выглядел одинаково
## при любом разрешении (пиксельный низкий вьюпорт и обычный).
static func px(h: float, ratio: float) -> int:
	return maxi(1, roundi(h * ratio))


static func metal_style(h: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = METAL
	s.border_color = STEEL
	s.set_border_width_all(px(h, 0.006))
	s.set_corner_radius_all(px(h, 0.012))
	s.set_content_margin_all(h * 0.03)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = px(h, 0.02)
	return s


static func screen_style(h: float, edge: Color = CYAN_DIM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SCREEN_BG
	s.border_color = edge
	s.set_border_width_all(px(h, 0.004))
	s.set_corner_radius_all(px(h, 0.006))
	s.set_content_margin_all(h * 0.018)
	return s


static func button_style(h: float, fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(px(h, 0.004))
	s.set_corner_radius_all(px(h, 0.006))
	s.set_content_margin_all(h * 0.014)
	return s


## Строчная развёртка + медленно ползущая светлая полоса, как на старом мониторе.
static func draw_scanlines(ci: CanvasItem, rect: Rect2, step: float, alpha: float) -> void:
	var y := rect.position.y
	while y < rect.end.y:
		ci.draw_rect(Rect2(rect.position.x, y, rect.size.x, maxf(1.0, step * 0.5)), Color(0, 0, 0, alpha))
		y += step
	var t := fmod(Time.get_ticks_msec() / 1000.0 * 0.3, 1.0)
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * t, rect.size.x, step * 3.0),
			Color(CYAN, 0.05))


## Прозрачный слой поверх экрана: рисует развёртку и не ловит мышь.
## Добавляй ПОСЛЕДНИМ ребёнком экрана — тогда он лежит сверху.
class Scan extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var h := get_viewport().get_visible_rect().size.y
		TerminalStyle.draw_scanlines(self, Rect2(Vector2.ZERO, size), maxf(2.0, h * 0.007), 0.16)
