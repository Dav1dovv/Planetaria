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

@export_group("Infection (получено заражение)")
## HDR-фиолет: на миг заливает персонажа и медленно «впитывается» (дольше, чем красный урон)
@export var infection_color : Color = Color(1.9, 0.35, 2.3, 1.0)
@export_range(0.0, 1.0, 0.01) var infection_tilt : float = 0.12
## Высота звука: если свой звук не задан, берётся звук урона, но ниже и «глуше»
@export_range(0.2, 1.5, 0.05) var infection_pitch : float = 0.55
## Свой звук заражения (необязательно)
@export var infection_audio : AudioStreamPlayer2D
## Цвет частиц, которые втягиваются в игрока
@export var infection_particle_color : Color = Color(0.85, 0.3, 1.0, 1.0)

var _tween : Tween
var _infection_fx : CPUParticles2D
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


## Игрок получил заражение: фиолетовая заливка с «пульсом», дрожь, фиолетовые
## искры, втягивающиеся в тело, всплывающее «+N», звук, лёгкая тряска и вибрация.
## Намеренно непохоже на урон (красный + кровь): игрок сразу видит, что это порча.
func _infection_vfx(amount : float = 0.0) -> void:
	_play_infection_audio()
	_play_infection_particles()

	if not _begin(character):
		vfx_finished.emit()
		return

	var tilt := infection_tilt
	_tween = character.create_tween().set_parallel(true)

	# Цвет: вспышка → пульс (как будто зараза «бьётся» внутри) → медленное угасание
	var mid := infection_color.lerp(_rest_modulate, 0.55)
	_tween.tween_property(character, "modulate", infection_color, 0.07)
	_tween.tween_property(character, "modulate", mid, 0.10).set_delay(0.07)
	_tween.tween_property(character, "modulate", infection_color.lerp(_rest_modulate, 0.2), 0.08) \
			.set_delay(0.17)
	_tween.tween_property(character, "modulate", _rest_modulate, 0.45) \
			.set_delay(0.25).set_ease(Tween.EASE_OUT)

	# Дрожь: быстрые наклоны вправо-влево и возврат
	_tween.tween_property(character, "rotation", _rest_rotation + tilt, 0.05)
	_tween.tween_property(character, "rotation", _rest_rotation - tilt, 0.08).set_delay(0.05)
	_tween.tween_property(character, "rotation", _rest_rotation + tilt * 0.5, 0.07).set_delay(0.13)
	_tween.tween_property(character, "rotation", _rest_rotation, 0.1).set_delay(0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Масштаб: резкое «сжатие» от неприятного ощущения и пружинистый возврат
	_tween.tween_method(_set_scale_factor, Vector2.ONE, Vector2(0.88, 0.88), 0.06) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_scale_factor, Vector2(0.88, 0.88), Vector2.ONE, 0.2) \
			.set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_tween_finished)

	if amount > 0.0:
		GameJuice.floating_text(character.global_position + Vector2(0.0, -28.0),
				"+%d" % roundi(amount), infection_particle_color, 1.0, 0.9, 22.0, 1.5)
	GameJuice.shake(2.0, 0.15)
	Rumble.confirm(true)


func _play_infection_audio() -> void:
	if is_instance_valid(infection_audio):
		infection_audio.play()
		return
	if not is_instance_valid(audio_player):
		return
	if _base_pitch < 0.0:
		_base_pitch = audio_player.pitch_scale
	audio_player.pitch_scale = _base_pitch * infection_pitch \
			* (1.0 + randf_range(-pitch_variation, pitch_variation))
	audio_player.play()


## Фиолетовые искры возникают вокруг игрока и втягиваются внутрь (отрицательное
## радиальное ускорение) — «порча заходит в тело».
func _play_infection_particles() -> void:
	if not is_instance_valid(character):
		return
	if not is_instance_valid(_infection_fx):
		var fx := CPUParticles2D.new()
		fx.emitting = false
		fx.one_shot = true
		fx.explosiveness = 0.9
		fx.amount = 24
		fx.lifetime = 0.55
		fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		fx.emission_sphere_radius = 20.0
		fx.direction = Vector2.ZERO
		fx.spread = 180.0
		fx.gravity = Vector2(0.0, -25.0)
		fx.initial_velocity_min = 0.0
		fx.initial_velocity_max = 8.0
		fx.radial_accel_min = -140.0
		fx.radial_accel_max = -90.0
		fx.scale_amount_min = 1.5
		fx.scale_amount_max = 3.0
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		ramp.colors = PackedColorArray([
			Color(infection_particle_color, 0.0),
			Color(infection_particle_color, 1.0),
			Color(infection_particle_color.darkened(0.5), 0.0),
		])
		fx.color_ramp = ramp
		fx.position = Vector2(0.0, -10.0)
		fx.z_index = 2
		character.add_child(fx)
		_infection_fx = fx
	_infection_fx.restart()
	_infection_fx.emitting = true


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
