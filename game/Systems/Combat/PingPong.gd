extends RefCounted
class_name PingPong
## Общие помощники «пинг-понга»: кого считать игроком, куда летит отбитый мяч, как
## отражается от стены. Используют Projectile (пули) и CorruptionOrb (заражение).


## Игрок, который нанёс удар: сам игрок, владелец оружия (PlayerHitBox) или стрелок
## дружественной пули. Иначе null (враг, взрыв, неизвестный источник).
static func resolve_player(source: Node) -> Node2D:
	if source == null:
		return null
	if source is Projectile:
		var shooter = source.owner_player
		return shooter as Node2D if shooter != null and is_instance_valid(shooter) \
				and shooter.is_in_group("Player") else null
	if source.is_in_group("Player"):
		return source as Node2D
	if source.owner != null and source.owner.is_in_group("Player"):
		return source.owner as Node2D
	return null


## Бьёт ли источник «за игрока»: ракетка (оружие), его пуля или он сам.
static func is_player_source(source: Node) -> bool:
	if source is Projectile:
		return source.shot_target == "Ennemy"
	return resolve_player(source) != null


## Куда полетит отбитый мяч: смесь «куда целился игрок» и «прочь от удара».
## precision: 0 — строго от удара, 1 — строго в точку прицела (курсор / правый стик).
static func aim_direction(source: Node2D, from_pos: Vector2, precision: float) -> Vector2:
	if source == null:
		return Vector2.from_angle(randf() * TAU)
	var away := (from_pos - source.global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)

	var aim := away
	var projectile_dir = source.get("direction")
	if projectile_dir is Vector2 and projectile_dir != Vector2.ZERO:
		aim = (projectile_dir as Vector2).normalized()           # выстрел
	else:
		var holder: Object = source
		if holder.get("mouse_pos") == null and source.owner != null:
			holder = source.owner                                # PlayerHitBox → Player
		var mouse = holder.get("mouse_pos")
		if mouse is Vector2:
			var to_cursor: Vector2 = (mouse as Vector2) - source.global_position
			if to_cursor.length() > 1.0:
				aim = to_cursor.normalized()

	var dir := away.lerp(aim, precision)
	return dir.normalized() if dir != Vector2.ZERO else aim


## Луч до ближайшей СТЕНЫ (тайлы и статичные объекты). Тела существ лежат на том же
## слое, поэтому их пропускаем — иначе пуля «отскакивала» бы от тела врага.
## Возвращает результат intersect_ray или пустой словарь.
static func cast_wall(world: World2D, from: Vector2, to: Vector2, mask: int) -> Dictionary:
	if mask == 0:
		return {}
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	for i in 4:
		query.exclude = exclude
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider = hit.get("collider")
		if collider is TileMapLayer or collider is StaticBody2D or collider is TileMap:
			return hit
		exclude.append(hit.rid)
	return {}
