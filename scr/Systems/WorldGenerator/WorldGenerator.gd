@tool
extends Node2D
class_name WorldMapGenerator

## Стреляет сразу после того, как target был телепортирован на
## противоположный край карты (World Wrap). Передаёт его НОВУЮ мировую
## позицию. Подпишись на этот сигнал в скрипте камеры, чтобы принудительно
## "телепортировать" её вслед за игроком (reset_smoothing() у Camera2D),
## иначе камера со сглаживанием будет плавно и неправильно ехать через
## всю карту вместо мгновенного переноса.
signal world_wrapped(new_position: Vector2)

# ═══════════════════════════════════════════════════════════════════════════════
#  WorldMapGenerator — генерирует ТАЙЛОВЫЙ ландшафт (трава/вода) на карте
#  ФИКСИРОВАННОГО размера, но строит его ЧАНКАМИ, как твой старый ChunkManager —
#  чтобы не проседали кадры на большой карте.
#
#  ИДЕЯ:
#   • Карта делится на чанки map_size_chunks × chunk_size тайлов.
#   • Тип тайла (вода/суша) — ЧИСТАЯ функция от мировых координат тайла и шума.
#     Значит хранить данные чанка НЕ нужно — только флаг "чанк отрисован".
#     Это экономит память и убирает целый класс багов рассинхронизации.
#   • Отрисовка чанка — это ДВА пакетных вызова set_cells_terrain_connect()
#     (земля + вода), а не тысячи одиночных set_cell(). Так Godot сам
#     проставляет автотайлинг (терраса/берег) за один проход по соседям.
#   • Если задан target_path (обычно игрок) — чанки строятся/стираются вокруг
#     него (поток), и работа размазана по кадрам через chunks_per_frame,
#     чтобы не было хитчей. Если target_path пуст — вся (фиксированная!)
#     карта строится один раз при старте, тоже по бюджету кадра.
#   • Спец-структуры (лагеря, данжи) — используют тот же RNG/сид и
#     ресурс SpecialStructure.gd, который уже есть в проекте, чтобы не
#     плодить второй похожий класс. Генерация дорог убрана.
#   • WORLD WRAP: у карты больше нет "формы острова" и обрыва в пустоту —
#     карта всегда полностью занята сушей/водой (просто шум высоты).
#     Вместо этого добавлен ТОРОВЫЙ wrap: когда target (игрок) выходит за
#     нижний/верхний/левый/правый край карты, он мгновенно переносится на
#     противоположный край (как в старых Asteroids) — создаётся иллюзия
#     бесконечной планеты без физических границ. См. группу "World Wrap".
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
#  Размер карты и чанков
# ─────────────────────────────────────────
@export_group("Map")
## Размер карты в ЧАНКАХ (не в тайлах!). Например (20, 20) — карта из 20×20
## чанков. Итоговый размер карты в тайлах = это число × chunk_size.
## Карта строится вокруг точки (0,0) — то есть (0,0) всегда её центр.
@export var map_size_chunks: Vector2i = Vector2i(20, 20)
## Размер ОДНОГО чанка в тайлах. Чанк — это "блок" карты, который
## отрисовывается/стирается целиком за раз. Трогать обычно не нужно —
## 16×16 хорошо сбалансирован по производительности.
@export var chunk_size: Vector2i = Vector2i(16, 16)   # тайлов в чанке
## Уникальное имя этой локации/карты. Используется, чтобы сохранить сид
## генерации и собранные ресурсы отдельно для каждой локации — если у тебя
## несколько карт (например деревня и подземелье), у них должны быть
## РАЗНЫЕ location_id, иначе они перепутают сохранения друг друга.
@export var location_id: String = "world_map"
## Если включено — генератор будет печатать в консоль подробности о том,
## что он делает (сид карты, сколько чанков строится и т.п.). Полезно для
## отладки, в релизной сборке лучше выключить.
@export var debug_logging: bool = false

# ─────────────────────────────────────────
#  Слои TileMapLayer (перетащи ноды в инспекторе)
# ─────────────────────────────────────────
@export_group("Layers")
## TileMapLayer-нода, на которой рисуется СУША (трава). Обязательно перетащи
## сюда нужную ноду из сцены — без неё генератор не запустится.
@export var ground_layer: TileMapLayer      # трава/суша
## TileMapLayer-нода, на которой рисуется ВОДА. Можно оставить пустым —
## тогда вода будет рисоваться прямо на ground_layer тем же TileSet'ом.
@export var water_layer: TileMapLayer       # вода. Если не задан — вода красится в ground_layer тем же TileSet'ом

## Номер Terrain Set в твоём TileSet (вкладка TileSet → Terrains в Godot).
## Обычно 0, если у тебя один набор террейнов.
@export var ground_terrain_set: int = 0
## ID террейна "трава/суша" внутри выбранного Terrain Set.
@export var grass_terrain_id: int = 0
## ID террейна "вода" внутри выбранного Terrain Set.
@export var water_terrain_id: int = 1

@export_subgroup("Fallback (без Terrain)")
## Резервный режим — если Terrain Set не настроен или не найден, генератор
## рисует обычными тайлами по этим atlas-координатам (без авто-связывания
## краёв берега). Source id атласа с тайлом травы.
@export var grass_atlas_source_id: int = 0
## Координаты тайла травы внутри атласа (resource fallback-режима).
@export var grass_atlas_coords: Vector2i = Vector2i(0, 0)
## Source id атласа с тайлом воды (resource fallback-режима).
@export var water_atlas_source_id: int = 0
## Координаты тайла воды внутри атласа (resource fallback-режима).
@export var water_atlas_coords: Vector2i = Vector2i(0, 0)

