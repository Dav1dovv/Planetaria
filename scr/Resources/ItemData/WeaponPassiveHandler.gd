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
				var is_crit := false
				var final_damage := lunge_damage
				var poise_dmg := 0.0
				if _current_equip:
					is_crit = randf() < _current_equip.critical_chance
					if is_crit:
						final_damage *= _current_equip.critical_multiplier
					poise_dmg = _current_equip.poise_damage * 0.6  # рывок стаггерит слабее прямого удара

				body.take_damage(final_damage, _player, is_crit, poise_dmg)
				already_hit.append(body)


## Вызывается из player_combat.gd → on_weapon_hit() при обычном ударе (не рывке).
## Ожидает на equip_data необязательные поля:
##   on_hit_effect: Effect  — какой эффект накладывать на цель
##   on_hit_effect_chance: float — шанс срабатывания 0..1 (по умолчанию 1.0, если поля нет)
## ВНИМАНИЕ: у меня нет исходника equip_data.gd, поэтому имена полей — предположение.
## Если у тебя они называются иначе, поправь два .get() ниже (или пришли equip_data.gd).
func try_apply_on_hit_effect(target: Node) -> void:
	if not _current_equip or not is_instance_valid(target):
		return

	var on_hit_effect = _current_equip.get("on_hit_effect")
	if on_hit_effect == null or not (on_hit_effect is Effect):
		return

	var chance = _current_equip.get("on_hit_effect_chance")
	if chance == null:
		chance = 1.0

	if randf() <= float(chance) and target.has_method("apply_effect_instance"):
		target.apply_effect_instance(on_hit_effect)


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
