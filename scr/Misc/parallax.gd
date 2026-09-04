## ParallaxMouseController.gd
## Вешается на узел ParallaxBackground (CanvasLayer/ParallaxBackground).
##
## Дочерние узлы — Parallax2D, они НЕ читают scroll_offset родителя,
## поэтому скрипт двигает каждый слой лично.
##
## ВАЖНО про дыры по краям:
## Раньше сдвиг = mouse_strength * scroll_scale — для Island2 (scroll_scale=6)
## это давало слишком большой пробег и оголяло края спрайтов/фон.
## Теперь у каждого слоя есть СВОЙ потолок сдвига (max_offset_px), который
## не зависит напрямую от scroll_scale — его надо подобрать руками под
## реальный запас пикселей на краях каждой картинки.

extends ParallaxBackground

## Общая "чувствительность" к мыши (0..1 нормализованная позиция * strength)
@export var mouse_strength: float = 1.0

## Скорость плавного следования
@export var follow_speed: float = 4.0

## true — дальние слои уезжают в сторону, противоположную курсору (эффект глубины)
@export var invert: bool = true

## Потолок сдвига (в пикселях) для КАЖДОГО слоя отдельно.
## Ключ — имя узла (как в сцене: "BG", "CloudBack", "Island1", "Island2", "Island3", "CloudFront").
## Подбери значения под свои картинки: сколько лишних пикселей есть за пределами
## видимой области экрана у каждого спрайта — столько и можно смещать безопасно.
## Если слоя нет в словаре — он не будет двигаться мышью вообще (останется статичным).
@export var max_offset_by_layer: Dictionary = {
	"BG": Vector2(15, 8),
	"Planets": Vector2(25, 10),
	"Island1": Vector2(10, 5),
	"Island2": Vector2(8, 4),
	"Island3": Vector2(8, 4),
	"CloudFront": Vector2(30, 12),
}

var _layers: Array[Parallax2D] = []
var _base_offsets: Array[Vector2] = []
var _max_offsets: Array[Vector2] = []
var _current_t: Vector2 = Vector2.ZERO  # сглаженная нормализованная позиция мыши -1..1


func _ready() -> void:
	for child in get_children():
		if child is Parallax2D and max_offset_by_layer.has(child.name):
			_layers.append(child)
			_base_offsets.append(child.scroll_offset)
			_max_offsets.append(max_offset_by_layer[child.name])


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return

	var mouse_pos := get_viewport().get_mouse_position()

	# -1 .. 1 относительно центра экрана
	var normalized: Vector2 = ((mouse_pos / viewport_size) - Vector2(0.5, 0.5)) * 2.0
	normalized = normalized.clamp(Vector2(-1, -1), Vector2(1, 1))

	var dir := -1.0 if invert else 1.0
	_current_t = _current_t.lerp(normalized * dir, clamp(delta * follow_speed, 0.0, 1.0))

	for i in _layers.size():
		var layer := _layers[i]
		var offset: Vector2 = _current_t * _max_offsets[i] * mouse_strength
		layer.scroll_offset = _base_offsets[i] + offset
