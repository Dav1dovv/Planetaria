extends Node
class_name ElderDirector

## Ставит Старейшину рядом с игроком при входе на планету и показывает на него
## стрелку, пока задание «Поговорить со старейшиной» не выполнено.
## Всё делается в рантайме — править сцену мира не нужно.

const ELDER_SCENE := preload("res://misc/Entity/NPC/NPC_Elder.tscn")
const QUEST_ID := "meet_elder"
const SPAWN_DELAY := 1.5

var _seen_player: Node = null
var _delay: float = 0.0
var _elder: Node2D = null
var _marker_id: int = -1


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null or Global.get_planet(Global.current_location) == null:
		_forget()
		return

	if player != _seen_player:
		_seen_player = player
		_delay = SPAWN_DELAY
		_marker_id = -1
		_elder = null
		return

	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			_spawn(player)
		return

	_update_marker()


func _spawn(player: Node2D) -> void:
	var existing := get_tree().get_first_node_in_group("QuestGiver") as Node2D
	if existing != null:
		_elder = existing
		return
	var parent: Node = get_tree().get_first_node_in_group("World")
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return
	var elder := ELDER_SCENE.instantiate() as Node2D
	var side := 1.0 if randf() < 0.5 else -1.0
	elder.global_position = player.global_position + Vector2(56.0 * side, randf_range(-20.0, 20.0))
	parent.add_child(elder)
	_elder = elder


func _update_marker() -> void:
	var marker := Global.get_node_or_null("ObjectiveMarker") as ObjectiveMarker
	if marker == null:
		return
	var needed = is_instance_valid(_elder) and not Global.is_quest_done(QUEST_ID)
	if needed and _marker_id == -1:
		_marker_id = marker.track(_elder, Loc.t("Старейшина"))
	elif not needed and _marker_id != -1:
		marker.untrack(_marker_id)
		_marker_id = -1


func _forget() -> void:
	_seen_player = null
	_elder = null
	if _marker_id != -1:
		var marker := Global.get_node_or_null("ObjectiveMarker") as ObjectiveMarker
		if marker:
			marker.untrack(_marker_id)
		_marker_id = -1
