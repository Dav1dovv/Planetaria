@tool
extends Sprite2D
class_name RandomSprite2D

# ═══════════════════════════════════════════════════════════════════════════════
#  RandomSprite2D — выбирает кадр спрайта по весам.
#  В игре: детерминирован — результат зависит от сида локации + позиции,
#          поэтому при перезагрузке сцены спрайт всегда тот же.
#  В редакторе: работает как раньше (кнопка Randomize Sprite).
# ═══════════════════════════════════════════════════════════════════════════════

@export var frame_weights: Array[float]
@export_tool_button("Randomize Sprite", "Callable")
var Randomize = func(): random_sprite_editor()


func _ready() -> void:
	if Engine.is_editor_hint():
		# В редакторе просто рандомизируем без привязки к сиду
		random_sprite_editor()
	else:
		# В игре — детерминированный выбор по позиции + сиду локации
		random_sprite_seeded()


# ─── Версия для редактора (кнопка + preview) ──────────────────────────────────
func random_sprite_editor() -> void:
	if frame_weights.is_empty():
		return
	# В редакторе ок использовать randomize() — это не влияет на игру
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	frame = _pick_frame(rng)


# ─── Версия для игры — детерминированная ──────────────────────────────────────
func random_sprite_seeded() -> void:
	if frame_weights.is_empty():
		return

	# Изолированный RNG — не трогает глобальный seed()
	var rng := RandomNumberGenerator.new()

	# Берём сид из GameManager если доступен
	var game_manager = get_tree().get_first_node_in_group("World")
	if game_manager and game_manager.has_method("get_or_create_location_seed"):
		var generator = get_tree().get_first_node_in_group("Generator")
		var location_id: String = "default_location"
		if generator and "location_id" in generator:
			location_id = generator.location_id
		var location_seed: int = game_manager.get_or_create_location_seed(location_id)
		var pos_hash: int = (str(global_position.x) + "," + str(global_position.y)).hash()
		rng.seed = location_seed ^ pos_hash
	else:
		# Запасной вариант — только позиция
		rng.seed = (str(global_position.x) + "," + str(global_position.y)).hash()

	frame = _pick_frame(rng)


# ─── Общая логика выбора кадра по весам ───────────────────────────────────────
func _pick_frame(rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	for w in frame_weights:
		total_weight += w

	if total_weight == 0.0:
		return 0

	var random_value := rng.randf() * total_weight
	var cumulative_weight := 0.0

	for i in range(frame_weights.size()):
		cumulative_weight += frame_weights[i]
		if random_value <= cumulative_weight:
			return i

	return frame_weights.size() - 1
