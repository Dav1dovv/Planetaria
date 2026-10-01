@icon("res://addons/at-icons/mesh/arrow_projectile.svg")
extends RapierCharacterBody2D
class_name Projectile

# Сигнал попадания по цели — PlayerCombat использует его для эффектов оружия (on-hit)
signal hit_target(target: Node)

@export var speed: float = 400.0
@export var lifetime: float = 5.0
@export var damage: float = 25.0

@export_enum("normal", "boomerang", "bomb") var projectile_type: String = "normal"
@export_enum("Player","Ennemy") var shot_target : String = "Player"

@export var explosion_radius: float = 80.0
@export var explode_on_hit: bool = true
@export var bomb_timer: float = 2.5
@export var homing_strength: float = 3.0      # Для бумеранга — сила притяжения при возврате
@export var max_travel_distance: float = 600.0  # Для бумеранга — когда начинать возвращаться

@export_group("Collision layers")
## Слой HurtBox врагов — его видят пули игрока (shot_target = "Ennemy")
@export_range(1, 32) var enemy_hurtbox_layer : int = 5
## Слой HurtBox игрока — его видят пули врагов (shot_target = "Player").
## ВАЖНО: поставь номер слоя, на котором лежит HurtBox игрока
@export_range(1, 32) var player_hurtbox_layer : int = 6

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var bomb_timer_node: Timer = $BombTimer
@onready var area: Area2D = $Area2D
@onready var sprite: Sprite2D = $Sprite2D          # ← Обязательно назови спрайт так в сцене!
@onready var hit_particles: GPUParticles2D = $HitParticles  # Опционально
@onready var explosion_particles: GPUParticles2D = $ExplosionParticles  # Опционально

var direction: Vector2 = Vector2.RIGHT
var owner_player: Node2D = null   # Player или враг, выстреливший снаряд
var start_position: Vector2
var has_returned: bool = false
var is_exploded: bool = false

func _ready() -> void:
	# Настройка слоёв (пуля игрока)
	area.set_collision_layer_value(1, false)
	area.set_collision_layer_value(4, true)   # HitBox layer
	area.set_collision_mask_value(1, false)
	# Видим HurtBox своей цели: игрока (для пуль врагов) или врагов (для пуль игрока)
	var target_layer : int = player_hurtbox_layer if shot_target == "Player" else enemy_hurtbox_layer
	area.set_collision_mask_value(target_layer, true)    # HurtBox layer

	area.area_entered.connect(_on_area_entered)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.start()

	# Таймер для бомбы
	if projectile_type == "bomb":
		bomb_timer_node.wait_time = bomb_timer
		bomb_timer_node.one_shot = true
		bomb_timer_node.timeout.connect(_explode)
		bomb_timer_node.start()

func setup(
		start_pos: Vector2,
		dir: Vector2,
		dmg: float,
	) -> void:
	
	global_position = start_pos
	start_position = start_pos
	direction = dir
	damage = dmg

	
	# Сразу поворачиваем спрайт
	if sprite:
		sprite.rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if is_exploded:
		return

	# === Бумеранг: прямо вперёд → разворот → возврат к игроку ===
	if projectile_type == "boomerang":
		if not has_returned and global_position.distance_to(start_position) >= max_travel_distance:
			has_returned = true

		if has_returned and owner_player:
			# Летим прямо к текущей позиции игрока
			direction = (owner_player.global_position - global_position).normalized()

	# Вычисляем скорость уже после изменения direction
	var vel = direction * speed

	# === Обновляем ротацию спрайта ===
	if sprite:
		if projectile_type == "boomerang":
			sprite.rotation += 5.0 * delta  # Крутится вокруг своей оси
		else:
			sprite.rotation = direction.angle()

	# Движение
	velocity = vel
	move_and_slide()

func _on_area_entered(area: Area2D) -> void:
	# Не бьём своего владельца
	if area.get_parent() == owner_player:
		if projectile_type == "boomerang" and has_returned:
			# Поймали бумеранг — уничтожаем
			queue_free()
		return

	# Бумеранг на обратном пути не наносит урон повторно
	if projectile_type == "boomerang" and has_returned:
		return

	if area.is_in_group("Ennemy") or area.is_in_group("Harvestable"):
		if projectile_type == "bomb" and explode_on_hit:
			_explode()
			return

	if area.is_in_group(shot_target):
		var victim := area.get_parent()
		victim.take_damage(damage, self)
		# Сообщаем о попадании (если цель не успела удалиться от урона)
		if is_instance_valid(victim):
			hit_target.emit(victim)
		print("weapon damaged: " + str(damage))
		_play_hit_effect()
		if projectile_type == "boomerang":
			has_returned = true
			return
		queue_free()
	elif area.is_in_group("Harvestable"):
		_play_hit_effect()
		if projectile_type == "boomerang":
			has_returned = true
			return
		queue_free()
	elif projectile_type == "boomerang":
		# Бумеранг задел любой другой объект — возвращаемся
		_play_hit_effect()
		has_returned = true

func _explode() -> void:
	if is_exploded:
		return
	is_exploded = true

	# Отключаем коллизию и движение
	set_physics_process(false)
	area.monitoring = false
	if sprite:
		sprite.visible = false

	# Частицы взрыва
	if explosion_particles:
		explosion_particles.emitting = true

	# AOE урон
	var bodies = get_tree().get_nodes_in_group("Creature")
	bodies.append_array(get_tree().get_nodes_in_group("Harvestable"))
	
	for body in bodies:
		if body == owner_player:
			continue
		if global_position.distance_to(body.global_position) <= explosion_radius:
			if body.has_method("take_damage"):
				body.take_damage(damage * 0.8, owner_player)  # 80% урона в AOE
			elif body.has_method("Harvest"):
				body.Harvest(damage * 0.8, 1, false)

	print("BOOM! ", projectile_type, " exploded! Radius: ", explosion_radius)

	# Удаляем через время (чтобы частицы доиграли)
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _play_hit_effect() -> void:
	if hit_particles:
		hit_particles.emitting = true
		hit_particles.reparent(get_parent())  # Чтобы частицы остались в мире
	print("Projectile hit! Damage: ", damage)

# Таймер жизни
func _on_lifetime_timer_timeout() -> void:
	if projectile_type == "bomb" and not is_exploded:
		_explode()
	else:
		queue_free()
