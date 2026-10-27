@tool
extends Node2D
class_name WorldMapGenerator

# ═══════════════════════════════════════════════════════════════════════════════
#  WorldMapGenerator — расставляет спец-структуры (лагеря, данжи) и ресурсы
#  (кусты, руда, деревья) внутри области, заданной ФОРМОЙ Polygon2D (generation_area).
#
#  ЧТО УБРАНО по сравнению со старой версией:
#   • Вся отрисовка тайлов (ground_layer/water_layer, terrain-автотайлинг,
#     fallback atlas-тайлы, декоративные вариации травы). Этот генератор
#     больше НЕ рисует ландшафт — только расставляет объекты (Generation/
#     SpecialStructure) как ноды-сцены.
#   • Бесконечная потоковая генерация чанков вокруг игрока (target_path,
#     stream_radius_chunks, build/erase очереди) и World Wrap (телепорт на
#     противоположный край карты). Область теперь ФИКСИРОВАННАЯ и строится
#     ОДИН раз при старте.
#
#  ЧТО ВЗАМЕН:
#   • Размер и форма области генерации задаются нодой Polygon2D
#     (generation_area) прямо в редакторе — просто нарисуй нужный контур.
#   • Структуры размещаются случайными точками внутри этого полигона
#     (Geometry2D.is_point_in_polygon), с той же логикой мин-дистанций, что и раньше.
#   • Инстанцирование ресурсов всё ещё размазано по кадрам через
#     resource_spawn_per_frame, чтобы не было хитча при старте на большой площади.
#
#  МОДУЛЬНОСТЬ (новое):
#   • ГДЕ расставлять ресурсы — теперь отдельная подключаемая стратегия
#     (GenerationPlacementStrategy). Есть RandomPlacementStrategy (старое
#     поведение, точки случайны) и GridPlacementStrategy (точки — по сетке
#     ячеек, а САМО количество объектов решает шум плотности, а не число,
#     заданное вручную). Своя стратегия = свой .gd, extends
#     GenerationPlacementStrategy — генератор трогать не нужно.
#   • Сохранение (сид локации + harvested-ресурсы) идёт через ЛЮБУЮ ноду,
#     на которую указывает save_provider_path, а не жёстко через SaveSystem —
#     достаточно, чтобы она реализовывала те же 4 метода. Сохранение целиком
#     можно выключить флагом enable_saving (тогда сид каждый раз новый,
#     harvested не запоминается — удобно для превью/тестовых сцен).
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
#  Общее
# ─────────────────────────────────────────
@export_group("General")
## Polygon2D, чья форма (в мировых координатах, с учётом её transform) задаёт
## границы области генерации. Обязательно перетащи сюда ноду — без неё
## генератор не запустится. Просто нарисуй/подвинь полигон в редакторе,
## чтобы изменить размер и форму области.
@export var generation_area: Polygon2D
## Уникальное имя этой локации/карты. Используется, чтобы сохранить сид
## генерации и собранные ресурсы отдельно для каждой локации — если у тебя
## несколько областей (например деревня и подземелье), у них должны быть
## РАЗНЫЕ location_id, иначе они перепутают сохранения друг друга.
@export var location_id: String = "world_map"
## Если включено — генератор будет печатать в консоль подробности о том,
## что он делает (сид, сколько структур/ресурсов расставлено и т.п.).
## Полезно для отладки, в релизной сборке лучше выключить.
@export var debug_logging: bool = false

# ─────────────────────────────────────────
#  Зоны (биомы) — переиспользуем существующий ресурс GenerationZone.gd
# ─────────────────────────────────────────
@export_group("Zones")
## Зоны определяют доминантные ресурсы в разных участках области. Зона активна
## в точке, если значение zone-шума в этой точке не ниже её noise_threshold.
## Если зон несколько — побеждает та, у которой порог выше (более
## "требовательные"/редкие зоны приоритетнее общих).
@export var zones: Array[GenerationZone] = []
## Масштаб шума, который определяет границы биомов/зон. Меньше значение =
## более крупные, растянутые зоны биомов, больше = зоны мельче и чаще чередуются.
@export var zone_noise_scale: float = 0.008

