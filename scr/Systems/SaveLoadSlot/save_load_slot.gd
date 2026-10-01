# save_load_slot.gd
extends CanvasLayer

const SLOT_SCENE_PATH := "res://scr/Systems/SaveLoadSlot/Save_load_Button.tscn"

@export var new_save_panel:     VBoxContainer
@export var player_name_input:  LineEdit
@export var skin_selector:      PlayerSkin
@export var create_button:      Button
@export var save_slot_template: PackedScene

@onready var save_slots_container: Container = $Panel/VBoxContainer/ScrollContainer/SaveSlots
@onready var blur: Control = %Blur

var current_slots: Array = []
var sort_by_date_desc: bool = true
var name_gen := SimpleNameGenerator.new()


func _ready() -> void:
	_resolve_exports()
	new_save_panel.visible = false
	blur.visible = false
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


## remove_child + queue_free: старые кнопки исчезают сразу, а не в конце кадра,
## поэтому не задерживают раскладку GridContainer вместе с новыми.
func _clear_slot_buttons() -> void:
	for child in save_slots_container.get_children():
		save_slots_container.remove_child(child)
		child.queue_free()


func _display_sorted_slots() -> void:
	for save_data in current_slots:
		var slot_button = save_slot_template.instantiate()
		save_slots_container.add_child(slot_button)
		slot_button.setup_slot(save_data)
		slot_button.pressed.connect(_on_save_slot_selected.bind(save_data["slot_name"]))
		slot_button.deleted.connect(_on_slot_deleted)


func _on_slot_deleted(_slot_name: String) -> void:
	# отложенно: кнопка ещё внутри собственного сигнала
	update_save_slots.call_deferred()


func _on_save_slot_selected(slot_name: String) -> void:
	if SaveLoad.load_save(slot_name):
		Global.scene_manager.change_scene("Vehana", Vector2.ZERO)
	else:
		push_warning("[SaveLoadSlot] Cannot load slot: %s" % slot_name)


# ─────────────────────────────────────────────────────────────────────────────
#  Создание нового персонажа
# ─────────────────────────────────────────────────────────────────────────────

func _on_new_save_pressed() -> void:
	save_slots_container.visible = false
	blur.visible = true
	new_save_panel.visible = true
	player_name_input.grab_focus()
	_update_create_button()


func _on_create_pressed() -> void:
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		return

	var slot: String = SaveLoad.create_new_save(player_name, "World")
	if slot.is_empty():
		push_error("[SaveLoadSlot] Failed to create new save")
		return

	player_name_input.clear()
	_close_new_save_panel()
	update_save_slots()


func _on_random_name_pressed() -> void:
	player_name_input.text = name_gen.generate_name()
	_update_create_button()


func _on_line_edit_text_changed(_new_text: String) -> void:
	_update_create_button()


func _update_create_button() -> void:
	create_button.disabled = player_name_input.text.strip_edges().is_empty()


func _close_new_save_panel() -> void:
	new_save_panel.visible = false
	blur.visible = false
	save_slots_container.visible = true


# ─────────────────────────────────────────────────────────────────────────────
#  Кнопки «Назад»
# ─────────────────────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	var menu := get_node_or_null("../CanvasLayer") as CanvasLayer
	if menu:
		menu.visible = true
	visible = false


## Назад из панели создания персонажа: возвращаемся к списку слотов.
func _on_Craft_back_pressed() -> void:
	_close_new_save_panel()
