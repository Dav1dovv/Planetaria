extends Node2D
class_name Fire_collison

## Костёр: поджигает игрока и существ, пока они стоят в огне; взрывает заражение (CorruptionOrb.explode).
##
## Как это работает:
##   • fire_area (Area2D костра) ловит HurtBox'ы (слой 5) — это те же Area2D, что бьёт оружие.
##   • Вход в огонь → сразу поджигаем; пока стоят внутри — продлеваем горение каждые refresh_interval секунд.
##   • Урон тикает через Effect BURN (EffectManager), поэтому работают иконка эффекта и все правила эффектов.
##   • Если effect_source не назначен — горение собирается из чисел ниже (Effect.create_burn).

@export_group("Эффект горения")
## Готовый Effect (Burn). ПУСТО — используется Effect.create_burn(burn_damage_per_tick, burn_duration).
@export var effect_source : Effect
## Урон за тик (тик = 1 сек у Effect.create_burn). Работает, когда effect_source пуст.
@export_range(0.0, 50.0, 0.5) var burn_damage_per_tick : float = 3.0
## Сколько секунд горит после выхода из огня. Работает, когда effect_source пуст.
@export_range(0.5, 20.0, 0.5, "suffix:s") var burn_duration : float = 3.0
## Как часто костёр «поджигает заново», пока существо стоит в огне (продлевает горение).
@export_range(0.1, 2.0, 0.05, "suffix:s") var refresh_interval : float = 0.35
## Мгновенный урон в момент касания (без отбрасывания). 0 = выключено.
@export_range(0.0, 50.0, 0.5) var touch_damage : float = 0.0

@export_group("Кого жжёт")
@export var burn_player : bool = true
@export var burn_creatures : bool = true

@export_group("Зона костра")
## Area2D костра. ПУСТО — берётся первый Area2D среди дочерних узлов.
@export var fire_area : Area2D
## Писать в Output, кого костёр поджёг и почему не смог.
@export var debug_log : bool = false

var _inside : Array[Area2D] = []
var _refresh_timer : float = 0.0


func _ready() -> void:
	if fire_area == null:
		fire_area = _find_area(self)
	if fire_area == null:
		push_error("Fire_collison '%s': не найден Area2D костра — назначь fire_area в Inspector" % name)
		set_physics_process(false)
		return

	# Сигналы подключаются сами, если в сцене они не подключены (или подключены к другому методу)
	if not fire_area.area_entered.is_connected(something_enter):
		fire_area.area_entered.connect(something_enter)
	if not fire_area.area_exited.is_connected(something_exit):
		fire_area.area_exited.connect(something_exit)

	# HurtBox'ы лежат на слое 5 — без этого бита в маске костёр их просто не видит
	if not fire_area.get_collision_mask_value(5):
		fire_area.set_collision_mask_value(5, true)
		push_warning("Fire_collison '%s': в маске зоны костра не было слоя 5 (HurtBox) — включён автоматически" % name)
	fire_area.set_deferred("monitoring", true)
	set_physics_process(false)  # включается, пока в огне кто-то есть


func something_enter(area: Area2D) -> void:
	if area.is_in_group("corruption"):
		# Заражение коснулось огня — взрыв ранит существ рядом (см. CorruptionOrb.explode)
		var orb := area.get_parent()
		if orb != null and orb.has_method("explode"):
			orb.explode()
		return

	if area.is_in_group("explosive_projectile"):
		# Пуля влетела в огонь — взрывается (см. Projectile.explode_from_fire)
		var bullet := area.get_parent()
		if bullet != null and bullet.has_method("explode_from_fire"):
			bullet.explode_from_fire()
		return

	if _can_burn(area):
		if not _inside.has(area):
			_inside.append(area)
		_touch(area)
		_burn(area)
		_refresh_timer = refresh_interval
		set_physics_process(true)


func something_exit(area: Area2D) -> void:
	_inside.erase(area)
	if _inside.is_empty():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = refresh_interval
	# Чистим удалённых и поджигаем остальных заново (продлевает горение, пока стоят в огне)
	for i in range(_inside.size() - 1, -1, -1):
		var area := _inside[i]
		if not is_instance_valid(area):
			_inside.remove_at(i)
			continue
		_burn(area)
	if _inside.is_empty():
		set_physics_process(false)


# ─── Внутреннее ───────────────────────────────────────────────────────────────

func _can_burn(area: Area2D) -> bool:
	if area.is_in_group("Player"):
		return burn_player
	if area.is_in_group("Ennemy") and not area.is_in_group("corruption"):
		return burn_creatures
	return false


## Поджигает владельца HurtBox. Эффект BURN обновляет таймер, а не копится (max_stacks = 1).
func _burn(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or not target.has_method("apply_effect_instance"):
		if debug_log:
			print("[Костёр] %s: у цели нет apply_effect_instance — поджечь нельзя" % area.get_path())
		return
	if target.get("is_alive") == false:
		return
	var effect := effect_source if effect_source != null else Effect.create_burn(burn_damage_per_tick, burn_duration)
	target.apply_effect_instance(effect)
	if debug_log:
		print("[Костёр] горит: %s" % target.name)


func _touch(area: Area2D) -> void:
	if touch_damage <= 0.0:
		return
	var target := area.get_parent()
	if target != null and target.has_method("take_dot_damage"):
		target.take_dot_damage(touch_damage)


func _find_area(node: Node) -> Area2D:
	for child in node.get_children():
		if child is Area2D:
			return child
		var nested := _find_area(child)
		if nested != null:
			return nested
	return null