# ─────────────────────────────────────────
#  Специальные структуры (переиспользуем существующий ресурс)
# ─────────────────────────────────────────
@export_group("Special Structures")
## Список особых построек (лагеря, данжи и т.п.), которые генератор
## попробует расставить внутри области. Каждый элемент — ресурс SpecialStructure
## с собственными настройками (тип, минимальные дистанции между постройками).
@export var special_structures: Array[SpecialStructure] = []
## Сколько раз генератор попытается найти место под структуру, прежде чем
## сдаться и пропустить её. Больше значение = выше шанс, что все структуры
## из списка всё-таки поместятся в область, но дольше генерация на старте.
@export var max_structure_attempts: int = 200

# ─────────────────────────────────────────
#  Ресурсы локации (кусты, руда, деревья и т.п. — переиспользуем Generation.gd)
# ─────────────────────────────────────────
@export_group("Resources")
## Список того, что может появиться в этой локации, с весами
## (Generation.spawn_weight) — так же, как в старом WorldGenerator.
@export var resource_items: Array[Generation] = []
## Стратегия расстановки — решает, КАКИЕ точки внутри области предложить под
## ресурсы. По умолчанию (если оставить пустым) генератор сам создаст
## RandomPlacementStrategy — это то же поведение, что было раньше (300
## случайных точек). Назначь сюда GridPlacementStrategy в инспекторе, чтобы
## ресурсы легли по сетке, а их количество определялось шумом плотности, а
## не заданным вручную числом. Можно написать и свою стратегию — см.
## GenerationPlacementStrategy.gd.
@export var resource_placement_strategy: GenerationPlacementStrategy
## Минимальное расстояние между двумя заспавненными ресурсами (px).
@export var resource_min_spacing: float = 20.0
## Минимальное расстояние (px) от ЛЮБОЙ уже размещённой структуры, на
## котором разрешено ставить ресурс. Нужно, чтобы кусты/деревья не
## прорастали посередине домика или лагеря — структуры размещаются
## раньше ресурсов, и это расстояние проверяется дополнительно к обычному
## resource_min_spacing (который работает только между самими ресурсами).
@export var resource_structure_clearance: float = 64.0
## Если true — уже собранные (harvested) позиции не заспавнятся повторно
## после перезахода в локацию (используется SaveSystem.save_harvested/load_harvested).
@export var track_harvested: bool = true
## Если true — каждому заспавненному ресурсу назначается случайный размер из
## Generation.random_scales (Standart/Middle/Big), как было в старом WorldGenerator.
@export var apply_random_scale: bool = true
## Сколько РЕСУРСОВ (кустов/руды/деревьев) реально инстанцировать (instantiate +
## add_child) за один кадр. Заспавнить сразу сотни физических объектов
## (Harvestable — коллизии, шейдеры, частицы) в один кадр — частый источник
## хитчей на старте. Поэтому инстанцирование размазано по кадрам.
@export var resource_spawn_per_frame: int = 6

# ─────────────────────────────────────────
#  Сохранение (сид локации + harvested)
# ─────────────────────────────────────────
@export_group("Saving")
## Если выключено — генератор вообще не обращается к save-провайдеру:
## сид локации будет каждый раз новым (случайным), а harvested-ресурсы не
## запоминаются между заходами в локацию. Удобно для превью в редакторе,
## тестовых сцен или локаций, которые не должны сохраняться на диск.
@export var enable_saving: bool = true
## Путь до ноды, которая умеет сохранять/загружать сид и harvested. По
## умолчанию — автозагрузка /root/SaveSystem, но можно указать ЛЮБУЮ другую
## ноду: генератор обращается к ней только по именам методов
## (load_world_seeds, save_world_seeds, load_harvested, save_harvested),
## а не по classname, так что реализацию сохранения можно полностью
## подменить, не трогая WorldMapGenerator.
@export var save_provider_path: NodePath = ^"/root/SaveSystem"

