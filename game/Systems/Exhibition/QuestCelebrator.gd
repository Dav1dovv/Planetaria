extends Node
class_name QuestCelebrator

## Празднует выполнение заданий планеты: тост + звук + награда.
## Когда выполнено финальное задание (FINALE_QUEST_ID) — большой баннер и
## сигнал finale_reached, по которому ExhibitionManager показывает итоговый экран.

signal quest_completed(planet: PlanetData, quest: QuestData)
signal finale_reached(planet: PlanetData)
signal planet_fully_explored(planet: PlanetData)

## Задание, после которого игра считается «пройденной» (босс побеждён)
const FINALE_QUEST_ID := &"defeat_cooper_knight"

const SFX_QUEST: AudioStream = preload("uid://b1pe4ord4bxue")
const SFX_FINALE: AudioStream = preload("uid://bbfobmlxk6mlx")

var _sfx: AudioStreamPlayer
## QuestData.get_instance_id() -> true: на какие задания уже подписались
var _bound: Dictionary = {}
## Planet_Name -> true: уже праздновали (чтобы не дублировать после загрузки)
var _finale_done: Dictionary = {}
var _full_done: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = _pick_bus()
	add_child(_sfx)

	Global.planets_loaded.connect(_on_planets_loaded)
	_on_planets_loaded()


func _pick_bus() -> StringName:
	for bus_name in ["SFX", "Sfx", "sfx"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			return bus_name
	return &"Master"


## Подписываемся на все задания и запоминаем, что уже выполнено на момент загрузки.
func _on_planets_loaded() -> void:
	for planet in Global.planets_data:
		if planet == null:
			continue
		for quest in planet.get_all_quests():
			if quest == null:
				continue
			var key = quest.get_instance_id()
			if _bound.has(key):
				continue
			_bound[key] = true
			quest.completed.connect(_on_quest_completed.bind(planet))

		var finale_quest = planet.get_quest(FINALE_QUEST_ID)
		_finale_done[planet.Planet_Name] = finale_quest != null and finale_quest.is_completed()
		_full_done[planet.Planet_Name] = planet.max_explore_value > 0 \
				and planet.get_completed_count() >= planet.max_explore_value


func _on_quest_completed(quest: QuestData, planet: PlanetData) -> void:
	quest_completed.emit(planet, quest)

	var title := quest.title if not quest.title.is_empty() else String(quest.quest_id)
	GameJuice.toast(Loc.t("Quest complete: ") + Loc.t(title), Color(0.55, 1.0, 0.6))
	_play(SFX_QUEST)
	_give_rewards(quest)

	var all_done := planet.get_completed_count() >= planet.max_explore_value
	var planet_key := planet.Planet_Name

	if quest.quest_id == FINALE_QUEST_ID and not _finale_done.get(planet_key, false):
		_finale_done[planet_key] = true
		if all_done:
			_full_done[planet_key] = true
		_run_finale(planet)
	elif all_done and not _full_done.get(planet_key, false):
		_full_done[planet_key] = true
		planet_fully_explored.emit(planet)
		GameJuice.banner(Loc.t("100% EXPLORED"), Loc.t(planet_key), Color(1.0, 0.85, 0.3), 2.4)


func _give_rewards(quest: QuestData) -> void:
	for reward in quest.rewards:
		if reward == null or reward.item == null:
			continue
		# .duplicate(): у каждого стака в инвентаре должен быть свой Resource
		Global.pickup_item(reward.item.duplicate(), reward.amount)


func _run_finale(planet: PlanetData) -> void:
	await get_tree().create_timer(1.0).timeout
	GameJuice.banner(Loc.t("PLANET SAVED"), Loc.t(planet.Planet_Name), Color(1.0, 0.85, 0.3), 3.0)
	GameJuice.shake(3.0, 0.5)
	_play(SFX_FINALE)
	await get_tree().create_timer(3.8).timeout
	finale_reached.emit(planet)


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()
