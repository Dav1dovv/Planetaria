extends Node2D
class_name SurvivorRescue

## Задание «Спасти выжившего» (вид RESCUE_SURVIVOR): член пропавшей команды или робот
## ждёт помощи. Игрок подходит — выживший идёт за ним по его следу до корабля.
##
## КАК НАСТРОИТЬ (всё в редакторе, без кода):
##  1. Добавь в сцену планеты узел с этим скриптом, а внутрь — Sprite2D / AnimatedSprite2D
##     с картинкой выжившего (скрипт сам покачивает и разворачивает первый такой узел).
##  2. quest_id — ID задания в PlanetData, survivor_id — его target_id (может быть пустым).
##  3. Корабль находится сам: Dropoff -> группа ShipLanding -> SceneChanger, который
##     ведёт на сцену «Ship». Вручную нужно только если на планете нет такого выхода.
##
## ПОЧЕМУ ХОДИТ ПО СЛЕДУ ИГРОКА: там, где прошёл игрок, пройдёт и выживший — не нужна
## навигация и не нужно знать слои коллизий. Если игрок слишком оторвался (например,
## использовал телепортер), выживший догоняет его вспышкой, а не пропадает.

enum State { WAITING, FOLLOWING, SAVED }

@export var quest_id: StringName = &"rescue_survivor"
## target_id задания; пусто = засчитывается любому заданию этого вида
@export var survivor_id: String = ""

@export_group("Место спасения")
## Куда довести. Пусто — ищем корабль автоматически (см. шапку)
@export var dropoff: Node2D
@export_range(16.0, 200.0, 2.0) var dropoff_radius: float = 56.0

@export_group("Поведение")
## С какого расстояния выживший присоединяется к игроку
@export_range(16.0, 120.0, 2.0) var join_radius: float = 44.0
## Дистанция, которую выживший держит позади игрока (по следу)
@export_range(8.0, 80.0, 1.0) var follow_gap: float = 26.0
@export_range(40.0, 250.0, 5.0) var follow_speed: float = 105.0
## Если игрок дальше — выживший перемещается к нему вспышкой
@export_range(150.0, 900.0, 10.0) var warp_distance: float = 380.0

@export_group("Награда и подсказки")
## Дополнительные монеты за спасение (основная награда — в самом задании)
@export_range(0, 500, 5) var bonus_coins: int = 25
## Как часто выживший зовёт на помощь, пока игрок рядом (сек)
@export_range(0.8, 6.0, 0.1) var call_interval: float = 1.8
@export var color: Color = Color(1.0, 0.85, 0.3)

## Расстояние между точками следа игрока (px)
const TRAIL_STEP := 6.0
const TRAIL_MAX := 480
const SOUND_RANGE := 260.0

var _state: State = State.WAITING
var _trail: PackedVector2Array = PackedVector2Array()
var _cursor: int = 0
var _player: Node2D
var _marker_id: int = -1
var _call_timer: float = 0.0
var _bob_time: float = 0.0
## Пауза между повторными поисками корабля, если он не найден (сек)
var _dropoff_retry: float = 0.0
## Сглаженная скорость игрока (px/с): выживший не должен отставать от бегущего героя
var _player_speed: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _visual: Node2D
var _visual_base_y: float = 0.0


func _ready() -> void:
	# Спасён раньше (после загрузки слота или возврата на планету) — второй раз не нужен
	if Global.is_quest_done(String(quest_id)):
		queue_free()
		return
	_visual = _find_visual()
	if _visual != null:
		_visual_base_y = _visual.position.y


func _exit_tree() -> void:
	_untrack_marker()


func _physics_process(delta: float) -> void:
	if _state == State.SAVED:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("Player") as Node2D
		if _player == null:
			return

	_animate(delta)
	match _state:
		State.WAITING:
			_tick_waiting(delta)
		State.FOLLOWING:
			_tick_following(delta)


# ─────────────────────────────────────────────────────────────────────────────
#  Ожидание: зовём на помощь, ждём игрока
# ─────────────────────────────────────────────────────────────────────────────
func _tick_waiting(delta: float) -> void:
	var dist := global_position.distance_to(_player.global_position)
	if dist <= join_radius:
		_join()
		return
	if dist > SOUND_RANGE:
		return
	_call_timer -= delta
	if _call_timer <= 0.0:
		_call_timer = call_interval
		GameJuice.floating_text(global_position + Vector2(0.0, -22.0), Loc.t("Help!"), color, 1.1, 1.2, 10.0, 1.7)


func _join() -> void:
	_state = State.FOLLOWING
	_trail = PackedVector2Array([_player.global_position])
	_cursor = 0
	_last_player_pos = _player.global_position
	_player_speed = 0.0
	GameJuice.toast(Loc.t("Survivor found! Get them to the ship"), color)
	GameJuice.floating_text(global_position + Vector2(0.0, -22.0), "!", color, 1.4, 1.0, 14.0, 1.8)

	var target := _resolve_dropoff()
	var marker := Global.get_node_or_null("ObjectiveMarker") as ObjectiveMarker
	if target != null and marker != null:
		_marker_id = marker.track(target, Loc.t("Ship"), color)
	elif target == null:
		push_warning("[SurvivorRescue] %s: не найден корабль/место спасения — назначь Dropoff" % name)


