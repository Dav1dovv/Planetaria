extends Resource
class_name SceneRegistry

# ═══════════════════════════════════════════════════════════════════════════════
#  SceneRegistry — реестр всех сцен игры, настраивается из Инспектора
# ───────────────────────────────────────────────────────────────────────────────
#  Создать: ПКМ в FileSystem → New Resource → SceneRegistry
#  Назначить: в поле scene_registry у ноды SceneManager
#
#  Пример заполнения в Инспекторе:
#    scenes:
#      [0] SceneData  key="village"   scene_path="res://..."  biome="Village"
#      [1] SceneData  key="deep_cave" scene_path="res://..."  biome="Cave"  is_underground=true
# ═══════════════════════════════════════════════════════════════════════════════

## Все сцены игры. Добавляй сюда новые SceneData ресурсы.
@export var scenes: Array[SceneData] = []


# ── Кэш для быстрого поиска по ключу (строится один раз) ──────────────────────
var _cache: Dictionary = {}


func _build_cache() -> void:
	_cache.clear()
	for scene_data: SceneData in scenes:
		if scene_data == null or scene_data.key.is_empty():
			push_warning("SceneRegistry: найден SceneData без ключа, пропускаем.")
			continue
		if _cache.has(scene_data.key):
			push_warning("SceneRegistry: дублирующийся ключ '%s', будет использован последний." % scene_data.key)
		_cache[scene_data.key] = scene_data


func get_scene(key: String) -> SceneData:
	if _cache.is_empty():
		_build_cache()
	return _cache.get(key, null)


func has_scene(key: String) -> bool:
	if _cache.is_empty():
		_build_cache()
	return _cache.has(key)


func get_all_keys() -> Array[String]:
	if _cache.is_empty():
		_build_cache()
	var keys: Array[String] = []
	keys.assign(_cache.keys())
	return keys


## Добавить сцену во время игры (например, из DLC или мода)
func register_at_runtime(scene_data: SceneData) -> void:
	if scene_data == null or scene_data.key.is_empty():
		push_error("SceneRegistry: нельзя зарегистрировать SceneData без ключа.")
		return
	scenes.append(scene_data)
	_cache[scene_data.key] = scene_data
