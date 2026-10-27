# save_load_slot.gd
## Экран «Ваши персонажи»: сетка пропусков-сохранений + создание нового пропуска.
##
## UX-правила экрана:
##   * Карточки «раздаются» на стол по очереди, самая свежая сразу выбрана (Enter / A = войти).
##   * Последняя в сетке пустая карточка «Выписать пропуск» – единственный вход в создание персонажа.
##   * Удаление: × на карточке, Del или Y; всегда с подтверждением внутри самой карточки.
##   * Esc / B всегда ведёт на шаг назад: подтверждение → список → главное меню.
##   * Во время сканирования пропуска остальные карточки блокируются.
extends CanvasLayer

const SLOT_SCENE_PATH   := "res://game/Systems/SaveLoadSlot/Save_load_Button.tscn"
const BUTTON_SCENE_PATH := "res://tools/Misc/UIelements/button.tscn"

const GRID_COLUMNS  := 3
const DEAL_STAGGER  := 0.045  ## задержка между карточками при «раздаче», сек

@export var new_save_panel:     VBoxContainer
@export var player_name_input:  LineEdit
@export var create_button:      Button
@export var save_slot_template: PackedScene

@onready var save_slots_container: GridContainer = $Panel/VBoxContainer/ScrollContainer/SaveSlots
@onready var _scroll: ScrollContainer = $Panel/VBoxContainer/ScrollContainer
@onready var _list_box: Control = $Panel/VBoxContainer
@onready var blur: Control = %Blur

var current_slots: Array = []
var sort_by_date_desc: bool = true
var name_gen := SimpleNameGenerator.new()

var _preview: CrewBadge
var _preview_skin: int = 0
var _preview_head: int = 0
var _preview_colors: SkinColors = null   # null = оригинальные цвета выбранного скина
var _picker: SkinColorPicker
var _hint: Label
var _busy: bool = false      ## идёт сканирование пропуска / создание: ввод игнорируем


func _ready() -> void:
	_resolve_exports()

	save_slots_container.columns = GRID_COLUMNS
	save_slots_container.custom_minimum_size = Vector2.ZERO
	save_slots_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # ячейки делят ширину, карточки по центру
	save_slots_container.add_theme_constant_override("h_separation", 0)
	save_slots_container.add_theme_constant_override("v_separation", 2)
	_scroll.follow_focus = true  # фокус с геймпада/клавиатуры сам прокручивает список
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	new_save_panel.visible = false
	blur.visible = false

	_build_hint()
	_build_new_pass_preview()
	player_name_input.text_submitted.connect(_on_name_submitted)
	visibility_changed.connect(_on_visibility_changed)

	update_save_slots()


## Подстраховка на случай, если экспорты не подцепились из сцены.
func _resolve_exports() -> void:
	if new_save_panel == null:
		new_save_panel = get_node_or_null("NewSavePanel") as VBoxContainer
	if player_name_input == null:
		player_name_input = get_node_or_null("NewSavePanel/NameBox/LineEdit") as LineEdit
	if create_button == null:
		create_button = get_node_or_null("NewSavePanel/HBoxContainer/Create") as Button
	if save_slot_template == null:
		save_slot_template = load(SLOT_SCENE_PATH) as PackedScene

	assert(new_save_panel != null,    "[SaveLoadSlot] new_save_panel is null")
	assert(player_name_input != null, "[SaveLoadSlot] player_name_input is null")
	assert(create_button != null,     "[SaveLoadSlot] create_button is null")
	assert(save_slot_template != null, "[SaveLoadSlot] save_slot_template is null")


func _on_visibility_changed() -> void:
	if not visible:
		return
	# Экран открыт заново: перечитываем слоты (мета могла измениться) и раздаём карточки
	_busy = false
	update_save_slots()
	_focus_first_card()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _busy or not Global.is_escape_event(event):
		return
	get_viewport().set_input_as_handled()
	Global.mark_menu_closed()
	if new_save_panel.visible:
		_on_Craft_back_pressed()
	else:
		_on_back_pressed()


# ─────────────────────────────────────────────────────────────────────────────
#  Список слотов
# ─────────────────────────────────────────────────────────────────────────────

func update_save_slots() -> void:
	_clear_slot_buttons()
	current_slots.clear()

	for slot_name in SaveLoad.get_save_slots():
		var data: Dictionary = SaveLoad.load_slot_meta(slot_name)
		if data.is_empty():
			push_warning("[SaveLoadSlot] Cannot read meta for slot: %s" % slot_name)
			continue

		data["slot_name"] = slot_name
		if not data.has("last_save_time"):
			data["last_save_time"] = FileAccess.get_modified_time(
				SaveLoadSystem.SAVE_DIR + slot_name + "/" + SaveLoadSystem.SLOT_META_FILE
			)
		current_slots.append(data)

	current_slots.sort_custom(_sort_by_date)
	_display_sorted_slots()


