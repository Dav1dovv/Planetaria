extends Node2D
class_name HuntTarget

## Задание «Охота» (вид HUNT_RARE): выследить редкого врага по следам.
##
## КАК НАСТРОИТЬ (всё в редакторе, без кода):
##  1. Поставь узел с этим скриптом туда, где ЛОГОВО зверя — он появится именно здесь.
##  2. Внутрь добавь несколько Marker2D: это путь следов. Порядок в дереве = порядок пути
##     (от начала к логову). Следы дорисовываются сами, двигай маркеры — путь меняется.
##  3. enemy_scene — сцена врага (например, Pig_BOs.tscn для «большого хряка»).
##  4. quest_id — ID задания в PlanetData, hunt_id — его target_id (может быть пустым).
##
## Следы бледные издалека и ярко светятся, когда игрок рядом: видно, что здесь что-то
## есть, но идти по ним — награда за внимательность. Если задание выполнено, зверь
## и следы больше не появляются.

signal hunted

@export var quest_id: StringName = &"hunt_rare"
@export var hunt_id: String = ""
@export var enemy_scene: PackedScene

@export_group("Редкий враг")
@export_range(1.0, 10.0, 0.1) var health_mult: float = 3.0
@export_range(1.0, 2.5, 0.05) var scale_mult: float = 1.25
@export var tint: Color = Color(1.0, 0.85, 0.3)
@export_range(0, 500, 5) var bonus_coins: int = 60

@export_group("Следы")
@export_range(6.0, 40.0, 1.0) var track_spacing: float = 14.0
## Ближе этого расстояния следы светятся ярко
@export_range(40.0, 400.0, 10.0) var reveal_radius: float = 140.0
@export_range(0.0, 1.0, 0.05) var far_alpha: float = 0.22
@export var track_color: Color = Color(1.0, 0.85, 0.3)

const CHECK_INTERVAL := 0.15

var _enemy: Entity
var _active: bool = false
var _dots: PackedVector2Array = PackedVector2Array()
var _alphas: PackedFloat32Array = PackedFloat32Array()
var _timer: float = 0.0
var _announced: bool = false


func _ready() -> void:
	if enemy_scene == null:
		push_warning("[HuntTarget] %s: не назначена enemy_scene" % name)
		return
	if Global.is_quest_done(String(quest_id)):
		return  # охота уже выполнена — ни зверя, ни следов
	_active = true
	_build_tracks()
	_spawn_enemy.call_deferred()


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	_update_alphas()


# ─────────────────────────────────────────────────────────────────────────────
#  Зверь
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_enemy() -> void:
	var holder := get_parent()
	if holder == null:
		return
	_enemy = enemy_scene.instantiate() as Entity
	if _enemy == null:
		push_warning("[HuntTarget] %s: enemy_scene должна быть Entity (враг)" % name)
		_active = false
		return
	# Чтобы EliteDirector не сделал зверя элитой второй раз
	_enemy.set_meta(&"elite_checked", true)
	holder.add_child(_enemy)
	_enemy.global_position = global_position

	# Статы враг выставляет в своём _ready() — усиливаем уже после него
	await get_tree().process_frame
	if not is_instance_valid(_enemy):
		return
	_boost(_enemy)
	_enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)


func _boost(enemy: Entity) -> void:
	var stats := enemy.Entity_stats
	stats.max_health = roundi(stats.max_health * health_mult)
	stats.current_health = stats.max_health
	enemy.health_changed.emit(stats.current_health)
	if scale_mult != 1.0:
		enemy.scale *= scale_mult
	_tint_sprites(enemy, tint)
	_add_aura(enemy, tint)


## self_modulate, а не modulate: вспышку урона твинит именно modulate (как у элиты).
func _tint_sprites(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			(child as CanvasItem).self_modulate = color
		_tint_sprites(child, color)


func _add_aura(enemy: Entity, color: Color) -> void:
	var aura := CPUParticles2D.new()
	aura.amount = 12
	aura.lifetime = 1.0
	aura.local_coords = false
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 10.0
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


func _on_enemy_died() -> void:
	_active = false
	queue_redraw()
	var pos := global_position
	if is_instance_valid(_enemy):
		pos = _enemy.global_position
	Global.report_planet_event(Global.current_location, QuestData.Kind.HUNT_RARE, hunt_id)
	if bonus_coins > 0:
		LootUtil.drop(LootUtil.COIN, bonus_coins, pos)
	GameJuice.toast(Loc.t("The rare beast is down!"), tint)
	GameJuice.shake(2.5, 0.3)
	hunted.emit()


# ─────────────────────────────────────────────────────────────────────────────
#  Следы
# ─────────────────────────────────────────────────────────────────────────────
## Путь = все Marker2D внутри по порядку + логово (начало координат этого узла).
func _build_tracks() -> void:
	var path: PackedVector2Array = PackedVector2Array()
	for child in get_children():
		if child is Marker2D:
			path.append((child as Marker2D).position)
	path.append(Vector2.ZERO)

	_dots.clear()
	var side := 1.0
	var carry := 0.0
	for i in range(path.size() - 1):
		var from := path[i]
		var to := path[i + 1]
		var seg := to - from
		var length := seg.length()
		if length < 0.01:
			continue
		var dir := seg / length
		var normal := Vector2(-dir.y, dir.x)
		var d := carry
		while d <= length:
			# Лапы идут «лесенкой»: левая — правая — левая
			_dots.append(from + dir * d + normal * 3.0 * side)
			side = -side
			d += track_spacing
		carry = d - length
	_alphas.resize(_dots.size())
	_alphas.fill(far_alpha)
	queue_redraw()


func _update_alphas() -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	var changed := false
	var closest := INF
	for i in _dots.size():
		var dist := to_global(_dots[i]).distance_to(player.global_position)
		closest = minf(closest, dist)
		# 1.0 вплотную, far_alpha за пределами reveal_radius
		var near := clampf(1.0 - dist / reveal_radius, 0.0, 1.0)
		var alpha := lerpf(far_alpha, 1.0, near)
		if absf(alpha - _alphas[i]) > 0.02:
			_alphas[i] = alpha
			changed = true
	if changed:
		queue_redraw()

	# Первый раз заметил следы — подсказка, что с ними делать
	if not _announced and closest <= reveal_radius * 0.6:
		_announced = true
		GameJuice.toast(Loc.t("Fresh tracks! Follow them"), track_color)


func _draw() -> void:
	if not _active:
		return
	for i in _dots.size():
		var c := Color(track_color, _alphas[i])
		var p := _dots[i]
		# Пиксельная лапа: подушка 2x2 и пара «пальцев»
		draw_rect(Rect2(p + Vector2(-1.0, 0.0), Vector2(2.0, 2.0)), c)
		draw_rect(Rect2(p + Vector2(-2.0, -1.5), Vector2(1.0, 1.0)), c)
		draw_rect(Rect2(p + Vector2(1.0, -1.5), Vector2(1.0, 1.0)), c)
