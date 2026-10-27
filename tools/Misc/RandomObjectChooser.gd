extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
#  RandomObjectChooser — выбирает одного случайного дочернего объекта
#  и удаляет остальных. Результат детерминирован: зависит от сида локации
#  и позиции этого объекта в мире → при повторной загрузке выбор тот же.
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Берём сид из GameManager чтобы выбор был детерминирован
	var game_manager = get_tree().get_first_node_in_group("World")

	# Строим уникальный сид для этого конкретного объекта:
	# комбинируем сид локации + позицию → каждое дерево/камень выбирает
	# свой вариант стабильно, но независимо от других таких же объектов
	var local_seed: int
	if game_manager and game_manager.has_method("get_or_create_location_seed"):
		# Ищем ближайший WorldGenerator чтобы получить location_id
		var generator = get_tree().get_first_node_in_group("Generator")
		var location_id: String = "default_location"
		if generator and generator.has_method("get") and "location_id" in generator:
			location_id = generator.location_id

		var location_seed: int = game_manager.get_or_create_location_seed(location_id)
		# Смешиваем сид локации с позицией объекта для уникальности каждого
		var pos_hash: int = (str(global_position.x) + "," + str(global_position.y)).hash()
		local_seed = location_seed ^ pos_hash
	else:
		# Запасной вариант — позиция объекта как сид (хотя бы стабильно)
		push_warning("[RandomObjectChooser] GameManager не найден, использую позицию как сид")
		local_seed = (str(global_position.x) + "," + str(global_position.y)).hash()

	# Создаём изолированный генератор случайных чисел — НЕ трогаем глобальный seed()
	var rng := RandomNumberGenerator.new()
	rng.seed = local_seed

	var r_child := rng.randi() % get_child_count()
	for i in get_child_count():
		if i == r_child:
			get_child(r_child).visible = true
		else:
			get_child(i).queue_free()
