extends Resource
class_name Effect

# ─────────────────────────────────────────────────────────────────────────────
# EffectResource.gd  |  Caves & Swords  |  Content v1.3
#
# Изменения относительно предыдущей версии:
#   + BLEED            (Кровотечение) — DOT по % от max HP
#   + CORRUPTION       (Заражение)    — DOT + баф врага, тематика Бездны
#   + MINING_SPEED_BOOST              — ускорение добычи
#   + INFECTION_RESIST                — снижение накопления заражения x0.7
#   + COLD_IMMUNITY                   — иммунитет к DOT заморозки (Огненный грог)
#   + INVINCIBILITY                   — неуязвимость 2–3 сек (редкая находка)
#   + DOUBLE_LOOT                     — шанс двойного лута (Талисман удачи)
#   + PANIC                           — потеря управления движением (от BURN)
#   FREEZE теперь реально работает: слабый DOT + замедление −30–40%
#   BLIND и STUN убраны — не используются по дизайну (GDD v1.3)
# ─────────────────────────────────────────────────────────────────────────────

enum EffectType {
	# ── На себя (зелья, аксессуары) ───────────────────────────────
	HEALTH_RESTORE       = 0,
	REGENERATION         = 3,
	SPEED_BOOST          = 1,
	DAMAGE_BOOST         = 2,
	DEFENSE_BOOST        = 4,
	MINING_SPEED_BOOST   = 5,
	INVISIBILITY         = 6,
	COLD_IMMUNITY        = 12,
	INFECTION_RESIST     = 13,
	INVINCIBILITY        = 14,
	DOUBLE_LOOT          = 15,

	# ── На врага (от оружия) ──────────────────────────────────────
	POISON               = 8,   # Отравление DOT; иммун: голем/скелет
	BURN                 = 10,  # Обжиг DOT + PANIC
	FREEZE               = 11,  # Замедление -30-40% + слабый DOT
	BLEED                = 16,  # Кровотечение: % от max HP в тик
	CORRUPTION           = 17,  # Заражение: DOT + враг усиливается
	SLOW                 = 9,   # Замедление без DOT

	# ── Вспомогательный ──────────────────────────────────────────
	PANIC                = 18,  # Потеря контроля движения (от BURN)
}

# Существа иммунные к яду — проверяется в EffectManager
const POISON_IMMUNE_GROUPS := ["golem", "skeleton"]

@export_category("Effect Properties")
@export var effect_icon   : Texture
@export var effect_type   : EffectType = EffectType.HEALTH_RESTORE
@export var value         : float = 0.0
@export var duration      : float = 0.0   # 0 = мгновенный, -1 = бесконечный (пока в слоте)
@export var tick_interval : float = 1.0
@export var max_stacks    : int   = 1

# BLEED: урон = bleed_percent * target.max_health за тик
@export var bleed_percent : float = 0.03

# CORRUPTION: насколько усиливает врага пока действует
@export var corruption_damage_bonus : float = 0.15

@export_category("Visual Effects")
@export var particle_color : Color = Color.WHITE
@export var particle       : PackedScene
@export var icon           : Texture2D
@export var sound_effect   : AudioStream

@export_category("UI Display")
@export var display_name : String = "Effect"
@export_multiline var description : String = ""


# ─── Применение / снятие ──────────────────────────────────────────────────────

func apply_effect(target: Node) -> void:
	if target.has_method("apply_effect_instance"):
		target.apply_effect_instance(self)
	else:
		_apply_direct_effect(target)

func _apply_direct_effect(target: Node) -> void:
	match effect_type:
		EffectType.HEALTH_RESTORE:
			if target.has_method("heal"):
				target.heal(value)
		EffectType.SPEED_BOOST:
			if target.has_method("add_speed_modifier"):
				target.add_speed_modifier(value, duration)
		EffectType.DAMAGE_BOOST:
			if target.has_method("add_damage_modifier"):
				target.add_damage_modifier(value, duration)
		EffectType.REGENERATION:
			if target.has_method("start_regeneration"):
				target.start_regeneration(value, duration, tick_interval)
		EffectType.DEFENSE_BOOST:
			if target.has_method("add_defense_modifier"):
				target.add_defense_modifier(value, duration)
		EffectType.INVISIBILITY:
			if target.has_method("set_invisibility"):
				target.set_invisibility(true, duration)
		EffectType.POISON:
			if target.has_method("apply_poison"):
				target.apply_poison(value, duration, tick_interval)
		EffectType.SLOW, EffectType.FREEZE:
			if target.has_method("add_speed_modifier"):
				target.add_speed_modifier(-value, duration)

