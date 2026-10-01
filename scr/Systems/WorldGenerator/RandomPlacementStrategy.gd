extends GenerationPlacementStrategy
class_name RandomPlacementStrategy

# ═══════════════════════════════════════════════════════════════════════════════
#  RandomPlacementStrategy — старое поведение генератора: случайные точки
#  внутри ограничивающего прямоугольника области, пока не наберётся
#  target_count штук (или не кончатся попытки).
# ═══════════════════════════════════════════════════════════════════════════════

## Сколько объектов хотим разместить всего.
@export var target_count: int = 300
## Во сколько раз больше точек-кандидатов сгенерировать, чем target_count —
## запас нужен, потому что часть кандидатов отсеется в WorldMapGenerator
## по спейсингу/harvested/клиренсу от структур.
@export var max_attempts_multiplier: int = 20

var _area_rect: Rect2


func setup(_area_polygon: PackedVector2Array, area_rect: Rect2, _location_seed: int) -> void:
	_area_rect = area_rect


func generate_candidates(rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if _area_rect.size == Vector2.ZERO:
		return points

	var attempts: int = max(target_count * max_attempts_multiplier, target_count)
	for _i in attempts:
		points.append(Vector2(
			rng.randf_range(_area_rect.position.x, _area_rect.position.x + _area_rect.size.x),
			rng.randf_range(_area_rect.position.y, _area_rect.position.y + _area_rect.size.y)
		))
	return points


func is_count_emergent() -> bool:
	return false


func get_target_count() -> int:
	return target_count
