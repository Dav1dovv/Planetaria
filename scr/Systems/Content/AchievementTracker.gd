extends Node
class_name AchievementTracker

## Мелкие «медальки» за этапы игры: тост, звук и немного монет. Каждое действие
## игрока приближает к какой-нибудь цели — это и держит интерес.
## Прогресс живёт в памяти и сбрасывается вместе с сессией (режим выставки).

signal unlocked(id: StringName)

const SFX: AudioStream = preload("res://Assets/Audio/SFX/WIN_SFX.mp3")
const GOLD := Color(1.0, 0.85, 0.3)

## id, ключ названия, ключ описания, монеты в награду
const LIST: Array[Array] = [
	[&"first_blood", "First Blood", "Defeat your first enemy", 10],
	[&"slime_slayer", "Slime Slayer", "Defeat 10 slimes", 20],
	[&"pig_wrangler", "Pig Wrangler", "Defeat 12 pigs", 20],
	[&"combo_5", "Combo Starter", "Reach a 5x combo", 15],
	[&"combo_10", "Combo Master", "Reach a 10x combo", 40],
	[&"elite_hunter", "Elite Hunter", "Defeat an elite enemy", 30],
	[&"elite_bane", "Elite Bane", "Defeat 3 elite enemies", 60],
	[&"collector", "Collector", "Pick up 40 items", 20],
	[&"lumberjack", "Lumberjack", "Gather 30 wood", 20],
	[&"stonemason", "Stonemason", "Gather 30 stone", 20],
	[&"treasure_hunter", "Treasure Hunter", "Collect 200 coins", 30],
	[&"event_hero", "Event Hero", "Complete a world event", 30],
	[&"event_veteran", "Event Veteran", "Complete 3 world events", 60],
	[&"quest_hand", "Quest Hand", "Complete 3 quests", 30],
	[&"knight_breaker", "Knight Breaker", "Defeat the Copper Knight", 100],
]

var _unlocked: Dictionary = {}
var _kills: Dictionary = {}
var _kills_total: int = 0
var _items_total: int = 0
var _wood: int = 0
var _stone: int = 0
var _coins: int = 0
var _elites: int = 0
var _events: int = 0
var _quests: int = 0
var _best_combo: int = 0
var _granting: bool = false
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = SFX
	_sfx.pitch_scale = 2.5
	add_child(_sfx)

	Global.enemy_killed.connect(_on_enemy_killed)
	Global.item_picked.connect(_on_item_picked)
	Global.elite_defeated.connect(_on_elite_defeated)
	Global.world_event_completed.connect(_on_event_completed)

	var tracker := Global.get_node_or_null("SessionTracker") as SessionTracker
	if tracker:
		tracker.combo_changed.connect(_on_combo_changed)
	var celebrator := Global.get_node_or_null("QuestCelebrator") as QuestCelebrator
	if celebrator:
		celebrator.quest_completed.connect(_on_quest_completed)


func get_unlocked_count() -> int:
	return _unlocked.size()


func get_total_count() -> int:
	return LIST.size()


## Новая сессия (следующий посетитель выставки).
func reset() -> void:
	_unlocked.clear()
	_kills.clear()
	_kills_total = 0
	_items_total = 0
	_wood = 0
	_stone = 0
	_coins = 0
	_elites = 0
	_events = 0
	_quests = 0
	_best_combo = 0


func _on_enemy_killed(enemy_id: String, _pos: Vector2) -> void:
	_kills_total += 1
	_kills[enemy_id] = int(_kills.get(enemy_id, 0)) + 1
	_evaluate()


func _on_item_picked(item: ItemData, amount: int) -> void:
	if _granting:
		return  # награды за достижения сами достижения не двигают
	_items_total += amount
	match item.item_name:
		"Wood": _wood += amount
		"Stone": _stone += amount
		"Coin": _coins += amount
	_evaluate()


func _on_elite_defeated(_affixes: Array) -> void:
	_elites += 1
	_evaluate()


func _on_event_completed(_event_id: String) -> void:
	_events += 1
	_evaluate()


func _on_combo_changed(streak: int) -> void:
	_best_combo = maxi(_best_combo, streak)
	_evaluate()


func _on_quest_completed(_planet: PlanetData, _quest: QuestData) -> void:
	_quests += 1
	_evaluate()


func _is_earned(id: StringName) -> bool:
	match id:
		&"first_blood": return _kills_total >= 1
		&"slime_slayer": return int(_kills.get("slime", 0)) >= 10
		&"pig_wrangler": return int(_kills.get("pig", 0)) >= 12
		&"combo_5": return _best_combo >= 5
		&"combo_10": return _best_combo >= 10
		&"elite_hunter": return _elites >= 1
		&"elite_bane": return _elites >= 3
		&"collector": return _items_total >= 40
		&"lumberjack": return _wood >= 30
		&"stonemason": return _stone >= 30
		&"treasure_hunter": return _coins >= 200
		&"event_hero": return _events >= 1
		&"event_veteran": return _events >= 3
		&"quest_hand": return _quests >= 3
		&"knight_breaker": return int(_kills.get("cooperknight", 0)) >= 1
	return false


func _evaluate() -> void:
	for entry in LIST:
		var id: StringName = entry[0]
		if _unlocked.has(id) or not _is_earned(id):
			continue
		_unlocked[id] = true
		_announce(entry)


func _announce(entry: Array) -> void:
	GameJuice.toast(Loc.t("Achievement unlocked: ") + Loc.t(entry[1]), GOLD, 3.2)
	_sfx.play()
	_granting = true
	Global.pickup_item(LootUtil.COIN.duplicate(), int(entry[3]), true)
	_granting = false
	unlocked.emit(entry[0])
