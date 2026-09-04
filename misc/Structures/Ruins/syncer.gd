extends Node2D
class_name Syncer

@onready var interaction: interaction_area   = $interaction_area
@onready var particles: GPUParticles2D       = $GPUParticles2D
@onready var sfx: AudioStreamPlayer2D        = $AudioStreamPlayer2D

## .dialogue-файл синкера (Syncer.dialogue)
@export var dialogue_resource: DialogueResource

## Сколько золота стоит сохранение здесь
@export var save_cost: int = 20

const COLOR_ENOUGH     := "#6bdc6b"
const COLOR_NOT_ENOUGH := "#ff5c5c"

## Синкер одноразовый — после успешной активации навсегда потрачен
var _used: bool = false


func _ready() -> void:
	interaction.interact = Callable(self, "_on_interact")


func _on_interact() -> void:
	if _used or not dialogue_resource:
		return
	# передаём сам синкер как extra_game_state — диалог сможет звать
	# price_text() / has_enough_gold() / save() прямо на этом объекте
	DialogueManager.show_dialogue_balloon(dialogue_resource, "start", [self])


# ─────────────────────────────────────────────────────────────────
#  Вызывается из диалога через {{ }} / [if ...]
# ─────────────────────────────────────────────────────────────────

## Цветной текст "баланс / цена" для подстановки в реплику диалога
func price_text() -> String:
	var balance := _get_balance()
	var color := COLOR_ENOUGH if balance >= save_cost else COLOR_NOT_ENOUGH
	return "[color=%s]%d[/color] / %d" % [color, balance, save_cost]

func has_enough_gold() -> bool:
	return _get_balance() >= save_cost

func _get_balance() -> int:
	if Global.inventory and Global.inventory.gold_slot:
		return Global.inventory.gold_slot.get_balance()
	return 0


# ─────────────────────────────────────────────────────────────────
#  Вызывается из диалога через `do save()` при подтверждении оплаты
# ─────────────────────────────────────────────────────────────────
func save() -> void:
	if _used:
		return
	if not Global.inventory or not Global.inventory.gold_slot:
		return
	if not Global.inventory.gold_slot.spend(save_cost):
		return  # подстраховка — по идее выбор скрыт условием [if has_enough_gold()]

	_used = true
	interaction.queue_free()

	particles.emitting = true
	sfx.play()

	var game   = get_tree().get_first_node_in_group("World")
	var player = get_tree().get_first_node_in_group("Player")
	if game and player:
		game.set_spawn_point(player.position)

	Global.save()
