extends Harvest_item

@export var Boss : PackedScene
@export_placeholder("Scare") var boss_name : String = ""


# Переопределяем логику уничтожения из Harvestable: разрушили объект — проснулся босс
func _on_tree_exiting() -> void:
	# Выгрузка сцены / смена локации — не повод звать босса
	if Global.scene_manager.is_busy():
		return
	_spawn_boss()


func _spawn_boss() -> void:
	if Boss == null:
		push_warning("BossCaller: Boss не назначен в Инспекторе")
		return
	if get_parent() == null or get_parent().get_parent() == null:
		return

	GameJuice.banner(boss_name.to_upper(), Loc.t("awakens…"), Color(0.85, 0.15, 0.1), 1.8)
	GameJuice.shake(5.0, 0.6)

	var boss_instance := Boss.instantiate() as Node2D
	boss_instance.add_to_group("Boss")  # события и элиты не запускаются во время боя с боссом
	var spawn_pos := global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	# Объект уже выходит из дерева — добавляем босса на следующем кадре и только потом ставим позицию
	boss_instance.tree_entered.connect(func() -> void: boss_instance.global_position = spawn_pos, CONNECT_ONE_SHOT)
	get_parent().get_parent().add_child.call_deferred(boss_instance)
