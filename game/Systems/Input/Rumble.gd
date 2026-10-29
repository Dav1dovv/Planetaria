extends RefCounted
class_name Rumble

## Вибрация геймпада (GDD, таблица Game Feel: «короткая вибрация при уроне, можно отключить»).
## Включение управляется настройкой vibration (SettingsManager) через Rumble.enabled.

static var enabled: bool = true


## Короткий удар: получил урон.
static func hit() -> void:
	_play(0.5, 0.2, 0.18)


## Подтверждение попадания по врагу: едва заметный «тык» (тяжёлый удар/крит — сильнее).
static func confirm(heavy: bool = false) -> void:
	if heavy:
		_play(0.35, 0.45, 0.10)
	else:
		_play(0.25, 0.0, 0.05)


## Мощный удар: смерть, босс.
static func heavy() -> void:
	_play(0.8, 0.8, 0.4)


static func _play(weak: float, strong: float, duration: float) -> void:
	if not enabled:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)