func remove_effect(target: Node) -> void:
	if target.has_method("remove_effect_instance"):
		target.remove_effect_instance(self)
	else:
		_remove_direct_effect(target)

func _remove_direct_effect(target: Node) -> void:
	match effect_type:
		EffectType.SPEED_BOOST, EffectType.SLOW, EffectType.FREEZE:
			if target.has_method("remove_speed_modifier"):
				target.remove_speed_modifier(value)
		EffectType.DAMAGE_BOOST:
			if target.has_method("remove_damage_modifier"):
				target.remove_damage_modifier(value)
		EffectType.DEFENSE_BOOST:
			if target.has_method("remove_defense_modifier"):
				target.remove_defense_modifier(value)
		EffectType.INVISIBILITY:
			if target.has_method("set_invisibility"):
				target.set_invisibility(false)


# ─── Tooltip ──────────────────────────────────────────────────────────────────

func get_tooltip_text() -> String:
	var text := display_name + "\n" + description + "\n\n"
	match effect_type:
		EffectType.HEALTH_RESTORE:
			text += "Восстанавливает %d HP" % int(value)
		EffectType.REGENERATION:
			text += "Восстанавливает %.1f HP каждые %.1f сек" % [value, tick_interval]
		EffectType.SPEED_BOOST:
			text += "Скорость движения +%d%%" % int(value * 100)
		EffectType.DAMAGE_BOOST:
			text += "Урон +%d%%" % int(value * 100)
		EffectType.DEFENSE_BOOST:
			text += "Защита +%d" % int(value)
		EffectType.MINING_SPEED_BOOST:
			text += "Скорость добычи +%d%%" % int(value * 100)
		EffectType.INVISIBILITY:
			text += "Духи и одержимые тебя не замечают"
		EffectType.COLD_IMMUNITY:
			text += "Иммунитет к DOT заморозки"
		EffectType.INFECTION_RESIST:
			text += "Накопление заражения ×%.1f" % value
		EffectType.INVINCIBILITY:
			text += "Неуязвимость"
		EffectType.DOUBLE_LOOT:
			text += "Шанс двойного лута +%d%%" % int(value * 100)
		EffectType.POISON:
			text += "Яд: %.1f урона каждые %.1f сек" % [value, tick_interval]
		EffectType.BURN:
			text += "Обжиг: %.1f урона каждые %.1f сек + паника движения" % [value, tick_interval]
		EffectType.FREEZE:
			text += "Заморозка: замедление -%d%%, слабый DOT" % int(value * 100)
		EffectType.BLEED:
			text += "Кровотечение: %.0f%% max HP каждые %.1f сек" % [bleed_percent * 100, tick_interval]
		EffectType.CORRUPTION:
			text += "Заражение: DOT + враг усиливается на %.0f%%" % (corruption_damage_bonus * 100)
		EffectType.SLOW:
			text += "Замедление -%d%%" % int(value * 100)
		EffectType.PANIC:
			text += "Потеря контроля движения"
	if duration > 0:
		text += "\nДлительность: %.1f сек" % duration
	elif duration == 0 and effect_type != EffectType.HEALTH_RESTORE:
		text += "\nМгновенный"
	if max_stacks > 1:
		text += "\nМакс. стаков: %d" % max_stacks
	return text


# ─── Фабричные методы ─────────────────────────────────────────────────────────

static func create_poison(dmg_per_tick: float = 2.0, dur: float = 5.0) -> Effect:
	var e := Effect.new()
	e.effect_type   = EffectType.POISON
	e.value         = dmg_per_tick
	e.duration      = dur
	e.tick_interval = 1.0
	e.display_name  = "Отравление"
	e.description   = "Тикающий урон. Не действует на големов и скелетов."
	e.particle_color = Color(0.4, 0.9, 0.1)
	return e

