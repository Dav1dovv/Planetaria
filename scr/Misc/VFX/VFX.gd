extends Node
class_name VFX

## Базовый класс визуальных эффектов: звук + частицы.
## Наследники (например, VFX_damage) добавляют анимацию персонажа.

## Эффект целиком завершён (для VFX_damage — когда доиграла анимация персонажа).
signal vfx_finished
## Частицы полностью отыграли и исчезли.
signal particles_finished
## Устаревшее имя (опечатка) — оставлено, чтобы не сломать уже подключённые
## сигналы в сценах. Эмитится вместе с particles_finished.
signal paricles_finished

@export var audio_player : AudioStreamPlayer2D
@export var particles : GPUParticles2D
## Случайный разброс высоты звука (±), чтобы повторяющиеся удары не звучали
## одинаково. 0 — выключено.
@export_range(0.0, 0.5, 0.01) var pitch_variation : float = 0.06

var _base_pitch : float = -1.0
## Номер последнего запуска частиц: устаревшие ожидания (из-за повторного
## запуска) молча завершаются и не шлют сигнал второй раз.
var _particles_run : int = 0


func _play_audio() -> void:
	if not is_instance_valid(audio_player):
		return
	# Базовую высоту запоминаем один раз, чтобы разброс не «уплывал» от удара к удару
	if _base_pitch < 0.0:
		_base_pitch = audio_player.pitch_scale
	audio_player.pitch_scale = _base_pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	audio_player.play()


func _play_particles() -> void:
	if not is_instance_valid(particles):
		_emit_particles_finished()
		return

	_particles_run += 1
	var run := _particles_run

	particles.restart()
	particles.emitting = true

	if particles.one_shot:
		# Сигнал приходит, когда эмиссия закончилась И все частицы погасли
		await particles.finished
	else:
		# Непрерывные частицы сами не заканчиваются: ждём одну жизнь частицы
		await get_tree().create_timer(particles.lifetime / maxf(particles.speed_scale, 0.001)).timeout

	if run != _particles_run:
		return  # частицы перезапущены новым вызовом — сигнал отправит он
	_emit_particles_finished()


func _emit_particles_finished() -> void:
	particles_finished.emit()
	paricles_finished.emit()
