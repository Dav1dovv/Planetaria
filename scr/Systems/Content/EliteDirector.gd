extends Node
class_name EliteDirector

## Иногда рядом с обычными врагами появляется ЭЛИТА: крупнее/быстрее/толще,
## светится аурой и даёт хороший лут. У каждого элитного — свой «аффикс».
## Работает поверх существующих врагов (ничего в их сценах менять не нужно).

signal elite_spawned(enemy: Entity, affixes: Array)

## Кто может стать элитой (ID по Entity.get_enemy_id()). Боссы и звери — нет.
const ELITE_IDS: Array[String] = ["slime", "pig", "rat", "bee", "enem"]
const BASE_CHANCE := 0.04
const MAX_CHANCE := 0.10
## Шанс растёт со временем игры — к концу забега элит больше
const CHANCE_PER_MINUTE := 0.01
const MAX_ALIVE := 1
const HEALTH_MULT := 2.0
const SECOND_AFFIX_CHANCE := 0.25
const GOLD := Color(1.0, 0.85, 0.3)

const AFFIXES := {
	&"giant": {"name": "Giant", "tint": Color(1.0, 0.68, 0.62)},
	&"swift": {"name": "Swift", "tint": Color(0.62, 0.95, 1.0)},
	&"armored": {"name": "Armored", "tint": Color(0.78, 0.82, 0.95)},
	&"regenerating": {"name": "Regenerating", "tint": Color(0.66, 1.0, 0.72)},
	&"golden": {"name": "Golden", "tint": Color(1.0, 0.9, 0.4)},
}

# Намеренно без типа: Array.filter() возвращает нетипизированный массив
var _alive: Array = []
var _play_time: float = 0.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	if get_tree().get_first_node_in_group("Player") != null:
		_play_time += delta
	_tick_regeneration(delta)


func reset() -> void:
	_play_time = 0.0
	_alive.clear()


func _on_node_added(node: Node) -> void:
	if node is Entity and not node.is_in_group("Player"):
		# Отложенно: к этому моменту у врага уже отработал _ready()
		_consider.call_deferred(node)


func _consider(enemy: Entity) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.has_meta(&"elite_checked"):
		return
	enemy.set_meta(&"elite_checked", true)

	if Global.get_planet(Global.current_location) == null:
		return
	if not ELITE_IDS.has(enemy.get_enemy_id()) or enemy.is_in_group("Boss"):
		return
	if enemy is MeleeEnemy and (enemy as MeleeEnemy).is_boss:
		return

	_alive = _alive.filter(func(e: Entity) -> bool: return is_instance_valid(e) and e.is_alive)
	if _alive.size() >= MAX_ALIVE:
		return
	if randf() > minf(MAX_CHANCE, BASE_CHANCE + CHANCE_PER_MINUTE * _play_time / 60.0):
		return
	_make_elite(enemy)


func _make_elite(enemy: Entity) -> void:
	var affixes := _roll_affixes()
	var stats := enemy.Entity_stats
	var health_mult := HEALTH_MULT
	var scale_mult := 1.0

	for affix in affixes:
		match affix:
			&"giant":
				health_mult *= 1.4
				scale_mult = 1.3
			&"swift":
				stats.add_speed_modifier(35.0)
			&"armored":
				stats.armor += 25.0

	stats.max_health = roundi(stats.max_health * health_mult)
	stats.current_health = stats.max_health
	enemy.health_changed.emit(stats.current_health)
	if scale_mult != 1.0:
		enemy.scale *= scale_mult

	var tint: Color = AFFIXES[affixes[0]]["tint"]
	_tint_sprites(enemy, tint)
	_add_aura(enemy, tint)

	enemy.set_meta(&"elite_affixes", affixes)
	_alive.append(enemy)
	enemy.died.connect(_on_elite_died.bind(enemy, affixes), CONNECT_ONE_SHOT)

	var title := Loc.t("ELITE") + ": " + Loc.t(AFFIXES[affixes[0]]["name"])
	GameJuice.floating_text(enemy.global_position + Vector2(0.0, -18.0), title, GOLD, 1.2, 1.5, 22.0, 1.8)
	elite_spawned.emit(enemy, affixes)


func _roll_affixes() -> Array[StringName]:
	var pool: Array = AFFIXES.keys()
	var result: Array[StringName] = []
	var first: StringName = pool.pick_random()
	result.append(first)
	if randf() < SECOND_AFFIX_CHANCE:
		pool.erase(first)
		result.append(pool.pick_random())
	return result


## self_modulate, а не modulate: вспышку урона (DamageVFX) твинит именно modulate,
## и она не должна стирать цвет элиты.
func _tint_sprites(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			(child as CanvasItem).self_modulate = color
		_tint_sprites(child, color)


## Аура из мелких квадратиков-частиц — графика не нужна, стиль пиксельный.
func _add_aura(enemy: Entity, color: Color) -> void:
	var aura := CPUParticles2D.new()
	aura.amount = 10
	aura.lifetime = 0.9
	aura.local_coords = false
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 9.0
	aura.direction = Vector2.UP
	aura.spread = 30.0
	aura.gravity = Vector2.ZERO
	aura.initial_velocity_min = 8.0
	aura.initial_velocity_max = 18.0
	aura.scale_amount_min = 1.5
	aura.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(color, 1.0), Color(color, 0.0)])
	aura.color_ramp = ramp
	aura.z_index = 2
	enemy.add_child(aura)


func _tick_regeneration(delta: float) -> void:
	for enemy in _alive:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var affixes: Array = enemy.get_meta(&"elite_affixes", [])
		if affixes.has(&"regenerating"):
			enemy.heal(enemy.Entity_stats.max_health * 0.02 * delta)


func _on_elite_died(enemy: Entity, affixes: Array) -> void:
	_alive.erase(enemy)
	var pos := enemy.global_position
	var golden := affixes.has(&"golden")

	LootUtil.drop(LootUtil.COIN, randi_range(8, 14) * (2 if golden else 1), pos)
	if golden or randf() < 0.35:
		LootUtil.drop(LootUtil.POTION, 1, pos)
	# Элита — главный источник кристаллов (ремонт лучшего оружия) и редкая Звезда удачи
	LootUtil.drop(LootUtil.CRYSTAL_SHARD, randi_range(1, 2) * (2 if golden else 1), pos)
	if golden and randf() < 0.5:
		LootUtil.drop(LootUtil.LUCKY_STAR, 1, pos)

	Global.report_planet_event(Global.current_location, QuestData.Kind.KILL_ENEMY, "elite")
	Global.elite_defeated.emit(affixes)
	GameJuice.toast(Loc.t("Elite defeated: ") + Loc.t(AFFIXES[affixes[0]]["name"]), GOLD)
	GameJuice.shake(2.5, 0.25)
