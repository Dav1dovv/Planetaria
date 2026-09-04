extends Node
class_name VFX

signal vfx_finished
signal paricles_finished

@export var audio_player : AudioStreamPlayer2D
@export var particles : GPUParticles2D

func _play_particles():
	if particles == null:
		paricles_finished.emit()
		return
	
	particles.restart()
	particles.emitting = true
	
	# ЖДЁМ, пока частицы закончатся
	while particles.emitting:
		await get_tree().process_frame  # Ждём кадр
	
	# Дополнительно: ждём, пока все частицы исчезнут
	await get_tree().create_timer(particles.lifetime).timeout
	
	paricles_finished.emit()  # Только теперь!