# ─────────────────────────────────────────
#  Внутреннее состояние
# ─────────────────────────────────────────
var _zone_noise: FastNoiseLite
var _rng: RandomNumberGenerator
var _location_seed: int

var _area_polygon: PackedVector2Array   # точки полигона в мировых координатах
var _area_rect: Rect2                    # ограничивающий прямоугольник области

var _save_system: Node   # нода из save_provider_path, если enable_saving включён и сохранение
						  # разрешено — используется только через has_method(), см. _save_ready()

var _placed_structures: Array[Dictionary] = []
var _harvested_set: Dictionary = {}          # "x,y" -> true, снято через SaveSystem.load_harvested()
var _total_resource_weight: float = 0.0

## Ресурсы, для которых уже выбрана позиция/тип (дёшево), но ЕЩЁ НЕ
## инстанцированы (дорого) — обрабатываются по resource_spawn_per_frame за кадр.
## Каждый элемент: { "pos": Vector2, "item": Generation, "scene_index": int, "scale": Variant }
var _pending_resource_spawns: Array[Dictionary] = []


# ═══════════════════════════════════════════════════════════════════════════════
#  СТАРТ
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if generation_area == null:
		push_warning("[WorldMapGenerator] generation_area (Polygon2D) не назначен — генерация невозможна.")
		return

	if enable_saving:
		_save_system = get_node_or_null(save_provider_path)
		if _save_system == null:
			push_warning("[WorldMapGenerator] enable_saving=true, но по save_provider_path (%s) ничего не найдено — сид и harvested не будут сохраняться." % save_provider_path)
	else:
		_save_system = null
		_log("[WorldMapGenerator] Сохранение отключено (enable_saving=false) — сид и harvested не персистятся между заходами.")

	if resource_placement_strategy == null:
		resource_placement_strategy = RandomPlacementStrategy.new()
		_log("[WorldMapGenerator] resource_placement_strategy не задан в инспекторе — создаю RandomPlacementStrategy по умолчанию (эквивалент старого поведения).")

	_apply_performance_preset()
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and sm.has_signal("settings_changed"):
		sm.settings_changed.connect(_apply_performance_preset)

	_setup_seed()
	_compute_area_bounds()
	_load_harvested()

	for item in resource_items:
		if item:
			_total_resource_weight += item.spawn_weight

	if not special_structures.is_empty():
		_place_special_structures()

	_spawn_all_resources()

	set_process(true)
	_log("[WorldMapGenerator] Старт: сид='%s':%d, структур=%d, ресурсов в очереди=%d" % [
		location_id, _location_seed, _placed_structures.size(), _pending_resource_spawns.size()
	])


func _setup_seed() -> void:
	_location_seed = _get_or_create_location_seed(location_id)

	# Шум зон/биомов — со своим сидом (сдвинутым от основного), чтобы биомы
	# не были жёстко привязаны к чему-либо ещё в генерации.
	_zone_noise = FastNoiseLite.new()
	_zone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_zone_noise.fractal_octaves = 2
	_zone_noise.frequency = zone_noise_scale
	_zone_noise.seed = _location_seed + 1

	_rng = RandomNumberGenerator.new()
	_rng.seed = _location_seed

	_log("[WorldMapGenerator] Сид '%s': %d" % [location_id, _location_seed])


## Считает точки полигона в мировых координатах (с учётом transform ноды
## generation_area) и её ограничивающий прямоугольник — используется для
## быстрой случайной выборки точек (сэмплим внутри rect, затем проверяем
## попадание в реальный полигон).
func _compute_area_bounds() -> void:
	var local_points := generation_area.polygon
	var xform := generation_area.global_transform

	_area_polygon = PackedVector2Array()
	for p in local_points:
		_area_polygon.append(xform * p)

	if _area_polygon.is_empty():
		push_warning("[WorldMapGenerator] У generation_area пустой Polygon2D.polygon — область генерации нулевая.")
		_area_rect = Rect2()
		return

	var rect := Rect2(_area_polygon[0], Vector2.ZERO)
	for p in _area_polygon:
		rect = rect.expand(p)
	_area_rect = rect


