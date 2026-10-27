extends Node
class_name PlayerDevCommands
## Регистрация и обработчики консольных dev-команд игрока.
## Новую команду — новый _cmd_* метод + строчка в register_all().

@onready var player: Player = get_parent()


func register_all() -> void:
	var c = Global.developer_console
	c.register_command("set_speed",     _cmd_set_speed,                      "Set player speed: set_speed [value]")
	c.register_command("tp",            _cmd_teleport,                       "Teleport: tp [x] [y]")
	c.register_command("multiply",      _cmd_set_standart_multipilier_speed, "Default movement multiplier: multiply [value]")
	c.register_command("slow_multiply", _cmd_set_slow_multipilier_speed,     "Slow multiplier: slow_multiply [value]")
	c.register_command("dash_multiply", _cmd_set_dash_multipilier_speed,     "Dash multiplier: dash_multiply [value]")
	c.register_command("scale",         _cmd_scale_change,                   "Player scale: scale [x] [y]")
	c.register_command("unkillable",    _cmd_unkillable,                     "Toggle damage immunity")
	c.register_command("effect",        _cmd_effect,                         "Apply effect: effect [poison|burn|freeze|bleed|corruption|speed|damage|defense|regen|heal|invis|invincible] [value] [duration]")
	c.register_command("clear_effects", _cmd_clear_effects,                  "Remove all active effects")
	c.register_command("effect_debug",  _cmd_effect_debug,                   "Print EffectManager diagnostics")


func _cmd_set_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		player.Entity_stats.move_speed = args[0].to_float()
		return "Speed set to " + str(player.Entity_stats.move_speed)
	return "Usage: set_speed [value]"


func _cmd_set_standart_multipilier_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		player.movement.standart_speed = args[0].to_float()
		return "Multiplier set to " + str(player.movement.standart_speed)
	return "Usage: multiply [value]"


func _cmd_set_slow_multipilier_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		player.movement.slow_speed = args[0].to_float()
		return "Slow multiplier set to " + str(player.movement.slow_speed)
	return "Usage: slow_multiply [value]"


func _cmd_set_dash_multipilier_speed(args: Array) -> String:
	if args.size() == 1 and args[0].is_valid_float():
		player.movement.dash_speed = args[0].to_float()
		return "Dash multiplier set to " + str(player.movement.dash_speed)
	return "Usage: dash_multiply [value]"


func _cmd_teleport(args: Array) -> String:
	if args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
		player.position = Vector2(args[0].to_float(), args[1].to_float())
		return "Teleported to " + str(player.position)
	return "Usage: tp [x] [y]"


func _cmd_scale_change(args: Array) -> String:
	if args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
		player.scale = Vector2(args[0].to_float(), args[1].to_float())
		return "Scale set to " + str(player.scale)
	return "Usage: scale [x] [y]"


func _cmd_unkillable(args: Array) -> String:
	player._hurt_col.disabled = not player._hurt_col.disabled
	return "Damage: " + ("OFF (unkillable)" if player._hurt_col.disabled else "ON")


## Быстрый тест системы эффектов из консоли, напр:
##   effect poison 4 6      -> яд 4 урона/сек на 6 сек
##   effect speed 0.3 10    -> +30% скорости на 10 сек
func _cmd_effect(args: Array) -> String:
	if args.size() < 1:
		return "Usage: effect [poison|burn|freeze|bleed|corruption|speed|damage|defense|regen|heal|invis|invincible] [value] [duration]"

	var name: String = String(args[0]).to_lower()
	var value: float = args[1].to_float() if args.size() > 1 and args[1].is_valid_float() else -1.0
	var duration: float = args[2].to_float() if args.size() > 2 and args[2].is_valid_float() else -1.0

	var e: Effect
	match name:
		"poison":
			e = Effect.create_poison(value if value >= 0 else 2.0, duration if duration >= 0 else 5.0)
		"burn":
			e = Effect.create_burn(value if value >= 0 else 3.0, duration if duration >= 0 else 3.0)
		"freeze":
			e = Effect.create_freeze(value if value >= 0 else 0.35, duration if duration >= 0 else 3.0)
		"bleed":
			e = Effect.create_bleed(value if value >= 0 else 0.03, duration if duration >= 0 else 5.0)
		"corruption":
			e = Effect.create_corruption(value if value >= 0 else 2.0, 0.15, duration if duration >= 0 else 6.0)
		"speed":
			e = Effect.new()
			e.effect_type = Effect.EffectType.SPEED_BOOST
			e.value = value if value >= 0 else 0.3
			e.duration = duration if duration >= 0 else 10.0
		"damage":
			e = Effect.create_damage_boost(value if value >= 0 else 0.2, duration if duration >= 0 else 60.0)
		"defense":
			e = Effect.new()
			e.effect_type = Effect.EffectType.DEFENSE_BOOST
			e.value = value if value >= 0 else 0.15
			e.duration = duration if duration >= 0 else 30.0
		"regen":
			e = Effect.create_regeneration(value if value >= 0 else 2.0, duration if duration >= 0 else 10.0)
		"heal":
			e = Effect.create_health_restore(value if value >= 0 else 15.0)
		"invis":
			e = Effect.new()
			e.effect_type = Effect.EffectType.INVISIBILITY
			e.duration = duration if duration >= 0 else 5.0
		"invincible":
			e = Effect.create_invincibility(duration if duration >= 0 else 2.5)
		_:
			return "Unknown effect: " + name

	player.apply_effect_instance(e)
	return "Applied effect: " + name


func _cmd_clear_effects(args: Array) -> String:
	player.effect_manager.clear_all_effects()
	return "All effects cleared"


## Диагностика: показывает, дошёл ли эффект до EffectManager и реально ли
## изменились Stats. Запусти "effect speed 0.3 10", потом сразу "effect_debug".
func _cmd_effect_debug(args: Array) -> String:
	var lines: Array = []

	lines.append("effect_manager present: " + str(player.effect_manager != null))
	if player.effect_manager == null:
		return "\n".join(lines)

	lines.append("effect_manager.character == player: " + str(player.effect_manager.character == player))
	lines.append("Entity.has_method(take_dot_damage): " + str(player.has_method("take_dot_damage")))
	lines.append("Stats.has_method(add_speed_modifier): " + str(player.Entity_stats.has_method("add_speed_modifier")))
	lines.append("base_move_speed=%.3f  move_speed(current)=%.3f" % [
		player.Entity_stats.base_move_speed, player.Entity_stats.move_speed
	])
	lines.append("current_health=%.1f / max_health=%d" % [
		player.Entity_stats.current_health, player.Entity_stats.max_health
	])

	var active := player.effect_manager.get_active_effects()
	lines.append("active effects count: %d" % active.size())
	for entry in active:
		var e: Effect = entry["effect"]
		lines.append(" - %s  value=%.2f  stacks=%d  time_left=%.1f  duration=%.1f" % [
			_effect_type_name(e.effect_type),
			e.value,
			entry["stacks"],
			entry["time_left"],
			entry["duration"],
		])

	return "\n".join(lines)


## Effect.EffectType задан с явными (не по порядку) числовыми значениями
## (POISON=8, BURN=10 и т.д.), поэтому EffectType.keys()[e.effect_type] — баг:
## keys() идёт в порядке ОБЪЯВЛЕНИЯ в enum, а не по значению. Ищем индекс
## через values(), который значению как раз соответствует.
func _effect_type_name(effect_type: int) -> String:
	var idx: int = Effect.EffectType.values().find(effect_type)
	if idx == -1:
		return "UNKNOWN(%d)" % effect_type
	return Effect.EffectType.keys()[idx]