# ─────────────────────────────────────────
#  Декоративные вариации травы (НЕ terrain-тайлы — обычные альтернативные
#  тайлы того же атласа, например "трава с цветами/камушками"). Автотайлинг
#  их не расставляет сам, поэтому раскидываем их вручную поверх готовой
#  земли, псевдослучайно и детерминированно (по сиду чанка).
# ─────────────────────────────────────────
@export_group("Grass Variation")
## Слой, куда рисуются декоративные тайлы травы (поверх ground_layer).
## Если не задан — рисуются прямо в ground_layer (может немного мешать
## пересчёту terrain-автосвязи на этом тайле в будущем — отдельный слой безопаснее).
@export var grass_variation_layer: TileMapLayer
## Atlas source id тайлсета, где лежат декоративные варианты травы (обычно
## тот же атлас, что и grass_atlas_source_id / GrassAutoTile.png и т.п.).
@export var grass_variation_atlas_source_id: int = 0
## Координаты тайла(ов)-вариаций в атласе (кликни на нужный тайл в панели
## "Тайлы" внизу — Godot покажет его atlas coords). Можно добавить несколько —
## тогда каждый раз будет выбираться случайный из списка.
@export var grass_variation_coords: Array[Vector2i] = []
## Шанс, что конкретный тайл травы получит декорацию (0..1).
@export_range(0.0, 1.0) var grass_variation_chance: float = 0.12
## Если true — декорации не ставятся на тайлы, граничащие с водой/дорогой
## (край автотайла выглядит иначе, декорация там может "торчать").
@export var grass_variation_avoid_edges: bool = true

# ─────────────────────────────────────────
#  Шум ландшафта
# ─────────────────────────────────────────
@export_group("Noise")
## Масштаб шума высоты — это "зум" узора суши/воды. МЕНЬШЕ значение = более
## КРУПНЫЕ материки/озёра (шум растянут). БОЛЬШЕ значение = более мелкая,
## рваная, "шумная" картинка суши/воды. Начни с 0.02 и подкручивай.
@export var noise_scale: float = 0.02
## Количество слоёв шума, наложенных друг на друга (fractal octaves).
## Больше слоёв = больше мелких деталей и неровностей на берегу,
## но чуть дороже по производительности. 3-4 обычно достаточно.
@export var noise_octaves: int = 3
## Порог высоты (0..1): всё что НИЖЕ этого значения — вода, всё что ВЫШЕ
## или равно — суша. Подними, чтобы было больше воды (остров меньше),
## опусти — чтобы было больше суши (остров больше).
@export_range(0.0, 1.0) var water_level: float = 0.35   # ниже этого — вода

# ─────────────────────────────────────────
#  Мировой wrap ("планета без краёв") — см. группу World Wrap ниже,
#  рядом со Streaming. Форма острова убрана полностью: карта теперь
#  сплошная (суша/вода по шуму высоты), а не парящий кусок с обрывом
#  в пустоту — обрыву просто неоткуда взяться, если у карты нет края.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
#  Специальные структуры (переиспользуем существующий ресурс)
# ─────────────────────────────────────────
@export_group("Special Structures")
## Список особых построек (лагеря, данжи и т.п.), которые генератор
## попробует расставить по карте. Каждый элемент — ресурс SpecialStructure
## с собственными настройками (тип, минимальные дистанции между постройками).
@export var special_structures: Array[SpecialStructure] = []
## Сколько раз генератор попытается найти место под структуру, прежде чем
## сдаться и пропустить её. Больше значение = выше шанс, что все структуры
## из списка всё-таки поместятся на карту, но дольше генерация на старте.
@export var max_structure_attempts: int = 200

# ─────────────────────────────────────────
#  Ресурсы локации (кусты, руда, деревья и т.п. — переиспользуем Generation.gd)
# ─────────────────────────────────────────
@export_group("Resources")
## Список того, что может появиться на земле в этой локации, с весами
## (Generation.spawn_weight) — так же, как в старом WorldGenerator.
@export var resource_items: Array[Generation] = []
## Сколько ресурсов пытаемся посадить на один чанк (до фильтрации по спейсингу/воде).
@export var resources_per_chunk: int = 4
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

# ─────────────────────────────────────────
#  Зоны (биомы) — переиспользуем существующий ресурс GenerationZone.gd
# ─────────────────────────────────────────
@export_group("Zones")
## Зоны определяют доминантные ресурсы в разных участках карты. Зона активна
## в чанке, если значение zone-шума в этом чанке не ниже её noise_threshold.
## Если зон несколько — побеждает та, у которой порог выше (более
## "требовательные"/редкие зоны приоритетнее общих).
@export var zones: Array[GenerationZone] = []
## Масштаб отдельного шума, который определяет ГРАНИЦЫ биомов/зон (не путать
## с noise_scale — тем шумом определяется суша/вода). Меньше значение = более
## крупные, растянутые зоны биомов, больше = зоны мельче и чаще чередуются.
@export var zone_noise_scale: float = 0.008

