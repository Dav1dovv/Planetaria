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
@onready var effect_display_ui: EffectDisplayUI      = $GUI/EffectDisplay
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

## Регенерация вне боя: после REGEN_DELAY секунд без урона лечимся REGEN_PER_SEC в секунду.
## Игрок не «выгорает» к середине забега, но и не отхиливается прямо в драке.
const REGEN_DELAY := 5.0
const REGEN_PER_SEC := 1.5
const MIN_INVINCIBILITY := 0.5
var _since_damage: float = 0.0
var _last_health: float = -1.0

func _tick_regen(delta: float) -> void:
	var hp := Entity_stats.current_health
	if _last_health >= 0.0 and hp < _last_health:
		_since_damage = 0.0
	_last_health = hp
	_since_damage += delta
	if _since_damage < REGEN_DELAY or hp >= Entity_stats.max_health:
		return
	Entity_stats.current_health = minf(hp + REGEN_PER_SEC * delta, Entity_stats.max_health)
	_last_health = Entity_stats.current_health
	health_bar.update_value(Entity_stats.current_health, Entity_stats.max_health, corruption)

func _ready() -> void:
	super._ready()
	invincibility_duration = maxf(invincibility_duration, MIN_INVINCIBILITY)
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
		_tick_regen(delta)
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
	$CollisionShape2D.disabled = false
	$Dropper._drop_items()
	gui.call_death()

func respawn() -> void:
	# 1. Entity.die() выключает слой/маску 1 — без возврата игрок проваливается сквозь стены
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	$CollisionShape2D.disabled = false
	if _hurt_col:
		_hurt_col.disabled = false
	gui.call_respawn()

	# 2. Снимаем временные эффекты (яд, ожог, баффы). Постоянные — от реликвий и
	#    оружия в руках — остаются, иначе после возрождения они молча пропадут.
	for type in effect_manager.active_effects.keys().duplicate():
		if not effect_manager.active_effects[type].permanent:
			effect_manager.remove_effect(type)

	# 3. Порча: если она >= HP после возрождения, игрок умирал заново от любого удара
	corruption = minf(corruption, Entity_stats.max_health * 0.15)

	# 4. Состояние боя: умер посреди атаки → is_attack залипал и бить/стрелять было нельзя
	is_attack = false
	_hand.rotation = 0
	combat.is_lunging = false
	movement.current_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_since_damage = 0.0

	# 5. Здоровье — ПОСЛЕ is_alive, иначе проверка смерти в _on_health_changed не сработает как надо
	is_alive = true
	Entity_stats.current_health = Entity_stats.max_health / 3.0
	_last_health = Entity_stats.current_health
	BodyAnimator.play("Idle")
	emit_signal("health_changed", Entity_stats.current_health)
	health_bar.update_value(Entity_stats.current_health, Entity_stats.max_health, corruption)

	_grant_respawn_invincibility()


## 2 секунды неуязвимости, чтобы не умереть сразу на месте возрождения.
func _grant_respawn_invincibility(seconds: float = 2.0) -> void:
	is_invincible = true
	await get_tree().create_timer(seconds).timeout
	is_invincible = false


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
