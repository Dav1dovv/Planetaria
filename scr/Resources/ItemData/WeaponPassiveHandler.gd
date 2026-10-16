# WeaponPassiveHandler.gd
# ─────────────────────────────────────────────────────────────────────────────
# Компонент-нода. Добавь её как дочернюю к Player.
# Имя ноды в сцене: WeaponPassiveHandler
#
# Отвечает за:
#   1. Пассивный свет оружия (PointLight2D добавляется/убирается динамически)
#   2. Пассивные эффекты на игрока (regen, speed_boost, и т.д.)
#   3. Накладывание on-hit эффектов на врагов (вызывается из player.gd)
#   4. Нанесение урона рывка врагам, оказавшимся на пути (вызывается из player.gd)
# ─────────────────────────────────────────────────────────────────────────────
extends Node
class_name WeaponPassiveHandler

# Ссылки — заполнятся в _ready через get_parent()
var _player:  Player       = null
var _hit_box              = null   # player_HitBox

# Текущее активное оружие (equip_data или null)
var _current_equip: equip_data = null

# Динамически создаваемый свет
var _light: PointLight2D = null

# Флаг активного пассивного эффекта (чтобы не добавлять дважды)
var _passive_effect_active: bool = false

# Ресурс эффекта, который сейчас держит текущее оружие (нужен, чтобы снять
# именно его при смене оружия — EffectManager снимает по effect_type).
var _current_passive_effect: Effect = null


func _ready() -> void:
	_player  = get_parent() as Player
	assert(_player != null, "WeaponPassiveHandler must be a child of Player")
	_hit_box = _player.hit_box


func _process(delta: float) -> void:
	var equip := _get_current_equip()

	# Если оружие сменилось — обновляем пассивы
	if equip != _current_equip:
		_on_equip_changed(_current_equip, equip)
		_current_equip = equip


# ─── Публичный API ────────────────────────────────────────────────────────────

## Вызывается из player.gd на каждом шаге рывка.
## Возвращает список нод, которым нанесён урон (чтобы не бить дважды).
func apply_lunge_damage(already_hit: Array, lunge_damage: float) -> void:
	if not _hit_box:
		return
	# Проверяем перекрытия HitBox с врагами
	for area in _hit_box.get_overlapping_areas():
		var body: Node = area.get_parent()
		if body in already_hit:
			continue
		if area.is_in_group("Ennemy") or area.is_in_group("Harvestable"):
			if body.has_method("take_damage"):
				body.take_damage(lunge_damage, _player, _current_equip.knockback if _current_equip else 0.0)
				already_hit.append(body)


## Вызывается при попадании: из PlayerHitBox (ближний бой) и player_combat.on_weapon_hit (снаряды).
## Эффект строится из полей equip_data: on_hit_effect / _chance / _duration / _potency / ...
## Для freeze и slow potency — ПРОЦЕНТЫ замедления (35 = -35% скорости).
func try_apply_on_hit_effect(target: Node) -> void:
	if not _current_equip or not is_instance_valid(target):
		return
	var kind := _current_equip.on_hit_effect
	if kind == "none" or randf() > _current_equip.on_hit_chance:
		return

	if kind == "heal_on_hit":
		if _player.has_method("heal"):
			_player.heal(_current_equip.on_hit_potency)
		return

	if not target.has_method("apply_effect_instance"):
		return
	var effect := _build_on_hit_effect(_current_equip)
	if effect:
		target.apply_effect_instance(effect)


func _build_on_hit_effect(e: equip_data) -> Effect:
	var dur := e.on_hit_duration
	match e.on_hit_effect:
		"burn":       return Effect.create_burn(e.on_hit_potency, dur)
		"poison":     return Effect.create_poison(e.on_hit_potency, dur)
		"freeze":     return Effect.create_freeze(e.on_hit_potency / 100.0, dur)
		"bleed":      return Effect.create_bleed(e.on_hit_bleed_percent, dur)
		"corruption": return Effect.create_corruption(e.on_hit_potency, e.on_hit_corruption_bonus, dur)
		"slow":
			var slow := Effect.new()
			slow.effect_type = Effect.EffectType.SLOW
			slow.value = e.on_hit_potency / 100.0
			slow.duration = dur
			slow.display_name = "Замедление"
			slow.particle_color = Color(0.7, 0.8, 0.9)
			return slow
	return null


# ─── Внутренняя логика ────────────────────────────────────────────────────────

func _get_current_equip() -> equip_data:
	if not _hit_box:
		return null
	return _hit_box.equip as equip_data


func _on_equip_changed(old_equip: equip_data, new_equip: equip_data) -> void:
	# Убираем старые пассивы
	if old_equip:
		_remove_light()
		_remove_passive_player_effect(old_equip)

	# Применяем новые пассивы
	if new_equip:
		if new_equip.passive_emits_light:
			_create_light(new_equip)
		if new_equip.passive_player_effect != "none":
			_apply_passive_player_effect(new_equip)
			_passive_effect_active = true
		else:
			_passive_effect_active = false
	else:
		_passive_effect_active = false


func _create_light(e: equip_data) -> void:
	_remove_light()
	_light = PointLight2D.new()
	_light.texture = preload("uid://dsqxjnpk365qg")
	_light.color        = e.passive_light_color
	_light.texture_scale = e.passive_light_radius / 64.0  # нормализация под стандартный градиент
	_light.energy       = e.passive_light_energy
	_light.shadow_enabled = true
	# Лёгкое мерцание через AnimationPlayer можно добавить позже
	# Вешаем свет на руку игрока, чтобы он двигался вместе с ней
	_player.add_child(_light)
	_light.position = Vector2.ZERO


func _remove_light() -> void:
	if is_instance_valid(_light):
		_light.queue_free()
	_light = null


func _apply_passive_player_effect(e: equip_data) -> void:
	var effect := _build_passive_effect(e)
	if effect == null:
		return
	_current_passive_effect = effect
	_player.apply_passive_effect(effect)


func _remove_passive_player_effect(e: equip_data) -> void:
	_passive_effect_active = false
	if _current_passive_effect == null:
		return
	_player.remove_passive_effect(_current_passive_effect)
	_current_passive_effect = null


## Строит Effect-ресурс из строкового passive_player_effect оружия.
## Длительность не важна — apply_passive_effect() держит эффект, пока
## явно не вызовут remove_passive_effect() (т.е. пока оружие экипировано).
func _build_passive_effect(e: equip_data) -> Effect:
	match e.passive_player_effect:
		"regen":
			return Effect.create_regeneration(e.passive_player_potency, -1.0)
		"speed_boost":
			var eff := Effect.new()
			eff.effect_type = Effect.EffectType.SPEED_BOOST
			eff.value = e.passive_player_potency
			eff.duration = -1.0
			return eff
		"poison":
			# Оружие-проклятие: тикает урон по владельцу, пока оружие в руках
			return Effect.create_poison(e.passive_player_potency, -1.0)
		"burn":
			return Effect.create_burn(e.passive_player_potency, -1.0)
		_:
			return null