# ─────────────────────────────────────────
#  Потоковая генерация (streaming)
# ─────────────────────────────────────────
@export_group("Streaming")
## Нода, вокруг которой строится/стирается мир (обычно игрок).
## Пусто = вся карта строится один раз при старте (подходит для небольших карт).
@export var target_path: NodePath
## Радиус (в чанках) вокруг игрока, который держится построенным. Чанки
## за пределами этого радиуса стираются, чтобы не тратить память/CPU на
## невидимые игроку части карты. Больше значение = дальше видно карту
## заранее, но больше нагрузка.
@export var stream_radius_chunks: int = 3
## Сколько чанков красится ОДНИМ вызовом set_cells_terrain_connect() за кадр
## (см. _build_chunks_batch). Стоимость самого вызова почти фиксирована и не
## растёт линейно от количества клеток в нём — поэтому выгоднее красить
## сразу пачку чанков одним вызовом, чем чанк за чанком. Больше значение —
## меньше вызовов и меньше суммарный лаг при подгрузке, но один такой кадр
## обрабатывает больше данных за раз (крупная пачка на очень слабом
## железе/встроенной графике может дать один более заметный, но короткий,
## стук вместо растянутой серии мелких). 8-24 обычно хороший баланс.
@export var max_chunks_per_batch: int = 16
## Бюджет ВРЕМЕНИ на СТИРАНИЕ чанков за кадр (мс). На постройку больше не
## влияет — постройка теперь батчится через max_chunks_per_batch (см. выше),
## потому что оказалось, что дорог не объём покраски чанка, а число вызовов
## set_cells_terrain_connect(), так что "бюджет по времени на чанк" для
## постройки больше не имеет смысла.
@export var chunk_time_budget_ms: float = 3.0
## Сколько РЕСУРСОВ (кустов/руды/деревьев) реально инстанцировать (instantiate +
## add_child) за один кадр. Покраска тайлов чанка быстрая (пакетный вызов), а вот
## заспавнить сразу десятки физических объектов (Harvestable — коллизии, шейдеры,
## частицы) в один кадр — самый частый источник хитчей, особенно на старте или
## когда игрок быстро бежит и сразу открывается много новых чанков. Поэтому
## инстанцирование ресурсов размазано по кадрам отдельно от покраски тайлов.
@export var resource_spawn_per_frame: int = 6

# ─────────────────────────────────────────
#  World Wrap — "планета без краёв". Работает ТОЛЬКО в режиме стриминга
#  (когда задан target_path), потому что оборачивать нечего, если карта не
#  привязана к движению конкретной ноды.
# ─────────────────────────────────────────
@export_group("World Wrap")
## Если включено — карта ведёт себя как тор без краёв: как только target
## (обычно игрок) пересекает нижнюю/верхнюю/левую/правую границу карты,
## он МГНОВЕННО переносится на противоположную сторону (классический
## screen-wrap, как в Asteroids). Чанки на новом месте уже сгенерированы
## детерминированно тем же шумом/сидом — поэтому "другая сторона" всегда
## выглядит одинаково при каждом переходе, никаких швов и дублей карты.
@export var world_wrap_enabled: bool = true
## Небольшой запас (px), на который позиция "утапливается" внутрь
## противоположного края после переноса, а не ставится ровно на границу.
## Нужен, чтобы игрок не застрял и не задребезжал туда-обратно, если стоит
## вплотную к краю (граница есть — обрыва за ней теперь просто нет).
@export var world_wrap_inset: float = 1.0

# ─────────────────────────────────────────
#  Внутреннее состояние
# ─────────────────────────────────────────
var _noise: FastNoiseLite
var _zone_noise: FastNoiseLite
var _rng: RandomNumberGenerator
var _location_seed: int
var _target: Node2D

## Границы карты в чанках — карта теперь строится ВОКРУГ (0,0), а не только
## в положительном квадранте, чтобы игрок, заспавненный у мировых координат
## (0,0), оказывался в ЦЕНТРЕ карты, а не в углу.
var _chunk_min: Vector2i
var _chunk_max: Vector2i   # эксклюзивная граница

var _chunk_zone: Dictionary = {}         # Vector2i(chunk) -> GenerationZone или null
var _save_system: Node   # автозагрузка SaveSystem — берём по пути, т.к. class_name SaveSystem
						  # конфликтует с именем синглтона при прямом обращении "SaveSystem.xxx()"

var _built_chunks: Dictionary = {}      # Vector2i(chunk) -> true, если чанк отрисован
var _build_queue: Array[Vector2i] = []  # чанки, которые надо построить
var _erase_queue: Array[Vector2i] = []  # чанки, которые надо стереть
var _queued_set: Dictionary = {}        # чанки уже в одной из очередей (анти-дубликат)

var _placed_structures: Array[Dictionary] = []
var _tile_size: int = 16   # берётся из TileSet автоматически в _ready()
var _use_ground_terrain: bool = false

var _chunk_resource_nodes: Dictionary = {}   # Vector2i(chunk) -> Array[Node], для очистки при erase_chunk
var _harvested_set: Dictionary = {}          # "x,y" -> true, снято через SaveSystem.load_harvested()
var _total_resource_weight: float = 0.0

## Ресурсы, для которых уже выбрана позиция/тип (дёшево), но ЕЩЁ НЕ
## инстанцированы (дорого) — обрабатываются по resource_spawn_per_frame за кадр.
## Каждый элемент: { "chunk": Vector2i, "pos": Vector2, "item": Generation }
var _pending_resource_spawns: Array[Dictionary] = []


