extends Node
class_name PlayerDevCommands
## Регистрация и обработчики консольных dev-команд игрока.
## Новую команду — новый _cmd_* метод + строчка в register_all().

@onready var player: Player = get_parent()


func register_all() -> void:
	var c := Global.developer_console
	c.register_command("set_speed",     _cmd_set_speed,                      "Set player speed: set_speed [value]")
	c.register_command("tp",            _cmd_teleport,                       "Teleport: tp [x] [y]")
	c.register_command("multiply",      _cmd_set_standart_multipilier_speed, "Default movement multiplier: multiply [value]")
	c.register_command("slow_multiply", _cmd_set_slow_multipilier_speed,     "Slow multiplier: slow_multiply [value]")
	c.register_command("dash_multiply", _cmd_set_dash_multipilier_speed,     "Dash multiplier: dash_multiply [value]")
	c.register_command("scale",         _cmd_scale_change,                   "Player scale: scale [x] [y]")
	c.register_command("unkillable",    _cmd_unkillable,                     "Toggle damage immunity")


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
