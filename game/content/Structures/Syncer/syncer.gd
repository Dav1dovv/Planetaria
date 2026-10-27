extends Node2D
class_name Syncer

@onready var interaction: interaction_area   = $interaction_area
@onready var particles: GPUParticles2D       = $GPUParticles2D
@onready var sfx: AudioStreamPlayer2D        = $AudioStreamPlayer2D

const COLOR_ENOUGH     := "#6bdc6b"
const COLOR_NOT_ENOUGH := "#ff5c5c"

## Синкер одноразовый — после успешной активации навсегда потрачен
var _used: bool = false
var player : Player

func _ready() -> void:
	interaction.interact = Callable(self, "_on_interact")


func _on_interact() -> void:
	if !_used:
		player = get_tree().get_first_node_in_group("Player")
		$Sprite2D.play("Turn")
		player.heal(100)
		$GPUParticles2D.emitting = true
		save()
		$interaction_area.queue_free()
		#GameJuice.banner(boss_name.to_upper(), Loc.t("awakens…"), Color(0.85, 0.15, 0.1), 1.8)
		GameJuice.shake(17,0.3)
		GameJuice.banner("CHECKPOINT","checkpoint set and progress saved",Color(0.137, 0.412, 0.706, 1.0))

		

func save() -> void:
	_used = true
	interaction.queue_free()

	particles.emitting = true
	sfx.play()

	var game   = get_tree().get_first_node_in_group("World")
	player = get_tree().get_first_node_in_group("Player")
	if game and player:
		game.set_spawn_point(player.position)

	Global.save()