# ═══════════════════════════════════════════════════════════════════════════════
#  СТАРТ
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if ground_layer == null:
		push_warning("[WorldMapGenerator] ground_layer не назначен — генерация невозможна.")
		return

	_save_system = get_node_or_null("/root/SaveSystem")
	if _save_system == null:
		push_warning("[WorldMapGenerator] Автозагрузка SaveSystem не найдена по пути /root/SaveSystem — проверь Project Settings → Autoload.")

	_apply_performance_preset()
	var sm := get_node_or_null("/root/SettingsManager")
	if sm and sm.has_signal("settings_changed"):
		sm.settings_changed.connect(_apply_performance_preset)

	_setup_seed()
	_read_tile_size()
	_use_ground_terrain = _check_ground_terrain_valid()
	_compute_chunk_bounds()
	_load_harvested()

	for item in resource_items:
		if item:
			_total_resource_weight += item.spawn_weight

	if not target_path.is_empty():
		_target = get_node_or_null(target_path)
		if _target == null:
			push_warning("[WorldMapGenerator] target_path='%s' не резолвится в ноду — стриминг не запустится, карта не будет построена." % target_path)

	if not special_structures.is_empty():
		_place_special_structures()

	if _target:
		# Игрок мог заспавниться на позиции, которая оказывается водой
		# (например, всегда на (0,0), а (0,0) теперь центр карты, но не
		# гарантия суши при экстремальных настройках шума/water_level).
		# Подстраховываемся и переносим его на ближайшую сушу ДО первой
		# отрисовки чанков.
		if not is_land_at(_target.global_position):
			var land_pos := find_nearest_land(_target.global_position)
			_target.global_position = land_pos
			_log("[WorldMapGenerator] Точка спавна была не на суше — игрок перенесён на ближайшую сушу: %s" % land_pos)
		_refresh_stream_queues()
	else:
		# Небольшая/фиксированная карта без стриминга — строим всё сразу,
		# но всё равно по бюджету кадра, чтобы не было единого хитча на старте.
		for cy in range(_chunk_min.y, _chunk_max.y):
			for cx in range(_chunk_min.x, _chunk_max.x):
				_enqueue_build(Vector2i(cx, cy))

	set_process(true)
	print("[WorldMapGenerator] Старт: use_terrain=%s, target=%s, в очереди на постройку=%d чанков" % [
		_use_ground_terrain, str(_target), _build_queue.size()
	])


## Проверяет, реально ли существует Terrain Set с нужным id в TileSet.
## Если нет — переключаемся на резервный режим (обычные atlas-тайлы),
## иначе set_cells_terrain_connect() молча ничего не рисует.
func _check_ground_terrain_valid() -> bool:
	if ground_terrain_set < 0:
		return false
	if ground_layer.tile_set == null:
		push_warning("[WorldMapGenerator] У ground_layer не назначен TileSet.")
		return false
	var ts := ground_layer.tile_set
	if ground_terrain_set >= ts.get_terrain_sets_count():
		push_warning("[WorldMapGenerator] ground_terrain_set=%d не существует в TileSet (terrain sets: %d). Переключаюсь на fallback-режим (atlas coords)." % [ground_terrain_set, ts.get_terrain_sets_count()])
		return false
	var terrains_count := ts.get_terrains_count(ground_terrain_set)
	if grass_terrain_id >= terrains_count or water_terrain_id >= terrains_count:
		push_warning("[WorldMapGenerator] grass_terrain_id/water_terrain_id вне диапазона (в terrain set %d их всего %d). Переключаюсь на fallback-режим." % [ground_terrain_set, terrains_count])
		return false
	return true


func _setup_seed() -> void:
	_location_seed = _get_or_create_location_seed(location_id)

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_octaves = noise_octaves
	_noise.frequency = noise_scale
	_noise.seed = _location_seed

	# Отдельные шумы для зон и заражения — со своим сидом (сдвинутым от основного),
	# чтобы биомы/заражение не были жёстко привязаны к форме берегов ландшафта.
	_zone_noise = FastNoiseLite.new()
	_zone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_zone_noise.fractal_octaves = 2
	_zone_noise.frequency = zone_noise_scale
	_zone_noise.seed = _location_seed + 1

	_rng = RandomNumberGenerator.new()
	_rng.seed = _location_seed

	_log("[WorldMapGenerator] Сид '%s': %d" % [location_id, _location_seed])


## Считает границы карты в чанках так, чтобы (0,0) оказался в её ЦЕНТРЕ
## (а не в углу, как раньше). При нечётном map_size_chunks лишний чанк
## уходит в положительную сторону — это не критично и не ломает симметрию заметно.
func _compute_chunk_bounds() -> void:
	_chunk_min = Vector2i(-map_size_chunks.x / 2, -map_size_chunks.y / 2)
	_chunk_max = _chunk_min + map_size_chunks


## Читает сид локации из world_seeds.json (через SaveSystem). Если для этой
## локации сида ещё нет — создаёт новый (детерминированно от master_seed +
## location_id, чтобы одинаковый мастер-сид всегда давал одинаковую карту)
## и сразу дописывает его в тот же файл — при следующей загрузке слота
## SaveSystem.load_world_seeds() вернёт уже сохранённое значение.
func _get_or_create_location_seed(id: String) -> int:
	var slot: String = Global.current_save_slot
	if slot.is_empty() or _save_system == null:
		push_warning("[WorldMapGenerator] current_save_slot пуст или SaveSystem недоступен — сид не сохраняется.")
		return ResourceUID.create_id()

	var world_data: Dictionary = _save_system.load_world_seeds()
	var location_seeds: Dictionary = world_data.get("location_seeds", {})

	if location_seeds.has(id):
		return int(location_seeds[id])

	var master_seed: int = world_data.get("master_seed", 0)
	var world_seed: String = world_data.get("world_seed", "")
	if world_data.is_empty():
		# Для этого слота вообще ещё нет world_seeds.json — заводим мастер-сид один раз,
		# дальше все локации (включая старый WorldGenerator) должны брать сид отсюда же.
		master_seed = randi()
		world_seed = str(master_seed)

	var new_seed: int = hash(str(master_seed) + "_" + id)
	location_seeds[id] = new_seed

	if not _save_system.save_world_seeds(master_seed, world_seed, location_seeds):
		push_warning("[WorldMapGenerator] Не удалось сохранить сид локации '%s'." % id)

	return new_seed


## Загружает уже собранные (harvested) позиции для этой локации из SaveSystem,
## чтобы при повторном построении чанка на этих местах ресурс не появился снова.
func _load_harvested() -> void:
	if not track_harvested or _save_system == null:
		return
	var all_harvested: Dictionary = _save_system.load_harvested()
	var positions: Array = all_harvested.get(location_id, [])
	for p in positions:
		if p is Dictionary and p.has("x") and p.has("y"):
			_harvested_set[_snap_key(Vector2(p["x"], p["y"]))] = true


