extends VFX
class_name VFX_damage

## Эффекты урона для Node2D-персонажа.
##   _hit_vfx(персонаж)  — удар по цели: белая вспышка + «хлопок» масштаба + наклон.
##   _damage_vfx()       — урон по игроку: красный оттенок + наклон.
## Оба метода работают поверх одного и того же сохранённого «состояния покоя»
## (масштаб / поворот / цвет), поэтому частые удары не накапливают сдвиг,
## а отзеркаленный по X спрайт (scale.x < 0) не ломается.
## Окончание эффекта — сигнал vfx_finished.

@export var character : Node2D

@export_group("Hit (удар по цели)")
## HDR-цвет вспышки (значения > 1 дают свечение).
@export var hit_flash_color : Color = Color(18.892, 18.892, 18.892, 1.0)
@export var hit_flash_in : float = 0.04
@export var hit_flash_out : float = 0.16
## Во сколько раз персонаж «сжимается» в момент удара и «подпрыгивает» после.
@export var hit_shrink : Vector2 = Vector2(0.7, 0.7)
@export var hit_overshoot : Vector2 = Vector2(1.1, 1.1)
@export_range(0.0, 1.0, 0.01) var hit_tilt : float = 0.2

@export_group("Damage (урон по игроку)")
@export var damage_color : Color = Color(3.705, 0.0, 0.0, 1.0)
@export_range(0.0, 1.0, 0.01) var damage_tilt : float = 0.2

var _tween : Tween
## Узел, чьё состояние покоя запомнено, и само состояние.
var _rest_owner : Node2D
var _rest_scale : Vector2 = Vector2.ONE
var _rest_rotation : float = 0.0
var _rest_modulate : Color = Color.WHITE


## Удар по цели. Без аргумента берёт экспортируемого character.
func _hit_vfx(new_character : Node2D = null) -> void:
	_play_audio()
	_play_particles()

	var target := new_character if is_instance_valid(new_character) else character
	if not _begin(target):
		vfx_finished.emit()
		return

	var tilt := _rest_rotation + randf_range(-hit_tilt, hit_tilt)
	var shrink_t := 0.03
	var pop_t := 0.05
	var settle_t := 0.1

	# Tween создаётся у самого персонажа: если тот удалится (умер от удара),
	# анимация остановится без ошибок «target freed».
	_tween = target.create_tween().set_parallel(true)

	# Цвет: мгновенно вспыхнуть и плавно вернуться
	_tween.tween_property(target, "modulate", hit_flash_color, hit_flash_in)
	_tween.tween_property(target, "modulate", _rest_modulate, hit_flash_out) \
			.from(hit_flash_color).set_delay(hit_flash_in).set_ease(Tween.EASE_OUT)

	# Наклон: рывок в сторону и пружинистое возвращение
	_tween.tween_property(target, "rotation", tilt, shrink_t)
	_tween.tween_property(target, "rotation", _rest_rotation, pop_t + settle_t) \
			.from(tilt).set_delay(shrink_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Масштаб: сжатие → перелёт → возврат (через коэффициент от масштаба покоя)
	_tween.tween_method(_set_scale_factor, Vector2.ONE, hit_shrink, shrink_t) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_scale_factor, hit_shrink, hit_overshoot, pop_t) \
			.set_delay(shrink_t).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_scale_factor, hit_overshoot, Vector2.ONE, settle_t) \
			.set_delay(shrink_t + pop_t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_tween.finished.connect(_on_tween_finished)


## Урон по игроку: красный оттенок и лёгкий наклон.
func _damage_vfx() -> void:
	_play_audio()
	_play_particles()

	if not _begin(character):
		vfx_finished.emit()
		return

	var tilt := _rest_rotation + randf_range(-damage_tilt, damage_tilt)

	_tween = character.create_tween().set_parallel(true)
	_tween.tween_property(character, "rotation", tilt, 0.1)
	_tween.tween_property(character, "modulate", damage_color, 0.1)
	_tween.tween_property(character, "rotation", _rest_rotation, 0.1) \
			.from(tilt).set_delay(0.1)
	_tween.tween_property(character, "modulate", _rest_modulate, 0.2) \
			.from(damage_color).set_delay(0.1)
	_tween.finished.connect(_on_tween_finished)


# ─────────────────────────────────────────────────────────────────────────────
#  Внутренняя кухня
# ─────────────────────────────────────────────────────────────────────────────

## Подготавливает персонажа к новому эффекту: обрывает прежний (возвращая
## персонажа в покой, а не оставляя на полпути) и запоминает его покой заново.
func _begin(target : Node2D) -> bool:
	_cancel_running()
	if not is_instance_valid(target):
		return false
	character = target
	_rest_owner = target
	_rest_scale = target.scale
	_rest_rotation = target.rotation
	_rest_modulate = target.modulate
	return true


func _cancel_running() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_restore_rest()
	_tween = null


func _restore_rest() -> void:
	if not is_instance_valid(_rest_owner):
		return
	_rest_owner.rotation = _rest_rotation
	_rest_owner.modulate = _rest_modulate
	_rest_owner.scale = _scaled(Vector2.ONE)


func _set_scale_factor(factor : Vector2) -> void:
	if is_instance_valid(_rest_owner):
		_rest_owner.scale = _scaled(factor)


## Масштаб покоя × коэффициент. Знак берётся у ТЕКУЩего масштаба, поэтому если
## ИИ разворачивает спрайт (scale.x *= -1) во время эффекта, разворот не отменяется.
func _scaled(factor : Vector2) -> Vector2:
	var current := _rest_owner.scale
	return Vector2(
		absf(_rest_scale.x) * factor.x * (-1.0 if current.x < 0.0 else 1.0),
		absf(_rest_scale.y) * factor.y * (-1.0 if current.y < 0.0 else 1.0)
	)


func _on_tween_finished() -> void:
	vfx_finished.emit()