static func create_burn(dmg_per_tick: float = 3.0, dur: float = 3.0) -> Effect:
	var e := Effect.new()
	e.effect_type   = EffectType.BURN
	e.value         = dmg_per_tick
	e.duration      = dur
	e.tick_interval = 1.0
	e.display_name  = "Обжиг"
	e.description   = "Тикающий урон + временная потеря управления движением."
	e.particle_color = Color(1.0, 0.4, 0.0)
	return e

static func create_freeze(slow_pct: float = 0.35, dur: float = 3.0) -> Effect:
	var e := Effect.new()
	e.effect_type   = EffectType.FREEZE
	e.value         = slow_pct
	e.duration      = dur
	e.tick_interval = 1.0
	e.display_name  = "Заморозка"
	e.description   = "Замедление и слабый тикающий урон."
	e.particle_color = Color(0.5, 0.8, 1.0)
	return e

static func create_bleed(pct_per_tick: float = 0.03, dur: float = 5.0) -> Effect:
	var e := Effect.new()
	e.effect_type   = EffectType.BLEED
	e.bleed_percent = pct_per_tick
	e.value         = 0.0
	e.duration      = dur
	e.tick_interval = 1.0
	e.display_name  = "Кровотечение"
	e.description   = "Урон по % от max HP. Эффективен против врагов с высоким HP."
	e.particle_color = Color(0.8, 0.0, 0.0)
	return e

static func create_corruption(dot: float = 2.0, dmg_bonus: float = 0.15, dur: float = 6.0) -> Effect:
	var e := Effect.new()
	e.effect_type             = EffectType.CORRUPTION
	e.value                   = dot
	e.corruption_damage_bonus = dmg_bonus
	e.duration                = dur
	e.tick_interval           = 1.0
	e.display_name            = "Заражение"
	e.description             = "DOT + враг наносит больше урона. Тематика Бездны."
	e.particle_color          = Color(0.5, 0.0, 0.8)
	return e

static func create_health_restore(hp: float = 15.0) -> Effect:
	var e := Effect.new()
	e.effect_type  = EffectType.HEALTH_RESTORE
	e.value        = hp
	e.display_name = "Лечение"
	e.particle_color = Color.RED
	return e

static func create_regeneration(hp_per_tick: float = 1.0, dur: float = -1.0) -> Effect:
	var e := Effect.new()
	e.effect_type   = EffectType.REGENERATION
	e.value         = hp_per_tick
	e.duration      = dur
	e.tick_interval = 2.0
	e.display_name  = "Регенерация"
	e.particle_color = Color.GREEN
	return e

static func create_infection_resist(multiplier: float = 0.7, dur: float = 90.0) -> Effect:
	var e := Effect.new()
	e.effect_type  = EffectType.INFECTION_RESIST
	e.value        = multiplier
	e.duration     = dur
	e.display_name = "Сопротивление заражению"
	e.particle_color = Color(0.3, 0.5, 0.9)
	return e

static func create_cold_immunity(dur: float = 180.0) -> Effect:
	var e := Effect.new()
	e.effect_type  = EffectType.COLD_IMMUNITY
	e.duration     = dur
	e.display_name = "Иммунитет к холоду"
	e.description  = "Огненный грог. Контрпик Севера."
	e.particle_color = Color(1.0, 0.6, 0.1)
	return e

static func create_mining_speed_boost(pct: float = 0.15, dur: float = 300.0) -> Effect:
	var e := Effect.new()
	e.effect_type  = EffectType.MINING_SPEED_BOOST
	e.value        = pct
	e.duration     = dur
	e.display_name = "Скорость добычи"
	e.particle_color = Color(0.9, 0.7, 0.2)
	return e

static func create_invincibility(dur: float = 2.5) -> Effect:
	var e := Effect.new()
	e.effect_type  = EffectType.INVINCIBILITY
	e.duration     = dur
	e.display_name = "Неуязвимость"
	e.description  = "Редкая находка. Не крафтится."
	e.particle_color = Color.WHITE
	return e

static func create_damage_boost(pct: float = 0.20, dur: float = 60.0) -> Effect:
	var e := Effect.new()
	e.effect_type  = EffectType.DAMAGE_BOOST
	e.value        = pct
	e.duration     = dur
	e.display_name = "Атака +"
	e.particle_color = Color(1.0, 0.8, 0.0)
	return e
