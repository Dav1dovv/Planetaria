extends Creature
class_name NPC

@onready var interaction: interaction_area = $interaction_area

## Расстояние, на котором НПС останавливается и смотрит на игрока
@export var awareness_radius: float = 80.0
## Расстояние, на котором НПС поворачивается лицом к игроку
@export var face_player_radius: float = 40.0

var inventory
@export var player: Player

var _npc_stopped: bool = false

func _ready() -> void:
	super._ready()
	if !player:
		player = get_tree().get_first_node_in_group("Player")
	inventory = get_tree().get_first_node_in_group("Inventory")
	interaction.interact = Callable(self, "Interact")

func Interact() -> void:
	if $show_dialog:
		$show_dialog.start()

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if current_state == State.DEAD:
		return

	# ОПТИМИЗАЦИЯ: sqrt не нужен — сравниваем квадраты расстояний
	var dist_sq := global_position.distance_squared_to(player.global_position)
	var face_radius_sq := face_player_radius * face_player_radius
	var awareness_radius_sq := awareness_radius * awareness_radius

	if dist_sq <= face_radius_sq:
		# Смотрим на игрока — останавливаемся и поворачиваемся
		if not _npc_stopped:
			_npc_stopped = true
			_enter_state(State.IDLE)
		var dir_to_player := (player.global_position - global_position).normalized()
		_facing_dir = dir_to_player
		if dir_to_player.x != 0.0:
			$Skin.scale.x = -1.0 if dir_to_player.x < 0.0 else 1.0

	elif dist_sq <= awareness_radius_sq:
		# В зоне осведомлённости — останавливаемся, но не поворачиваемся
		if not _npc_stopped:
			_npc_stopped = true
			_enter_state(State.IDLE)

	else:
		# Игрок ушёл — возобновляем обычное поведение
		if _npc_stopped:
			_npc_stopped = false
			_enter_state(_default_start_state())