func _sort_by_date(a: Dictionary, b: Dictionary) -> bool:
	var da: int = int(a.get("last_save_time", 0))
	var db: int = int(b.get("last_save_time", 0))
	return da > db if sort_by_date_desc else da < db


## remove_child + queue_free: старые карточки исчезают сразу, а не в конце кадра,
## поэтому не задерживают раскладку GridContainer вместе с новыми.
func _clear_slot_buttons() -> void:
	for child in save_slots_container.get_children():
		save_slots_container.remove_child(child)
		child.queue_free()


func _make_badge() -> CrewBadge:
	return save_slot_template.instantiate() as CrewBadge


func _display_sorted_slots() -> void:
	var index := 0
	for save_data in current_slots:
		var badge := _make_badge()
		save_slots_container.add_child(badge)
		badge.setup_slot(save_data)
		badge.activating.connect(_on_badge_activating.bind(badge))
		badge.activated.connect(_on_save_slot_selected.bind(badge))
		badge.revoke_confirmed.connect(_on_revoke_confirmed)
		badge.revoked.connect(_on_badge_revoked.bind(badge))
		badge.play_deal(index * DEAL_STAGGER)
		index += 1

	# Последняя карточка в сетке – «выписать новый пропуск»
	var blank := _make_badge()
	save_slots_container.add_child(blank)
	blank.setup_empty()
	blank.pressed.connect(_on_new_save_pressed)
	blank.play_deal(index * DEAL_STAGGER)


## Сразу выбираем самую свежую карточку: Enter/A = «продолжить игру».
func _focus_first_card() -> void:
	if not visible or new_save_panel.visible or save_slots_container.get_child_count() == 0:
		return
	(save_slots_container.get_child(0) as Control).grab_focus()


func _focus_slot(slot_name: String) -> void:
	for child in save_slots_container.get_children():
		var badge := child as CrewBadge
		if badge != null and badge.get_slot_name() == slot_name:
			badge.grab_focus()
			badge.flash()
			return
	_focus_first_card()


# ─────────────────────────────────────────────────────────────────────────────
#  Вход в игру
# ─────────────────────────────────────────────────────────────────────────────

func _on_badge_activating(_slot_name: String, selected: CrewBadge) -> void:
	_busy = true
	for child in save_slots_container.get_children():
		var other := child as CrewBadge
		if other != null and other != selected:
			other.set_locked(true)


func _on_save_slot_selected(slot_name: String, badge: CrewBadge) -> void:
	if SaveLoad.load_save(slot_name):
		Global.scene_manager.change_scene("Ship", Vector2.ZERO)
		return

	push_warning("[SaveLoadSlot] Cannot load slot: %s" % slot_name)
	_busy = false
	badge.reset_state()
	for child in save_slots_container.get_children():
		var other := child as CrewBadge
		if other != null:
			other.set_locked(false)


# ─────────────────────────────────────────────────────────────────────────────
#  Аннулирование пропуска (удаление сохранения)
# ─────────────────────────────────────────────────────────────────────────────

func _on_revoke_confirmed(slot_name: String) -> void:
	SaveLoad.delete_save(slot_name)
	current_slots = current_slots.filter(func(d: Dictionary) -> bool: return d.get("slot_name", "") != slot_name)


func _on_badge_revoked(_slot_name: String, badge: CrewBadge) -> void:
	# Карточка сейчас освободится сама; после этого переводим фокус на соседнюю
	var index := badge.get_index()
	await get_tree().process_frame
	if not visible or save_slots_container.get_child_count() == 0:
		return
	var next := save_slots_container.get_child(clampi(index, 0, save_slots_container.get_child_count() - 1))
	(next as Control).grab_focus()


# ─────────────────────────────────────────────────────────────────────────────
#  Создание нового пропуска
# ─────────────────────────────────────────────────────────────────────────────

func _build_new_pass_preview() -> void:
	var button_scene := load(BUTTON_SCENE_PATH) as PackedScene

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # стрелки «прижаты» к карточке
	row.add_theme_constant_override("separation", 10)
	new_save_panel.add_child(row)
	new_save_panel.move_child(row, 2) # между заголовком и полем имени

	row.add_child(_make_arrow(button_scene, "<", -1))
	_preview = _make_badge()
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(_preview)
	row.add_child(_make_arrow(button_scene, ">", 1))

	# Выбор цветов справа от пропуска; пропуск меняется вживую
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	row.add_child(gap)
	_picker = SkinColorPicker.new()
	_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_picker.colors_changed.connect(_on_colors_changed)
	row.add_child(_picker)

	_preview.setup_preview("", 0, 0)

	# Старая «пружина» под большую пустоту больше не нужна: место занимает превью
	var spacer := new_save_panel.get_node_or_null("Control2") as Control
	if spacer != null:
		spacer.custom_minimum_size.y = 8


