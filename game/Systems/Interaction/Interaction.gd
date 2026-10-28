extends RapierArea2D
class_name interaction_area

signal far
## Игрок начал удерживать кнопку (только при hold_to_interact)
signal hold_started
## Прогресс удержания 0..1 каждый кадр — можно повесить свою анимацию объекта
signal hold_progress(ratio: float)
## Отпустил кнопку раньше времени / отошёл / увёл курсор
signal hold_canceled
## Круг заполнился — сразу после этого вызывается interact
signal hold_completed

@export_multiline var show_message : String = "interact"
@export var icon_help : Texture2D
## Подсвечивать объект, когда он под курсором и игрок достаёт до него (GDD: «объект подсвечивается»)
@export var highlight: bool = true
## Что подсвечивать. Пусто — родитель этой зоны (если он CanvasItem).
## Если родитель — большая сцена целиком, назначь сюда конкретный спрайт.
@export var highlight_target: CanvasItem

@export_group("Удержание")
## ВКЛ — вместо клика нужно ЗАЖАТЬ кнопку действия (ЛКМ / RT) и держать, пока вокруг курсора не заполнится круг.
## ВЫКЛ — обычное взаимодействие одним кликом (как раньше).
@export var hold_to_interact: bool = false
## Сколько секунд нужно держать кнопку
@export_range(0.1, 10.0, 0.05, "suffix:s") var hold_time: float = 1.0
## Какое действие нужно удерживать (в Input Map). ЛКМ на геймпаде = RT, поэтому «LMB» работает везде.
@export var hold_action: StringName = &"LMB"
@export_group("")

## Дальность взаимодействия от игрока (px)
const INTERACT_RANGE := 60.0
var is_in_zone = false
var player
var interact: Callable = func():
	pass

var _holding: bool = false
var _hold_elapsed: float = 0.0

# Исправлено: connect сигналов перенесён из _init() в _ready(),
# так как в _init нода ещё не добавлена в дерево сцены
func _init() -> void:
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(8, true)
	set_collision_mask_value(9, true)
	add_to_group("interaction")

func _ready() -> void:
	# Исправлено: подключение сигналов перенесено сюда
	connect("area_entered", _on_area_entered)
	connect("area_exited", _on_area_exited)
	set_process(false)  # _process включается только на время удержания

## Вызывается ТОЛЬКО курсором (Cursor.gd), когда именно этот объект
## реально находится под курсором в момент нажатия ЛКМ (RT на геймпаде) —
## то же главное действие, что и удар (GDD, схема управления).
## Больше не полагаемся на локальный is_in_zone + глобальный _input —
## это и вызывало срабатывание у всех объектов сразу, если area_exited
## терялся из-за быстрого перемещения курсора (телепорт мыши каждый кадр).
func try_interact() -> void:
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	if not is_in_range():
		Global.hint(get_parent(), Loc.t("you're too far"))
		emit_signal("far")
	elif hold_to_interact:
		_begin_hold()
	else:
		interact.call()


## Достаёт ли игрок до объекта.
func is_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("Player") as Node2D
	return p != null and global_position.distance_to(p.global_position) < INTERACT_RANGE


func _on_area_entered(area: Area2D) -> void:
	Cursor.Help_hint(icon_help)
	is_in_zone = true


func _on_area_exited(area: Area2D) -> void:
	Input.set_custom_mouse_cursor(Global.MOUSE_Arrow, Input.CURSOR_ARROW, Vector2(0, 0))
	is_in_zone = false
	Cursor.Help_hint(null)


# ─── Удержание ────────────────────────────────────────────────────────────────
# Курсор вызывает try_interact() на нажатии ЛКМ (RT). Если hold_to_interact включён,
# здесь стартует удержание: пока кнопка зажата, игрок рядом и курсор на объекте —
# растёт прогресс и рисуется круг у курсора. Заполнился — вызывается interact.
# Отпустил, отошёл, увёл курсор, открыл меню/диалог — удержание сбрасывается.

func is_holding() -> bool:
	return _holding


## Прервать удержание из кода (например, объект стал недоступен).
func cancel_hold() -> void:
	if _holding:
		_cancel_hold()


func _begin_hold() -> void:
	if _holding:
		return
	_holding = true
	_hold_elapsed = 0.0
	set_process(true)
	hold_started.emit()
	Cursor.hold_progress(0.0)


func _process(delta: float) -> void:
	if not _holding:
		set_process(false)
		return
	if _should_cancel_hold():
		_cancel_hold()
		return
	_hold_elapsed += delta
	var ratio := clampf(_hold_elapsed / maxf(hold_time, 0.05), 0.0, 1.0)
	hold_progress.emit(ratio)
	Cursor.hold_progress(ratio)
	if ratio >= 1.0:
		_complete_hold()


func _should_cancel_hold() -> bool:
	if not Input.is_action_pressed(hold_action):
		return true
	if Global.is_opened_menu or DialogueLock.is_locked():
		return true
	if not is_in_range():
		return true
	# Курсор ушёл с объекта — удержание сбрасывается
	return Cursor.get_hovered_interaction() != self


func _complete_hold() -> void:
	_holding = false
	set_process(false)
	hold_completed.emit()
	Cursor.hold_end(true)
	Cursor.interact_count += 1  # для обучения: «шаг выполнен» считается по завершению, а не по нажатию
	interact.call()


func _cancel_hold() -> void:
	_holding = false
	set_process(false)
	hold_canceled.emit()
	Cursor.hold_end(false)


func _exit_tree() -> void:
	if _holding:
		_holding = false
		Cursor.hold_end(false)
