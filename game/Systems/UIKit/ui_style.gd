# ui_style.gd
## Единая палитра Planetoria. Цвета взяты из terminal_theme.tres и скриптов терминала.
## Для кода (шейдеры, _draw, частицы, динамические Label); для обычных Control используйте
## Theme Type Variation из terminal_theme.tres.
class_name UIStyle
extends RefCounted

const SCREEN_BG   := Color("171923")  ## фон корпуса
const SCREEN_DEEP := Color("061620")  ## глубокий фон «экрана» (ячейки, панели статов)
const METAL_DARK  := Color("5d6b73")  ## рамки, неактивное
const METAL_MID   := Color("6b7388")  ## винты, второстепенное
const METAL_LIGHT := Color("9aa5b8")  ## приглушённый, но читаемый текст

const CYAN_DIM    := Color("1f7f86")  ## заголовки, подписи, рамки экрана
const CYAN        := Color("45e6e6")  ## «можно взаимодействовать»
const CYAN_LIGHT  := Color("c9f7f7")  ## основной текст

const AMBER       := Color("ffc857")  ## важно: квест, награда, выбранное
const GREEN       := Color("6fe08a")  ## выполнено, хватает ресурсов
const RED         := Color("e8454f")  ## урон, опасность, не хватает


## «Включение монитора» для окон на обычном Panel (у PanelContainer есть свой TerminalScreen.boot()).
## Повторяет его параметры, чтобы все окна включались одинаково.
static func boot(ctrl: Control, open_time: float = 0.22, flash_time: float = 0.3, flash: float = 2.0) -> void:
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(1.0, 0.04)
	ctrl.modulate = Color(flash, flash, flash, 0.0)
	var tw := ctrl.create_tween().set_parallel(true)
	tw.tween_property(ctrl, "scale:y", 1.0, open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "modulate", Color.WHITE, flash_time)