func _make_arrow(button_scene: PackedScene, text: String, step: int) -> Button:
	var b := button_scene.instantiate() as Button
	b.text = text
	b.custom_minimum_size = Vector2(22, 24)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(_cycle_skin.bind(step))
	return b


func _on_new_save_pressed() -> void:
	# Начинаем с перекрашиваемого шаблона, чтобы выбор цвета сразу работал.
	# Готовые цветные скины доступны стрелками.
	_preview_skin = _first_colorable_style()
	_preview_head = _preview_skin
	_preview_colors = null          # каждый новый пропуск начинается с оригинальных цветов
	_picker.set_colors(null)
	_list_box.visible = false
	_hint.visible = false
	blur.visible = true
	new_save_panel.visible = true
	player_name_input.grab_focus()
	_sync_preview()
	_update_create_button()


func _on_create_pressed() -> void:
	if _busy:
		return
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		return

	# Цвета сохраняем, только если выбранный стиль вообще перекрашивается
	var colors: SkinColors = _preview_colors if _picker.is_enabled() else null
	var slot: String = SaveLoad.create_new_save(player_name, "World", _preview_skin, _preview_head, colors)
	if slot.is_empty():
		push_error("[SaveLoadSlot] Failed to create new save")
		return

	# Штамп «ВЫДАН» на превью, затем новая карточка «ложится» первой в списке
	_busy = true
	create_button.disabled = true
	var wait := _preview.play_stamp(Loc.t("ISSUED"), CrewBadge.C_OK, -10.0)
	await get_tree().create_timer(wait + 0.2).timeout
	_busy = false

	player_name_input.clear()
	_close_new_save_panel()
	update_save_slots()
	_focus_slot(slot)


func _on_random_name_pressed() -> void:
	player_name_input.text = name_gen.generate_name()
	_roll_look(true)
	_sync_preview()
	_preview.bump()
	_update_create_button()


func _on_line_edit_text_changed(_new_text: String) -> void:
	_sync_preview()
	_update_create_button()


func _on_name_submitted(_text: String) -> void:
	if not create_button.disabled:
		_on_create_pressed()


func _update_create_button() -> void:
	create_button.disabled = player_name_input.text.strip_edges().is_empty()


func _first_colorable_style() -> int:
	for i in CrewBadge.skin_count():
		if SkinColors.is_colorable(CrewBadge.get_skin(i)):
			return i
	return 0


## Случайный внешний вид: шлем и комбинезон бросаются независимо, как в мастерской.
## with_colors: бросаем ещё и цвета; тогда выбираем среди перекрашиваемых стилей,
## иначе цвета были бы не видны.
func _roll_look(with_colors: bool = false) -> void:
	var candidates: Array[int] = []
	for i in CrewBadge.skin_count():
		if not with_colors or SkinColors.is_colorable(CrewBadge.get_skin(i)):
			candidates.append(i)
	if candidates.is_empty():
		for i in CrewBadge.skin_count():
			candidates.append(i)
	_preview_skin = candidates[randi() % candidates.size()]
	_preview_head = candidates[randi() % candidates.size()]
	if with_colors:
		_picker.randomize_colors()   # сам вызовет _on_colors_changed


func _cycle_skin(step: int) -> void:
	var n := CrewBadge.skin_count()
	_preview_skin = wrapi(_preview_skin + step, 0, n)
	_preview_head = _preview_skin
	_sync_preview()
	_preview.bump()


func _sync_preview() -> void:
	# Выбор цвета доступен, только если хоть одна из частей нарисована шаблонными цветами
	var colorable := SkinColors.is_colorable(CrewBadge.get_skin(_preview_skin)) \
		or SkinColors.is_colorable(CrewBadge.get_skin(_preview_head))
	_picker.set_enabled(colorable)
	_preview.set_preview(player_name_input.text, _preview_skin, _preview_head, _preview_colors if colorable else null)


func _on_colors_changed(new_colors: SkinColors) -> void:
	_preview_colors = new_colors
	_sync_preview()
	_preview.flash()


func _close_new_save_panel() -> void:
	new_save_panel.visible = false
	blur.visible = false
	_list_box.visible = true
	_hint.visible = true


# ─────────────────────────────────────────────────────────────────────────────
#  Подсказка по управлению
# ─────────────────────────────────────────────────────────────────────────────

func _build_hint() -> void:
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 6)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	InputHints.bind_label(_hint, InputHints.save_screen_hint)  # Enter/Del/Esc, A/Y/B или ничего на телефоне
	$Panel.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -14
	_hint.offset_bottom = -4


# ─────────────────────────────────────────────────────────────────────────────
#  Кнопки «Назад»
# ─────────────────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	if _busy:
		return
	var menu := get_node_or_null("../CanvasLayer") as CanvasLayer
	if menu:
		menu.visible = true
	visible = false


## Назад из панели создания персонажа: возвращаемся к списку слотов.
func _on_Craft_back_pressed() -> void:
	if _busy:
		return
	_close_new_save_panel()
	_focus_first_card()
