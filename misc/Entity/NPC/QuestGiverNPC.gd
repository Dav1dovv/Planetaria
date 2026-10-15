extends NPC
class_name QuestGiverNPC

## NPC, который по взаимодействию открывает диалог (Dialogue Manager) и пока
## задание не выполнено — подмигивает золотым «!» над головой.
## Настраивается в Инспекторе: dialogue, dialogue_start, quest_id.

const DEFAULT_DIALOGUE := "res://misc/Dialogs/Elder/Elder.dialogue"

@export var dialogue: DialogueResource
@export var dialogue_start: String = "start"
## Пока это задание не выполнено — над NPC мигает «!»
@export var quest_id: StringName = &"meet_elder"
@export var marker_interval: float = 1.6


func _ready() -> void:
	super._ready()
	add_to_group("QuestGiver")
	if dialogue == null and ResourceLoader.exists(DEFAULT_DIALOGUE):
		dialogue = load(DEFAULT_DIALOGUE) as DialogueResource

	var timer := Timer.new()
	timer.wait_time = marker_interval
	timer.autostart = true
	timer.timeout.connect(_pulse_marker)
	add_child(timer)


## Вызывается системой взаимодействия (NPC.gd привязывает именно "_Do").
func _Do() -> void:
	if dialogue == null:
		push_warning("QuestGiverNPC: не назначен dialogue")
		return
	DialogueManager.show_dialogue_balloon(dialogue, dialogue_start)


func _pulse_marker() -> void:
	if Global.is_quest_done(quest_id) or not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null or player.global_position.distance_to(global_position) > 260.0:
		return
	GameJuice.floating_text(global_position + Vector2(0.0, -26.0), "!", Color(1.0, 0.85, 0.3), 1.5, 1.2, 8.0, 1.8)