func _snap_key(pos: Vector2) -> String:
	return "%d,%d" % [roundi(pos.x), roundi(pos.y)]


func _read_tile_size() -> void:
	if ground_layer and ground_layer.tile_set:
		var ts := ground_layer.tile_set.tile_size
		_tile_size = int(max(ts.x, 1))


# ═══════════════════════════════════════════════════════════════════════════════
#  ПОТОК (streaming) — вызывается каждый кадр, но с бюджетом
# ═══════════════════════════════════════════════════════════════════════════════

var _stream_refresh_timer: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _target:
		# Wrap проверяем КАЖДЫЙ кадр (не по таймеру, в отличие от стриминга) —
		# иначе игрок на пару кадров визуально "вылезет" за пределы карты
		# на быстром движении/дэше, прежде чем его перенесёт.
		_handle_world_wrap()
		_stream_refresh_timer -= delta
		if _stream_refresh_timer <= 0.0:
			_stream_refresh_timer = 0.25   # не пересчитываем радиус каждый кадр — 4 раза в сек достаточно
			_refresh_stream_queues()

	_process_queue_budget()


## Подтягивает текущий пресет оптимизации из SettingsManager (Настройки →
## Оптимизация) и присваивает его значения соответствующим @export-полям
## этого генератора (stream_radius_chunks, max_chunks_per_batch, и т.д.).
## Вызывается один раз при старте и повторно при каждом изменении настроек
## (см. подписку на settings_changed в _ready). Если SettingsManager не
## подключён как автозагрузка — просто ничего не делает, остаются значения
## по умолчанию из инспектора, как и раньше.
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


## Реализует "планету без краёв": если target вышел за прямоугольник карты
## (get_map_rect_px()) — переносит его на противоположную сторону с тем же
## запасом (world_wrap_inset), с которым он "провалился" за границу, плюс
## инсет, чтобы не дребезжать на самой кромке. X и Y обрабатываются
## независимо, поэтому диагональный выход из угла карты тоже отрабатывает
## правильно (перенесёт сразу по обеим осям за один кадр).
func _handle_world_wrap() -> void:
	if not world_wrap_enabled:
		return

	var rect := get_map_rect_px()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var pos := _target.global_position
	var wrapped := pos
	var did_wrap := false

	if pos.x < rect.position.x:
		wrapped.x = rect.position.x + rect.size.x - world_wrap_inset
		did_wrap = true
	elif pos.x >= rect.position.x + rect.size.x:
		wrapped.x = rect.position.x + world_wrap_inset
		did_wrap = true

	if pos.y < rect.position.y:
		wrapped.y = rect.position.y + rect.size.y - world_wrap_inset
		did_wrap = true
	elif pos.y >= rect.position.y + rect.size.y:
		wrapped.y = rect.position.y + world_wrap_inset
		did_wrap = true

	if not did_wrap:
		return

	_target.global_position = wrapped
	_refresh_stream_queues()   # сразу подгружаем чанки вокруг нового места, не ждём таймер
	world_wrapped.emit(wrapped)
	_log("[WorldMapGenerator] World Wrap: %s -> %s" % [pos, wrapped])


## Пересчитывает, какие чанки должны быть построены/стёрты, исходя из позиции target.
func _refresh_stream_queues() -> void:
	var center := _world_to_chunk(_target.global_position)
	var r := stream_radius_chunks

	var wanted := {}
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := center + Vector2i(dx, dy)
			if _chunk_in_bounds(c):
				wanted[c] = true

	for c in wanted.keys():
		if not _built_chunks.has(c):
			_enqueue_build(c)

	for c in _built_chunks.keys():
		if not wanted.has(c):
			_enqueue_erase(c)


func _enqueue_build(c: Vector2i) -> void:
	if _built_chunks.has(c) or _queued_set.has(c): return
	_build_queue.append(c)
	_queued_set[c] = true


func _enqueue_erase(c: Vector2i) -> void:
	if _queued_set.has(c): return
	_erase_queue.append(c)
	_queued_set[c] = true


func _process_queue_budget() -> void:
	var budget_usec := int(chunk_time_budget_ms * 1000.0)
	var start := Time.get_ticks_usec()

	# Стройку приоритизируем над стиранием — важнее не показать дыру под игроком.
	if not _build_queue.is_empty():
		_build_chunks_batch()

	while not _erase_queue.is_empty() and (Time.get_ticks_usec() - start) < budget_usec:
		var c: Vector2i = _erase_queue.pop_front()
		_queued_set.erase(c)
		_erase_chunk(c)

	_process_resource_spawn_budget()


## Инстанцирует не больше resource_spawn_per_frame ресурсов за кадр — покраска
## тайлов чанка уже дешёвая (пакетный вызов), а вот создание физических нод
## (Harvestable: коллизии/шейдеры/частицы) пачкой в один кадр и есть хитч.
func _process_resource_spawn_budget() -> void:
	var spawned := 0
	while spawned < resource_spawn_per_frame and not _pending_resource_spawns.is_empty():
		var entry: Dictionary = _pending_resource_spawns.pop_front()
		var c: Vector2i = entry["chunk"]
		# Чанк мог успеть стереться, пока запись ждала своей очереди — не спавним в никуда.
		if not _built_chunks.has(c):
			continue
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

	var c: Vector2i = entry["chunk"]
	if not _chunk_resource_nodes.has(c):
		_chunk_resource_nodes[c] = []
	_chunk_resource_nodes[c].append(obj)


# ═══════════════════════════════════════════════════════════════════════════════
#  ПОСТРОЙКА / СТИРАНИЕ ЧАНКА
# ═══════════════════════════════════════════════════════════════════════════════

