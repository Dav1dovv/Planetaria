extends GenerationPlacementStrategy
class_name GridPlacementStrategy

# ═══════════════════════════════════════════════════════════════════════════════
#  GridPlacementStrategy — расставляет объекты по регулярной сетке ячеек
#  cell_size×cell_size внутри области. КОЛИЧЕСТВО объектов НИКЕМ вручную не
#  задаётся — каждая ячейка сетки проверяется по шуму плотности
#  (density-шум): если шум в центре ячейки выше density_noise_threshold,
#  ячейка предлагает точку-кандидата, иначе — пропускается. То есть чем
#  крупнее density_noise_scale/порог, тем реже/чаще будут попадаться объекты,
#  а итоговое число вырастает само из формы шума, а не из числа в инспекторе.
#
#  cell_jitter добавляет случайное смещение внутри ячейки, чтобы сетка не
#  выглядела слишком механически ровной.
# ═══════════════════════════════════════════════════════════════════════════════

## Размер одной ячейки сетки в пикселях.
@export var cell_size: float = 48.0
## Случайное смещение точки внутри ячейки (0 = строго по центру ячейки,
## 1 = может уехать почти на пол-ячейки в любую сторону).
@export_range(0.0, 1.0, 0.05) var cell_jitter: float = 0.6

@export_group("Density Noise")
## Масштаб шума плотности. Меньше = крупные плотные/пустые пятна,
## больше = плотность чаще чередуется от ячейки к ячейке.
@export var density_noise_scale: float = 0.05
## Порог 0..1: ячейка спавнит объект, только если шум в её центре
## (нормализованный к 0..1) не ниже этого значения. Увеличивай, чтобы
## получить МЕНЬШЕ объектов, уменьшай — чтобы получить БОЛЬШЕ, без
## необходимости вручную считать их количество.
@export_range(0.0, 1.0, 0.01) var density_noise_threshold: float = 0.55
## Октавы фрактального шума плотности — больше октав = более "шумная",
## детализированная плотность.
@export var density_noise_octaves: int = 3

var _area_rect: Rect2
var _density_noise: FastNoiseLite


func setup(_area_polygon: PackedVector2Array, area_rect: Rect2, location_seed: int) -> void:
	_area_rect = area_rect

	_density_noise = FastNoiseLite.new()
	_density_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_density_noise.fractal_octaves = density_noise_octaves
	_density_noise.frequency = density_noise_scale
	# +4242 — просто сдвиг, чтобы этот шум не совпадал 1-в-1 с шумом зон или
	# другими шумами, использующими тот же _location_seed.
	_density_noise.seed = location_seed + 4242


func generate_candidates(rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if cell_size <= 0.0:
		push_warning("[GridPlacementStrategy] cell_size <= 0 — сетка невозможна.")
		return points
	if _area_rect.size == Vector2.ZERO:
		return points

	var start_x := _area_rect.position.x
	var start_y := _area_rect.position.y
	var cols := ceili(_area_rect.size.x / cell_size)
	var rows := ceili(_area_rect.size.y / cell_size)
	var half_cell := cell_size * 0.5

	for row in rows:
		for col in cols:
			var cell_center := Vector2(
				start_x + col * cell_size + half_cell,
				start_y + row * cell_size + half_cell
			)

			var n := (_density_noise.get_noise_2d(cell_center.x, cell_center.y) + 1.0) * 0.5
			if n < density_noise_threshold:
				continue  # шум говорит "тут пусто" — количество решает шум, а не число из инспектора

			var offset := Vector2.ZERO
			if cell_jitter > 0.0:
				offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (half_cell * cell_jitter)

			points.append(cell_center + offset)

	return points


func is_count_emergent() -> bool:
	return true
