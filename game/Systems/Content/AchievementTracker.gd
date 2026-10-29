extends Node
class_name AchievementTracker

## Мелкие «медальки» за этапы игры: тост, звук и немного монет. Каждое действие
## игрока приближает к какой-нибудь цели — это и держит интерес.
##
## Прогресс (открытые достижения И счётчики) хранится в слоте сохранения:
## user://Saves/{slot}/achievements.json. Открытое достижение больше никогда не
## объявляется и не выдаёт награду повторно. Окно достижений — AchievementsWindow.

signal unlocked(id: StringName)

const SFX: AudioStream = preload("uid://bbfobmlxk6mlx")
const GOLD := Color(1.0, 0.85, 0.3)

## Счётчики меняются часто (каждый убитый враг), поэтому пишем на диск не
## каждый раз, а через паузу после последнего изменения. Новое достижение
## и закрытие игры сохраняют сразу.
const SAVE_DELAY := 2.0
const SAVE_VERSION := 1

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

## id → unix-время открытия
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

## Слот, чей прогресс сейчас в памяти. Сверяется с Global.current_save_slot
## лениво (см. _ensure_loaded), поэтому не нужно вешать хуки на load_save.
var _loaded_slot: String = ""
var _dirty: bool = false
var _save_timer: Timer


func _ready() -> void:
	add_to_group("AchievementTracker")  # по нему окно находит трекер

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = SFX
	_sfx.pitch_scale = 2.5
	add_child(_sfx)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS  # не замирает на паузе
	_save_timer.timeout.connect(_flush)
	add_child(_save_timer)

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

	_ensure_loaded()


func _exit_tree() -> void:
	_flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush()


# ─────────────────────────────────────────────────────────────────────────────
#  Публичный API (его использует окно достижений)
# ─────────────────────────────────────────────────────────────────────────────

func get_unlocked_count() -> int:
	_ensure_loaded()
	return _unlocked.size()


func get_total_count() -> int:
	return LIST.size()


func is_unlocked(id: StringName) -> bool:
	_ensure_loaded()
	return _unlocked.has(id)


## Unix-время открытия или 0, если достижение ещё не открыто.
func get_unlocked_time(id: StringName) -> int:
	_ensure_loaded()
	return int(_unlocked.get(id, 0))


## Vector2i(текущее, цель); текущее не превышает цель.
func get_progress(id: StringName) -> Vector2i:
	_ensure_loaded()
	var p := _progress(id)
	return Vector2i(mini(p.x, p.y), p.y)


## Новая сессия. По умолчанию просто перечитывает сохранённый прогресс слота
## (открытое не «забывается»). wipe_saved = true стирает и сохранённый прогресс.
func reset(wipe_saved: bool = false) -> void:
	_save_timer.stop()
	_clear_progress()
	if wipe_saved:
		_dirty = true
		_flush()
	else:
		_dirty = false
		_loaded_slot = ""
		_ensure_loaded()


# ─────────────────────────────────────────────────────────────────────────────
#  Обработчики событий
# ─────────────────────────────────────────────────────────────────────────────

func _on_enemy_killed(enemy_id: String, _pos: Vector2) -> void:
	_ensure_loaded()
	_kills_total += 1
	_kills[enemy_id] = int(_kills.get(enemy_id, 0)) + 1
	_evaluate()


func _on_item_picked(item: ItemData, amount: int) -> void:
	if _granting:
		return  # награды за достижения сами достижения не двигают
	_ensure_loaded()
	_items_total += amount
	match item.item_name:
		"Wood": _wood += amount
		"Stone": _stone += amount
		"Coin": _coins += amount
	_evaluate()


func _on_elite_defeated(_affixes: Array) -> void:
	_ensure_loaded()
	_elites += 1
	_evaluate()


func _on_event_completed(_event_id: String) -> void:
	_ensure_loaded()
	_events += 1
	_evaluate()


func _on_combo_changed(streak: int) -> void:
	_ensure_loaded()
	if streak <= _best_combo:
		return  # рекорд не побит — нечего считать и сохранять
	_best_combo = streak
	_evaluate()


func _on_quest_completed(_planet: PlanetData, _quest: QuestData) -> void:
	_ensure_loaded()
	_quests += 1
	_evaluate()


# ─────────────────────────────────────────────────────────────────────────────
#  Прогресс и условия
# ─────────────────────────────────────────────────────────────────────────────