## Читает сид локации из world_seeds.json (через SaveSystem). Если для этой
## локации сида ещё нет — создаёт новый (детерминированно от master_seed +
## location_id, чтобы одинаковый мастер-сид всегда давал одинаковую карту)
## и сразу дописывает его в тот же файл — при следующей загрузке слота
## SaveSystem.load_world_seeds() вернёт уже сохранённое значение.
func _get_or_create_location_seed(id: String) -> int:
	var slot: String = Global.current_save_slot
	if not _save_ready(["load_world_seeds", "save_world_seeds"]):
		return ResourceUID.create_id()
	if slot.is_empty():
		push_warning("[WorldMapGenerator] current_save_slot пуст — сид не сохраняется.")
		return ResourceUID.create_id()

	var world_data: Dictionary = _save_system.load_world_seeds()
	var location_seeds: Dictionary = world_data.get("location_seeds", {})

	if location_seeds.has(id):
		return int(location_seeds[id])

	var master_seed: int = world_data.get("master_seed", 0)
	var world_seed: String = world_data.get("world_seed", "")
	if world_data.is_empty():
		# Для этого слота вообще ещё нет world_seeds.json — заводим мастер-сид один раз,
		# дальше все локации должны брать сид отсюда же.
		master_seed = randi()
		world_seed = str(master_seed)

	var new_seed: int = hash(str(master_seed) + "_" + id)
	location_seeds[id] = new_seed

	if not _save_system.save_world_seeds(master_seed, world_seed, location_seeds):
		push_warning("[WorldMapGenerator] Не удалось сохранить сид локации '%s'." % id)

	return new_seed


## Загружает уже собранные (harvested) позиции для этой локации из SaveSystem,
## чтобы повторно эти места не заспавнили ресурс снова.
func _load_harvested() -> void:
	if not track_harvested:
		return
	if not _save_ready(["load_harvested"]):
		return
	var all_harvested: Dictionary = _save_system.load_harvested()
	var positions: Array = all_harvested.get(location_id, [])
	for p in positions:
		if p is Dictionary and p.has("x") and p.has("y"):
			_harvested_set[_snap_key(Vector2(p["x"], p["y"]))] = true


func _snap_key(pos: Vector2) -> String:
	return "%d,%d" % [roundi(pos.x), roundi(pos.y)]


# ═══════════════════════════════════════════════════════════════════════════════
#  ПОКАДРОВЫЙ БЮДЖЕТ (только на инстанцирование уже решённых ресурсов)
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_process_resource_spawn_budget()

	if _pending_resource_spawns.is_empty():
		set_process(false)   # область фиксированная и строится один раз — дальше кадры не нужны


## Подтягивает текущий пресет оптимизации из SettingsManager (Настройки →
## Оптимизация) и присваивает его значения соответствующим @export-полям
## этого генератора (например resource_spawn_per_frame). Вызывается один раз
## при старте и повторно при каждом изменении настроек. Если SettingsManager
## не подключён как автозагрузка — просто ничего не делает.
func _apply_performance_preset() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if sm == null or not sm.has_method("get_performance_tuning"):
		return

	var tuning: Dictionary = sm.get_performance_tuning()
	for key in tuning:
		if key == "max_fps":
			continue   # это движковая настройка, её применяет сам SettingsManager
		if key in self:
			set(key, tuning[key])

	if debug_logging:
		_log("[WorldMapGenerator] Применён пресет оптимизации: %s" % tuning)


## Инстанцирует не больше resource_spawn_per_frame ресурсов за кадр — создание
## физических нод (Harvestable: коллизии/шейдеры/частицы) пачкой в один кадр
## и есть хитч.
func _process_resource_spawn_budget() -> void:
	var spawned := 0
	while spawned < resource_spawn_per_frame and not _pending_resource_spawns.is_empty():
		var entry: Dictionary = _pending_resource_spawns.pop_front()
		_instantiate_resource(entry)
		spawned += 1


