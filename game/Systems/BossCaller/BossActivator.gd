extends Sprite2D

@export var Boss : PackedScene
@export_placeholder("Scare") var boss_name : String = ""
## Пауза между «пробуждением» и появлением босса, секунды
@export var spawn_delay: float = 2.0
@onready var interaction: interaction_area = $interaction_area
const ARTEFACT_BOSS_CALLER = preload("uid://b63ly05pw5sp4")

var _summoning: bool = false


func _ready() -> void:
	interaction.interact = Callable(self, "interact")


func interact() -> void:
	if _summoning:
		return
	if not Global.inventory.has_total_item(ARTEFACT_BOSS_CALLER, 1):
		# Раньше игрок просто ничего не получал в ответ — теперь есть подсказка
		Global.hint(self, Loc.t("Needs a Boss Caller"))
		return

	Global.inventory.remove_from_total(ARTEFACT_BOSS_CALLER, 1)
	_summoning = true
	Global.developer_console.log_message(boss_name + " awakening", Color(0.52, 0.0, 0.0, 1.0))

	# Драматургия: баннер + нарастающая тряска, и только потом босс.
	# Раньше таймер создавался, но его никто не ждал — босс появлялся мгновенно.
	GameJuice.banner(boss_name.to_upper(), Loc.t("awakens…"), Color(0.85, 0.15, 0.1), spawn_delay)
	GameJuice.shake(3.0, spawn_delay)
	await get_tree().create_timer(spawn_delay).timeout

	_spawn_boss()
	_summoning = false


func _spawn_boss() -> void:
	if Boss == null:
		push_warning("BossActivator: Boss не назначен в Инспекторе")
		return

	# Родитель родителя — как в оригинале (слой с Y-сортировкой); запасной вариант — корень мира
	var parent: Node = null
	if get_parent() != null:
		parent = get_parent().get_parent()
	if parent == null:
		parent = get_tree().get_first_node_in_group("World")
	if parent == null:
		return

	var boss_instance := Boss.instantiate() as Node2D
	boss_instance.add_to_group("Boss")  # события и элиты не запускаются во время боя с боссом
	parent.add_child(boss_instance)
	boss_instance.global_position = global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
