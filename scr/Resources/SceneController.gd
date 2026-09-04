extends Resource
class_name SceneData

# ═══════════════════════════════════════════════════════════════════════════════
#  SceneData — описание одной локации, настраивается из Инспектора
# ───────────────────────────────────────────────────────────────────────────────
#  Создать: ПКМ в FileSystem → New Resource → SceneData
#  Использовать: добавить в массив scenes у SceneRegistry
# ═══════════════════════════════════════════════════════════════════════════════

## Уникальный ключ сцены (используется в коде: SceneManager.change_scene("deep_cave"))
@export var key: String = ""

## Путь к .tscn файлу
@export_file("*.tscn") var scene_path: String = ""

## Человекочитаемое название (для UI, загрузочного экрана и т.п.)
@export var display_name: String = ""

# ── Параметры мира ─────────────────────────────────────────────────────────────

## Биом / тип локации
@export_enum("Desert", "Forest", "Thundra","Deep")
var biome: String = "Forest"

## Уровень заражения этой локации (0 = чисто, 3 = полностью заражено)
@export_range(0, 3, 1) var corruption_level: int = 0

## Эта локация находится под землёй (скрыть day/night цикл)
@export var is_underground: bool = false

## Ключ музыкальной темы для MusicManager
@export var music_key: String = ""

## Загрузочные подсказки, специфичные для этой локации.
## Если пусто — используются глобальные подсказки из SceneManager.
@export var loading_hints: Array[String] = []

# ── Метаданные для метроидвании ────────────────────────────────────────────────

## Эта локация уже открыта игроком (можно менять во время игры через WorldState)
@export var is_unlocked: bool = true

## Ключи сцен, к которым можно перейти из этой локации (для карты мира)
@export var connected_scenes: Array[String] = []


func _to_string() -> String:
	return "SceneData(%s → %s)" % [key, scene_path]
