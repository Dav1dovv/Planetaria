extends Node
class_name EffectManager
## Управляет активными эффектами (баффы/дебаффы/DoT) на одном существе.
## Работает одинаково для Player и любого Creature — оба наследуются от Entity,
## у которого есть Entity_stats, heal() и take_dot_damage().
##
## Добавляется как дочерний Node к Entity автоматически в Entity._ready(),
## руками в сцену добавлять не обязательно.
##
## Использование:
##   character.apply_effect_instance(Effect.create_poison())
##   character.effect_manager.has_effect(Effect.EffectType.POISON)

signal effect_added(effect: Effect)
signal effect_removed(effect: Effect)
signal effect_stacks_changed(effect_type: int, stacks: int)

var character: Entity

# Эффекты, наносящие периодический урон (DoT). REGENERATION тикает отдельно,
# т.к. лечит, а не наносит урон.
const DOT_TYPES := [
	Effect.EffectType.POISON,
	Effect.EffectType.BURN,
	Effect.EffectType.FREEZE,
	Effect.EffectType.BLEED,
	Effect.EffectType.CORRUPTION,
]

class ActiveEffect:
	var effect: Effect
	var time_left: float = 0.0   # <= 0 и duration <= 0 → бесконечный, снимается только вручную
	var tick_timer: float = 0.0
	var stacks: int = 1          # для UI, ограничено effect.max_stacks
	var source_count: int = 1    # сколько источников (аксессуары, оружие) держат эффект активным
	var permanent: bool = false  # true → длительность игнорируется, снимается только явным remove

var active_effects: Dictionary = {}  # Effect.EffectType -> ActiveEffect


func _ready() -> void:
	character = get_parent() as Entity


func _process(delta: float) -> void:
	if active_effects.is_empty():
		return

	var expired: Array = []
	for type in active_effects.keys():
		var ae: ActiveEffect = active_effects[type]

		if type in DOT_TYPES:
			ae.tick_timer -= delta
			if ae.tick_timer <= 0.0:
				ae.tick_timer += maxf(ae.effect.tick_interval, 0.1)
				_apply_dot_tick(ae)
		elif type == Effect.EffectType.REGENERATION:
			ae.tick_timer -= delta
			if ae.tick_timer <= 0.0:
				ae.tick_timer += maxf(ae.effect.tick_interval, 0.1)
				if character and character.has_method("heal"):
					character.heal(ae.effect.value * ae.stacks)

		if not ae.permanent and ae.effect.duration > 0.0:
			ae.time_left -= delta
			if ae.time_left <= 0.0:
				expired.append(type)

	for type in expired:
		remove_effect(type)


# ─────────────────────────────────────────────────────────────────────────────
#  Публичное API
# ─────────────────────────────────────────────────────────────────────────────

func has_effect(effect_type) -> bool:
	return active_effects.has(effect_type)


func get_stacks(effect_type) -> int:
	return active_effects[effect_type].stacks if has_effect(effect_type) else 0


## Список активных эффектов для UI (иконки баффов/дебаффов и т.п.).
## Каждый элемент — словарь: effect (ресурс Effect), time_left (сек. до конца,
## <= 0 у бесконечных эффектов), duration (исходная длительность), stacks.
func get_active_effects() -> Array:
	var result: Array = []
	for type in active_effects.keys():
		var ae: ActiveEffect = active_effects[type]
		result.append({
			"effect": ae.effect,
			"time_left": ae.time_left,
			"duration": ae.effect.duration,
			"stacks": ae.stacks,
		})
	return result


## Значение эффекта (Effect.value), если он активен, иначе default_value.
## Удобно для систем вне EffectManager — напр. player.add_infection() умножает
## накопление заражения на get_effect_value(INFECTION_RESIST, 1.0).
func get_effect_value(effect_type, default_value: float = 0.0) -> float:
	if has_effect(effect_type):
		return active_effects[effect_type].effect.value
	return default_value


## Сколько секунд осталось до снятия эффекта. 0 у бесконечных/постоянных
## эффектов и у тех, что уже не активны — используется EffectDisplayUI для
## текста таймера на иконке.
func get_effect_time_remaining(effect_type) -> float:
	if not has_effect(effect_type):
		return 0.0
	var ae: ActiveEffect = active_effects[effect_type]
	if ae.permanent or ae.effect.duration <= 0.0:
		return 0.0
	return ae.time_left


## Главная точка входа. Если эффект уже активен — освежает длительность
## и добавляет стак (пока не упрётся в max_stacks).
## permanent=true — эффект не снимается по таймеру, только явным remove_effect
## (используется для "пока предмет экипирован" — см. apply_passive_effect).
func apply_effect(effect: Effect, permanent: bool = false) -> void:
	if effect == null or character == null:
		return
	if not _can_apply(effect):
		return

	var type = effect.effect_type

	# Мгновенные эффекты (напр. лечение зельем) — применяются один раз, не хранятся
	if effect.duration == 0.0 and type == Effect.EffectType.HEALTH_RESTORE:
		if character.has_method("heal"):
			character.heal(effect.value)
		return

	if active_effects.has(type):
		var existing: ActiveEffect = active_effects[type]
		existing.source_count += 1
		if existing.stacks < effect.max_stacks:
			existing.stacks += 1
			effect_stacks_changed.emit(type, existing.stacks)
		if not existing.permanent:
			existing.time_left = effect.duration
		existing.effect = effect
		return

	var ae := ActiveEffect.new()
	ae.effect = effect
	ae.time_left = effect.duration
	ae.tick_timer = effect.tick_interval
	ae.permanent = permanent

	active_effects[type] = ae
	_apply_start(ae)
	effect_added.emit(effect)


