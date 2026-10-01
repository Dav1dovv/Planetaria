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

@onready var player = get_parent()

@export var shot_marker : Marker2D

# ─────────────────────────────────────────────────────────────────────────────
#  Ввод / атака
# ─────────────────────────────────────────────────────────────────────────────

func handle_input(event: InputEvent) -> void:
	if not event.is_action_pressed("LMB") or player.is_attack or Global.is_opened_menu:
		return

	var hit_box   = player.hit_box
	var hand_anim = player.HandAanimator

	if hit_box.is_weapon and hit_box.equip is equip_data:
		var equip := hit_box.equip as equip_data

		# Стрелковое оружие — отдельная ветка (см. раздел «Стрельба» ниже)
		if equip.play_anim == "Shoot":
			_begin_shot(equip)
			return

		hit_box.look_at(player.mouse_pos)
		player.is_attack      = true
		hand_anim.speed_scale = equip.Atk_speed
		hand_anim.play(equip.play_anim)

		if equip.lunge_enabled and not is_lunging:
			start_lunge(equip)

		if equip.play_anim == "Attack":
			call_deferred("_start_attack_cooldown", equip.one_shot_attack)

	elif hit_box.equip is FoodData:
		player.is_attack = true
		hand_anim.play(hit_box.equip.play_anim)
		call_deferred("_start_eat_cooldown")

	else:
		player.is_attack = true
		hand_anim.play(hit_box.equip.play_anim)
		call_deferred("_start_attack_cooldown", true)


func _start_attack_cooldown(one_shot: bool) -> void:
	var hand_anim = player.HandAanimator
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
## Поток выстрела:
##   1. ЛКМ → handle_input() → _begin_shot(): поворот руки к курсору, запуск анимации "Shoot"
##   2. В нужном кадре анимации (Call Method Track) вызывается shoot() — вылетают снаряды
##   3. Анимация закончилась → _start_shot_cooldown(): если оружие не one_shot и ЛКМ зажата,
##      следующий выстрел начинается автоматически (автоогонь)
## Скорострельность задаётся Atk_speed (скорость анимации).

func _begin_shot(equip: equip_data) -> void:
	player.is_attack = true
	player.hit_box.look_at(player.mouse_pos)
	player._hand.look_at(player.mouse_pos)

	player.HandAanimator.speed_scale = equip.Atk_speed
	player.HandAanimator.play(equip.play_anim)
	call_deferred("_start_shot_cooldown", equip.one_shot_attack)


func _start_shot_cooldown(one_shot: bool) -> void:
	await player.HandAanimator.animation_finished
	player.is_attack = false
	player._hand.look_at(player.mouse_pos)
	player.hit_box.look_at(player.mouse_pos)

	# Зажата ЛКМ и оружие автоматическое — сразу начинаем следующий выстрел
	if not one_shot and Input.is_action_pressed("LMB") \
			and player.hit_box.is_weapon and player.hit_box.equip is equip_data:
		_begin_shot(player.hit_box.equip as equip_data)
	else:
		player._hand.rotation = 0


func shoot() -> void:
	## Вызывается из анимации "Shoot" (Call Method Track) в момент вылета снаряда.
	var equip := player.hit_box.equip as equip_data
	if not equip or not equip.projectile:
		return

	var marker = shot_marker

	# Направление от дула к курсору. Если курсор почти в самом дуле — стреляем по направлению маркера
	var to_mouse : Vector2 = player.get_global_mouse_position() - marker.global_position
	var base_dir : Vector2 = to_mouse.normalized() if to_mouse.length() > 1.0 \
			else Vector2.RIGHT.rotated(marker.global_rotation)

	for i in equip.num_projectiles:
		var bullet := equip.projectile.instantiate() as Projectile
		if bullet == null:
			push_warning("PlayerCombat: корневой узел сцены снаряда должен быть Projectile")
			return

		bullet.owner_player = player
		bullet.shot_target  = "Ennemy"

		# Сначала в дерево, потом setup: иначе @onready-узлы (sprite и т.д.) ещё не готовы
		player.get_parent().add_child(bullet)
		bullet.setup(
			marker.global_position,
			base_dir.rotated((randf() - 0.5) * deg_to_rad(equip.spread_degrees)),
			equip.Damage
		)

		# Эффекты «при попадании» (яд, огонь и т.д.) — так же, как у ближнего боя
		if bullet.has_signal("hit_target"):
			bullet.hit_target.connect(on_weapon_hit)


func on_weapon_hit(target: Node) -> void:
	if player.weapon_passive:
		player.weapon_passive.try_apply_on_hit_effect(target)
