extends AnimationPlayer
class_name ShipIntro

## Вступительная катсцена корабля (анимация «Intro» на узле CutScene).
##
## Раньше «Intro» стояла в Autoplay и проигрывалась при КАЖДОМ входе на корабль.
## Теперь:
##   • новый персонаж (слот создан, а катсцену ещё не видел) → играет катсцену;
##     игрок заморожен, интерфейс скрыт (см. PlayerCutsceneLock);
##   • катсцену досмотрели → в слоте ставится флаг intro_seen, больше не показывается;
##   • все остальные заходы на корабль → сцена сразу в итоговом состоянии
##     (капсула открыта, игрок на месте, свет включён), без диалога и затемнения.
##
## Повесь этот скрипт на узел CutScene и убери у него Autoplay.

@export var intro_animation : StringName = &"Intro"
## Игрок (его is_in_cutscene блокирует управление и интерфейс)
@export var player : Player
## Запуск сцены из редактора без слота сохранения: true = показывать катсцену (удобно для отладки)
@export var play_without_save_slot : bool = true
## Отладка: всегда показывать катсцену, даже если персонаж её уже видел
@export var force_play : bool = false


func _ready() -> void:
	if not has_animation(intro_animation):
		push_warning("ShipIntro: нет анимации '%s'" % intro_animation)
		return
	if _is_intro_pending():
		_play_intro()
	else:
		_apply_end_state()


func _is_intro_pending() -> bool:
	if force_play:
		return true
	var slot : String = Global.current_save_slot
	if slot.is_empty():
		return play_without_save_slot
	return SaveLoad.is_intro_pending(slot)


func _play_intro() -> void:
	# Замораживаем игрока до первого кадра, не дожидаясь трека анимации
	if player != null:
		player.is_in_cutscene = true
	animation_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	play(intro_animation)


func _on_intro_finished(anim_name: StringName) -> void:
	if anim_name != intro_animation:
		return
	# Страховка: если в анимации нет трека, который снимает блокировку
	if player != null:
		player.is_in_cutscene = false
	if not Global.current_save_slot.is_empty():
		SaveLoad.mark_intro_seen(Global.current_save_slot)


## Перематываем «Intro» в конец, не вызывая методы (диалог и fade) — получается состояние «после катсцены».
func _apply_end_state() -> void:
	var anim := get_animation(intro_animation)
	var muted : Array[int] = []
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_METHOD and anim.track_is_enabled(i):
			anim.track_set_enabled(i, false)
			muted.append(i)
	play(intro_animation)
	seek(anim.length, true)
	stop(true)  # keep_state: оставляем итоговые значения
	for i in muted:
		anim.track_set_enabled(i, true)