## Строит СРАЗУ ПАЧКУ чанков (до max_chunks_per_batch штук) за ОДИН вызов
## set_cells_terrain_connect() на пачку, а не один вызов на каждый чанк.
## ПОЧЕМУ: замеры (debug_logging) показали, что стоимость одного вызова
## set_cells_terrain_connect() почти НЕ зависит от количества клеток в нём —
## что для 5 клеток, что для 250 цена одна и та же (Godot синхронно
## пересобирает физику/навигацию TileMapLayer на каждый вызов). Значит дорог
## не объём покраски, а само ЧИСЛО вызовов — поэтому чанки больше не красятся
## по одному, их клетки собираются вместе и красятся одним вызовом на всю пачку.
## chunk_time_budget_ms здесь больше не при делах (он был бюджетом на чанк,
## а не на вызов) — размер пачки регулируется max_chunks_per_batch.
func _build_chunks_batch() -> void:
	var chunks_in_batch: Array[Vector2i] = []
	var all_land: Array[Vector2i] = []
	var all_water: Array[Vector2i] = []
	var per_chunk_land: Dictionary = {}   # Vector2i(chunk) -> Array[Vector2i], нужно дальше для декора/ресурсов

	while not _build_queue.is_empty() and chunks_in_batch.size() < max_chunks_per_batch:
		var c: Vector2i = _build_queue.pop_front()
		_queued_set.erase(c)
		chunks_in_batch.append(c)

		var land_cells: Array[Vector2i] = []
		var water_cells: Array[Vector2i] = []
		var origin := c * chunk_size
		for ly in chunk_size.y:
			for lx in chunk_size.x:
				var cell := origin + Vector2i(lx, ly)
				match _cell_kind(cell):
					CellKind.WATER:
						water_cells.append(cell)
					CellKind.LAND:
						land_cells.append(cell)

		per_chunk_land[c] = land_cells
		all_land.append_array(land_cells)
		all_water.append_array(water_cells)

	if chunks_in_batch.is_empty():
		return

	var terrain_t0 := Time.get_ticks_usec()
	var w_layer: TileMapLayer = water_layer if water_layer else ground_layer

	if _use_ground_terrain:
		# Один вызов на ВСЮ пачку чанков вместо одного вызова на каждый —
		# именно это убирает фиксированную стоимость за вызов, умноженную на N чанков.
		if not all_land.is_empty():
			ground_layer.set_cells_terrain_connect(all_land, ground_terrain_set, grass_terrain_id, true)
		if not all_water.is_empty():
			w_layer.set_cells_terrain_connect(all_water, ground_terrain_set, water_terrain_id, true)
	else:
		# Fallback: без автосвязи краёв, но гарантированно рисует что-то видимое.
		for cell in all_land:
			ground_layer.set_cell(cell, grass_atlas_source_id, grass_atlas_coords)
		for cell in all_water:
			w_layer.set_cell(cell, water_atlas_source_id, water_atlas_coords)
	var terrain_ms := (Time.get_ticks_usec() - terrain_t0) / 1000.0

	var grass_ms := 0.0
	var resource_ms := 0.0
	for c in chunks_in_batch:
		var land_cells: Array[Vector2i] = per_chunk_land[c]

		var g_t0 := Time.get_ticks_usec()
		_paint_grass_variations(c, land_cells)
		grass_ms += (Time.get_ticks_usec() - g_t0) / 1000.0

		_built_chunks[c] = true

		var r_t0 := Time.get_ticks_usec()
		_spawn_chunk_resources(c, land_cells)
		resource_ms += (Time.get_ticks_usec() - r_t0) / 1000.0

	if debug_logging:
		_log("[WorldMapGenerator] Пачка из %d чанков: террейн=%.2f мс, декор травы=%.2f мс, ресурсы=%.2f мс, итого=%.2f мс" % [
			chunks_in_batch.size(), terrain_ms, grass_ms, resource_ms, terrain_ms + grass_ms + resource_ms
		])



func _erase_chunk(c: Vector2i) -> void:
	if _chunk_resource_nodes.has(c):
		for node in _chunk_resource_nodes[c]:
			if is_instance_valid(node):
				node.queue_free()
		_chunk_resource_nodes.erase(c)

	# Ресурсы этого чанка, которые ещё ждут своей очереди на instantiate,
	# больше не нужны — иначе они всплывут позже уже для стёртого чанка
	# (не страшно само по себе, _process_resource_spawn_budget это отфильтрует,
	# но лучше не копить память на давно неактуальные записи).
	if not _pending_resource_spawns.is_empty():
		_pending_resource_spawns = _pending_resource_spawns.filter(func(e): return e["chunk"] != c)

	var w_layer: TileMapLayer = water_layer if water_layer else ground_layer
	var origin := c * chunk_size
	for ly in chunk_size.y:
		for lx in chunk_size.x:
			var cell := origin + Vector2i(lx, ly)
			ground_layer.erase_cell(cell)
			if w_layer != ground_layer:
				w_layer.erase_cell(cell)
			if grass_variation_layer and grass_variation_layer != ground_layer:
				grass_variation_layer.erase_cell(cell)
	_built_chunks.erase(c)


## Возвращает высоту рельефа 0..1 в точке (мировые координаты тайла).
func _elevation_at(cell: Vector2i) -> float:
	return (_noise.get_noise_2d(cell.x, cell.y) + 1.0) * 0.5


## Два возможных состояния тайла карты. VOID убран вместе с формой острова —
## у карты больше нет "обрыва в пустоту", она всюду либо суша, либо вода,
## а за физический край теперь отвечает World Wrap (см. _handle_world_wrap).
enum CellKind { WATER, LAND }

## Определяет, что должно быть нарисовано в этой клетке:
## WATER — высота ниже water_level (озеро/пруд/океан).
## LAND  — высота выше или равна water_level (обычная суша).
func _cell_kind(cell: Vector2i) -> int:
	if _elevation_at(cell) < water_level:
		return CellKind.WATER
	return CellKind.LAND


