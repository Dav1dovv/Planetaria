extends Entity
class_name Player

const ANIM_SPEED_SCALE      := 1.5
const HAND_ANIM_SPEED_SCALE := 1.0

# ─────────────────────────────────────────────────────────────────────────────
#  Компоненты
#  Новый функционал добавляй отдельным Node + скриптом (по образцу этих трёх),
#  а не новыми переменными/методами прямо здесь.
# ─────────────────────────────────────────────────────────────────────────────

@onready var movement:     PlayerMovement    = %PlayerMovement
@onready var combat:       PlayerCombat      = $PlayerCombat
@onready var dev_commands: PlayerDevCommands = $PlayerDevCommands

# ─────────────────────────────────────────────────────────────────────────────
#  Ноды
# ─────────────────────────────────────────────────────────────────────────────

@onready var gui:               CanvasLayer          = $GUI
@onready var health_bar:        health_bar           = $GUI/HUD/HealthBar
@onready var skin                                    = $Skin
@onready var hit_box:           player_HitBox        = %player_HitBox
@onready var defense_label:     Label                = $HUD/HBoxContainer/Deffense/Label
@onready var death_menu:        Control              = $HUD/DeathMenu
@onready var effect_display_ui: EffectDisplayUI      = $GUI/HUD/EffectDisplayUI
@onready var _hand:             Node2D               = $Skin/Body/Hand
@onready var _hurt_col:         CollisionShape2D     = $HurtBox/CollisionShape2D
@onready var curse_label:       Label                = $HUD/HealthBar/HBoxContainer/CurseIcon/CurseLabel
@onready var weapon_passive:    WeaponPassiveHandler = $WeaponPassiveHandler

@export var BodyAnimator:  AnimationPlayer
@export var HandAanimator: AnimationPlayer

var dir:       Vector2 = Vector2.ZERO
var mouse_pos: Vector2 = Vector2.ZERO
var is_attack: bool    = false

var corruption: float = 0
var hunger : int = 100

# ─────────────────────────────────────────────────────────────────────────────
#  Инициализация
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	Global.hotbar    = get_tree().get_first_node_in_group("Hotbar")    as Hotbar
	Global.inventory = get_tree().get_first_node_in_group("Inventory") as Inventory
	get_tree().get_first_node_in_group("DebugObject").update()
	gui.player = self

	SaveLoad.load_player(self)
	print("Player Corruption Level is: " + str(corruption))

	if Entity_stats.current_health <= 0:
		Entity_stats.current_health = Entity_stats.max_health
		_on_health_changed(Entity_stats.current_health)

	health_bar.update_value(Entity_stats.current_health, Entity_stats.max_health, corruption)

	effect_display_ui.set_entity(self)

	dev_commands.register_all()
	movement.try_resume_pending_exit_walk()


# ─────────────────────────────────────────────────────────────────────────────
#  Физика и движение
# ─────────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	mouse_pos = get_global_mouse_position()

	if is_alive:
		if not combat.is_lunging:
			velocity = movement.process(delta)
		_animate()

		if not is_attack:
			hit_box.look_at(mouse_pos)

		if velocity.length_squared() <= 1.0 or is_attack:
			skin.scale.x = scale.x if mouse_pos.x > position.x else -scale.x

	move_and_slide()


func _animate() -> void:
	var looking_right   := mouse_pos.x > position.x
	var moving_backward := (looking_right and velocity.x < 0) or (not looking_right and velocity.x > 0)

	if velocity.length_squared() > 1.0:
		var spd := -1.0 if moving_backward else 1.0
		BodyAnimator.play("Walk", -1.0, spd)
		if not is_attack:
			HandAanimator.play("Walk", -1.0, spd)
	else:
		BodyAnimator.play("Idle")
		if not is_attack:
			HandAanimator.play("Idle")


# ─────────────────────────────────────────────────────────────────────────────
#  Ввод
# ─────────────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	combat.handle_input(event)


# ─────────────────────────────────────────────────────────────────────────────
#  Публичное API (дергается извне: анимациями, дверями, дебафами и т.п.)
#  Имена оставлены как в исходнике, чтобы не пересобирать связи в редакторе.
# ─────────────────────────────────────────────────────────────────────────────

func shoot() -> void:
	combat.shoot()

func _on_weapon_hit(target: Node) -> void:
	combat.on_weapon_hit(target)

func queue_exit_walk(direction: Vector2, duration: float, speed_mult: float) -> void:
	Global.pending_exit_walk = {
		"active":     true,
		"direction":  direction,
		"duration":   duration,
		"speed_mult": speed_mult,
	}


# ─────────────────────────────────────────────────────────────────────────────
#  Здоровье / порча (corruption) / смерть
# ─────────────────────────────────────────────────────────────────────────────

func remove_curse(value: int) -> void:
	corruption -= value
	health_bar.update_value(Entity_stats.current_health, Entity_stats.max_health, corruption)
	cure_infection(value)

func _on_health_changed(new_health: float) -> void:
	health_bar.update_value(new_health, Entity_stats.max_health, corruption)
	if new_health <= corruption:
		die()

func _on_died() -> void:
	Global.play_game_over()
	HandAanimator.stop()
	BodyAnimator.play("Death")
	gui.call_death()

func respawn() -> void:
	Entity_stats.current_health = Entity_stats.max_health / 3.0
	_on_health_changed(Entity_stats.current_health)
	movement.current_velocity = Vector2.ZERO
	combat.is_lunging          = false
	is_alive                   = true


#region infection
func add_infection(amount: float) -> void:
	# Пример использования EffectManager вне самого менеджера: если активен
	# INFECTION_RESIST, домножаем накопление заражения на его value (напр. x0.7).
	amount *= effect_manager.get_effect_value(Effect.EffectType.INFECTION_RESIST, 1.0)
	corruption += amount
	coruption_change()

func cure_infection(amount: float) -> void:
		corruption -= amount
		coruption_change()

func full_cure_infection() -> void:
		corruption = 0
		coruption_change()


func coruption_change() -> void:
	health_bar.update_value(Entity_stats.current_health, Entity_stats.max_health, corruption)
	if corruption >= Entity_stats.current_health:
		die()
	elif corruption >= Entity_stats.max_health:
		die()

#endregion
# ─────────────────────────────────────────────────────────────────────────────
#  Сохранение (вызывается через group "Save")
# ─────────────────────────────────────────────────────────────────────────────

func save_game() -> void:
	SaveLoad.save_player(self)