## decrement_only=true — уменьшает счётчик источников и снимает эффект
## только когда источников не осталось (нужно для аксессуаров/оружия:
## два предмета дают один и тот же бафф — снятие одного не должно гасить
## бафф от второго). Используется через remove_passive_effect().
func remove_effect(effect_type, decrement_only: bool = false) -> void:
	if not active_effects.has(effect_type):
		return
	var ae: ActiveEffect = active_effects[effect_type]

	if decrement_only:
		ae.source_count -= 1
		if ae.stacks > 1:
			ae.stacks -= 1
			effect_stacks_changed.emit(effect_type, ae.stacks)
		if ae.source_count > 0:
			return

	_apply_end(ae)
	active_effects.erase(effect_type)
	effect_removed.emit(ae.effect)


## Эффект "пока экипировано" — аксессуары (AccessoryData) и пассивы оружия
## (WeaponPassiveHandler) используют именно это, а не apply_effect() напрямую.
func apply_passive_effect(effect: Effect) -> void:
	apply_effect(effect, true)


func remove_passive_effect(effect: Effect) -> void:
	if effect == null:
		return
	remove_effect(effect.effect_type, true)


func clear_all_effects() -> void:
	for type in active_effects.keys().duplicate():
		remove_effect(type)


# ─────────────────────────────────────────────────────────────────────────────
#  Иммунитеты (голем/скелет к яду, "Иммунитет к холоду" блокирует заморозку)
# ─────────────────────────────────────────────────────────────────────────────

func _can_apply(effect: Effect) -> bool:
	match effect.effect_type:
		Effect.EffectType.POISON:
			for group in Effect.POISON_IMMUNE_GROUPS:
				if character.is_in_group(group):
					return false
		Effect.EffectType.FREEZE:
			if has_effect(Effect.EffectType.COLD_IMMUNITY):
				return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
#  Урон со временем (DoT)
# ─────────────────────────────────────────────────────────────────────────────

func _apply_dot_tick(ae: ActiveEffect) -> void:
	if not is_instance_valid(character) or not character.has_method("take_dot_damage"):
		return
	var e := ae.effect
	var amount := 0.0
	match e.effect_type:
		Effect.EffectType.BLEED:
			var max_hp := 100.0
			if character.Entity_stats:
				max_hp = character.Entity_stats.max_health
			amount = max_hp * e.bleed_percent
		_:
			amount = e.value
	character.take_dot_damage(amount * ae.stacks)


# ─────────────────────────────────────────────────────────────────────────────
#  Баффы / дебаффы — применение при старте и снятие по истечении
# ─────────────────────────────────────────────────────────────────────────────

func _apply_start(ae: ActiveEffect) -> void:
	var e := ae.effect
	var st := character.Entity_stats
	match e.effect_type:
		Effect.EffectType.SPEED_BOOST:
			st.add_speed_modifier(e.value)
		Effect.EffectType.SLOW, Effect.EffectType.FREEZE:
			st.add_speed_modifier(-e.value)
		Effect.EffectType.DAMAGE_BOOST:
			st.add_damage_modifier(e.value)
		Effect.EffectType.CORRUPTION:
			st.add_damage_modifier(e.corruption_damage_bonus)
		Effect.EffectType.DEFENSE_BOOST:
			st.add_defense_modifier(e.value)
		Effect.EffectType.INVISIBILITY:
			if character.has_method("set_invisibility"):
				character.set_invisibility(true)
		Effect.EffectType.INVINCIBILITY:
			character.is_invincible = true


func _apply_end(ae: ActiveEffect) -> void:
	var e := ae.effect
	var st := character.Entity_stats
	match e.effect_type:
		Effect.EffectType.SPEED_BOOST:
			st.remove_speed_modifier(e.value)
		Effect.EffectType.SLOW, Effect.EffectType.FREEZE:
			st.remove_speed_modifier(-e.value)
		Effect.EffectType.DAMAGE_BOOST:
			st.remove_damage_modifier(e.value)
		Effect.EffectType.CORRUPTION:
			st.remove_damage_modifier(e.corruption_damage_bonus)
		Effect.EffectType.DEFENSE_BOOST:
			st.remove_defense_modifier(e.value)
		Effect.EffectType.INVISIBILITY:
			if character.has_method("set_invisibility"):
				character.set_invisibility(false)
		Effect.EffectType.INVINCIBILITY:
			character.is_invincible = false