func _instantiate_resource(entry: Dictionary) -> void:
	var item: Generation = entry["item"]
	var scenes: Array[PackedScene] = [item.Generation_scene]
	scenes.append_array(item.Generation_random_versions)
	var scene: PackedScene = scenes[entry["scene_index"]] if entry["scene_index"] < scenes.size() else scenes[0]
	if not scene:
		return

	var obj := scene.instantiate()
	obj.global_position = entry["pos"]
	_apply_random_scale_value(obj, entry.get("scale"))
	add_child(obj)


## Вызови этот метод из скрипта самого ресурса, когда игрок его собрал/уничтожил —
## освобождает ноду и запоминает позицию через SaveSystem.save_harvested(), чтобы
## при повторном заходе в локацию он не заспавнился снова.
func mark_resource_harvested(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var pos: Vector2 = node.global_position
	node.queue_free()

	if not track_harvested:
		return
	_harvested_set[_snap_key(pos)] = true

	if not _save_ready(["load_harvested", "save_harvested"]):
		return
	var all_harvested: Dictionary = _save_system.load_harvested()
	var positions: Array = all_harvested.get(location_id, [])
	positions.append({ "x": pos.x, "y": pos.y })
	all_harvested[location_id] = positions
	if not _save_system.save_harvested(all_harvested):
		push_warning("[WorldMapGenerator] Не удалось сохранить harvested для '%s'." % location_id)


## Единая проверка перед любым обращением к save-провайдеру: включено ли
## сохранение, назначена ли нода в save_provider_path, и реализует ли она
## ВСЕ нужные для этой операции методы. Возвращает false тихо (без варнинга),
## если сохранение просто выключено флагом — это ожидаемо, не ошибка.
func _save_ready(required_methods: Array) -> bool:
	if not enable_saving or _save_system == null:
		return false
	for m in required_methods:
		if not _save_system.has_method(m):
			push_warning("[WorldMapGenerator] Save-провайдер (%s) не реализует метод '%s' — эта операция сохранения пропущена." % [save_provider_path, m])
			return false
	return true


func _can_place_structure(structure: SpecialStructure, pos: Vector2) -> bool:
	var any_sq := structure.min_distance_between_any * structure.min_distance_between_any
	var same_sq := structure.min_distance_between_same_type * structure.min_distance_between_same_type
	for placed in _placed_structures:
		var d_sq: float = pos.distance_squared_to(placed["position"])
		if d_sq < any_sq: return false
		if placed["structure"].structure_type == structure.structure_type and d_sq < same_sq:
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
#  СПЕЦСТРУКТУРЫ — случайные точки внутри полигона области
# ═══════════════════════════════════════════════════════════════════════════════

## Расстановка лагерей/данжей — точки берутся напрямую из Polygon2D-области
## (случайная точка в ограничивающем rect + проверка попадания в полигон),
## а не из тайловой сетки суши, как в промежуточной чанковой версии.
func _place_special_structures() -> void:
	var sorted := special_structures.duplicate()
	sorted.sort_custom(func(a, b): return a.spawn_priority > b.spawn_priority)

	for structure in sorted:
		if not structure.generation_item or _rng.randf() > structure.spawn_chance:
			continue

		var placed := 0
		for _attempt in range(max_structure_attempts):
			if placed >= structure.max_instances:
				break
			var pos := _random_point_in_rect(_rng)
			if not is_point_in_area(pos):
				continue
			if not _can_place_structure(structure, pos):
				continue

			var scenes: Array[PackedScene] = [structure.generation_item.Generation_scene]
			scenes.append_array(structure.generation_item.Generation_random_versions)
			var scene: PackedScene = scenes[_rng.randi() % scenes.size()]
			if not scene:
				continue
			var obj := scene.instantiate()
			obj.global_position = pos
			call_deferred("add_child", obj)
			_placed_structures.append({ "position": pos, "structure": structure, "instance": obj })
			placed += 1


# ═══════════════════════════════════════════════════════════════════════════════
#  РЕСУРСЫ — случайные точки внутри полигона области (один проход при старте)
# ═══════════════════════════════════════════════════════════════════════════════

## Решает, ЧТО и ГДЕ заспавнить внутри области (дёшево — без instantiate/
## add_child) и складывает решения в очередь _pending_resource_spawns, которая
## расходуется по resource_spawn_per_frame за кадр в _process_resource_spawn_budget().
## RNG — свой, детерминированный от сида локации, не трогает общий _rng
## (тот расходуется на структуры) — так повторный запуск с тем же сидом даёт
## тот же результат.
##
## ГДЕ предлагать точки-кандидаты решает resource_placement_strategy (см.
## GenerationPlacementStrategy.gd) — сам метод дальше одинаково фильтрует
## любые кандидаты: попадание в полигон, harvested, спейсинг между ресурсами,
## клиренс от структур. Если стратегия "эмерджентная" (например
## GridPlacementStrategy — считает количество через шум плотности), метод не
## останавливается на каком-то заданном числе, а размещает все прошедшие
## проверки точки.
func _spawn_all_resources() -> void:
	if resource_items.is_empty() or _area_rect.size == Vector2.ZERO:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _location_seed + 1000

	resource_placement_strategy.setup(_area_polygon, _area_rect, _location_seed)
	var candidates := resource_placement_strategy.generate_candidates(rng)
	var emergent := resource_placement_strategy.is_count_emergent()
	var target_count := resource_placement_strategy.get_target_count()

	var placed_positions: Array[Vector2] = []
	var spacing_sq := resource_min_spacing * resource_min_spacing
	var structure_clearance_sq := resource_structure_clearance * resource_structure_clearance
	var placed_count := 0

	for pos in candidates:
		if not emergent and target_count >= 0 and placed_count >= target_count:
			break

		if not is_point_in_area(pos):
			continue
		if track_harvested and _harvested_set.has(_snap_key(pos)):
			continue

		var too_close := false
		for p in placed_positions:
			if p.distance_squared_to(pos) < spacing_sq:
				too_close = true
				break
		if too_close:
			continue

		# Не сажаем ресурс поверх/впритык к уже размещённой структуре
		# (структуры расставляются раньше ресурсов, так что список уже полон).
		var too_close_to_structure := false
		for placed in _placed_structures:
			if pos.distance_squared_to(placed["position"]) < structure_clearance_sq:
				too_close_to_structure = true
				break
		if too_close_to_structure:
			continue

		var item := _pick_weighted_resource_for_pos(rng, pos)
		if item == null or not item.Generation_scene:
			continue

		var scene_count := 1 + item.Generation_random_versions.size()
		var scene_index := rng.randi() % scene_count

		_pending_resource_spawns.append({
			"pos": pos,
			"item": item,
			"scene_index": scene_index,
			"scale": _pick_random_scale_value(item, rng),
		})
		placed_positions.append(pos)
		placed_count += 1

	if debug_logging:
		if emergent:
			_log("[WorldMapGenerator] Ресурсы (эмерджентно, через шум плотности): размещено %d." % placed_count)
		elif target_count >= 0 and placed_count < target_count:
			_log("[WorldMapGenerator] Ресурсы: удалось разместить только %d из %d — область может быть слишком маленькой/тесной для этих настроек спейсинга." % [
				placed_count, target_count
			])
		else:
			_log("[WorldMapGenerator] Ресурсы: размещено %d." % placed_count)


## Взвешенный выбор ресурса для конкретной точки: общий пул resource_items +
## (если точка попала в зону) dominant_items этой зоны с их spawn_weight_multiplier.
func _pick_weighted_resource_for_pos(rng: RandomNumberGenerator, pos: Vector2) -> Generation:
	var pool: Array[Generation] = []
	var weights: Array[float] = []
	var total_weight := 0.0

	for item in resource_items:
		if item == null:
			continue
		pool.append(item)
		weights.append(item.spawn_weight)
		total_weight += item.spawn_weight

	var zone := get_zone_at(pos)
	if zone and not zone.dominant_items.is_empty():
		for item in zone.dominant_items:
			if item == null:
				continue
			var w: float = item.spawn_weight * zone.spawn_weight_multiplier
			pool.append(item)
			weights.append(w)
			total_weight += w

	if pool.is_empty() or total_weight <= 0.0:
		return null

	return _pick_weighted_resource(rng, pool, weights, total_weight)


func _pick_weighted_resource(rng: RandomNumberGenerator, pool: Array[Generation], weights: Array[float], total: float) -> Generation:
	var roll := rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return null


## Выбирает случайный размер из Generation.random_scales (Standart/Middle/Big
## и т.п.), либо null, если применять размер не нужно/нечего.
func _pick_random_scale_value(item: Generation, rng: RandomNumberGenerator):
	if not apply_random_scale or not item.random_scales or item.random_scales.is_empty():
		return null
	var keys := item.random_scales.keys()
	var chosen_key = keys[rng.randi() % keys.size()]
	return item.random_scales[chosen_key]


func _apply_random_scale_value(obj: Node, scale_value) -> void:
	if scale_value == null:
		return
	if obj is Node2D or obj is CanvasItem:
		obj.scale = scale_value


# ═══════════════════════════════════════════════════════════════════════════════
#  ВСПОМОГАТЕЛЬНЫЕ / ПУБЛИЧНЫЙ API
# ═══════════════════════════════════════════════════════════════════════════════

func _random_point_in_rect(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(_area_rect.position.x, _area_rect.position.x + _area_rect.size.x),
		rng.randf_range(_area_rect.position.y, _area_rect.position.y + _area_rect.size.y)
	)


## true, если мировая точка находится внутри полигона generation_area.
## Замена старому is_land_at/is_water_at — тайлов и понятия "суша/вода" больше
## нет, есть только "внутри области генерации" или нет.
func is_point_in_area(world_pos: Vector2) -> bool:
	if _area_polygon.is_empty():
		return false
	return Geometry2D.is_point_in_polygon(world_pos, _area_polygon)


## Центр (центроид) полигона области — используется как безопасная точка
## по умолчанию, если что-то оказалось снаружи области.
func get_area_center() -> Vector2:
	if _area_polygon.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for p in _area_polygon:
		sum += p
	return sum / _area_polygon.size()


## Ищет ближайшую точку внутри области генерации к заданной мировой позиции —
## расходящимися кольцами по кругу. Используется, чтобы игрок никогда не
## спавнился за пределами области, даже если его точка спавна (0,0) снаружи.
func find_nearest_point_in_area(from_world_pos: Vector2, max_radius: float = 1024.0, radius_step: float = 16.0, samples_per_ring: int = 16) -> Vector2:
	if is_point_in_area(from_world_pos):
		return from_world_pos

	var radius := radius_step
	while radius <= max_radius:
		for i in samples_per_ring:
			var angle := TAU * i / samples_per_ring
			var candidate := from_world_pos + Vector2(cos(angle), sin(angle)) * radius
			if is_point_in_area(candidate):
				return candidate
		radius += radius_step

	push_warning("[WorldMapGenerator] find_nearest_point_in_area: точка внутри области не найдена в радиусе %.0f от %s — возвращаю центр области." % [max_radius, from_world_pos])
	return get_area_center()


func get_area_size_px() -> Vector2:
	return _area_rect.size


func get_area_rect_px() -> Rect2:
	return _area_rect


func get_placed_structures() -> Array[Dictionary]:
	return _placed_structures


# ─────────────────────────────────────────
#  Зоны по мировым точкам
# ─────────────────────────────────────────

## Возвращает зону, "владеющую" данной мировой точкой (или null, если зон нет,
## либо шум в этой точке не превысил порог ни одной из них).
func get_zone_at(world_pos: Vector2) -> GenerationZone:
	if zones.is_empty():
		return null

	var n := (_zone_noise.get_noise_2d(world_pos.x, world_pos.y) + 1.0) * 0.5

	var sorted_zones := zones.duplicate()
	sorted_zones.sort_custom(func(a, b): return a.noise_threshold > b.noise_threshold)
	for z in sorted_zones:
		if z and n >= z.noise_threshold:
			return z
	return null


func _log(msg: String) -> void:
	if debug_logging:
		print(msg)
