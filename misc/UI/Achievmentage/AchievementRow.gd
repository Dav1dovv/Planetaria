extends PanelContainer
class_name AchievementRow

## Одна строка в окне достижений. Внешний вид — в AchievementRow.tscn
## (стили, шрифты, размеры правятся в редакторе); скрипт только подставляет данные.

@export var done_style: StyleBox
@export var locked_style: StyleBox
@export var done_badge: StyleBox
@export var locked_badge: StyleBox
@export var color_done := Color(1.0, 0.85, 0.3)
@export var color_text := Color(0.92, 0.95, 1.0)
@export var color_muted := Color(0.55, 0.62, 0.72)

@onready var _badge: Panel = %Badge
@onready var _name: Label = %NameLabel
@onready var _desc: Label = %DescLabel
@onready var _bar: ProgressBar = %ProgressBar
@onready var _progress_label: Label = %ProgressLabel
@onready var _reward: Label = %RewardLabel
@onready var _status: Label = %StatusLabel


## entry — запись из AchievementTracker.LIST; progress = (набрано, нужно).
## Вызывать после add_child.
func setup(entry: Array, is_done: bool, unlock_time: int, progress: Vector2i) -> void:
	add_theme_stylebox_override("panel", done_style if is_done else locked_style)
	_badge.add_theme_stylebox_override("panel", done_badge if is_done else locked_badge)

	_name.text = Loc.t(entry[1])
	_name.add_theme_color_override("font_color", color_done if is_done else color_text)
	_desc.text = Loc.t(entry[2])

	# Полоска нужна только для незавершённых «счётных» достижений
	var show_progress := not is_done and progress.y > 1
	_bar.visible = show_progress
	_progress_label.visible = show_progress
	if show_progress:
		_bar.max_value = progress.y
		_bar.value = progress.x
		_progress_label.text = "%d / %d" % [progress.x, progress.y]

	_reward.text = "+%d" % int(entry[3])
	_reward.add_theme_color_override("font_color", color_done if is_done else color_muted)
	_status.text = _status_text(is_done, unlock_time)
	_status.add_theme_color_override("font_color", color_done if is_done else color_muted)


func _status_text(is_done: bool, unlock_time: int) -> String:
	if not is_done:
		return Loc.t("Locked")
	if unlock_time <= 0:
		return Loc.t("Unlocked")
	var d := Time.get_datetime_dict_from_unix_time(unlock_time)
	return "%s %02d.%02d.%d" % [Loc.t("Unlocked"), d.day, d.month, d.year]
