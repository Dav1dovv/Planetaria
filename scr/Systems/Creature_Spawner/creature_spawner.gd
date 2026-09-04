# creature_spawner.gd
#
# ИЗМЕНЕНИЯ В ЭТОЙ ВЕРСИИ:
#  • Чистка мёртвых ссылок из _tracked перенесена из _physics_process() (каждый кадр)
#    в _check_despawn() (раз в despawn_check_interval). Раньше при большом числе
#    существ это был лишний проход по массиву 60 раз в секунду без реальной нужды.
#  • Если despawn_enabled == false, чистка мёртвых ссылок всё равно делается —
#    отдельным лёгким таймером _cleanup_timer, чтобы _tracked не пух бесконечно.
#  • _cmd_clear(): расстояния до игрока считаются один раз в массив пар,
#    а не пересчитываются на каждое сравнение внутри sort_custom.
extends Node2D
class_name CreatureSpawner

# ─────────────────────────────────────────────
#  НАСТРОЙКИ
# ─────────────────────────────────────────────
@export_category("Spawner Settings")
@export var is_active: bool = true
@export var player: Node2D
## Ссылка на DayNightCycle (если не задана — ищется по группе "day_night_cycle")
var day_night_cycle: DayNightCycle

@export_range(50, 2000) var spawn_distance_min: float = 200.0
@export_range(50, 2000) var spawn_distance_max: float = 500.0
@export var max_creatures: int = 50

@export_group("Spawn Validation")
## TileMapLayer с которым проверяем тайл под точкой спавна (обычно Island)
@export var spawn_tilemap: TileMapLayer
## Название Custom Data тайла которое разрешает спавн (например "spawnable")
@export var spawn_custom_data: String = "spawnable"
## Сколько попыток найти валидную точку спавна прежде чем сдаться
@export_range(5, 50) var spawn_attempts: int = 20

@export_group("Creature Pools")
@export var creatures: Array[CreatureConfig] = []

@export_group("Spawn Timing")
@export var base_spawn_interval: float = 10.0
@export var spawn_interval_variation: float = 3.0
@export_range(1, 10) var spawn_count_min: int = 1
@export_range(1, 10) var spawn_count_max: int = 3
## Ночью интервал делится на этот множитель (>1 = чаще)
@export var night_spawn_multiplier: float = 1.5

@export_group("Despawn Settings")
@export var despawn_enabled: bool = true
@export var despawn_check_interval: float = 5.0
@export var time_offscreen_to_despawn: float = 15.0
@export var offscreen_margin: float = 200.0

# ─────────────────────────────────────────────
#  ВНУТРЕННЕЕ СОСТОЯНИЕ
# ─────────────────────────────────────────────
var _current_pool: Array[CreatureConfig] = []
var _can_spawn: bool = true
var _is_night: bool = false
var _current_event: String = "NONE"
var _current_day: int = 1

var _spawn_timer: Timer
var _despawn_timer: Timer
var _cleanup_timer: Timer  # чистит _tracked, если despawn выключен

# Node -> время последнего появления на экране (сек)
var _offscreen_tracker: Dictionary = {}
# Живые отслеживаемые существа
var _tracked: Array[Node] = []
# Счётчик живых существ — не сканируем группу каждый кадр
var _alive_count: int = 0
# Кеш камеры
var _camera: Camera2D


# ─────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	add_to_group("Spawner")

	# Найти DayNightCycle если не назначен в инспекторе
	if not is_instance_valid(day_night_cycle):
		var found := get_tree().get_nodes_in_group("day_night_cycle")
		if found.size() > 0:
			day_night_cycle = found[0]

	if is_instance_valid(day_night_cycle):
		day_night_cycle.phase_changed.connect(_on_phase_changed)
		day_night_cycle.day_changed.connect(_on_day_changed)
		# Синхронизируем начальное состояние
		_is_night = day_night_cycle.current_phase == DayNightCycle.Phase.NIGHT
		_current_day = day_night_cycle.current_day
		_sync_event()
	else:
		push_warning("CreatureSpawner: DayNightCycle не найден!")

	_spawn_timer = _make_timer(0.0, false, _on_spawn_timer_timeout)

	if despawn_enabled:
		_despawn_timer = _make_timer(despawn_check_interval, true, _check_despawn)
	else:
		# despawn выключен, но мёртвые ссылки из _tracked всё равно надо иногда убирать,
		# иначе массив будет расти бесконечно (существа умирают от урона/скриптов).
		_cleanup_timer = _make_timer(despawn_check_interval, true, _cleanup_tracked)

	_register_console_commands()

	if is_active:
		_update_pool()
		_restart_spawn_timer()

	# Кешируем камеру один раз
	_camera = get_viewport().get_camera_2d()