## Vector2i(сколько набрано, сколько нужно). Единственное место, где описаны
## условия: и «заработано ли», и полоски прогресса в окне считаются отсюда.
func _progress(id: StringName) -> Vector2i:
	match id:
		&"first_blood": return Vector2i(_kills_total, 1)
		&"slime_slayer": return Vector2i(int(_kills.get("slime", 0)), 10)
		&"pig_wrangler": return Vector2i(int(_kills.get("pig", 0)), 12)
		&"combo_5": return Vector2i(_best_combo, 5)
		&"combo_10": return Vector2i(_best_combo, 10)
		&"elite_hunter": return Vector2i(_elites, 1)
		&"elite_bane": return Vector2i(_elites, 3)
		&"collector": return Vector2i(_items_total, 200)
		&"lumberjack": return Vector2i(_wood, 30)
		&"stonemason": return Vector2i(_stone, 30)
		&"treasure_hunter": return Vector2i(_coins, 200)
		&"event_hero": return Vector2i(_events, 1)
		&"event_veteran": return Vector2i(_events, 3)
		&"quest_hand": return Vector2i(_quests, 3)
		&"knight_breaker": return Vector2i(int(_kills.get("cooperknight", 0)), 1)
	return Vector2i(0, 1)


func _is_earned(id: StringName) -> bool:
	var p := _progress(id)
	return p.x >= p.y


func _evaluate() -> void:
	_dirty = true
	var any_new := false
	for entry in LIST:
		var id: StringName = entry[0]
		if _unlocked.has(id) or not _is_earned(id):
			continue
		_unlocked[id] = int(Time.get_unix_time_from_system())
		any_new = true
		_announce(entry)
	if any_new:
		_flush()  # новое достижение не должно потеряться при вылете
	elif _save_timer.is_stopped():
		_save_timer.start()


func _announce(entry: Array) -> void:
	GameJuice.toast(Loc.t("Achievement unlocked: ") + Loc.t(entry[1]), GOLD, 3.2)
	_sfx.play()
	_granting = true
	Global.pickup_item(LootUtil.COIN.duplicate(), int(entry[3]), true)
	_granting = false
	unlocked.emit(entry[0])


# ─────────────────────────────────────────────────────────────────────────────
#  Сохранение / загрузка
# ─────────────────────────────────────────────────────────────────────────────

func _is_known(id: StringName) -> bool:
	for entry in LIST:
		if entry[0] == id:
			return true
	return false


func _clear_progress() -> void:
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


## Подгружает прогресс, если текущий слот сменился (или это первый вызов).
## Незаписанный прогресс прошлого слота дописывается до переключения.
func _ensure_loaded() -> void:
	var slot: String = Global.current_save_slot
	if slot == _loaded_slot:
		return
	_flush()
	_clear_progress()
	_loaded_slot = slot
	_dirty = false
	if slot.is_empty():
		return
	var saves := SaveLoadSystem.find_instance(get_tree())
	if saves:
		_apply(saves.load_achievements(slot))


func _apply(data: Dictionary) -> void:
	if data.is_empty():
		return
	var saved_unlocked: Dictionary = data.get("unlocked", {})
	for key in saved_unlocked:
		var id := StringName(str(key))
		if _is_known(id):  # выкинутые из игры достижения не засоряют счётчик
			_unlocked[id] = int(saved_unlocked[key])
	var saved_kills: Dictionary = data.get("kills", {})
	for key in saved_kills:
		_kills[str(key)] = int(saved_kills[key])
	_kills_total = int(data.get("kills_total", 0))
	_items_total = int(data.get("items_total", 0))
	_wood = int(data.get("wood", 0))
	_stone = int(data.get("stone", 0))
	_coins = int(data.get("coins", 0))
	_elites = int(data.get("elites", 0))
	_events = int(data.get("events", 0))
	_quests = int(data.get("quests", 0))
	_best_combo = int(data.get("best_combo", 0))


func _to_dict() -> Dictionary:
	var unlocked_out := {}
	for id in _unlocked:
		unlocked_out[str(id)] = _unlocked[id]
	return {
		"version": SAVE_VERSION,
		"unlocked": unlocked_out,
		"kills": _kills,
		"kills_total": _kills_total,
		"items_total": _items_total,
		"wood": _wood,
		"stone": _stone,
		"coins": _coins,
		"elites": _elites,
		"events": _events,
		"quests": _quests,
		"best_combo": _best_combo,
	}


## Пишет прогресс на диск, если он изменился. Пишет в слот, чей прогресс
## лежит в памяти (_loaded_slot), а не в текущий — они могут не совпадать
## в момент переключения слота.
func _flush() -> void:
	if _save_timer:
		_save_timer.stop()
	if not _dirty or _loaded_slot.is_empty():
		return
	var saves = SaveLoadSystem.find_instance(get_tree()) if is_inside_tree() else null
	if saves and saves.save_achievements(_to_dict(), _loaded_slot):
		_dirty = false
