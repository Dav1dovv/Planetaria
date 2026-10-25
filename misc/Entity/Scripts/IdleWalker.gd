class_name IdleWander
extends RefCounted

## «Жизнь» врага, пока он не видит игрока: пауза → неспешная прогулка к случайной
## точке возле «дома» → пауза → ... Иногда во время паузы враг оглядывается.
## Модуль ничего не знает о враге: update() получает позицию и скорость и
## возвращает скорость (px/с). Используется EnemyBase и MeleeEnemy.

enum State { PAUSE, WALK }

## Время плавного разгона в начале прогулки (сек)
const RAMP_TIME := 0.25
## Сколько секунд можно не двигаться при ходьбе, прежде чем сдаться (упёрся в стену)
const STUCK_TIME := 0.35
## Страховка: максимальная длительность одной прогулки
const MAX_WALK_TIME := 4.0

var radius : float = 40.0
var pause_min : float = 1.0
var pause_max : float = 3.0
var look_around_chance : float = 0.4

var _state : State = State.PAUSE
var _home : Vector2 = Vector2.ZERO
var _target : Vector2 = Vector2.ZERO
var _timer : float = 0.0
var _pause_total : float = 0.0
var _look_at : float = -1.0
var _look_pending : bool = false
var _ramp : float = 0.0
var _stuck : float = 0.0
var _last_pos : Vector2 = Vector2.ZERO


func configure(new_radius: float, new_pause_min: float, new_pause_max: float, new_look_chance: float) -> void:
	radius = maxf(new_radius, 0.0)
	pause_min = maxf(new_pause_min, 0.0)
	pause_max = maxf(new_pause_max, pause_min)
	look_around_chance = clampf(new_look_chance, 0.0, 1.0)
	# Случайный первый отсчёт: враги не начинают ходить синхронно
	_enter_pause(randf_range(0.0, pause_max))


func set_home(pos: Vector2) -> void:
	_home = pos


## Враг потерял игрока: новый «дом» там, где он стоит (не тащим его обратно),
## короткая пауза «куда он делся?» и дальше обычная жизнь.
func rehome(pos: Vector2) -> void:
	_home = pos
	_enter_pause(randf_range(0.3, 1.0))


## Вернёт true один раз, когда врагу пора оглянуться (развернуться на месте).
func consume_look_around() -> bool:
	var result := _look_pending
	_look_pending = false
	return result


## pos — глобальная позиция врага, walk_speed — скорость прогулки (px/с).
## Возвращает желаемую скорость: Vector2.ZERO во время паузы.
func update(delta: float, pos: Vector2, walk_speed: float) -> Vector2:
	if walk_speed <= 0.0 or radius <= 0.0:
		return Vector2.ZERO
	if _state == State.PAUSE:
		return _update_pause(delta, pos)
	return _update_walk(delta, pos, walk_speed)


func _update_pause(delta: float, pos: Vector2) -> Vector2:
	_timer -= delta
	if _look_at >= 0.0 and _pause_total - _timer >= _look_at:
		_look_at = -1.0
		_look_pending = true
	if _timer <= 0.0:
		_start_walk(pos)
	return Vector2.ZERO


func _update_walk(delta: float, pos: Vector2, walk_speed: float) -> Vector2:
	_timer -= delta
	var to_target := _target - pos
	var dist := to_target.length()
	var arrive_dist := maxf(1.5, walk_speed * delta * 1.5)

	# Дошли (или прогулка затянулась) — отдыхаем
	if dist <= arrive_dist or _timer <= 0.0:
		_enter_pause(randf_range(pause_min, pause_max))
		return Vector2.ZERO

	# Упёрлись в стену или другого врага — не топчемся на месте
	var moved := pos.distance_to(_last_pos)
	_last_pos = pos
	if _ramp >= 1.0 and moved < walk_speed * delta * 0.25:
		_stuck += delta
		if _stuck >= STUCK_TIME:
			_enter_pause(randf_range(pause_min, pause_max))
			return Vector2.ZERO
	else:
		_stuck = 0.0

	# Плавный разгон в начале и замедление у цели — движение не выглядит механическим
	_ramp = move_toward(_ramp, 1.0, delta / RAMP_TIME)
	var slow_zone := maxf(walk_speed * 0.4, 1.0)
	var arrive_factor := clampf(dist / slow_zone, 0.35, 1.0)
	return to_target / dist * walk_speed * _ramp * arrive_factor


func _enter_pause(duration: float) -> void:
	_state = State.PAUSE
	_timer = duration
	_pause_total = duration
	_ramp = 0.0
	_look_at = duration * randf_range(0.3, 0.8) if randf() < look_around_chance else -1.0


func _start_walk(pos: Vector2) -> void:
	_state = State.WALK
	# sqrt(randf) — точки равномерно по площади круга, а не кучкой у центра
	_target = _home + Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
	_timer = MAX_WALK_TIME
	_stuck = 0.0
	_last_pos = pos
	_ramp = 0.0