func _make_timer(wait: float, autostart: bool, cb: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = maxf(wait, 0.001)
	t.one_shot = false
	t.autostart = autostart
	t.timeout.connect(cb)
	add_child(t)
	return t


# ─────────────────────────────────────────────
#  СИГНАЛЫ DayNightCycle
# ─────────────────────────────────────────────
func _on_phase_changed(is_night: bool) -> void:
	_is_night = is_night
	_sync_event()
	_update_pool()
	_restart_spawn_timer()


func _on_day_changed() -> void:
	if is_instance_valid(day_night_cycle):
		_current_day = day_night_cycle.current_day
		_sync_event()


func _sync_event() -> void:
	if not is_instance_valid(day_night_cycle):
		_current_event = "NONE"
		return
	_current_event = DayNightCycle.Event.keys()[day_night_cycle.current_event]


# ─────────────────────────────────────────────
#  ПУЛ СУЩЕСТВ
# ─────────────────────────────────────────────
func _update_pool() -> void:
	_current_pool = []
	for cfg in creatures:
		if is_instance_valid(cfg) and is_instance_valid(cfg.creature_scene):
			if cfg.can_spawn(_is_night, _current_day, _current_event):
				_current_pool.append(cfg)

	if _current_pool.is_empty() and not creatures.is_empty():
		push_warning("CreatureSpawner: нет существ для фазы '%s', день %d, событие %s" % [
			"Night" if _is_night else "Day", _current_day, _current_event])


# ─────────────────────────────────────────────
#  СПАВН
# ─────────────────────────────────────────────
func _on_spawn_timer_timeout() -> void:
	if not is_active or not _can_spawn:
		return
	if not is_instance_valid(player):
		push_warning("CreatureSpawner: player не назначен!")
		return

	if _current_pool.is_empty():
		_restart_spawn_timer()
		return

	var count := randi_range(spawn_count_min, spawn_count_max)
	for i in count:
		if not _can_spawn:
			break
		var cfg := _pick_weighted(_current_pool)
		if cfg:
			_do_spawn(cfg)

	_restart_spawn_timer()


func _do_spawn(cfg: CreatureConfig) -> void:
	var scene := cfg.get_random_scene()
	if not scene:
		return
	var instance := scene.instantiate()
	instance.global_position = _random_spawn_pos()
	instance.add_to_group("Creature")
	get_tree().current_scene.add_child(instance)
	_tracked.append(instance)
	_alive_count += 1

	# Счётчик вида
	cfg._alive_count += 1
	instance.tree_exiting.connect(func():
		cfg._alive_count = maxi(cfg._alive_count - 1, 0)
		_alive_count = maxi(_alive_count - 1, 0)
		_offscreen_tracker.erase(instance)
	)


func _pick_weighted(pool: Array[CreatureConfig]) -> CreatureConfig:
	var total := 0.0
	for c in pool: total += c.spawn_weight
	if total <= 0.0: return pool[0]
	var roll := randf() * total
	var acc := 0.0
	for c in pool:
		acc += c.spawn_weight
		if roll <= acc: return c
	return pool.back()


func _random_spawn_pos() -> Vector2:
	# Если tilemap не назначен — фоллбэк на старое поведение
	if not is_instance_valid(spawn_tilemap) or spawn_custom_data.is_empty():
		return _raw_spawn_pos()

	for _i in spawn_attempts:
		var candidate := _raw_spawn_pos()
		if _is_valid_spawn_tile(candidate):
			return candidate

	# Все попытки исчерпаны — возвращаем последнюю кандидатуру
	push_warning("CreatureSpawner: не нашли валидный тайл за %d попыток" % spawn_attempts)
	return _raw_spawn_pos()


func _raw_spawn_pos() -> Vector2:
	var angle := randf() * TAU
	var dist  := randf_range(spawn_distance_min, spawn_distance_max)
	return player.global_position + Vector2(cos(angle), sin(angle)) * dist


func _is_valid_spawn_tile(world_pos: Vector2) -> bool:
	var tile_pos := spawn_tilemap.local_to_map(spawn_tilemap.to_local(world_pos))
	var data := spawn_tilemap.get_cell_tile_data(tile_pos)
	if data == null:
		return false  # нет тайла вообще (за краем карты)
	# Если custom data не задана на тайле — считаем false
	var value = data.get_custom_data(spawn_custom_data)
	return value == true


func _restart_spawn_timer() -> void:
	if not is_active or _current_pool.is_empty():
		_spawn_timer.stop()
		return
	var interval := randf_range(
		base_spawn_interval - spawn_interval_variation,
		base_spawn_interval + spawn_interval_variation)
	if _is_night:
		interval /= night_spawn_multiplier
	_spawn_timer.start(maxf(interval, 0.5))


# ─────────────────────────────────────────────
#  PHYSICS PROCESS — только _can_spawn (лёгкая проверка каждый кадр)
# ─────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	_can_spawn = _alive_count < max_creatures


## Чистит мёртвые ссылки из _tracked. Раньше вызывалось каждый физтик,
## теперь — раз в despawn_check_interval (через _despawn_timer или _cleanup_timer).
func _cleanup_tracked() -> void:
	for i in range(_tracked.size() - 1, -1, -1):
		if not is_instance_valid(_tracked[i]):
			_tracked.remove_at(i)


# ─────────────────────────────────────────────
#  ДЕСПАВН
# ─────────────────────────────────────────────
func _check_despawn() -> void:
	_cleanup_tracked()

	var now := Time.get_ticks_msec() / 1000.0

	# Обновляем видимость здесь — раз в despawn_check_interval, не каждый кадр
	for creature in _tracked:
		if is_instance_valid(creature) and _is_on_screen(creature):
			_offscreen_tracker[creature] = now

	var to_remove: Array[Node] = []

	for creature in _offscreen_tracker.keys():
		if not is_instance_valid(creature):
			to_remove.append(creature)
			continue
		if now - _offscreen_tracker[creature] > time_offscreen_to_despawn:
			to_remove.append(creature)

	for c in to_remove:
		_offscreen_tracker.erase(c)
		if is_instance_valid(c):
			c.queue_free()


func _is_on_screen(node: Node2D) -> bool:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		if not _camera:
			return true
	# Переводим мировую позицию в экранную через viewport transform
	var screen_pos := get_viewport().get_canvas_transform() * node.global_position
	return get_viewport().get_visible_rect().grow(offscreen_margin).has_point(screen_pos)


# ─────────────────────────────────────────────
#  КОНСОЛЬНЫЕ КОМАНДЫ
# ─────────────────────────────────────────────
func _register_console_commands() -> void:
	var cmds := {
		"creature_count": [_cmd_count, "Кол-во живых существ"],
		"creatures_list":  [_cmd_list,  "Список всех конфигов"],
		"creature_clear":  [_cmd_clear, "creature_clear [count] — удалить N ближайших (0 = все)"],
		"spawn":           [_cmd_spawn, "spawn [index] [count] — заспавнить"],
		"debug_spawn":     [_cmd_debug, "Дебаг состояния спавнера"],
	}
	for cmd in cmds:
		Global.developer_console.register_command(cmd, cmds[cmd][0], cmds[cmd][1])


func _cmd_count(_args: Array) -> String:
	return "Существ: %d / %d | Пул: %d | Ночь: %s | Событие: %s" % [
		_get_alive_count(), max_creatures, _current_pool.size(),
		_is_night, _current_event]


func _cmd_list(_args: Array) -> String:
	if creatures.is_empty():
		return "Список пуст"
	var lines := ["--- Creatures ---"]
	for i in creatures.size():
		var cfg := creatures[i]
		if not cfg:
			lines.append("%d: (null)" % i)
			continue
		var nm := cfg.creature_scene.resource_path.get_file().get_basename() if cfg.creature_scene else "NO SCENE"
		var in_pool := "v" if _current_pool.has(cfg) else "x"
		lines.append("%d [%s] %s  w=%.1f  phase=%s  minday=%d  alive=%d/%d  event=%s" % [
			i, in_pool, nm, cfg.spawn_weight, cfg.spawn_phase,
			cfg.min_day, cfg._alive_count, cfg.max_alive, cfg.required_event])
	return "\n".join(lines)


func _cmd_clear(args: Array) -> String:
	var group := get_tree().get_nodes_in_group("Creature")
	if group.is_empty():
		return "Существ нет"
	var total := group.size()
	var count := total
	if not args.is_empty() and args[0].is_valid_int():
		count = mini(maxi(int(args[0]), 1), total)

	if count == total:
		for c in group:
			if is_instance_valid(c): c.queue_free()
		_tracked.clear()
		_offscreen_tracker.clear()
		return "Удалено все %d существ" % total

	if not is_instance_valid(player):
		return "Player не найден"

	# Считаем расстояние один раз на существо, а не на каждое сравнение внутри sort.
	var with_dist: Array = []
	for c in group:
		if is_instance_valid(c):
			with_dist.append({ "node": c, "dist": player.global_position.distance_squared_to(c.global_position) })
	with_dist.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var cleared := 0
	for i in mini(count, with_dist.size()):
		var node: Node = with_dist[i]["node"]
		if is_instance_valid(node):
			node.queue_free()
			cleared += 1
	return "Удалено %d из %d" % [cleared, total]


func _cmd_spawn(args: Array) -> String:
	if args.is_empty():
		return "Использование: spawn [index] [count]\n" + _cmd_list([])
	if not args[0].is_valid_int():
		return "Индекс должен быть числом"
	var idx := int(args[0])
	if idx < 0 or idx >= creatures.size():
		return "Индекс вне диапазона (0-%d)" % (creatures.size() - 1)
	var cfg := creatures[idx]
	if not cfg or not cfg.creature_scene:
		return "Нет сцены у конфига #%d" % idx
	var count := 1
	if args.size() > 1 and args[1].is_valid_int():
		count = maxi(int(args[1]), 1)
	var available := max_creatures - _get_alive_count()
	if available <= 0:
		return "Лимит достигнут (%d)" % max_creatures
	count = mini(count, available)
	for i in count:
		_do_spawn(cfg)
	return "Заспавнено %d x %s" % [count, cfg.creature_scene.resource_path.get_file().get_basename()]


func _cmd_debug(_args: Array) -> String:
	return "=== SpawnDebug ===\nAlive: %d/%d\nCan spawn: %s\nIs night: %s\nDay: %d\nEvent: %s\nPool size: %d" % [
		_get_alive_count(), max_creatures, _can_spawn,
		_is_night, _current_day, _current_event, _current_pool.size()]


# ─────────────────────────────────────────────
#  УТИЛИТЫ
# ─────────────────────────────────────────────
func _get_alive_count() -> int:
	return _alive_count


func _get_configuration_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if not player:
		w.append("Player не назначен.")
	if creatures.is_empty():
		w.append("Нет ни одного CreatureConfig.")
	if spawn_distance_min > spawn_distance_max:
		w.append("spawn_distance_min > spawn_distance_max.")
	if not spawn_tilemap:
		w.append("spawn_tilemap не назначен — существа могут спавниться в воде!")
	if spawn_tilemap and spawn_custom_data.is_empty():
		w.append("spawn_custom_data пустой — проверка тайлов отключена.")
	for cfg in creatures:
		if not cfg or not cfg.creature_scene:
			w.append("CreatureConfig без сцены!")
	return w
