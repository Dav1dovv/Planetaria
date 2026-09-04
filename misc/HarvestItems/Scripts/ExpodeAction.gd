extends HarvestAction
class_name ExplodeAction

## Действие "Взрыв": спавнит VFX взрыва на месте объекта и опционально
## наносит урон всем телам в радиусе (включая игрока и другие
## Harvestable, если у них есть метод Harvest).

@export_group("VFX")
@export var explosion_scene : PackedScene  ## Сцена взрыва (партиклы/спрайт-анимация). Если не назначена — используется встроенный fallback-эффект.
@export_range(0.0, 1.0, 0.05) var screen_shake : float = 0.3  ## Сила тряски камеры, если в Global есть camera_shake()

@export_group("Damage")
@export var deal_damage : bool = true
@export_range(0.0, 999.0, 1.0) var damage : float = 25.0
@export_range(8.0, 400.0, 1.0) var radius : float = 80.0
@export var damage_player : bool = true  ## Бьёт ли взрыв по игроку, если он попал в радиус


func execute(harvestable: Node2D) -> void:
	var pos : Vector2 = harvestable.global_position
	var tree : SceneTree = harvestable.get_tree()
	if tree == null:
		return

	_spawn_vfx(pos, harvestable, tree)

	if deal_damage:
		_apply_damage(pos, harvestable, tree)

	_shake_camera()


func _spawn_vfx(pos: Vector2, harvestable: Node2D, tree: SceneTree) -> void:
	if explosion_scene:
		var fx := explosion_scene.instantiate()
		# Добавляем в текущую сцену, а не в harvestable — он будет удалён сразу после
		tree.current_scene.add_child(fx)
		if fx is Node2D:
			fx.global_position = pos
		return

	# Запасной эффект кодом, если сцена взрыва не назначена в инспекторе
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 28
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 170.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.55, 0.15)
	tree.current_scene.add_child(particles)
	particles.global_position = pos
	particles.emitting = true

	var timer := tree.create_timer(particles.lifetime + 0.2)
	timer.timeout.connect(particles.queue_free)


func _apply_damage(pos: Vector2, harvestable: Node2D, tree: SceneTree) -> void:
	var space_state := harvestable.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [harvestable.get_rid()]

	var results := space_state.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body == null or body == harvestable:
			continue
		if body.is_in_group("Player") and not damage_player:
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage)
		elif body.has_method("Harvest"):
			# Цепная реакция: взрыв задевает соседние Harvestable-объекты
			body.Harvest(damage, 0, false)


func _shake_camera() -> void:
	# Global — автозагружаемый синглтон проекта. Если в нём появится
	# метод camera_shake(strength), взрыв будет трясти камеру.
	if Global.has_method("camera_shake"):
		Global.camera_shake(screen_shake)
