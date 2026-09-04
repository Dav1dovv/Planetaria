extends ColorRect
class_name InfectionVignette
## Экранная винетка заражения — GDD 3.3 "Заражение".
##
## Как подключить:
##   1. В GUI/HUD игрока добавь полноэкранный ColorRect (anchors = Full Rect,
##      mouse_filter = Ignore), поверх всего остального HUD.
##   2. Назначь ему материал ShaderMaterial с шейдером infection_vignette.gdshader.
##   3. Повесь этот скрипт на тот же ColorRect.
## Дальше всё работает само — компонент сам находит игрока и подписывается
## на PlayerInfection.tier_changed.

const STRENGTH_WEAK   := 0.25   # 10-49%
const STRENGTH_MEDIUM := 0.65   # 50-79% (см. GDD: "~65%")
const STRENGTH_STRONG := 0.85   # 80-100% (см. GDD: "~85%")
const FADE_DURATION    := 0.4

var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = material as ShaderMaterial
	if _material == null:
		push_warning("[InfectionVignette] Материал не назначен или это не ShaderMaterial")
		return

	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		return

func _apply_strength_for_tier(tier: int, instant: bool = false) -> void:
	if not _material:
		return

	var target := 0.0
	match tier:
		1: target = STRENGTH_WEAK
		2: target = STRENGTH_MEDIUM
		3: target = STRENGTH_STRONG
		_: target = 0.0

	if instant:
		_material.set_shader_parameter("strength", target)
		return

	if _tween:
		_tween.kill()
	var current: float = _material.get_shader_parameter("strength")
	_tween = create_tween()
	_tween.tween_method(
		func(v): _material.set_shader_parameter("strength", v),
		current, target, FADE_DURATION
	)