# ─────────────────────────────────────────────────────────────────────────────
#  Путь за игроком по его следу
# ─────────────────────────────────────────────────────────────────────────────
func _tick_following(delta: float) -> void:
	_dropoff_retry = maxf(0.0, _dropoff_retry - delta)
	var instant_speed := _player.global_position.distance_to(_last_player_pos) / maxf(delta, 0.0001)
	_player_speed = lerpf(_player_speed, instant_speed, 0.15)
	_last_player_pos = _player.global_position
	_record_trail()

	var to_player := global_position.distance_to(_player.global_position)
	if to_player > warp_distance:
		_warp_to_player()
		return

	_follow_trail(delta)

	var target := _resolve_dropoff()
	if target == null:
		return
	# Спасён, когда САМ дошёл до корабля. Поблажка для игрока, который встал у корабля:
	# выживший уже догнал его (стоит на своей дистанции), значит, дошёл тоже.
	var arrived := global_position.distance_to(target.global_position) <= dropoff_radius
	var caught_up := _player.global_position.distance_to(target.global_position) <= dropoff_radius * 0.6 \
			and to_player <= follow_gap * 1.5
	if arrived or caught_up:
		_save()


func _record_trail() -> void:
	var last := _trail[_trail.size() - 1]
	if _player.global_position.distance_to(last) < TRAIL_STEP:
		return
	_trail.append(_player.global_position)
	# Старый след выбрасываем пачкой, чтобы массив не рос бесконечно
	if _trail.size() > TRAIL_MAX:
		var drop := TRAIL_MAX / 2
		_trail = _trail.slice(drop)
		_cursor = maxi(0, _cursor - drop)


func _follow_trail(delta: float) -> void:
	# Держим дистанцию: пока впереди меньше follow_gap следа — стоим
	var points_ahead := _trail.size() - 1 - _cursor
	if points_ahead * TRAIL_STEP < follow_gap:
		return
	var target := _trail[_cursor]
	# Не медленнее игрока (с запасом), иначе при бодром беге выживший отстаёт и телепортируется
	var step := maxf(follow_speed, _player_speed * 1.15) * delta
	var to_target := target - global_position
	if to_target.length() <= step:
		global_position = target
		_cursor += 1
	else:
		global_position += to_target.normalized() * step
		_face(to_target.x)


func _warp_to_player() -> void:
	GameJuice.floating_text(global_position + Vector2(0.0, -16.0), Loc.t("Wait for me!"), color, 1.0, 0.9, 12.0, 1.4)
	global_position = _player.global_position
	_trail = PackedVector2Array([_player.global_position])
	_cursor = 0
	InfectionCleanup.pop(global_position, color)  # общая вспышка частиц


# ─────────────────────────────────────────────────────────────────────────────
#  Спасение
# ─────────────────────────────────────────────────────────────────────────────
func _save() -> void:
	_state = State.SAVED
	_untrack_marker()
	Global.report_planet_event(Global.current_location, QuestData.Kind.RESCUE_SURVIVOR, survivor_id)

	if bonus_coins > 0:
		LootUtil.drop(LootUtil.COIN, bonus_coins, global_position)
	GameJuice.banner(Loc.t("SURVIVOR SAVED"), "", color, 1.8)
	GameJuice.shake(2.0, 0.3)

	# Радостный прыжок и растворение
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 14.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y, 0.18).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# ─────────────────────────────────────────────────────────────────────────────
#  Служебное
# ─────────────────────────────────────────────────────────────────────────────
## Dropoff -> группа ShipLanding -> SceneChanger, ведущий на сцену «Ship».
func _resolve_dropoff() -> Node2D:
	if dropoff != null and is_instance_valid(dropoff):
		return dropoff
	var landing := get_tree().get_first_node_in_group("ShipLanding") as Node2D
	if landing != null:
		dropoff = landing
		return dropoff
	if _dropoff_retry > 0.0:
		return null  # недавно искали и не нашли — не обходим группу каждый кадр
	for node in get_tree().get_nodes_in_group("interaction"):
		var changer := node as SceneChanger
		if changer != null and changer.scene == "Ship":
			dropoff = changer
			return dropoff
	_dropoff_retry = 1.0
	return null


func _untrack_marker() -> void:
	if _marker_id == -1:
		return
	var marker := Global.get_node_or_null("ObjectiveMarker") as ObjectiveMarker
	if marker != null:
		marker.untrack(_marker_id)
	_marker_id = -1


func _find_visual() -> Node2D:
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
	return null


func _face(dx: float) -> void:
	if _visual != null and absf(dx) > 0.01 and "flip_h" in _visual:
		_visual.set("flip_h", dx < 0.0)


## Лёгкое покачивание: у ждущего — нервное (быстрее), у идущего — шаги.
func _animate(delta: float) -> void:
	if _visual == null:
		return
	_bob_time += delta * (9.0 if _state == State.FOLLOWING else 4.0)
	_visual.position.y = _visual_base_y + sin(_bob_time) * (1.2 if _state == State.FOLLOWING else 0.6)
