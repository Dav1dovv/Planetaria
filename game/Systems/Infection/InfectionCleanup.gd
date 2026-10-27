extends RefCounted
class_name InfectionCleanup

## Задание «Очистить планету от заражения» (quest_id = cleanup_infection, вид CLEANSE_INFECTION).
##
## Как это играется:
##  * заражённые ресурсы (Harvestable.is_corrupted) — это «грязь» планеты;
##  * уничтожил заражённый объект -> +1 к заданию, зелёный взрыв спор и «+1» над ним;
##  * на 25 / 50 / 75% — короткие тосты, чтобы игрок видел: планета оживает;
##  * выполнил задание -> ВСЕ заражённые объекты вокруг мгновенно очищаются, игрок
##    лечится, новое заражение больше не появляется (планета излечена навсегда).
##
## Состояние хранить не нужно: «излечена» = задание выполнено, а прогресс заданий
## уже сохраняется системой слотов. Автозагрузка не нужна — всё статическое
## (так же устроен GameJuice).
##
## ЧТО ГДЕ МЕНЯТЬ (без кода):
##  * сколько объектов надо очистить — target_amount у задания в PlanetData (Vehana.tres);
##  * шанс, что ресурс родится заражённым — infect_chance у Harvestable в Инспекторе;
##  * награда — Rewards у задания.

const QUEST_ID: StringName = &"cleanup_infection"
const GREEN := Color(0.55, 1.0, 0.6)
## Доли выполнения, на которых показывается тост
const MILESTONES: Array[float] = [0.25, 0.5, 0.75]


## Задание очистки на ТЕКУЩЕЙ планете (null — на этой планете его нет).
static func get_quest() -> QuestData:
	var planet := Global.get_planet(Global.current_location)
	if planet == null:
		return null
	return planet.get_quest(QUEST_ID)


## Заражение ещё «живо»? Планеты без этого задания ведут себя как раньше.
static func is_infection_active() -> bool:
	var quest := get_quest()
	return quest == null or not quest.is_completed()


## Бросок кубика для нового ресурса: родиться заражённым или нет.
static func roll_infected(chance: float) -> bool:
	return is_infection_active() and randf() < chance


## Заражённый объект уничтожен. Вызывается из Harvestable.
static func report_cleansed(world_pos: Vector2) -> void:
	pop(world_pos)
	var quest := get_quest()
	if quest == null or quest.is_completed():
		return

	var before := float(quest.progress) / quest.target_amount
	Global.report_planet_event(Global.current_location, QuestData.Kind.CLEANSE_INFECTION, "", 1)
	var after := float(quest.progress) / quest.target_amount

	GameJuice.floating_text(world_pos + Vector2(0.0, -14.0), "+1 " + Loc.t("Purified"), GREEN, 1.0, 0.9, 22.0, 1.4)

	if quest.is_completed():
		_celebrate()
		return
	for milestone in MILESTONES:
		if before < milestone and after >= milestone:
			GameJuice.toast(Loc.t("The infection is receding: %d%%") % roundi(milestone * 100.0), GREEN)
			break


## «Пых» одноразовых частиц (по умолчанию зелёных спор), сами удаляются.
## Цвет можно передать — этой же вспышкой пользуются и другие задания.
static func pop(world_pos: Vector2, color: Color = GREEN) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var fx := CPUParticles2D.new()
	fx.one_shot = true
	fx.emitting = true
	fx.amount = 14
	fx.lifetime = 0.7
	fx.explosiveness = 0.95
	fx.local_coords = false
	fx.direction = Vector2.UP
	fx.spread = 180.0
	fx.gravity = Vector2(0.0, -10.0)
	fx.initial_velocity_min = 14.0
	fx.initial_velocity_max = 38.0
	fx.scale_amount_min = 1.5
	fx.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(color, 1.0), Color(color, 0.0)])
	fx.color_ramp = ramp
	fx.z_index = 3
	fx.global_position = world_pos
	tree.current_scene.add_child(fx)
	tree.create_timer(fx.lifetime + 0.3).timeout.connect(fx.queue_free)


## Планета излечена: очищаем всё живое заражение, лечим игрока, празднуем.
static func _celebrate() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	for node in tree.get_nodes_in_group("Harvestable"):
		if is_instance_valid(node) and node.has_method("cleanse"):
			node.call("cleanse")

	var player := tree.get_first_node_in_group("Player")
	if player != null and player.has_method("full_cure_infection"):
		player.call("full_cure_infection")

	GameJuice.banner(Loc.t("PLANET PURIFIED"), Loc.t(Global.current_location), GREEN, 2.6)
	GameJuice.shake(3.0, 0.5)
