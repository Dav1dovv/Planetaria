# save_load_slot.gd
extends CanvasLayer

@onready var save_slots_container = $Panel/VBoxContainer/ScrollContainer/SaveSlots
@export var new_save_panel:    VBoxContainer
@export var player_name_input: LineEdit
@export var skin_selector:     PlayerSkin
@export var create_button:     Button
@export var save_slot_template: PackedScene

var current_slots: Array = []
var sort_by_date_desc: bool = true
var NameGen := SimpleNameGenerator.new()


func _ready() -> void:
	update_save_slots()
	new_save_panel.visible = false


func update_save_slots() -> void:
	for child in save_slots_container.get_children():
		child.queue_free()

	current_slots.clear()

	for slot_name in SaveLoad.get_save_slots():
		var data = SaveLoad.load_slot_meta(slot_name)
		if data.is_empty():
			push_warning("[SaveLoadSlot] Cannot read meta for slot: %s" % slot_name)
			continue

		data["slot_name"]      = slot_name
		data["last_save_time"] = data.get(
			"last_save_time",
			FileAccess.get_modified_time(SaveLoadSystem.SAVE_DIR + slot_name + "/" + SaveLoadSystem.SLOT_META_FILE)
		)
		current_slots.append(data)

	current_slots.sort_custom(_sort_by_date)
	_display_sorted_slots()


func _sort_by_date(a, b) -> bool:
	var da: int = a.get("last_save_time", 0)
	var db: int = b.get("last_save_time", 0)
	return da > db if sort_by_date_desc else da < db


func _display_sorted_slots() -> void:
	for child in save_slots_container.get_children():
		child.queue_free()

	for save_data in current_slots:
		var slot_button = save_slot_template.instantiate()
		save_slots_container.add_child(slot_button)
		slot_button.setup_slot(save_data)
		slot_button.pressed.connect(_on_save_slot_selected.bind(save_data["slot_name"]))


func _on_save_slot_selected(slot_name: String) -> void:
	if SaveLoad.load_save(slot_name):
		Global.scene_manager.change_scene("Vehana", Vector2.ZERO)


func _on_new_save_pressed() -> void:
	save_slots_container.visible = false
	%Blur.visible           = true
	new_save_panel.visible       = true
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		create_button.disabled = true


func _on_back_pressed() -> void:
	$"../CanvasLayer".visible = true
	visible = false


func _on_create_pressed() -> void:
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		return

	var slot = SaveLoad.create_new_save(
		player_name,
		skin_selector.skin_index,
		skin_selector.head_inex,
		"World"
	)

	if not slot.is_empty():
		update_save_slots()
		new_save_panel.visible       = false
		%Blur.visible           = false
		save_slots_container.visible = true
		player_name_input.clear()
	else:
		push_error("[SaveLoadSlot] Failed to create new save")


func _on_random_name_pressed() -> void:
	player_name_input.text = NameGen.generate_name()
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		create_button.disabled = true
	else:
		create_button.disabled = false

func _on_Craft_back_pressed() -> void:
	$"../CanvasLayer".visible = true
	new_save_panel.visible = false
	%Blur.visible = false
	save_slots_container.visible = true
	


func _on_line_edit_text_changed(new_text: String) -> void:
	var player_name := player_name_input.text.strip_edges()
	if player_name.is_empty():
		create_button.disabled = true
	else:
		create_button.disabled = false
