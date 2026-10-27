extends PanelContainer
class_name EffectTooltip
## Подсказка эффекта (сцена effect_tooltip.tscn): название, тип, описание, сколько осталось.
## Внешний вид — узлы сцены и Theme. Рамка зависит от типа через Theme Type Variation
## (TerminalTipBuff / TerminalTipDebuff / TerminalTipPassive в terminal_theme.tres).

@export_group("Тексты (ключи перевода)")
@export var buff_key: String = "BUFF"
@export var debuff_key: String = "DEBUFF"
@export var passive_key: String = "EQUIPPED"
@export var time_left_key: String = "Time left: %d s"
## Строка «Длительность» в описании прячем: ниже живой счётчик «осталось».
@export var duration_line_key: String = "\nДлительность: %.1f сек"

@export_group("Цвета названия")
@export var color_buff: Color = Color("6fe08a")
@export var color_debuff: Color = Color("e8454f")
@export var color_passive: Color = Color("6b7388")

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _left: Label = %Left


var _effect: Effect
var _kind: EffectSlot.Kind = EffectSlot.Kind.BUFF
var _time_left: float = 0.0


## Данные можно передать до того, как подсказка появилась в дереве — применятся в _ready().
func setup(effect: Effect, kind: EffectSlot.Kind, time_left: float) -> void:
	_effect = effect
	_kind = kind
	_time_left = time_left
	if is_node_ready():
		_apply()


func _ready() -> void:
	if _effect != null:
		_apply()


func _apply() -> void:
	var effect := _effect
	var kind := _kind
	var time_left := _time_left
	var tag := Loc.t(buff_key)
	var color := color_buff
	var variation := &"TerminalTipBuff"
	if kind == EffectSlot.Kind.DEBUFF:
		tag = Loc.t(debuff_key)
		color = color_debuff
		variation = &"TerminalTipDebuff"
	elif kind == EffectSlot.Kind.PASSIVE:
		tag = Loc.t(passive_key)
		color = color_passive
		variation = &"TerminalTipPassive"
	theme_type_variation = variation

	var duration_line := (Loc.t(duration_line_key) % effect.duration).strip_edges()
	var lines: PackedStringArray = []
	for line in effect.get_tooltip_text().split("\n"):
		if line.strip_edges() != duration_line:
			lines.append(line)

	_title.text = "%s  [%s]" % [lines[0], tag]
	_title.add_theme_color_override("font_color", color)
	_body.text = "\n".join(lines.slice(1)).strip_edges()
	_left.visible = kind != EffectSlot.Kind.PASSIVE and time_left > 0.0
	_left.text = Loc.t(time_left_key) % ceili(time_left)
