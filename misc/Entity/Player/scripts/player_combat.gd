extends Node
class_name PlayerCombat
## Компонент боя игрока: обычная атака, рывок (lunge) и стрельба.
##
## Сюда добавляй новые типы оружия/способностей — например, если появится
## оружие с зарядкой удара, это отдельный метод + флаг здесь, а не в Player.

var is_lunging:       bool    = false
var _lunge_timer:      float   = 0.0
var _lunge_direction:  Vector2 = Vector2.ZERO
var _lunge_hit_bodies: Array   = []

@onready var player: Player = get_parent()


# ─────────────────────────────────────────────────────────────────────────────
#  Ввод / атака
# ─────────────────────────────────────────────────────────────────────────────

func handle_input(event: InputEvent) -> void:
	if not event.is_action_pressed("LMB") or player.is_attack or Global.is_opened_menu:
		return

	var hit_box   := player.hit_box
	var hand_anim := player.HandAanimator

	if hit_box.is_weapon and hit_box.equip is equip_data:
		var equip := hit_box.equip as equip_data
		hit_box.look_at(player.mouse_pos)
		player.is_attack      = true
		hand_anim.speed_scale = equip.Atk_speed
		hand_anim.play(equip.play_anim)

		if equip.lunge_enabled and not is_lunging:
			start_lunge(equip)

		if equip.play_anim == "Attack":
			call_deferred("_start_attack_cooldown", equip.one_shot_attack)
		elif equip.play_anim == "Shoot":
			player._hand.look_at(player.mouse_pos)
			call_deferred("_start_shot_cooldown", equip.one_shot_attack)

	elif hit_box.equip is FoodData:
		player.is_attack = true
		hand_anim.play(hit_box.equip.play_anim)
		call_deferred("_start_eat_cooldown")

	else:
		player.is_attack = true
		hand_anim.play(hit_box.equip.play_anim)
		call_deferred("_start_attack_cooldown", true)


func _start_attack_cooldown(one_shot: bool) -> void:
	var hand_anim := player.HandAanimator
	await hand_anim.animation_finished
	player.is_attack = false
	player.hit_box.look_at(player.mouse_pos)

	if not one_shot and Input.is_action_pressed("LMB") \
			and player.hit_box.is_weapon and player.hit_box.equip is equip_data:
		var equip := player.hit_box.equip as equip_data
		player.is_attack       = true
		hand_anim.speed_scale  = equip.Atk_speed
		hand_anim.play(player.hit_box.play_anim)
		player.hit_box.look_at(player.mouse_pos)
		if equip.lunge_enabled and not is_lunging:
			start_lunge(equip)
		call_deferred("_start_attack_cooldown", false)


func _start_shot_cooldown(one_shot: bool) -> void:
	var hand_anim := player.HandAanimator
	await hand_anim.animation_finished
	player.is_attack = false
	player._hand.look_at(player.mouse_pos)
	player.hit_box.look_at(player.mouse_pos)

	if not one_shot and Input.is_action_pressed("LMB") \
			and player.hit_box.is_weapon and player.hit_box.equip is equip_data:
		var equip := player.hit_box.equip as equip_data
		player.is_attack      = true
		hand_anim.speed_scale = equip.Atk_speed
		hand_anim.play(player.hit_box.play_anim)
		player.hit_box.look_at(player.mouse_pos)
		call_deferred("_start_attack_cooldown", false)
	else:
		player._hand.rotation = 0


func _start_eat_cooldown() -> void:
	await player.HandAanimator.animation_finished
	player.is_attack = false


# ─────────────────────────────────────────────────────────────────────────────
#  Lunge (рывок-атака)
# ─────────────────────────────────────────────────────────────────────────────

func start_lunge(equip: equip_data) -> void:
	is_lunging        = true
	_lunge_timer       = equip.lunge_duration
	_lunge_direction   = (player.mouse_pos - player.global_position).normalized()
	_lunge_hit_bodies  = []

	if equip.lunge_invincible:
		player._hurt_col.disabled = true

	if equip.lunge_trail_scene:
		var trail := equip.lunge_trail_scene.instantiate()
		player.get_parent().add_child(trail)
		if trail.has_method("start"):
			trail.start(player)

	player.hit_box.look_at(player.global_position + _lunge_direction)


func update_lunge(delta: float) -> void:
	## ВНИМАНИЕ: в исходном скрипте этот метод (_update_lunge) нигде не
	## вызывался из _physics_process — я оставил то же поведение (см.
	## комментарий в Player._physics_process). Если рывок у тебя реально
	## работает — значит, что-то вызывает его иначе; если нет — просто
	## раскомментируй вызов в Player, я его пометил.
	var equip := player.hit_box.equip as equip_data
	if not equip:
		end_lunge()
		return

	_lunge_timer -= delta
	player.velocity = _lunge_direction * equip.lunge_speed

	if player.weapon_passive:
		player.weapon_passive.apply_lunge_damage(_lunge_hit_bodies, equip.Damage * equip.lunge_damage_multiplier)

	if _lunge_timer <= 0.0:
		end_lunge()


func end_lunge() -> void:
	is_lunging        = false
	_lunge_timer       = 0.0
	_lunge_hit_bodies  = []
	player.movement.sync_after_lunge(player.velocity)

	var equip := player.hit_box.equip as equip_data
	if equip and equip.lunge_invincible:
		player._hurt_col.disabled = false


# ─────────────────────────────────────────────────────────────────────────────
#  Стрельба
# ─────────────────────────────────────────────────────────────────────────────

func shoot() -> void:
	var equip := player.hit_box.equip as equip_data
	if not equip or not equip.projectile:
		return

	var marker   := player.hit_box.get_node("Marker2D")
	var base_dir  = (player.get_global_mouse_position() - marker.global_position).normalized()
	for i in equip.num_projectiles:
		var bullet := equip.projectile.instantiate() as Projectile
		bullet.shot_target = "Ennemy"
		bullet.setup(
			marker.global_position,
			base_dir.rotated((randf() - 0.5) * deg_to_rad(equip.spread_degrees)),
			equip.Damage,
			equip.projectile_speed,
		)
		player.get_parent().add_child(bullet)


func on_weapon_hit(target: Node) -> void:
	if player.weapon_passive:
		player.weapon_passive.try_apply_on_hit_effect(target)