func _is_land(cell: Vector2i) -> bool:
	return _cell_kind(cell) == CellKind.LAND


## Раскидывает декоративные вариации травы (тайлы вроде "трава с цветами",
## которые НЕ являются частью terrain-автотайлинга) по уже готовой земле
## чанка — псевдослучайно, но детерминированно (свой RNG от сида чанка,
## как и у ресурсов), так что при пересборке чанка узор не "мигает".
func _paint_grass_variations(c: Vector2i, land_cells: Array[Vector2i]) -> void:
	if grass_variation_coords.is_empty() or grass_variation_chance <= 0.0 or land_cells.is_empty():
		return

	var deco_layer: TileMapLayer = grass_variation_layer if grass_variation_layer else ground_layer

	var deco_rng := RandomNumberGenerator.new()
	deco_rng.seed = hash("%d_deco_%d_%d" % [_location_seed, c.x, c.y])

	for cell in land_cells:
		if deco_rng.randf() > grass_variation_chance:
			continue
		if grass_variation_avoid_edges and _touches_non_land(cell):
			continue
		var coord: Vector2i = grass_variation_coords[deco_rng.randi() % grass_variation_coords.size()]
		deco_layer.set_cell(cell, grass_variation_atlas_source_id, coord)


## true, если у клетки есть сосед-НЕ-суша (вода/т.п.) — используется, чтобы не
## сажать декорацию на кромку берега, где и так уже автотайл-переход.
func _touches_non_land(cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _is_land(cell + d):
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
#  СПЕЦСТРУКТУРЫ (генерируются один раз при старте, не по чанкам —
#  их обычно немного, поэтому линейный проход не является узким местом)
# ═══════════════════════════════════════════════════════════════════════════════

## Расстановка лагерей/данжей — та же логика мин-дистанций, что и в WorldGenerator,
## но точки берутся из тайловой сетки суши, а не из Polygon2D формы.
func _place_special_structures() -> void:
	var sorted := special_structures.duplicate()
	sorted.sort_custom(func(a, b): return a.spawn_priority > b.spawn_priority)

	var tile_min := _chunk_min * chunk_size
	var tile_max := _chunk_max * chunk_size   # эксклюзивно

	for structure in sorted:
		if not structure.generation_item or _rng.randf() > structure.spawn_chance:
			continue

		var placed := 0
		for _attempt in range(max_structure_attempts):
			if placed >= structure.max_instances:
				break
			var cell := Vector2i(_rng.randi_range(tile_min.x, tile_max.x - 1), _rng.randi_range(tile_min.y, tile_max.y - 1))
			if not _is_land(cell):
				continue
			var pos := Vector2(cell) * _tile_size
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


## Решает, ЧТО и ГДЕ заспавнить на суше чанка (дёшево — без instantiate/add_child)
## и складывает решения в очередь _pending_resource_spawns, которая расходуется
## по resource_spawn_per_frame за кадр в _process_resource_spawn_budget().
## RNG — свой, детерминированный от (сид локации + координаты чанка), не трогает
## общий _rng (тот расходуется один раз на дороги/структуры при старте) — так при
## повторной постройке того же чанка результат всегда одинаковый.
func _spawn_chunk_resources(c: Vector2i, land_cells: Array[Vector2i]) -> void:
	if land_cells.is_empty():
		return

	# Пул ресурсов для ЭТОГО чанка = общий resource_items + (если чанк попал в
	# зону) dominant_items этой зоны с их spawn_weight_multiplier — так зоны
	# реально влияют на то, что спавнится, а не только на визуал/заражение.
	var pool: Array[Generation] = []
	var weights: Array[float] = []
	var total_weight := 0.0

	for item in resource_items:
		if item == null:
			continue
		pool.append(item)
		weights.append(item.spawn_weight)
		total_weight += item.spawn_weight

	var zone := _zone_at(c)
	if zone and not zone.dominant_items.is_empty():
		for item in zone.dominant_items:
			if item == null:
				continue
			var w: float = item.spawn_weight * zone.spawn_weight_multiplier
			pool.append(item)
			weights.append(w)
			total_weight += w

	if pool.is_empty() or total_weight <= 0.0:
		return

	var chunk_rng := RandomNumberGenerator.new()
	chunk_rng.seed = hash("%d_res_%d_%d" % [_location_seed, c.x, c.y])

	var placed_here: Array[Vector2] = []
	var spacing_sq := resource_min_spacing * resource_min_spacing
	var structure_clearance_sq := resource_structure_clearance * resource_structure_clearance
	var queued_any := false

	for _i in resources_per_chunk:
		var cell: Vector2i = land_cells[chunk_rng.randi() % land_cells.size()]
		var pos := Vector2(cell) * _tile_size

		if track_harvested and _harvested_set.has(_snap_key(pos)):
			continue

		var too_close := false
		for p in placed_here:
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

		var item := _pick_weighted_resource(chunk_rng, pool, weights, total_weight)
		if item == null or not item.Generation_scene:
			continue

		var scene_count := 1 + item.Generation_random_versions.size()
		var scene_index := chunk_rng.randi() % scene_count

		_pending_resource_spawns.append({
			"chunk": c,
			"pos": pos,
			"item": item,
			"scene_index": scene_index,
			"scale": _pick_random_scale_value(item, chunk_rng),
		})
		placed_here.append(pos)
		queued_any = true

	# Регистрируем чанк даже без готовых нод, чтобы _erase_chunk знал, что для
	# него могут быть записи в очереди (актуальный список нод допишется по мере
	# фактического спавна в _instantiate_resource()).
	if queued_any and not _chunk_resource_nodes.has(c):
		_chunk_resource_nodes[c] = []


## Взвешенный выбор ресурса по весам пула (общие + зональные ресурсы вместе).
func _pick_weighted_resource(rng: RandomNumberGenerator, pool: Array[Generation], weights: Array[float], total: float) -> Generation:
	var roll := rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return null


## Выбирает случайный размер из Generation.random_scales (Standart/Middle/Big
## и т.п.), либо null, если применять размер не нужно/нечего — как было в
## старом WorldGenerator, а не всегда scale=(1,1).
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


## Вызови этот метод из скрипта самого ресурса, когда игрок его собрал/уничтожил —
## освобождает ноду и запоминает позицию через SaveSystem.save_harvested(), чтобы
## при повторном заходе в локацию (или возврате в этот чанк) он не заспавнился снова.
func mark_resource_harvested(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var pos: Vector2 = node.global_position
	node.queue_free()

	if not track_harvested:
		return
	_harvested_set[_snap_key(pos)] = true

	if _save_system == null:
		return
	var all_harvested: Dictionary = _save_system.load_harvested()
	var positions: Array = all_harvested.get(location_id, [])
	positions.append({ "x": pos.x, "y": pos.y })
	all_harvested[location_id] = positions
	if not _save_system.save_harvested(all_harvested):
		push_warning("[WorldMapGenerator] Не удалось сохранить harvested для '%s'." % location_id)


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
#  ВСПОМОГАТЕЛЬНЫЕ / ПУБЛИЧНЫЙ API
# ═══════════════════════════════════════════════════════════════════════════════

func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	var cell := Vector2i(world_pos / _tile_size)
	return Vector2i(
		floori(float(cell.x) / chunk_size.x),
		floori(float(cell.y) / chunk_size.y)
	)


func _chunk_in_bounds(c: Vector2i) -> bool:
	return c.x >= _chunk_min.x and c.y >= _chunk_min.y and c.x < _chunk_max.x and c.y < _chunk_max.y


## Публичные хелперы — например, чтобы WorldGenerator (спавнер объектов) не
## сажал кусты в воду: WorldMapGenerator.is_water_at(pos).
func is_water_at(world_pos: Vector2) -> bool:
	var cell := Vector2i(world_pos / _tile_size)
	return _cell_kind(cell) == CellKind.WATER

## Пустоты (VOID) в проекте больше нет — карта торовая, у неё нет обрыва
## в пустоту, физический край карты просто оборачивается World Wrap'ом
## (см. world_wrapped/_handle_world_wrap). Функция оставлена ради обратной
## совместимости с кодом, который мог её вызывать, и всегда возвращает false.
func is_void_at(world_pos: Vector2) -> bool:
	return false

## true только если это обычная твёрдая суша (не вода).
func is_land_at(world_pos: Vector2) -> bool:
	var cell := Vector2i(world_pos / _tile_size)
	return _cell_kind(cell) == CellKind.LAND


## Ищет ближайший тайл суши к заданной мировой позиции — расширяющимися
## кольцами (спираль по квадратным "рамкам", а не по всей площади, иначе
## поиск был бы O(radius^3) вместо O(radius^2)). Используется, чтобы игрок
## никогда не спавнился в воде, даже если его точка спавна (0,0) по шуму
## оказалась водой.
func find_nearest_land(from_world_pos: Vector2, max_radius_tiles: int = 64) -> Vector2:
	var start_cell := Vector2i(from_world_pos / _tile_size)
	if _is_land(start_cell):
		return _cell_center_px(start_cell)

	for radius in range(1, max_radius_tiles + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(absi(dx), absi(dy)) != radius:
					continue   # только периметр текущего кольца
				var cell := start_cell + Vector2i(dx, dy)
				if not _chunk_in_bounds(_world_to_chunk(_cell_center_px(cell))):
					continue
				if _is_land(cell):
					return _cell_center_px(cell)

	push_warning("[WorldMapGenerator] find_nearest_land: суша не найдена в радиусе %d тайлов от %s — возвращаю исходную позицию." % [max_radius_tiles, from_world_pos])
	return from_world_pos


func _cell_center_px(cell: Vector2i) -> Vector2:
	return Vector2(cell) * _tile_size + Vector2(_tile_size, _tile_size) * 0.5


# ─────────────────────────────────────────
#  Зоны по чанкам
# ─────────────────────────────────────────

## Возвращает зону, "владеющую" данным чанком (или null, если зон нет,
## либо шум в этой точке не превысил порог ни одной из них). Результат
## кэшируется на чанк — шум не пересчитывается повторно.
func _zone_at(c: Vector2i) -> GenerationZone:
	if _chunk_zone.has(c):
		return _chunk_zone[c]

	var result: GenerationZone = null
	if not zones.is_empty():
		var center := Vector2(c * chunk_size) + Vector2(chunk_size) * 0.5
		var n := (_zone_noise.get_noise_2d(center.x, center.y) + 1.0) * 0.5

		var sorted_zones := zones.duplicate()
		sorted_zones.sort_custom(func(a, b): return a.noise_threshold > b.noise_threshold)
		for z in sorted_zones:
			if z and n >= z.noise_threshold:
				result = z
				break

	_chunk_zone[c] = result
	return result


func get_zone_at(world_pos: Vector2) -> GenerationZone:
	return _zone_at(_world_to_chunk(world_pos))

func get_map_size_px() -> Vector2:
	return Vector2(map_size_chunks * chunk_size * _tile_size)

## Прямоугольник карты в мировых координатах — теперь карта центрирована
## на (0,0), так что этот rect не начинается в (0,0), а окружает его.
## Полезно для лимитов камеры и т.п.
func get_map_rect_px() -> Rect2:
	var origin := Vector2(_chunk_min * chunk_size * _tile_size)
	return Rect2(origin, get_map_size_px())

func get_placed_structures() -> Array[Dictionary]:
	return _placed_structures

func _log(msg: String) -> void:
	if debug_logging:
		print(msg)
