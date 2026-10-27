extends Node
class_name SessionTracker

## Считает статистику текущей сессии (убийства, падения, комбо, время игры)
## и показывает комбо-текст при серии убийств. Создаётся из Global.

signal combo_changed(streak: int)

## Сколько секунд даётся на следующее убийство, чтобы не потерять серию
const COMBO_WINDOW := 3.5

var kills: int = 0
var deaths: int = 0
var best_combo: int = 0
var elites: int = 0
var events: int = 0
var playtime: float = 0.0

var _streak: int = 0
var _combo_left: float = 0.0
var _hook_timer: float = 0.0
var _hooked_player: Node = null


func _ready() -> void:
	Global.enemy_killed.connect(_on_enemy_killed)
	Global.elite_defeated.connect(func(_affixes: Array) -> void: elites += 1)
	Global.world_event_completed.connect(func(_id: String) -> void: events += 1)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null:
		playtime += delta

	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			_streak = 0
			combo_changed.emit(0)

	# Раз в полсекунды проверяем, что на актуального игрока подписаны
	_hook_timer -= delta
	if _hook_timer <= 0.0:
		_hook_timer = 0.5
		_hook_player(player)


func _hook_player(player: Node) -> void:
	if player == null:
		_hooked_player = null
		return
	if player == _hooked_player:
		return
	_hooked_player = player
	if player.has_signal("died") and not player.is_connected("died", _on_player_died):
		player.connect("died", _on_player_died)


func _on_player_died() -> void:
	deaths += 1
	_streak = 0
	_combo_left = 0.0
	combo_changed.emit(0)


func _on_enemy_killed(_enemy_id: String, world_pos: Vector2) -> void:
	kills += 1
	_streak += 1
	_combo_left = COMBO_WINDOW
	best_combo = maxi(best_combo, _streak)
	combo_changed.emit(_streak)
	if _streak < 2:
		return

	# Чем длиннее серия — тем крупнее и краснее надпись
	var t := clampf(float(_streak - 2) / 8.0, 0.0, 1.0)
	var color := Color(1.0, 0.95, 0.5).lerp(Color(1.0, 0.35, 0.2), t)
	GameJuice.floating_text(world_pos + Vector2(0.0, -26.0), Loc.t("COMBO x%d") % _streak,
			color, 1.0 + t * 0.7, 1.1, 30.0, 1.9)

	match _streak:
		5:  GameJuice.toast(Loc.t("Nice! 5 in a row"), Color(1.0, 0.85, 0.3))
		10: GameJuice.toast(Loc.t("RAMPAGE! 10 in a row"), Color(1.0, 0.45, 0.25))
		20: GameJuice.toast(Loc.t("UNSTOPPABLE!"), Color(1.0, 0.25, 0.25))


## Итоги для финального экрана.
func get_summary() -> Dictionary:
	var achievements := Global.get_node_or_null("AchievementTracker") as AchievementTracker
	var done := 0
	var total := 0
	for planet in Global.planets_data:
		if planet == null:
			continue
		done += planet.get_completed_count()
		total += planet.max_explore_value
	return {
		"playtime": playtime,
		"kills": kills,
		"deaths": deaths,
		"best_combo": best_combo,
		"elites": elites,
		"events": events,
		"achv_done": achievements.get_unlocked_count() if achievements else 0,
		"achv_total": achievements.get_total_count() if achievements else 0,
		"quests_done": done,
		"quests_total": total,
	}


## Новая сессия (следующий посетитель выставки).
func reset_session() -> void:
	kills = 0
	deaths = 0
	best_combo = 0
	elites = 0
	events = 0
	playtime = 0.0
	_streak = 0
	_combo_left = 0.0


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
