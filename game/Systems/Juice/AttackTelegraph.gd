extends RefCounted
class_name AttackTelegraph
## Единственный телеграф врагов: «!» над головой в момент, когда враг заметил игрока.
## Сами удары читаются по их анимации, без подсветки спрайта.

## Не показывать «!» чаще раза в эту паузу (враг на границе зрения не должен мигать)
const MIN_INTERVAL_MSEC := 2000


## Показывает «!» и возвращает новое время последнего сигнала (хранит сам враг).
static func alert(world_pos: Vector2, last_msec: int) -> int:
	var now := Time.get_ticks_msec()
	if now - last_msec < MIN_INTERVAL_MSEC:
		return last_msec
	GameJuice.floating_text(world_pos, "!", Color(1.0, 0.85, 0.2), 1.3, 0.6, 8.0, 1.4)
	return now
